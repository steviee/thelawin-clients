# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "envoice"
  spec.version = "0.1.0"
  spec.authors = ["envoice.dev"]
  spec.email = ["support@envoice.dev"]

  spec.summary = "Official Ruby SDK for envoice.dev"
  spec.description = "Generate ZUGFeRD/Factur-X compliant invoices with a simple API"
  spec.homepage = "https://envoice.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/steviee/envoice-clients"
  spec.metadata["changelog_uri"] = "https://github.com/steviee/envoice-clients/blob/main/ruby/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
