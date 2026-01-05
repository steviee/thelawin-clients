"""Type definitions for the envoice SDK."""

from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


class Party(BaseModel):
    """Party (seller or buyer) information."""

    name: str
    street: Optional[str] = None
    city: Optional[str] = None
    postal_code: Optional[str] = Field(None, alias="postalCode")
    country: Optional[str] = None
    vat_id: Optional[str] = Field(None, alias="vatId")
    email: Optional[str] = None
    phone: Optional[str] = None

    model_config = {"populate_by_name": True}


class LineItem(BaseModel):
    """Line item in an invoice."""

    description: str
    quantity: float
    unit: str = "C62"
    unit_price: float = Field(..., alias="unitPrice")
    vat_rate: float = Field(19.0, alias="vatRate")

    model_config = {"populate_by_name": True}


class PaymentInfo(BaseModel):
    """Payment information."""

    iban: Optional[str] = None
    bic: Optional[str] = None
    terms: Optional[str] = None
    reference: Optional[str] = None


class Customization(BaseModel):
    """Customization options for the invoice PDF."""

    logo_base64: Optional[str] = Field(None, alias="logoBase64")
    logo_width_mm: Optional[int] = Field(None, alias="logoWidthMm")
    footer_text: Optional[str] = Field(None, alias="footerText")
    accent_color: Optional[str] = Field(None, alias="accentColor")

    model_config = {"populate_by_name": True}


class InvoiceData(BaseModel):
    """Complete invoice data structure."""

    number: str
    date: str
    due_date: Optional[str] = Field(None, alias="dueDate")
    seller: Party
    buyer: Party
    items: list[LineItem]
    payment: Optional[PaymentInfo] = None
    currency: str = "EUR"

    model_config = {"populate_by_name": True}


class GenerateRequest(BaseModel):
    """Request payload for the generate endpoint."""

    template: Literal["minimal", "classic", "compact"] = "minimal"
    locale: str = "en"
    invoice: InvoiceData
    customization: Optional[Customization] = None


class ValidationResult(BaseModel):
    """Validation result from the API."""

    status: str
    profile: str
    version: str
    warnings: Optional[list[str]] = None


class AccountInfo(BaseModel):
    """Account information from the API."""

    remaining: int
    plan: str
    overage_count: Optional[int] = Field(None, alias="overageCount")
    overage_allowed: Optional[int] = Field(None, alias="overageAllowed")
    warning: Optional[str] = None

    model_config = {"populate_by_name": True}


class ValidationError(BaseModel):
    """Validation error detail."""

    path: str
    code: str
    message: str
    severity: Literal["error", "warning"] = "error"


class GenerateResponse(BaseModel):
    """Successful API response."""

    pdf_base64: str
    filename: str
    validation: ValidationResult
    account: Optional[AccountInfo] = None


class ErrorResponse(BaseModel):
    """Error response from the API."""

    error: str
    message: Optional[str] = None
    details: Optional[list[ValidationError]] = None
