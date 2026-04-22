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
    InvoiceFormat,
    InvoiceProfile,
    InvoiceTemplate,
    LineItem,
    Party,
    PaymentInfo,
    ValidationError,
    FormatInfo,
    AccountInfo,
)

if TYPE_CHECKING:
    from .client import ThelawinClient


@dataclass
class InvoiceSuccess:
    pdf_base64: str
    filename: str
    format: FormatInfo
    account: AccountInfo | None = None

    @property
    def success(self) -> Literal[True]:
        return True

    def save_pdf(self, file_path: str | Path) -> None:
        path = Path(file_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(base64.b64decode(self.pdf_base64))

    def to_bytes(self) -> bytes:
        return base64.b64decode(self.pdf_base64)

    def to_data_url(self) -> str:
        return f"data:application/pdf;base64,{self.pdf_base64}"


@dataclass
class InvoiceFailure:
    errors: list[ValidationError]

    @property
    def success(self) -> Literal[False]:
        return False


InvoiceResult = Union[InvoiceSuccess, InvoiceFailure]


@dataclass
class InvoiceBuilder:
    _client: "ThelawinClient"
    _number: str | None = None
    _date: str | None = None
    _due_date: str | None = None
    _seller: Party | None = None
    _buyer: Party | None = None
    _items: list[LineItem] = field(default_factory=list)
    _payment: PaymentInfo | None = None
    _currency: str = "EUR"
    _notes: str | None = None
    _format: InvoiceFormat = "auto"
    _profile: InvoiceProfile = "en16931"
    _template: InvoiceTemplate = "minimal"
    _locale: str = "en"
    _leitweg_id: str | None = None
    _buyer_reference: str | None = None
    _tipo_documento: str | None = None
    _customization: Customization = field(default_factory=Customization)

    def number(self, value: str) -> "InvoiceBuilder":
        self._number = value
        return self

    def date(self, value: str | date) -> "InvoiceBuilder":
        self._date = value.isoformat() if isinstance(value, date) else value
        return self

    def due_date(self, value: str | date) -> "InvoiceBuilder":
        self._due_date = value.isoformat() if isinstance(value, date) else value
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
        peppol_id: str | None = None,
        codice_fiscale: str | None = None,
    ) -> "InvoiceBuilder":
        self._seller = Party(
            name=name, street=street, city=city, postal_code=postal_code,
            country=country, vat_id=vat_id, email=email, phone=phone,
            peppol_id=peppol_id, codice_fiscale=codice_fiscale,
        )
        return self

    def seller_party(self, party: Party) -> "InvoiceBuilder":
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
        peppol_id: str | None = None,
        codice_fiscale: str | None = None,
        codice_destinatario: str | None = None,
        pec: str | None = None,
    ) -> "InvoiceBuilder":
        self._buyer = Party(
            name=name, street=street, city=city, postal_code=postal_code,
            country=country, vat_id=vat_id, email=email, phone=phone,
            peppol_id=peppol_id, codice_fiscale=codice_fiscale,
            codice_destinatario=codice_destinatario, pec=pec,
        )
        return self

    def buyer_party(self, party: Party) -> "InvoiceBuilder":
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
        natura: str | None = None,
    ) -> "InvoiceBuilder":
        self._items.append(
            LineItem(
                description=description, quantity=quantity, unit=unit,
                unit_price=unit_price, vat_rate=vat_rate, natura=natura,
            )
        )
        return self

    def add_item_obj(self, item: LineItem) -> "InvoiceBuilder":
        self._items.append(item)
        return self

    def items(self, items: list[LineItem]) -> "InvoiceBuilder":
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
        self._payment = PaymentInfo(iban=iban, bic=bic, terms=terms, reference=reference)
        return self

    def currency(self, value: str) -> "InvoiceBuilder":
        self._currency = value
        return self

    def notes(self, value: str) -> "InvoiceBuilder":
        self._notes = value
        return self

    def format(self, value: InvoiceFormat) -> "InvoiceBuilder":
        self._format = value
        return self

    def profile(self, value: InvoiceProfile) -> "InvoiceBuilder":
        self._profile = value
        return self

    def template(self, value: InvoiceTemplate) -> "InvoiceBuilder":
        self._template = value
        return self

    def locale(self, value: str) -> "InvoiceBuilder":
        self._locale = value
        return self

    def leitweg_id(self, value: str) -> "InvoiceBuilder":
        self._leitweg_id = value
        return self

    def buyer_reference(self, value: str) -> "InvoiceBuilder":
        self._buyer_reference = value
        return self

    def tipo_documento(self, value: str) -> "InvoiceBuilder":
        self._tipo_documento = value
        return self

    def logo_file(self, file_path: str | Path, width_mm: int | None = None) -> "InvoiceBuilder":
        path = Path(file_path)
        self._customization.logo_base64 = base64.b64encode(path.read_bytes()).decode("utf-8")
        if width_mm is not None:
            self._customization.logo_width_mm = width_mm
        return self

    def logo_base64(self, base64_data: str, width_mm: int | None = None) -> "InvoiceBuilder":
        self._customization.logo_base64 = base64_data
        if width_mm is not None:
            self._customization.logo_width_mm = width_mm
        return self

    def footer_text(self, text: str) -> "InvoiceBuilder":
        self._customization.footer_text = text
        return self

    def accent_color(self, color: str) -> "InvoiceBuilder":
        self._customization.accent_color = color
        return self

    def generate(self) -> InvoiceResult:
        return self._client._generate_sync(self._build_request())

    async def generate_async(self) -> InvoiceResult:
        return await self._client._generate_async(self._build_request())

    def _build_request(self) -> GenerateRequest | InvoiceFailure:
        errors: list[ValidationError] = []

        if not self._number:
            errors.append(ValidationError(path="$.invoice.number", code="REQUIRED", message="Invoice number is required"))
        if not self._date:
            errors.append(ValidationError(path="$.invoice.date", code="REQUIRED", message="Invoice date is required"))
        if not self._seller:
            errors.append(ValidationError(path="$.invoice.seller", code="REQUIRED", message="Seller information is required"))
        if not self._buyer:
            errors.append(ValidationError(path="$.invoice.buyer", code="REQUIRED", message="Buyer information is required"))
        if not self._items:
            errors.append(ValidationError(path="$.invoice.items", code="REQUIRED", message="At least one line item is required"))

        if errors:
            return InvoiceFailure(errors=errors)

        customization = None
        if self._customization.logo_base64 or self._customization.footer_text or self._customization.accent_color:
            customization = self._customization

        return GenerateRequest(
            format=self._format,
            profile=self._profile,
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
                notes=self._notes,
                leitweg_id=self._leitweg_id,
                buyer_reference=self._buyer_reference,
                tipo_documento=self._tipo_documento,
            ),
            customization=customization,
        )
