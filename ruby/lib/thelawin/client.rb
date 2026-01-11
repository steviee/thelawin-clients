# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "fileutils"

module Thelawin
  # Main client for interacting with the thelawin.dev API
  class Client
    attr_reader :api_key, :base_url, :timeout, :environment

    # Create a new Thelawin Client
    # @param api_key [String] Your API key (env_sandbox_* or env_live_*)
    # @param environment [Symbol] :production or :preview (default: from config or :production)
    # @param base_url [String] Custom API base URL (overrides environment)
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    def initialize(api_key: nil, environment: nil, base_url: nil, timeout: nil)
      @api_key = api_key || Thelawin.configuration.api_key
      @environment = environment || Thelawin.configuration.environment
      @timeout = timeout || Thelawin.configuration.timeout

      # Use custom base_url if provided, otherwise use environment default
      @base_url = base_url || Thelawin::ENVIRONMENTS[@environment]

      raise ArgumentError, "API key is required" if @api_key.nil? || @api_key.empty?
    end

    # Check if using preview environment
    # @return [Boolean]
    def preview?
      @environment == :preview
    end

    # Check if using production environment
    # @return [Boolean]
    def production?
      @environment == :production
    end

    # Backwards compatibility alias
    alias api_url base_url

    # Create a new invoice builder with fluent API
    # @return [InvoiceBuilder]
    def invoice
      InvoiceBuilder.new(self)
    end

    # Pre-validate invoice data without generating PDF (dry-run)
    # @param request [Hash] Invoice request data
    # @return [DryRunResult]
    def validate(request)
      response = connection.post("/v1/validate") do |req|
        req.body = request.to_json
      end

      data = handle_response(response)
      DryRunResult.new(data)
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

    def validate_invoice_internal(request)
      response = connection.post("/v1/validate") do |req|
        req.body = request.to_json
      end

      handle_validate_response(response)
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
          pdf_base64: data["pdfBase64"],
          filename: data["filename"],
          format: FormatInfo.new(data["format"]),
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

    def handle_validate_response(response)
      case response.status
      when 200
        data = JSON.parse(response.body)
        DryRunResult.new(data)
      when 422
        data = JSON.parse(response.body)
        if data["details"]
          InvoiceFailure.new(errors: data["details"].map { |e| e.transform_keys(&:to_sym) })
        else
          DryRunResult.new(data)
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
      @connection ||= Faraday.new(url: @base_url) do |f|
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
