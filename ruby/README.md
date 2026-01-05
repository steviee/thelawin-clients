# Envoice Ruby SDK

Official Ruby SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'envoice'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install envoice
```

## Quick Start

```ruby
require 'envoice'

client = Envoice::Client.new(api_key: 'env_sandbox_xxx')

result = client.invoice
  .number('2026-001')
  .date('2026-01-15')
  .seller('Acme GmbH',
    vat_id: 'DE123456789',
    street: 'Hauptstraße 1',
    city: 'Berlin',
    postal_code: '10115',
    country: 'DE')
  .buyer('Customer AG',
    city: 'München',
    country: 'DE')
  .add_item('Consulting Services',
    quantity: 8,
    unit: 'HUR',
    unit_price: 150.00,
    vat_rate: 19.0)
  .logo_file('./logo.png', width_mm: 30)
  .template('minimal')
  .generate

if result.success?
  result.save_pdf('./invoices/2026-001.pdf')
  puts "Generated: #{result.filename}"
  puts "Validation: #{result.validation.profile}"
else
  result.errors.each do |error|
    puts "#{error[:path]}: #{error[:message]}"
  end
end
```

## Configuration

You can configure the client globally:

```ruby
Envoice.configure do |config|
  config.api_key = 'env_live_xxx'
  config.api_url = 'https://api.envoice.dev'  # optional
  config.timeout = 30                          # optional
end

# Then create clients without passing options
client = Envoice::Client.new
```

## API Reference

### Client

```ruby
client = Envoice::Client.new(
  api_key: 'env_sandbox_xxx',        # Required
  api_url: 'https://api.envoice.dev', # Optional
  timeout: 30                         # Optional (seconds)
)
```

### InvoiceBuilder

Fluent builder for creating invoices:

```ruby
client.invoice
  .number(value)                     # Invoice number (required)
  .date(value)                       # Date string or Date object (required)
  .due_date(value)                   # Date string or Date object
  .seller(name, **opts)              # Seller info (required)
  .buyer(name, **opts)               # Buyer info (required)
  .add_item(description, quantity:, unit_price:, **opts)
  .items(items)                      # Set all items at once
  .payment(iban:, bic:, terms:, reference:)
  .currency(value)                   # Default: 'EUR'
  .template('minimal' | 'classic' | 'compact')
  .locale(value)                     # 'de', 'en', 'fr', 'es', 'it'
  .logo_file(path, width_mm: nil)
  .logo_base64(base64, width_mm: nil)
  .footer_text(text)
  .accent_color(hex)                 # e.g., '#8b5cf6'
  .generate
```

### Types

```ruby
# Party (seller or buyer)
party = Envoice::Party.new(
  name: 'Company Name',
  street: 'Street Address',
  city: 'City',
  postal_code: '12345',
  country: 'DE',            # ISO 3166-1 alpha-2
  vat_id: 'DE123456789',
  email: 'email@example.com',
  phone: '+49 30 12345678'
)

# Line item
item = Envoice::LineItem.new(
  description: 'Service Description',
  quantity: 8.0,
  unit: 'HUR',              # UN/ECE Rec 20 code
  unit_price: 150.00,
  vat_rate: 19.0
)

# Payment info
payment = Envoice::PaymentInfo.new(
  iban: 'DE89370400440532013000',
  bic: 'COBADEFFXXX',
  terms: 'Net 30 days',
  reference: 'Invoice 2026-001'
)
```

### Common Unit Codes

| Code | Description |
|------|-------------|
| `C62` | Piece (default) |
| `HUR` | Hour |
| `DAY` | Day |
| `MON` | Month |
| `KGM` | Kilogram |
| `MTR` | Meter |
| `LTR` | Liter |

### Direct API Methods

```ruby
# Validate an existing PDF
result = client.validate(pdf_base64)

# Get account info (quota, plan)
account = client.account
puts account.plan       # => "starter"
puts account.remaining  # => 450
```

## Error Handling

```ruby
begin
  result = client.invoice.number('2026-001').generate

  unless result.success?
    # Validation errors (422)
    result.errors.each do |error|
      puts "#{error[:path]}: #{error[:message]}"
    end
  end
rescue Envoice::QuotaExceededError
  puts 'Quota exceeded, upgrade your plan'
rescue Envoice::NetworkError => e
  puts "Network error: #{e.message}"
rescue Envoice::ApiError => e
  puts "API error #{e.status_code}: #{e.message}"
end
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

```bash
bundle install
bundle exec rspec
```

## License

MIT
