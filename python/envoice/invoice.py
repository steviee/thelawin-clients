"""Invoice builder for the envoice SDK."""

from __future__ import annotations

import base64
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING, Literal, Union

from .types import (
    Customization,
    GenerateRequest,
    InvoiceData,
    LineItem,
    Party,
    PaymentInfo,
    ValidationError,
    ValidationResult,
    AccountInfo,
)

if TYPE_CHECKING:
    from .client import EnvoiceClient


@dataclass
class InvoiceSuccess:
    """Result object returned after successful invoice generation."""

    pdf_base64: str
    filename: str
    validation: ValidationResult
    account: AccountInfo | None = None

    @property
    def success(self) -> Literal[True]:
        """Always True for successful results."""
        return True

    def save_pdf(self, file_path: str | Path) -> None:
        """Save the PDF to a file."""
        path = Path(file_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(base64.b64decode(self.pdf_base64))

    def to_bytes(self) -> bytes:
        """Get the PDF as bytes."""
        return base64.b64decode(self.pdf_base64)

    def to_data_url(self) -> str:
        """Get the PDF as a data URL."""
        return f"data:application/pdf;base64,{self.pdf_base64}"


@dataclass
class InvoiceFailure:
    """Result object returned when invoice generation fails."""

    errors: list[ValidationError]

    @property
    def success(self) -> Literal[False]:
        """Always False for failed results."""
        return False


InvoiceResult = Union[InvoiceSuccess, InvoiceFailure]


@dataclass
class InvoiceBuilder:
    """Fluent builder for creating invoices."""

    _client: "EnvoiceClient"
    _number: str | None = None
    _date: str | None = None
    _due_date: str | None = None
    _seller: Party | None = None
    _buyer: Party | None = None
    _items: list[LineItem] = field(default_factory=list)
    _payment: PaymentInfo | None = None
    _currency: str = "EUR"
    _template: Literal["minimal", "classic", "compact"] = "minimal"
    _locale: str = "en"
    _customization: Customization = field(default_factory=Customization)

    def number(self, value: str) -> "InvoiceBuilder":
        """Set the invoice number."""
        self._number = value
        return self

    def date(self, value: str | date) -> "InvoiceBuilder":
        """Set the invoice date (ISO format: YYYY-MM-DD)."""
        if isinstance(value, date):
            self._date = value.isoformat()
        else:
            self._date = value
        return self

    def due_date(self, value: str | date) -> "InvoiceBuilder":
        """Set the due date (ISO format: YYYY-MM-DD)."""
        if isinstance(value, date):
            self._due_date = value.isoformat()
        else:
            self._due_date = value
        return self

    def seller(
        self,
        name: str,
        *,
        street: str | None = None,
        city: str | None = None,
        postal_code: str | None = None,
        country: str | None = None,
        vat_id: str | None = None,
        email: str | None = None,
        phone: str | None = None,
    ) -> "InvoiceBuilder":
        """Set the seller information."""
        self._seller = Party(
            name=name,
            street=street,
            city=city,
            postal_code=postal_code,
            country=country,
            vat_id=vat_id,
            email=email,
            phone=phone,
        )
        return self

    def seller_party(self, party: Party) -> "InvoiceBuilder":
        """Set the seller from a Party object."""
        self._seller = party
        return self

    def buyer(
        self,
        name: str,
        *,
        street: str | None = None,
        city: str | None = None,
        postal_code: str | None = None,
        country: str | None = None,
        vat_id: str | None = None,
        email: str | None = None,
        phone: str | None = None,
    ) -> "InvoiceBuilder":
        """Set the buyer information."""
        self._buyer = Party(
            name=name,
            street=street,
            city=city,
            postal_code=postal_code,
            country=country,
            vat_id=vat_id,
            email=email,
            phone=phone,
        )
        return self

    def buyer_party(self, party: Party) -> "InvoiceBuilder":
        """Set the buyer from a Party object."""
        self._buyer = party
        return self

    def add_item(
        self,
        description: str,
        quantity: float,
        unit_price: float,
        *,
        unit: str = "C62",
        vat_rate: float = 19.0,
    ) -> "InvoiceBuilder":
        """Add a line item to the invoice."""
        self._items.append(
            LineItem(
                description=description,
                quantity=quantity,
                unit=unit,
                unit_price=unit_price,
                vat_rate=vat_rate,
            )
        )
        return self

    def add_item_obj(self, item: LineItem) -> "InvoiceBuilder":
        """Add a LineItem object to the invoice."""
        self._items.append(item)
        return self

    def items(self, items: list[LineItem]) -> "InvoiceBuilder":
        """Set multiple line items at once."""
        self._items = items
        return self

    def payment(
        self,
        *,
        iban: str | None = None,
        bic: str | None = None,
        terms: str | None = None,
        reference: str | None = None,
    ) -> "InvoiceBuilder":
        """Set payment information."""
        self._payment = PaymentInfo(
            iban=iban,
            bic=bic,
            terms=terms,
            reference=reference,
        )
        return self

    def currency(self, value: str) -> "InvoiceBuilder":
        """Set the currency (default: EUR)."""
        self._currency = value
        return self

    def template(self, value: Literal["minimal", "classic", "compact"]) -> "InvoiceBuilder":
        """Set the template style."""
        self._template = value
        return self

    def locale(self, value: str) -> "InvoiceBuilder":
        """Set the locale for labels (de, en, fr, es, it)."""
        self._locale = value
        return self

    def logo_file(self, file_path: str | Path, width_mm: int | None = None) -> "InvoiceBuilder":
        """Set a logo from a local file path."""
        path = Path(file_path)
        logo_bytes = path.read_bytes()
        self._customization.logo_base64 = base64.b64encode(logo_bytes).decode("utf-8")
        if width_mm is not None:
            self._customization.logo_width_mm = width_mm
        return self

    def logo_base64(self, base64_data: str, width_mm: int | None = None) -> "InvoiceBuilder":
        """Set a logo from a Base64 string."""
        self._customization.logo_base64 = base64_data
        if width_mm is not None:
            self._customization.logo_width_mm = width_mm
        return self

    def footer_text(self, text: str) -> "InvoiceBuilder":
        """Set footer text."""
        self._customization.footer_text = text
        return self

    def accent_color(self, color: str) -> "InvoiceBuilder":
        """Set accent color (hex code)."""
        self._customization.accent_color = color
        return self

    def generate(self) -> InvoiceResult:
        """Generate the invoice synchronously."""
        return self._client._generate_sync(self._build_request())

    async def generate_async(self) -> InvoiceResult:
        """Generate the invoice asynchronously."""
        return await self._client._generate_async(self._build_request())

    def _build_request(self) -> GenerateRequest | InvoiceFailure:
        """Build the request object, validating required fields."""
        errors: list[ValidationError] = []

        if not self._number:
            errors.append(
                ValidationError(
                    path="$.invoice.number",
                    code="REQUIRED",
                    message="Invoice number is required",
                )
            )
        if not self._date:
            errors.append(
                ValidationError(
                    path="$.invoice.date",
                    code="REQUIRED",
                    message="Invoice date is required",
                )
            )
        if not self._seller:
            errors.append(
                ValidationError(
                    path="$.invoice.seller",
                    code="REQUIRED",
                    message="Seller information is required",
                )
            )
        if not self._buyer:
            errors.append(
                ValidationError(
                    path="$.invoice.buyer",
                    code="REQUIRED",
                    message="Buyer information is required",
                )
            )
        if not self._items:
            errors.append(
                ValidationError(
                    path="$.invoice.items",
                    code="REQUIRED",
                    message="At least one line item is required",
                )
            )

        if errors:
            return InvoiceFailure(errors=errors)

        # Build customization only if there's content
        customization = None
        if (
            self._customization.logo_base64
            or self._customization.footer_text
            or self._customization.accent_color
        ):
            customization = self._customization

        return GenerateRequest(
            template=self._template,
            locale=self._locale,
            invoice=InvoiceData(
                number=self._number,  # type: ignore
                date=self._date,  # type: ignore
                due_date=self._due_date,
                seller=self._seller,  # type: ignore
                buyer=self._buyer,  # type: ignore
                items=self._items,
                payment=self._payment,
                currency=self._currency,
            ),
            customization=customization,
        )
