# frozen_string_literal: true

require_relative "envoice/version"
require_relative "envoice/errors"
require_relative "envoice/types"
require_relative "envoice/invoice"
require_relative "envoice/client"

# Official Ruby SDK for envoice.dev
# Generate ZUGFeRD/Factur-X compliant invoices with a simple API
module Envoice
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
  end

  # Configuration class for default settings
  class Configuration
    attr_accessor :api_key, :api_url, :timeout

    def initialize
      @api_key = nil
      @api_url = "https://api.envoice.dev"
      @timeout = 30
    end
  end
end
