# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "thelawin"
  spec.version = "0.2.0"
  spec.authors = ["thelawin.dev"]
  spec.email = ["support@thelawin.dev"]

  spec.summary = "Official Ruby SDK for thelawin.dev"
  spec.description = "Generate ZUGFeRD/Factur-X/XRechnung/Peppol/FatturaPA compliant invoices with a simple API"
  spec.homepage = "https://thelawin.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/steviee/thelawin-clients"
  spec.metadata["changelog_uri"] = "https://github.com/steviee/thelawin-clients/blob/main/ruby/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://docs.thelawin.dev/sdks/ruby"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2"  # Required for Ruby 3.4+
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
