# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Thelawin::InvoiceBuilder do
  let(:client) { Thelawin::Client.new(api_key: "env_sandbox_test") }
  let(:builder) { client.invoice }

  describe "fluent interface" do
    it "returns self for method chaining" do
      expect(builder.number("2026-001")).to be(builder)
      expect(builder.date("2026-01-15")).to be(builder)
      expect(builder.due_date("2026-02-15")).to be(builder)
      expect(builder.currency("EUR")).to be(builder)
      expect(builder.template("minimal")).to be(builder)
      expect(builder.locale("de")).to be(builder)
      expect(builder.footer_text("Thanks!")).to be(builder)
      expect(builder.accent_color("#8b5cf6")).to be(builder)
      expect(builder.format("zugferd")).to be(builder)
      expect(builder.profile("en16931")).to be(builder)
      expect(builder.notes("Test notes")).to be(builder)
    end
  end

  describe "format-specific methods" do
    it "supports leitweg_id for XRechnung" do
      expect(builder.leitweg_id("04011000-12345-67")).to be(builder)
    end

    it "supports buyer_reference for Peppol" do
      expect(builder.buyer_reference("PO-12345")).to be(builder)
    end

    it "supports tipo_documento for FatturaPA" do
      expect(builder.tipo_documento("TD01")).to be(builder)
    end
  end

  describe "#date" do
    it "accepts string" do
      builder.date("2026-01-15")
    end

    it "accepts Date object" do
      builder.date(Date.new(2026, 1, 15))
    end
  end

  describe "#seller" do
    it "accepts name with keyword arguments" do
      result = builder.seller("Acme GmbH",
                              vat_id: "DE123456789",
                              street: "Hauptstraße 1",
                              city: "Berlin",
                              postal_code: "10115",
                              country: "DE")
      expect(result).to be(builder)
    end

    it "accepts Party object" do
      party = Thelawin::Party.new(name: "Acme GmbH", city: "Berlin")
      builder.seller(party)
    end

    it "accepts keyword arguments only" do
      result = builder.seller(name: "Acme GmbH", city: "Berlin", country: "DE")
      expect(result).to be(builder)
    end

    it "supports Peppol fields" do
      result = builder.seller("Acme Ltd",
                              vat_id: "GB123456789",
                              peppol_id: "0088:1234567890123",
                              city: "London",
                              country: "GB")
      expect(result).to be(builder)
    end

    it "supports FatturaPA fields" do
      result = builder.seller("Acme S.r.l.",
                              vat_id: "IT12345678901",
                              codice_fiscale: "12345678901",
                              city: "Milano",
                              country: "IT")
      expect(result).to be(builder)
    end
  end

  describe "#buyer" do
    it "accepts name with keyword arguments" do
      result = builder.buyer("Customer AG", city: "München", country: "DE")
      expect(result).to be(builder)
    end

    it "supports FatturaPA fields" do
      result = builder.buyer("Cliente S.p.A.",
                             codice_destinatario: "ABCDEFG",
                             pec: "cliente@pec.it",
                             city: "Roma",
                             country: "IT")
      expect(result).to be(builder)
    end
  end

  describe "#add_item" do
    it "adds items to the invoice" do
      builder.add_item("Consulting", quantity: 8, unit_price: 150.0, unit: "HUR", vat_rate: 19.0)
      builder.add_item("Development", quantity: 16, unit_price: 120.0)
    end

    it "accepts LineItem object" do
      item = Thelawin::LineItem.new(description: "Item", quantity: 1, unit_price: 100.0)
      builder.add_item(item)
    end

    it "supports FatturaPA natura field" do
      builder.add_item("Exempt Service", quantity: 1, unit_price: 100.0, vat_rate: 0, natura: "N2.2")
    end
  end

  describe "#items" do
    it "sets multiple items at once" do
      builder.items([
                      { description: "Item 1", quantity: 1, unit_price: 100.0 },
                      { description: "Item 2", quantity: 2, unit_price: 200.0 }
                    ])
    end
  end

  describe "#logo_base64" do
    it "sets logo with width" do
      result = builder.logo_base64("iVBORw0KGgoAAAANS...", width_mm: 30)
      expect(result).to be(builder)
    end
  end

  describe "#logo_file" do
    it "reads and encodes file" do
      Tempfile.create(["logo", ".png"]) do |f|
        f.write("\x89PNG\r\n\x1a\n")
        f.flush

        result = builder.logo_file(f.path, width_mm: 25)
        expect(result).to be(builder)
      end
    end
  end
end

RSpec.describe Thelawin::InvoiceSuccess do
  let(:format_info) do
    Thelawin::FormatInfo.new(
      "formatUsed" => "zugferd",
      "profile" => "EN16931",
      "version" => "2.3",
      "formatReason" => "eu_internal_trade",
      "warnings" => []
    )
  end

  let(:success) do
    described_class.new(
      pdf_base64: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
      filename: "invoice-2026-001.pdf",
      format: format_info
    )
  end

  describe "#success?" do
    it "returns true" do
      expect(success).to be_success
    end
  end

  describe "#format" do
    it "returns FormatInfo" do
      expect(success.format).to be_a(Thelawin::FormatInfo)
      expect(success.format.format_used).to eq("zugferd")
      expect(success.format.profile).to eq("EN16931")
    end
  end

  describe "#xml_only?" do
    it "returns false for PDF formats" do
      expect(success.xml_only?).to be false
    end

    it "returns true for XML-only formats" do
      xml_format = Thelawin::FormatInfo.new("formatUsed" => "fatturapa")
      xml_success = described_class.new(
        pdf_base64: "PHhtbD4...",
        filename: "fattura.xml",
        format: xml_format
      )
      expect(xml_success.xml_only?).to be true
    end
  end

  describe "#to_bytes" do
    it "decodes base64 to bytes" do
      bytes = success.to_bytes
      expect(bytes).to start_with("%PDF")
    end
  end

  describe "#to_data_url" do
    it "returns a PDF data URL for PDF formats" do
      data_url = success.to_data_url
      expect(data_url).to start_with("data:application/pdf;base64,")
    end

    it "returns an XML data URL for XML-only formats" do
      xml_format = Thelawin::FormatInfo.new("formatUsed" => "peppol")
      xml_success = described_class.new(
        pdf_base64: "PHhtbD4...",
        filename: "invoice.xml",
        format: xml_format
      )
      expect(xml_success.to_data_url).to start_with("data:application/xml;base64,")
    end
  end

  describe "#save / #save_pdf" do
    it "saves PDF to file" do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, "subdir", "invoice.pdf")
        success.save_pdf(file_path)

        expect(File.exist?(file_path)).to be true
        content = File.binread(file_path)
        expect(content).to start_with("%PDF")
      end
    end
  end
end

RSpec.describe Thelawin::InvoiceFailure do
  describe "#success?" do
    it "returns false" do
      failure = described_class.new(errors: [
                                      { path: "$.invoice.number", code: "REQUIRED", message: "Required" }
                                    ])
      expect(failure).not_to be_success
      expect(failure.errors.length).to eq(1)
    end
  end
end

RSpec.describe Thelawin::FormatInfo do
  describe "#pdf_with_xml?" do
    it "returns true for ZUGFeRD" do
      format = described_class.new("formatUsed" => "zugferd")
      expect(format.pdf_with_xml?).to be true
    end

    it "returns true for Factur-X" do
      format = described_class.new("formatUsed" => "facturx")
      expect(format.pdf_with_xml?).to be true
    end

    it "returns false for UBL" do
      format = described_class.new("formatUsed" => "ubl")
      expect(format.pdf_with_xml?).to be false
    end
  end

  describe "#xml_only?" do
    it "returns true for UBL" do
      format = described_class.new("formatUsed" => "ubl")
      expect(format.xml_only?).to be true
    end

    it "returns true for FatturaPA" do
      format = described_class.new("formatUsed" => "fatturapa")
      expect(format.xml_only?).to be true
    end

    it "returns false for ZUGFeRD" do
      format = described_class.new("formatUsed" => "zugferd")
      expect(format.xml_only?).to be false
    end
  end

  describe "#plain_pdf?" do
    it "returns true for PDF format" do
      format = described_class.new("formatUsed" => "pdf")
      expect(format.plain_pdf?).to be true
    end

    it "returns false for ZUGFeRD" do
      format = described_class.new("formatUsed" => "zugferd")
      expect(format.plain_pdf?).to be false
    end
  end

  describe "#warnings" do
    it "parses legal warnings" do
      format = described_class.new(
        "formatUsed" => "fatturapa",
        "warnings" => [
          { "code" => "IT_SDI_REQUIRED", "message" => "SDI submission required", "legalBasis" => "D.Lgs. 127/2015" }
        ]
      )
      expect(format.warnings.length).to eq(1)
      expect(format.warnings[0]).to be_a(Thelawin::LegalWarning)
      expect(format.warnings[0].code).to eq("IT_SDI_REQUIRED")
    end
  end
end
