# frozen_string_literal: true

module Thelawin
  # Base error class for all Thelawin SDK errors
  class Error < StandardError; end

  # Error raised when the API returns validation errors
  class ValidationError < Error
    attr_reader :errors, :status_code

    def initialize(errors, status_code = 422)
      @errors = errors
      @status_code = status_code
      message = errors.map { |e| "#{e[:path]}: #{e[:message]}" }.join("; ")
      super("Validation failed: #{message}")
    end

    # Get a user-friendly error message
    # @return [String]
    def to_user_message
      @errors.map { |e| "- #{e[:path]}: #{e[:message]}" }.join("\n")
    end
  end

  # Error raised when the API returns an HTTP error
  class ApiError < Error
    attr_reader :status_code, :code

    def initialize(message, status_code, code = nil)
      @status_code = status_code
      @code = code
      super(message)
    end
  end

  # Error raised when a network request fails
  class NetworkError < Error
    attr_reader :cause

    def initialize(message, cause = nil)
      @cause = cause
      super(message)
    end
  end

  # Error raised when quota is exceeded
  class QuotaExceededError < ApiError
    def initialize(message)
      super(message, 402, "quota_exceeded")
    end
  end
end
