# frozen_string_literal: true

module Envoice
  # Party (seller or buyer) information
  class Party
    attr_accessor :name, :street, :city, :postal_code, :country, :vat_id, :email, :phone

    def initialize(name:, street: nil, city: nil, postal_code: nil, country: nil, vat_id: nil, email: nil, phone: nil)
      @name = name
      @street = street
      @city = city
      @postal_code = postal_code
      @country = country
      @vat_id = vat_id
      @email = email
      @phone = phone
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
        phone: @phone
      }.compact
    end
  end

  # Line item in an invoice
  class LineItem
    attr_accessor :description, :quantity, :unit, :unit_price, :vat_rate

    def initialize(description:, quantity:, unit_price:, unit: "C62", vat_rate: 19.0)
      @description = description
      @quantity = quantity
      @unit = unit
      @unit_price = unit_price
      @vat_rate = vat_rate
    end

    def to_h
      {
        description: @description,
        quantity: @quantity,
        unit: @unit,
        unitPrice: @unit_price,
        vatRate: @vat_rate
      }
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

  # Validation result from the API
  class ValidationResult
    attr_reader :status, :profile, :version, :warnings

    def initialize(data)
      @status = data["status"]
      @profile = data["profile"]
      @version = data["version"]
      @warnings = data["warnings"]
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
