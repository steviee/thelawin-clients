# envoice

Official Python SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

## Installation

```bash
pip install envoice
```

For async support with HTTP/2:

```bash
pip install envoice[async]
```

## Quick Start

```python
from envoice import EnvoiceClient

client = EnvoiceClient("env_sandbox_xxx")

result = (client.invoice()
    .number("2026-001")
    .date("2026-01-15")
    .seller(
        name="Acme GmbH",
        vat_id="DE123456789",
        street="Hauptstraße 1",
        city="Berlin",
        postal_code="10115",
        country="DE"
    )
    .buyer(
        name="Customer AG",
        city="München",
        country="DE"
    )
    .add_item(
        description="Consulting Services",
        quantity=8,
        unit="HUR",
        unit_price=150.00,
        vat_rate=19.0
    )
    .logo_file("./logo.png", width_mm=30)
    .template("minimal")
    .generate())

if result.success:
    result.save_pdf("./invoices/2026-001.pdf")
    print(f"Generated: {result.filename}")
    print(f"Validation: {result.validation.profile}")
else:
    for error in result.errors:
        print(f"{error.path}: {error.message}")
```

## Async Usage

```python
import asyncio
from envoice import EnvoiceClient

async def main():
    async with EnvoiceClient("env_live_xxx") as client:
        result = await (client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .seller("Acme GmbH", vat_id="DE123456789")
            .buyer("Customer AG")
            .add_item("Consulting", quantity=8, unit_price=150.0)
            .generate_async())

        if result.success:
            result.save_pdf("./invoice.pdf")

asyncio.run(main())
```

## API Reference

### EnvoiceClient

```python
client = EnvoiceClient(
    api_key: str,
    api_url: str = "https://api.envoice.dev",
    timeout: float = 30.0
)
```

### InvoiceBuilder

Fluent builder for creating invoices:

```python
client.invoice()
    .number(value: str)              # Invoice number (required)
    .date(value: str | date)         # Invoice date YYYY-MM-DD (required)
    .due_date(value: str | date)     # Due date YYYY-MM-DD
    .seller(name, *, vat_id, street, city, postal_code, country, email, phone)
    .buyer(name, *, vat_id, street, city, postal_code, country, email, phone)
    .add_item(description, quantity, unit_price, *, unit="C62", vat_rate=19.0)
    .items(items: list[LineItem])    # Set all items at once
    .payment(*, iban, bic, terms, reference)
    .currency(value: str)            # Default: "EUR"
    .template("minimal" | "classic" | "compact")
    .locale(value: str)              # "de", "en", "fr", "es", "it"
    .logo_file(path, width_mm=None)
    .logo_base64(base64, width_mm=None)
    .footer_text(text: str)
    .accent_color(hex: str)          # e.g., "#8b5cf6"
    .generate()                      # Sync
    .generate_async()                # Async
```

### Types

```python
from envoice import Party, LineItem, PaymentInfo

# Party (seller or buyer)
party = Party(
    name="Company Name",
    street="Street Address",
    city="City",
    postal_code="12345",
    country="DE",           # ISO 3166-1 alpha-2
    vat_id="DE123456789",
    email="email@example.com",
    phone="+49 30 12345678"
)

# Line item
item = LineItem(
    description="Service Description",
    quantity=8.0,
    unit="HUR",             # UN/ECE Rec 20 code
    unit_price=150.00,
    vat_rate=19.0
)

# Payment info
payment = PaymentInfo(
    iban="DE89370400440532013000",
    bic="COBADEFFXXX",
    terms="Net 30 days",
    reference="Invoice 2026-001"
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

```python
# Generate invoice directly (without builder)
result = client.generate_invoice(request)
result = await client.generate_invoice_async(request)

# Validate an existing PDF
result = client.validate(pdf_base64)
result = await client.validate_async(pdf_base64)

# Get account info (quota, plan)
account = client.get_account()
account = await client.get_account_async()
```

## Error Handling

```python
from envoice import (
    EnvoiceError,
    EnvoiceApiError,
    EnvoiceValidationError,
    EnvoiceNetworkError,
    EnvoiceQuotaExceededError,
)

try:
    result = client.invoice().number("2026-001").generate()

    if not result.success:
        # Validation errors (422)
        for error in result.errors:
            print(f"{error.path}: {error.message}")

except EnvoiceQuotaExceededError:
    print("Quota exceeded, upgrade your plan")
except EnvoiceNetworkError as e:
    print(f"Network error: {e}")
except EnvoiceApiError as e:
    print(f"API error {e.status_code}: {e}")
```

## Context Manager

```python
# Sync
with EnvoiceClient("env_sandbox_xxx") as client:
    result = client.invoice().number("001").generate()

# Async
async with EnvoiceClient("env_sandbox_xxx") as client:
    result = await client.invoice().number("001").generate_async()
```

## License

MIT
