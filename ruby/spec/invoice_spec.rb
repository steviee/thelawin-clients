# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Envoice::InvoiceBuilder do
  let(:client) { Envoice::Client.new(api_key: "env_sandbox_test") }
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
      party = Envoice::Party.new(name: "Acme GmbH", city: "Berlin")
      builder.seller(party)
    end
  end

  describe "#buyer" do
    it "accepts name with keyword arguments" do
      result = builder.buyer("Customer AG", city: "München", country: "DE")
      expect(result).to be(builder)
    end
  end

  describe "#add_item" do
    it "adds items to the invoice" do
      builder.add_item("Consulting", quantity: 8, unit_price: 150.0, unit: "HUR", vat_rate: 19.0)
      builder.add_item("Development", quantity: 16, unit_price: 120.0)
    end

    it "accepts LineItem object" do
      item = Envoice::LineItem.new(description: "Item", quantity: 1, unit_price: 100.0)
      builder.add_item(item)
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

RSpec.describe Envoice::InvoiceSuccess do
  let(:success) do
    described_class.new(
      pdf_base64: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
      filename: "invoice-2026-001.pdf",
      validation: Envoice::ValidationResult.new(
        "status" => "valid",
        "profile" => "EN16931",
        "version" => "2.3.2"
      )
    )
  end

  describe "#success?" do
    it "returns true" do
      expect(success).to be_success
    end
  end

  describe "#to_bytes" do
    it "decodes base64 to bytes" do
      bytes = success.to_bytes
      expect(bytes).to start_with("%PDF")
    end
  end

  describe "#to_data_url" do
    it "returns a data URL" do
      data_url = success.to_data_url
      expect(data_url).to start_with("data:application/pdf;base64,")
    end
  end

  describe "#save_pdf" do
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

RSpec.describe Envoice::InvoiceFailure do
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
