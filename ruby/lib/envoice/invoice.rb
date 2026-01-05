# frozen_string_literal: true

require "base64"
require "date"

module Envoice
  # Result object returned after successful invoice generation
  class InvoiceSuccess
    attr_reader :pdf_base64, :filename, :validation, :account

    def initialize(pdf_base64:, filename:, validation:, account: nil)
      @pdf_base64 = pdf_base64
      @filename = filename
      @validation = validation
      @account = account
    end

    # @return [Boolean] Always true
    def success?
      true
    end

    # Save the PDF to a file
    # @param file_path [String] Path to save the PDF
    def save_pdf(file_path)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.binwrite(file_path, to_bytes)
    end

    # Get the PDF as bytes
    # @return [String] Binary PDF data
    def to_bytes
      Base64.decode64(@pdf_base64)
    end

    # Get the PDF as a data URL
    # @return [String] Data URL
    def to_data_url
      "data:application/pdf;base64,#{@pdf_base64}"
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
      @number = nil
      @date = nil
      @due_date = nil
      @seller = nil
      @buyer = nil
      @items = []
      @payment = nil
      @currency = "EUR"
      @template = "minimal"
      @locale = "en"
      @customization = Customization.new
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
    # @param name [String]
    # @param opts [Hash] Optional attributes
    # @return [self]
    def seller(name = nil, **opts)
      if name.is_a?(Party)
        @seller = name
      else
        @seller = Party.new(name: name, **opts)
      end
      self
    end

    # Set the buyer information
    # @param name [String]
    # @param opts [Hash] Optional attributes
    # @return [self]
    def buyer(name = nil, **opts)
      if name.is_a?(Party)
        @buyer = name
      else
        @buyer = Party.new(name: name, **opts)
      end
      self
    end

    # Add a line item
    # @param description [String]
    # @param quantity [Numeric]
    # @param unit_price [Numeric]
    # @param opts [Hash] Optional attributes (unit, vat_rate)
    # @return [self]
    def add_item(description = nil, quantity: nil, unit_price: nil, **opts)
      if description.is_a?(LineItem)
        @items << description
      else
        @items << LineItem.new(description: description, quantity: quantity, unit_price: unit_price, **opts)
      end
      self
    end

    # Set multiple line items at once
    # @param items [Array<LineItem>]
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
      {
        template: @template,
        locale: @locale,
        invoice: {
          number: @number,
          date: @date,
          dueDate: @due_date,
          seller: @seller.to_h,
          buyer: @buyer.to_h,
          items: @items.map(&:to_h),
          payment: @payment&.to_h,
          currency: @currency
        }.compact,
        customization: @customization.empty? ? nil : @customization.to_h
      }.compact
    end
  end
end
