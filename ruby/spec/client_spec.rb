# frozen_string_literal: true

require "spec_helper"

RSpec.describe Thelawin::Client do
  let(:api_key) { "env_sandbox_test" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#initialize" do
    it "requires an API key" do
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, "API key is required")
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, "API key is required")
    end

    it "creates a client with valid API key" do
      expect(client.api_key).to eq(api_key)
    end

    it "uses default options" do
      expect(client.base_url).to eq("https://api.thelawin.dev")
      expect(client.environment).to eq(:production)
      expect(client.timeout).to eq(30)
    end

    it "accepts custom options" do
      custom_client = described_class.new(
        api_key: api_key,
        base_url: "https://custom.api.url",
        timeout: 60
      )
      expect(custom_client.base_url).to eq("https://custom.api.url")
      expect(custom_client.timeout).to eq(60)
    end

    it "uses configuration defaults" do
      Thelawin.configure do |config|
        config.api_key = "config_api_key"
        config.environment = :preview
        config.timeout = 45
      end

      config_client = described_class.new
      expect(config_client.api_key).to eq("config_api_key")
      expect(config_client.base_url).to eq("https://api.preview.thelawin.dev:3080")
      expect(config_client.environment).to eq(:preview)
      expect(config_client.timeout).to eq(45)
    end

    it "accepts environment parameter" do
      preview_client = described_class.new(api_key: api_key, environment: :preview)
      expect(preview_client.base_url).to eq("https://api.preview.thelawin.dev:3080")
      expect(preview_client.environment).to eq(:preview)
      expect(preview_client).to be_preview
      expect(preview_client).not_to be_production

      prod_client = described_class.new(api_key: api_key, environment: :production)
      expect(prod_client.base_url).to eq("https://api.thelawin.dev")
      expect(prod_client).to be_production
      expect(prod_client).not_to be_preview
    end

    it "custom base_url overrides environment" do
      custom_client = described_class.new(
        api_key: api_key,
        environment: :preview,
        base_url: "http://localhost:8080"
      )
      expect(custom_client.base_url).to eq("http://localhost:8080")
      expect(custom_client.environment).to eq(:preview)
    end
  end

  describe "#invoice" do
    it "returns an InvoiceBuilder" do
      expect(client.invoice).to be_a(Thelawin::InvoiceBuilder)
    end
  end

  describe "#generate" do
    let(:success_response) do
      {
        pdfBase64: "JVBERi0xLjQK...",
        filename: "invoice-2026-001.pdf",
        format: {
          formatUsed: "zugferd",
          profile: "EN16931",
          version: "2.3",
          formatReason: "eu_internal_trade",
          warnings: []
        },
        account: {
          remaining: 499,
          plan: "starter"
        }
      }
    end

    it "returns success on valid request" do
      stub_request(:post, "https://api.thelawin.dev/v1/generate")
        .with(headers: { "X-API-Key" => api_key })
        .to_return(status: 200, body: success_response.to_json, headers: { "Content-Type" => "application/json" })

      result = client.invoice
                     .number("2026-001")
                     .date("2026-01-15")
                     .seller("Acme GmbH", vat_id: "DE123456789", city: "Berlin", country: "DE")
                     .buyer("Customer AG", city: "München", country: "DE")
                     .add_item("Consulting", quantity: 8, unit_price: 150.0)
                     .generate

      expect(result).to be_success
      expect(result.pdf_base64).to eq("JVBERi0xLjQK...")
      expect(result.filename).to eq("invoice-2026-001.pdf")
      expect(result.format.format_used).to eq("zugferd")
      expect(result.format.profile).to eq("EN16931")
      expect(result.account.remaining).to eq(499)
    end

    it "returns validation errors on 422" do
      stub_request(:post, "https://api.thelawin.dev/v1/generate")
        .to_return(
          status: 422,
          body: {
            error: "validation_error",
            message: "Validation failed",
            details: [
              { path: "$.invoice.seller.vatId", code: "INVALID_FORMAT", message: "Invalid VAT ID format" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.invoice
                     .number("2026-001")
                     .date("2026-01-15")
                     .seller("Acme GmbH", vat_id: "INVALID", city: "Berlin", country: "DE")
                     .buyer("Customer AG")
                     .add_item("Consulting", quantity: 8, unit_price: 150.0)
                     .generate

      expect(result).not_to be_success
      expect(result.errors.length).to eq(1)
      expect(result.errors[0][:path]).to eq("$.invoice.seller.vatId")
    end

    it "raises QuotaExceededError on 402" do
      stub_request(:post, "https://api.thelawin.dev/v1/generate")
        .to_return(
          status: 402,
          body: { error: "quota_exceeded", message: "Monthly quota exceeded" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect do
        client.invoice
              .number("2026-001")
              .date("2026-01-15")
              .seller("Acme GmbH", vat_id: "DE123456789")
              .buyer("Customer AG")
              .add_item("Consulting", quantity: 8, unit_price: 150.0)
              .generate
      end.to raise_error(Thelawin::QuotaExceededError, "Monthly quota exceeded")
    end

    it "raises ApiError on other HTTP errors" do
      stub_request(:post, "https://api.thelawin.dev/v1/generate")
        .to_return(
          status: 500,
          body: { error: "internal_error", message: "Internal server error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect do
        client.invoice
              .number("2026-001")
              .date("2026-01-15")
              .seller("Acme GmbH", vat_id: "DE123456789")
              .buyer("Customer AG")
              .add_item("Consulting", quantity: 8, unit_price: 150.0)
              .generate
      end.to raise_error(Thelawin::ApiError) do |error|
        expect(error.status_code).to eq(500)
        expect(error.code).to eq("internal_error")
      end
    end

    it "validates required fields before API call" do
      result = client.invoice.generate

      expect(result).not_to be_success
      expect(result.errors.any? { |e| e[:path] == "$.invoice.number" }).to be true
      expect(result.errors.any? { |e| e[:path] == "$.invoice.date" }).to be true
      expect(result.errors.any? { |e| e[:path] == "$.invoice.seller" }).to be true
      expect(result.errors.any? { |e| e[:path] == "$.invoice.buyer" }).to be true
      expect(result.errors.any? { |e| e[:path] == "$.invoice.items" }).to be true
    end
  end

  describe "#validate (pre-validation)" do
    it "returns dry-run result" do
      stub_request(:post, "https://api.thelawin.dev/v1/validate")
        .to_return(
          status: 200,
          body: {
            valid: true,
            format: {
              formatUsed: "zugferd",
              profile: "EN16931",
              version: "2.3"
            },
            errors: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.validate({ invoice: { number: "2026-001" } })

      expect(result).to be_valid
      expect(result.format.format_used).to eq("zugferd")
    end
  end

  describe "#account" do
    it "returns account info" do
      stub_request(:get, "https://api.thelawin.dev/v1/account")
        .to_return(
          status: 200,
          body: { plan: "starter", remaining: 450, used: 50, limit: 500 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      account = client.account

      expect(account.plan).to eq("starter")
      expect(account.remaining).to eq(450)
    end
  end
end
