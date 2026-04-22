"""thelawin - Official Python SDK for thelawin.dev

Generate ZUGFeRD/Factur-X compliant e-invoices with a simple API.
"""

from .client import ThelawinClient
from .errors import (
    ThelawinApiError,
    ThelawinError,
    ThelawinNetworkError,
    ThelawinQuotaExceededError,
    ThelawinValidationError,
)
from .invoice import InvoiceBuilder, InvoiceFailure, InvoiceResult, InvoiceSuccess
from .types import (
    AccountInfo,
    Customization,
    DetectedFormat,
    DryRunResponse,
    ErrorResponse,
    FormatInfo,
    GenerateRequest,
    GenerateResponse,
    InvoiceData,
    LineItem,
    Party,
    PaymentInfo,
    RetrieveError,
    RetrieveResponse,
    ValidationError,
)

__version__ = "0.2.0"

__all__ = [
    "ThelawinClient",
    "InvoiceBuilder",
    "InvoiceResult",
    "InvoiceSuccess",
    "InvoiceFailure",
    "Party",
    "LineItem",
    "PaymentInfo",
    "Customization",
    "InvoiceData",
    "GenerateRequest",
    "FormatInfo",
    "AccountInfo",
    "GenerateResponse",
    "DryRunResponse",
    "ValidationError",
    "ErrorResponse",
    "DetectedFormat",
    "RetrieveError",
    "RetrieveResponse",
    "ThelawinError",
    "ThelawinApiError",
    "ThelawinValidationError",
    "ThelawinNetworkError",
    "ThelawinQuotaExceededError",
]
