# frozen_string_literal: true

require "base64"
require "date"

module Thelawin
  # Result object returned after successful invoice generation
  class InvoiceSuccess
    attr_reader :pdf_base64, :filename, :format, :account

    def initialize(pdf_base64:, filename:, format:, account: nil)
      @pdf_base64 = pdf_base64
      @filename = filename
      @format = format
      @account = account
    end

    # @return [Boolean] Always true
    def success?
      true
    end

    # Save the output to a file (PDF or XML depending on format)
    # @param file_path [String] Path to save the file
    def save(file_path)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.binwrite(file_path, to_bytes)
    end

    # Alias for backwards compatibility
    alias save_pdf save

    # Get the output as bytes
    # @return [String] Binary data (PDF or XML)
    def to_bytes
      Base64.decode64(@pdf_base64)
    end

    # Get the output as a data URL
    # @return [String] Data URL
    def to_data_url
      mime_type = @format.xml_only? ? "application/xml" : "application/pdf"
      "data:#{mime_type};base64,#{@pdf_base64}"
    end

    # Check if the output is XML-only (no visual PDF)
    def xml_only?
      @format.xml_only?
    end

    # Get legal warnings from format detection
    # @return [Array<LegalWarning>]
    def warnings
      @format.warnings
    end
  end

  # Result object returned when invoice generation fails
  class InvoiceFailure
    attr_reader :errors

    def initialize(errors:)
      @errors = errors
    end

    # @return [Boolean] Always false
    def success?
      false
    end
  end

  # Fluent builder for creating invoices
  class InvoiceBuilder
    def initialize(client)
      @client = client
      @format = "auto"
      @profile = "en16931"
      @number = nil
      @date = nil
      @due_date = nil
      @seller = nil
      @buyer = nil
      @items = []
      @payment = nil
      @currency = "EUR"
      @notes = nil
      @leitweg_id = nil
      @buyer_reference = nil
      @tipo_documento = nil
      @template = "minimal"
      @locale = "en"
      @customization = Customization.new
    end

    # Set the output format
    # @param value [String] "auto", "zugferd", "facturx", "xrechnung", "pdf", "ubl", "cii", "peppol", "fatturapa"
    # @return [self]
    def format(value)
      @format = value
      self
    end

    # Set the profile (for ZUGFeRD/Factur-X formats)
    # @param value [String] "minimum", "basic_wl", "basic", "en16931", "extended"
    # @return [self]
    def profile(value)
      @profile = value
      self
    end

    # Set the invoice number
    # @param value [String]
    # @return [self]
    def number(value)
      @number = value
      self
    end

    # Set the invoice date
    # @param value [String, Date] ISO format YYYY-MM-DD or Date object
    # @return [self]
    def date(value)
      @date = value.is_a?(Date) ? value.iso8601 : value
      self
    end

    # Set the due date
    # @param value [String, Date] ISO format YYYY-MM-DD or Date object
    # @return [self]
    def due_date(value)
      @due_date = value.is_a?(Date) ? value.iso8601 : value
      self
    end

    # Set the seller information
    # @param name_or_party [String, Party] Name or Party object
    # @param opts [Hash] Optional attributes (when name is a String)
    # @return [self]
    def seller(name_or_party = nil, **opts)
      if name_or_party.is_a?(Party)
        @seller = name_or_party
      elsif name_or_party.nil? && opts.any?
        @seller = Party.new(**opts)
      else
        @seller = Party.new(name: name_or_party, **opts)
      end
      self
    end

    # Set the buyer information
    # @param name_or_party [String, Party] Name or Party object
    # @param opts [Hash] Optional attributes (when name is a String)
    # @return [self]
    def buyer(name_or_party = nil, **opts)
      if name_or_party.is_a?(Party)
        @buyer = name_or_party
      elsif name_or_party.nil? && opts.any?
        @buyer = Party.new(**opts)
      else
        @buyer = Party.new(name: name_or_party, **opts)
      end
      self
    end

    # Add a line item
    # @param description [String, LineItem] Description or LineItem object
    # @param quantity [Numeric]
    # @param unit_price [Numeric]
    # @param opts [Hash] Optional attributes (unit, vat_rate, natura)
    # @return [self]
    def add_item(description = nil, quantity: nil, unit_price: nil, **opts)
      if description.is_a?(LineItem)
        @items << description
      elsif description.nil? && opts.any?
        @items << LineItem.new(**opts)
      else
        @items << LineItem.new(description: description, quantity: quantity, unit_price: unit_price, **opts)
      end
      self
    end

    # Set multiple line items at once
    # @param items [Array<LineItem, Hash>]
    # @return [self]
    def items(items)
      @items = items.map do |item|
        item.is_a?(LineItem) ? item : LineItem.new(**item)
      end
      self
    end

    # Set payment information
    # @param opts [Hash] Payment attributes
    # @return [self]
    def payment(**opts)
      @payment = opts.is_a?(PaymentInfo) ? opts : PaymentInfo.new(**opts)
      self
    end

    # Set the currency
    # @param value [String] Currency code (default: EUR)
    # @return [self]
    def currency(value)
      @currency = value
      self
    end

    # Set invoice notes/comments
    # @param value [String]
    # @return [self]
    def notes(value)
      @notes = value
      self
    end

    # Set Leitweg-ID for XRechnung (German B2G)
    # @param value [String] e.g., "04011000-12345-67"
    # @return [self]
    def leitweg_id(value)
      @leitweg_id = value
      self
    end

    # Set buyer reference for Peppol
    # @param value [String] Purchase order reference
    # @return [self]
    def buyer_reference(value)
      @buyer_reference = value
      self
    end

    # Set document type for FatturaPA
    # @param value [String] "TD01" (invoice), "TD04" (credit note), etc.
    # @return [self]
    def tipo_documento(value)
      @tipo_documento = value
      self
    end

    # Set the template style
    # @param value [String] "minimal", "classic", or "compact"
    # @return [self]
    def template(value)
      @template = value
      self
    end

    # Set the locale
    # @param value [String] "de", "en", "fr", "es", "it"
    # @return [self]
    def locale(value)
      @locale = value
      self
    end

    # Set logo from file
    # @param file_path [String] Path to logo file
    # @param width_mm [Integer, nil] Logo width in mm
    # @return [self]
    def logo_file(file_path, width_mm: nil)
      content = File.binread(file_path)
      @customization.logo_base64 = Base64.strict_encode64(content)
      @customization.logo_width_mm = width_mm if width_mm
      self
    end

    # Set logo from Base64 string
    # @param base64 [String] Base64 encoded logo
    # @param width_mm [Integer, nil] Logo width in mm
    # @return [self]
    def logo_base64(base64, width_mm: nil)
      @customization.logo_base64 = base64
      @customization.logo_width_mm = width_mm if width_mm
      self
    end

    # Set footer text
    # @param text [String]
    # @return [self]
    def footer_text(text)
      @customization.footer_text = text
      self
    end

    # Set accent color
    # @param color [String] Hex color code
    # @return [self]
    def accent_color(color)
      @customization.accent_color = color
      self
    end

    # Generate the invoice
    # @return [InvoiceSuccess, InvoiceFailure]
    def generate
      errors = validate_required_fields
      return InvoiceFailure.new(errors: errors) unless errors.empty?

      request = build_request
      @client.send(:generate_invoice_internal, request)
    end

    # Validate without generating (dry-run)
    # @return [DryRunResult]
    def validate
      errors = validate_required_fields
      return InvoiceFailure.new(errors: errors) unless errors.empty?

      request = build_request
      @client.send(:validate_invoice_internal, request)
    end

    private

    def validate_required_fields
      errors = []
      errors << { path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required" } unless @number
      errors << { path: "$.invoice.date", code: "REQUIRED", message: "Invoice date is required" } unless @date
      errors << { path: "$.invoice.seller", code: "REQUIRED", message: "Seller information is required" } unless @seller
      errors << { path: "$.invoice.buyer", code: "REQUIRED", message: "Buyer information is required" } unless @buyer
      errors << { path: "$.invoice.items", code: "REQUIRED", message: "At least one line item is required" } if @items.empty?
      errors
    end

    def build_request
      invoice_data = {
        number: @number,
        date: @date,
        dueDate: @due_date,
        seller: @seller.to_h,
        buyer: @buyer.to_h,
        items: @items.map(&:to_h),
        payment: @payment&.to_h,
        currency: @currency,
        notes: @notes,
        leitwegId: @leitweg_id,
        buyerReference: @buyer_reference,
        tipoDocumento: @tipo_documento
      }.compact

      {
        format: @format,
        profile: @profile,
        template: @template,
        locale: @locale,
        invoice: invoice_data,
        customization: @customization.empty? ? nil : @customization.to_h
      }.compact
    end
  end
end
