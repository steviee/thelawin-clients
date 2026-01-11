# frozen_string_literal: true

require_relative "thelawin/version"
require_relative "thelawin/errors"
require_relative "thelawin/types"
require_relative "thelawin/invoice"
require_relative "thelawin/client"

# Official Ruby SDK for thelawin.dev
# Generate ZUGFeRD/Factur-X/XRechnung/Peppol/FatturaPA compliant invoices with a simple API
module Thelawin
  # Supported invoice formats
  FORMATS = %w[auto zugferd facturx xrechnung pdf ubl cii peppol fatturapa].freeze

  # Supported profiles (ZUGFeRD/Factur-X)
  PROFILES = %w[minimum basic_wl basic en16931 extended].freeze

  # Supported templates
  TEMPLATES = %w[minimal classic compact].freeze

  # Supported locales
  LOCALES = %w[de en fr es it].freeze

  # Environment URLs
  ENVIRONMENTS = {
    production: "https://api.thelawin.dev",
    preview: "https://api.preview.thelawin.dev:3080"
  }.freeze

  class << self
    # Configure the default client
    # @yield [config] Configuration block
    def configure
      yield(configuration)
    end

    # Get the configuration
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Reset configuration to defaults
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Get a default client instance
    # @return [Client]
    def client
      @client ||= Client.new
    end

    # Reset the default client
    def reset_client!
      @client = nil
    end
  end

  # Configuration class for default settings
  class Configuration
    attr_accessor :api_key, :timeout
    attr_reader :environment

    def initialize
      @api_key = nil
      @environment = :production
      @base_url = nil  # nil means use environment default
      @timeout = 30
    end

    # Set the environment (:production or :preview)
    # @param env [Symbol] :production or :preview
    def environment=(env)
      env = env.to_sym
      unless ENVIRONMENTS.key?(env)
        raise ArgumentError, "Invalid environment: #{env}. Must be :production or :preview"
      end

      @environment = env
      @base_url = nil  # Reset custom URL when switching environments
    end

    # Get the base URL (custom or environment default)
    # @return [String]
    def base_url
      @base_url || ENVIRONMENTS[@environment]
    end

    # Set a custom base URL (overrides environment)
    # @param url [String]
    def base_url=(url)
      @base_url = url
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

    # Alias for backwards compatibility
    alias api_url base_url
    alias api_url= base_url=
  end
end
