"""Error classes for the envoice SDK."""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .types import ValidationError


class EnvoiceError(Exception):
    """Base error class for all envoice SDK errors."""

    pass


class EnvoiceValidationError(EnvoiceError):
    """Error raised when the API returns validation errors."""

    def __init__(self, errors: list[ValidationError], status_code: int = 422) -> None:
        self.errors = errors
        self.status_code = status_code
        message = "; ".join(f"{e.path}: {e.message}" for e in errors)
        super().__init__(f"Validation failed: {message}")

    def to_user_message(self) -> str:
        """Get a user-friendly error message."""
        return "\n".join(f"- {e.path}: {e.message}" for e in self.errors)


class EnvoiceApiError(EnvoiceError):
    """Error raised when the API returns an HTTP error."""

    def __init__(self, message: str, status_code: int, code: str | None = None) -> None:
        self.status_code = status_code
        self.code = code
        super().__init__(message)


class EnvoiceNetworkError(EnvoiceError):
    """Error raised when a network request fails."""

    def __init__(self, message: str, cause: Exception | None = None) -> None:
        self.cause = cause
        super().__init__(message)


class EnvoiceQuotaExceededError(EnvoiceApiError):
    """Error raised when quota is exceeded."""

    def __init__(self, message: str) -> None:
        super().__init__(message, 402, "quota_exceeded")
