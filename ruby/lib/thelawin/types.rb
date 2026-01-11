# frozen_string_literal: true

module Thelawin
  # Party (seller or buyer) information
  # Supports format-specific fields for Peppol and FatturaPA
  class Party
    attr_accessor :name, :street, :city, :postal_code, :country, :vat_id, :email, :phone,
                  :peppol_id, :codice_fiscale, :codice_destinatario, :pec

    # @param name [String] Company/person name (required)
    # @param street [String] Street address
    # @param city [String] City
    # @param postal_code [String] Postal/ZIP code
    # @param country [String] ISO 3166-1 alpha-2 country code (e.g., "DE", "IT")
    # @param vat_id [String] VAT identification number (e.g., "DE123456789")
    # @param email [String] Email address
    # @param phone [String] Phone number
    # @param peppol_id [String] Peppol participant ID (format: "EAS:ID", e.g., "0088:1234567890123")
    # @param codice_fiscale [String] Italian tax code (FatturaPA)
    # @param codice_destinatario [String] Italian SDI recipient code (FatturaPA, 7 chars or "0000000")
    # @param pec [String] Italian certified email (FatturaPA)
    def initialize(name:, street: nil, city: nil, postal_code: nil, country: nil, vat_id: nil,
                   email: nil, phone: nil, peppol_id: nil, codice_fiscale: nil,
                   codice_destinatario: nil, pec: nil)
      @name = name
      @street = street
      @city = city
      @postal_code = postal_code
      @country = country
      @vat_id = vat_id
      @email = email
      @phone = phone
      @peppol_id = peppol_id
      @codice_fiscale = codice_fiscale
      @codice_destinatario = codice_destinatario
      @pec = pec
    end

    def to_h
      {
        name: @name,
        street: @street,
        city: @city,
        postalCode: @postal_code,
        country: @country,
        vatId: @vat_id,
        email: @email,
        phone: @phone,
        peppolId: @peppol_id,
        codiceFiscale: @codice_fiscale,
        codiceDestinatario: @codice_destinatario,
        pec: @pec
      }.compact
    end
  end

  # Line item in an invoice
  # Supports format-specific fields for FatturaPA
  class LineItem
    attr_accessor :description, :quantity, :unit, :unit_price, :vat_rate, :natura

    # @param description [String] Item description (required)
    # @param quantity [Numeric] Quantity (required)
    # @param unit_price [Numeric] Net unit price (required)
    # @param unit [String] UN/ECE Rec 20 unit code (default: "C62" = piece)
    # @param vat_rate [Numeric] VAT rate in percent (default: 19.0)
    # @param natura [String] FatturaPA VAT exemption code (N1-N7, e.g., "N2.2" for non-taxable)
    def initialize(description:, quantity:, unit_price:, unit: "C62", vat_rate: 19.0, natura: nil)
      @description = description
      @quantity = quantity
      @unit = unit
      @unit_price = unit_price
      @vat_rate = vat_rate
      @natura = natura
    end

    def to_h
      result = {
        description: @description,
        quantity: @quantity,
        unit: @unit,
        unitPrice: @unit_price,
        vatRate: @vat_rate
      }
      result[:natura] = @natura if @natura
      result
    end
  end

  # Payment information
  class PaymentInfo
    attr_accessor :iban, :bic, :terms, :reference

    def initialize(iban: nil, bic: nil, terms: nil, reference: nil)
      @iban = iban
      @bic = bic
      @terms = terms
      @reference = reference
    end

    def to_h
      {
        iban: @iban,
        bic: @bic,
        terms: @terms,
        reference: @reference
      }.compact
    end
  end

  # Customization options for the invoice PDF
  class Customization
    attr_accessor :logo_base64, :logo_width_mm, :footer_text, :accent_color

    def initialize
      @logo_base64 = nil
      @logo_width_mm = nil
      @footer_text = nil
      @accent_color = nil
    end

    def to_h
      {
        logoBase64: @logo_base64,
        logoWidthMm: @logo_width_mm,
        footerText: @footer_text,
        accentColor: @accent_color
      }.compact
    end

    def empty?
      @logo_base64.nil? && @footer_text.nil? && @accent_color.nil?
    end
  end

  # Legal warning from format detection
  class LegalWarning
    attr_reader :code, :message, :legal_basis, :severity

    def initialize(data)
      @code = data["code"]
      @message = data["message"]
      @legal_basis = data["legalBasis"]
      @severity = data["severity"] || "warning"
    end

    def info?
      @severity == "info"
    end

    def warning?
      @severity == "warning"
    end
  end

  # Format information from the API response
  class FormatInfo
    attr_reader :format_used, :profile, :version, :format_reason, :warnings

    def initialize(data)
      @format_used = data["formatUsed"]
      @profile = data["profile"]
      @version = data["version"]
      @format_reason = data["formatReason"]
      @warnings = (data["warnings"] || []).map { |w| LegalWarning.new(w) }
    end

    # Check if format is a PDF with embedded XML
    def pdf_with_xml?
      %w[zugferd facturx xrechnung].include?(@format_used)
    end

    # Check if format is XML-only (no visual PDF)
    def xml_only?
      %w[ubl cii peppol fatturapa].include?(@format_used)
    end

    # Check if format is plain PDF (no XML)
    def plain_pdf?
      @format_used == "pdf"
    end
  end

  # Pre-validation result (dry-run without PDF generation)
  class DryRunResult
    attr_reader :valid, :format, :errors

    def initialize(data)
      @valid = data["valid"]
      @format = FormatInfo.new(data["format"]) if data["format"]
      @errors = data["errors"] || []
    end

    def valid?
      @valid
    end
  end

  # Account information from the API
  class AccountInfo
    attr_reader :remaining, :plan, :overage_count, :overage_allowed, :warning

    def initialize(data)
      @remaining = data["remaining"]
      @plan = data["plan"]
      @overage_count = data["overageCount"]
      @overage_allowed = data["overageAllowed"]
      @warning = data["warning"]
    end
  end
end
