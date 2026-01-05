"""
envoice - Official Python SDK for envoice.dev

Generate ZUGFeRD/Factur-X compliant invoices with a simple API.
"""

from .client import EnvoiceClient
from .errors import (
    EnvoiceApiError,
    EnvoiceError,
    EnvoiceNetworkError,
    EnvoiceQuotaExceededError,
    EnvoiceValidationError,
)
from .invoice import InvoiceBuilder, InvoiceFailure, InvoiceResult, InvoiceSuccess
from .types import (
    AccountInfo,
    Customization,
    ErrorResponse,
    GenerateRequest,
    GenerateResponse,
    InvoiceData,
    LineItem,
    Party,
    PaymentInfo,
    ValidationError,
    ValidationResult,
)

__version__ = "0.1.0"

__all__ = [
    # Client
    "EnvoiceClient",
    # Builder
    "InvoiceBuilder",
    "InvoiceResult",
    "InvoiceSuccess",
    "InvoiceFailure",
    # Types
    "Party",
    "LineItem",
    "PaymentInfo",
    "Customization",
    "InvoiceData",
    "GenerateRequest",
    "ValidationResult",
    "AccountInfo",
    "GenerateResponse",
    "ValidationError",
    "ErrorResponse",
    # Errors
    "EnvoiceError",
    "EnvoiceApiError",
    "EnvoiceValidationError",
    "EnvoiceNetworkError",
    "EnvoiceQuotaExceededError",
]
