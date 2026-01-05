# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "fileutils"

module Envoice
  # Main client for interacting with the envoice.dev API
  class Client
    attr_reader :api_key, :api_url, :timeout

    # Create a new EnvoiceClient
    # @param api_key [String] Your API key (env_sandbox_* or env_live_*)
    # @param api_url [String] API base URL (default: https://api.envoice.dev)
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    def initialize(api_key: nil, api_url: nil, timeout: nil)
      @api_key = api_key || Envoice.configuration.api_key
      @api_url = api_url || Envoice.configuration.api_url
      @timeout = timeout || Envoice.configuration.timeout

      raise ArgumentError, "API key is required" if @api_key.nil? || @api_key.empty?
    end

    # Create a new invoice builder with fluent API
    # @return [InvoiceBuilder]
    def invoice
      InvoiceBuilder.new(self)
    end

    # Validate an existing PDF for ZUGFeRD/Factur-X compliance
    # @param pdf_base64 [String] Base64 encoded PDF
    # @return [Hash] Validation result
    def validate(pdf_base64)
      response = connection.post("/v1/validate") do |req|
        req.body = { pdf_base64: pdf_base64 }.to_json
      end

      handle_response(response)
    end

    # Get account information (quota, plan, etc.)
    # @return [AccountInfo]
    def account
      response = connection.get("/v1/account")
      data = handle_response(response)
      AccountInfo.new(data)
    end

    private

    def generate_invoice_internal(request)
      response = connection.post("/v1/generate") do |req|
        req.body = request.to_json
      end

      handle_generate_response(response)
    rescue Faraday::TimeoutError
      raise NetworkError, "Request timeout"
    rescue Faraday::ConnectionFailed => e
      raise NetworkError.new("Connection failed", e)
    end

    def handle_generate_response(response)
      case response.status
      when 200
        data = JSON.parse(response.body)
        InvoiceSuccess.new(
          pdf_base64: data["pdf_base64"],
          filename: data["filename"],
          validation: ValidationResult.new(data["validation"]),
          account: data["account"] ? AccountInfo.new(data["account"]) : nil
        )
      when 402
        data = JSON.parse(response.body)
        raise QuotaExceededError, data["message"] || "Quota exceeded"
      when 422
        data = JSON.parse(response.body)
        if data["details"]
          InvoiceFailure.new(errors: data["details"].map { |e| e.transform_keys(&:to_sym) })
        else
          raise ApiError.new(data["message"] || data["error"], response.status, data["error"])
        end
      else
        data = JSON.parse(response.body) rescue { "error" => "unknown_error", "message" => "HTTP #{response.status}" }
        raise ApiError.new(data["message"] || data["error"], response.status, data["error"])
      end
    end

    def handle_response(response)
      unless response.success?
        data = JSON.parse(response.body) rescue { "error" => "unknown_error" }
        raise ApiError.new(data["message"] || data["error"], response.status, data["error"])
      end

      JSON.parse(response.body)
    end

    def connection
      @connection ||= Faraday.new(url: @api_url) do |f|
        f.request :retry, max: 2, interval: 0.5
        f.headers["Content-Type"] = "application/json"
        f.headers["X-API-Key"] = @api_key
        f.options.timeout = @timeout
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end
  end
end
