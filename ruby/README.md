# Thelawin Ruby SDK

Official Ruby SDK for [thelawin.dev](https://thelawin.dev) - Generate ZUGFeRD/Factur-X/XRechnung/Peppol/FatturaPA compliant invoices with a simple API.

## Installation

Add to your Gemfile:

```ruby
gem 'thelawin', '~> 0.2'
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install thelawin
```

## Quick Start

```ruby
require 'thelawin'

client = Thelawin::Client.new(api_key: 'env_sandbox_xxx')

result = client.invoice
  .number('2026-001')
  .date('2026-01-15')
  .seller(
    name: 'Acme GmbH',
    vat_id: 'DE123456789',
    street: 'Hauptstraße 1',
    city: 'Berlin',
    postal_code: '10115',
    country: 'DE'
  )
  .buyer(
    name: 'Customer AG',
    city: 'München',
    country: 'DE'
  )
  .add_item(
    description: 'Consulting Services',
    quantity: 8,
    unit: 'HUR',
    unit_price: 150.00,
    vat_rate: 19.0
  )
  .template('minimal')
  .generate

if result.success?
  result.save_pdf('./invoices/2026-001.pdf')
  puts "Generated: #{result.filename}"
  puts "Format: #{result.format.format_used}"  # => "zugferd"
else
  result.errors.each do |error|
    puts "#{error[:path]}: #{error[:message]}"
  end
end
```

## Configuration

You can configure the client globally:

```ruby
Thelawin.configure do |config|
  config.api_key = 'env_live_xxx'
  config.environment = :production  # :production or :preview
  config.timeout = 30               # optional
end

# Then create clients without passing options
client = Thelawin::Client.new

# Or use the global client directly
Thelawin.client.invoice.number('2026-001')...
```

### Environments

| Environment | URL | Description |
|-------------|-----|-------------|
| `:production` | `https://api.thelawin.dev` | Production API (default) |
| `:preview` | `https://api.preview.thelawin.dev:3080` | Preview/staging API |

```ruby
# Use preview environment globally
Thelawin.configure do |config|
  config.api_key = 'env_sandbox_xxx'
  config.environment = :preview
end

# Or per-client
client = Thelawin::Client.new(
  api_key: 'env_sandbox_xxx',
  environment: :preview
)

# Check environment
client.preview?     # => true
client.production?  # => false

# Custom URL (overrides environment)
client = Thelawin::Client.new(
  api_key: 'env_sandbox_xxx',
  base_url: 'http://localhost:8080'
)
```

## Supported Formats

| Format | Description | Output |
|--------|-------------|--------|
| `auto` | Auto-detect based on countries (default) | PDF or XML |
| `zugferd` | ZUGFeRD 2.3 (Germany/EU) | PDF/A-3 + CII XML |
| `facturx` | Factur-X 1.0 (France) | PDF/A-3 + CII XML |
| `xrechnung` | XRechnung 3.0 (German B2G) | PDF/A-3 + UBL XML |
| `pdf` | Plain PDF without XML | PDF |
| `ubl` | UBL 2.1 Invoice | XML only |
| `cii` | UN/CEFACT CII | XML only |
| `peppol` | Peppol BIS Billing 3.0 | XML only |
| `fatturapa` | FatturaPA 1.2.1 (Italy) | XML only |

## API Reference

### InvoiceBuilder

Fluent builder for creating invoices:

```ruby
client.invoice
  # Required fields
  .number(value)                     # Invoice number
  .date(value)                       # Date string or Date object
  .seller(name:, **opts)             # Seller info
  .buyer(name:, **opts)              # Buyer info
  .add_item(description:, quantity:, unit_price:, **opts)

  # Format & Profile
  .format('zugferd')                 # Output format (default: 'auto')
  .profile('en16931')                # Profile level (default: 'en16931')

  # Optional invoice fields
  .due_date(value)                   # Payment due date
  .currency('EUR')                   # Currency code (default: 'EUR')
  .notes('Thank you!')               # Invoice notes/comments
  .payment(iban:, bic:, terms:)      # Payment information

  # Format-specific fields
  .leitweg_id('04011000-12345-67')   # XRechnung: German B2G routing
  .buyer_reference('PO-12345')       # Peppol: Purchase order reference
  .tipo_documento('TD01')            # FatturaPA: Document type

  # Customization
  .template('minimal')               # 'minimal', 'classic', 'compact'
  .locale('de')                      # 'de', 'en', 'fr', 'es', 'it'
  .logo_file('./logo.png', width_mm: 30)
  .footer_text('Thank you!')
  .accent_color('#8b5cf6')

  # Execute
  .generate                          # Generate invoice
  .validate                          # Dry-run validation only
```

### Party (seller/buyer)

```ruby
Thelawin::Party.new(
  name: 'Company Name',              # Required
  street: 'Street Address',
  city: 'City',
  postal_code: '12345',
  country: 'DE',                     # ISO 3166-1 alpha-2
  vat_id: 'DE123456789',
  email: 'email@example.com',
  phone: '+49 30 12345678',
  # Peppol-specific
  peppol_id: '0088:1234567890123',   # EAS:ID format
  # FatturaPA-specific (Italy)
  codice_fiscale: 'RSSMRA80A01H501U',
  codice_destinatario: 'ABCDEFG',    # SDI code (7 chars)
  pec: 'email@pec.it'                # Certified email
)
```

### LineItem

```ruby
Thelawin::LineItem.new(
  description: 'Service',            # Required
  quantity: 8.0,                     # Required
  unit_price: 150.00,                # Required
  unit: 'HUR',                       # UN/ECE Rec 20 code (default: 'C62')
  vat_rate: 19.0,                    # Default: 19.0
  natura: 'N2.2'                     # FatturaPA: VAT exemption code
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

### Result Handling

```ruby
result = client.invoice.generate

if result.success?
  puts result.filename              # 'invoice-2026-001.pdf' or '.xml'
  puts result.format.format_used    # 'zugferd', 'fatturapa', etc.
  puts result.format.profile        # 'EN16931'
  puts result.format.version        # '2.3'

  # Check output type
  if result.xml_only?
    result.save('./invoice.xml')
  else
    result.save_pdf('./invoice.pdf')
  end

  # Legal warnings
  result.warnings.each do |warning|
    puts "#{warning.code}: #{warning.message}"
    puts "Legal basis: #{warning.legal_basis}"
  end
else
  result.errors.each do |error|
    puts "#{error[:path]}: #{error[:message]}"
  end
end
```

### Pre-Validation (Dry-Run)

Validate invoice data without generating PDF:

```ruby
result = client.invoice
  .number('2026-001')
  .date('2026-01-15')
  .seller(name: 'Acme', country: 'DE')
  .buyer(name: 'Customer', country: 'IT')
  .add_item(description: 'Service', quantity: 1, unit_price: 100)
  .format('fatturapa')
  .validate  # Dry-run validation

if result.valid?
  puts "Valid! Would generate: #{result.format.format_used}"
else
  result.errors.each { |e| puts e }
end
```

### Account Info

```ruby
account = client.account
puts account.plan           # => "starter"
puts account.remaining      # => 450
puts account.overage_count  # => 0
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
rescue Thelawin::QuotaExceededError
  puts 'Quota exceeded, upgrade your plan'
rescue Thelawin::NetworkError => e
  puts "Network error: #{e.message}"
rescue Thelawin::ApiError => e
  puts "API error #{e.status_code}: #{e.message}"
end
```

## Format-Specific Examples

### XRechnung (German B2G)

```ruby
result = client.invoice
  .format('xrechnung')
  .leitweg_id('04011000-12345-67')  # Required for B2G
  .seller(
    name: 'Acme GmbH',
    vat_id: 'DE123456789',
    email: 'invoice@acme.de',       # Required for XRechnung
    street: 'Hauptstraße 1',
    city: 'Berlin',
    postal_code: '10115',
    country: 'DE'
  )
  # ... rest of invoice
  .generate
```

### Peppol

```ruby
result = client.invoice
  .format('peppol')
  .buyer_reference('PO-12345')
  .seller(
    name: 'Acme Ltd',
    vat_id: 'GB123456789',
    peppol_id: '0088:1234567890123',
    # ...
  )
  .buyer(
    name: 'Customer BV',
    peppol_id: '0106:NL123456789B01',
    # ...
  )
  .generate
```

### FatturaPA (Italy)

```ruby
result = client.invoice
  .format('fatturapa')
  .tipo_documento('TD01')  # TD01=invoice, TD04=credit note
  .seller(
    name: 'Acme S.r.l.',
    vat_id: 'IT12345678901',
    codice_fiscale: '12345678901',
    street: 'Via Roma 1',
    city: 'Milano',
    postal_code: '20100',
    country: 'IT'
  )
  .buyer(
    name: 'Cliente S.p.A.',
    vat_id: 'IT98765432109',
    codice_destinatario: 'ABCDEFG',  # SDI code
    # OR: pec: 'cliente@pec.it'
    city: 'Roma',
    country: 'IT'
  )
  .add_item(
    description: 'Consulenza',
    quantity: 10,
    unit_price: 100,
    vat_rate: 22.0
  )
  .generate

# FatturaPA returns XML only
result.save('./fattura.xml')
```

## Rails Integration

```ruby
# config/initializers/thelawin.rb
Thelawin.configure do |config|
  config.api_key = Rails.application.credentials.thelawin_api_key
  config.environment = Rails.env.production? ? :production : :preview
end

# In your service
class InvoiceService
  def generate_invoice(order)
    Thelawin.client.invoice
      .number(order.invoice_number)
      .date(order.created_at.to_date)
      .seller(company_details)
      .buyer(customer_party(order.customer))
      .items(order.line_items.map { |li| line_item_attrs(li) })
      .generate
  end

  private

  def company_details
    Thelawin::Party.new(
      name: 'My Company',
      vat_id: ENV['COMPANY_VAT_ID'],
      street: '123 Main St',
      city: 'Berlin',
      postal_code: '10115',
      country: 'DE'
    )
  end
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
