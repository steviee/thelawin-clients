from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


class Party(BaseModel):
    name: str
    street: Optional[str] = None
    city: Optional[str] = None
    postal_code: Optional[str] = Field(None, alias="postalCode")
    country: Optional[str] = None
    vat_id: Optional[str] = Field(None, alias="vatId")
    email: Optional[str] = None
    phone: Optional[str] = None
    peppol_id: Optional[str] = Field(None, alias="peppolId")
    codice_fiscale: Optional[str] = Field(None, alias="codiceFiscale")
    codice_destinatario: Optional[str] = Field(None, alias="codiceDestinatario")
    pec: Optional[str] = None

    model_config = {"populate_by_name": True}


class LineItem(BaseModel):
    description: str
    quantity: float
    unit: str = "C62"
    unit_price: float = Field(..., alias="unitPrice")
    vat_rate: float = Field(19.0, alias="vatRate")
    natura: Optional[str] = None

    model_config = {"populate_by_name": True}


class PaymentInfo(BaseModel):
    iban: Optional[str] = None
    bic: Optional[str] = None
    terms: Optional[str] = None
    reference: Optional[str] = None


class Customization(BaseModel):
    logo_base64: Optional[str] = Field(None, alias="logoBase64")
    logo_width_mm: Optional[int] = Field(None, alias="logoWidthMm")
    footer_text: Optional[str] = Field(None, alias="footerText")
    accent_color: Optional[str] = Field(None, alias="accentColor")

    model_config = {"populate_by_name": True}


InvoiceFormat = Literal[
    "auto", "zugferd", "facturx", "xrechnung", "ubl", "cii", "peppol", "fatturapa", "pdf"
]

InvoiceProfile = Literal["minimum", "basic_wl", "basic", "en16931", "extended"]

InvoiceTemplate = Literal["minimal", "classic", "compact"]


class InvoiceData(BaseModel):
    number: str
    date: str
    due_date: Optional[str] = Field(None, alias="dueDate")
    seller: Party
    buyer: Party
    items: list[LineItem]
    payment: Optional[PaymentInfo] = None
    currency: str = "EUR"
    notes: Optional[str] = None
    leitweg_id: Optional[str] = Field(None, alias="leitwegId")
    buyer_reference: Optional[str] = Field(None, alias="buyerReference")
    tipo_documento: Optional[str] = Field(None, alias="tipoDocumento")

    model_config = {"populate_by_name": True}


class GenerateRequest(BaseModel):
    format: Optional[InvoiceFormat] = "auto"
    profile: Optional[InvoiceProfile] = "en16931"
    template: InvoiceTemplate = "minimal"
    locale: str = "en"
    invoice: InvoiceData
    customization: Optional[Customization] = None


class FormatInfo(BaseModel):
    format_used: str
    profile: Optional[str] = None
    version: Optional[str] = None
    format_reason: Optional[str] = None
    warnings: Optional[list[LegalWarning]] = None


class LegalWarning(BaseModel):
    code: str
    message: str
    legal_basis: str
    severity: Literal["info", "warning"] = "warning"


class AccountInfo(BaseModel):
    remaining: int
    plan: str
    overage_count: Optional[int] = Field(None, alias="overageCount")
    overage_allowed: Optional[int] = Field(None, alias="overageAllowed")
    topup_balance: Optional[int] = Field(None, alias="topupBalance")
    warning: Optional[str] = None

    model_config = {"populate_by_name": True}


class ValidationError(BaseModel):
    path: str
    code: str
    message: str
    severity: Literal["error", "warning"] = "error"


class GenerateResponse(BaseModel):
    pdf_base64: str
    filename: str
    format: FormatInfo
    account: Optional[AccountInfo] = None


class DryRunResponse(BaseModel):
    valid: bool
    format: FormatInfo
    errors: list[str] = []


class ErrorResponse(BaseModel):
    error: str
    message: Optional[str] = None
    details: Optional[list[ValidationError]] = None


class DetectedFormat(BaseModel):
    detected_format: str
    profile: Optional[str] = None
    version: Optional[str] = None
    xml_type: Optional[str] = None
    has_pdf: bool = False


class RetrieveError(BaseModel):
    code: str
    message: str
    path: Optional[str] = None
    severity: str = "error"


class RetrieveResponse(BaseModel):
    valid: bool
    format: DetectedFormat
    invoice: Optional[InvoiceData] = None
    source_xml_base64: Optional[str] = None
    transaction_id: str
    errors: list[RetrieveError] = []
    warnings: list[RetrieveError] = []
    locale: str = "de"


# FormatInfo references LegalWarning — resolve forward ref
FormatInfo.model_rebuild()
