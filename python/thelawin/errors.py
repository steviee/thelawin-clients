from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .types import ValidationError


class ThelawinError(Exception):
    pass


class ThelawinValidationError(ThelawinError):
    def __init__(self, errors: list[ValidationError], status_code: int = 422) -> None:
        self.errors = errors
        self.status_code = status_code
        message = "; ".join(f"{e.path}: {e.message}" for e in errors)
        super().__init__(f"Validation failed: {message}")

    def to_user_message(self) -> str:
        return "\n".join(f"- {e.path}: {e.message}" for e in self.errors)


class ThelawinApiError(ThelawinError):
    def __init__(self, message: str, status_code: int, code: str | None = None) -> None:
        self.status_code = status_code
        self.code = code
        super().__init__(message)


class ThelawinNetworkError(ThelawinError):
    def __init__(self, message: str, cause: Exception | None = None) -> None:
        self.cause = cause
        super().__init__(message)


class ThelawinQuotaExceededError(ThelawinApiError):
    def __init__(self, message: str) -> None:
        super().__init__(message, 402, "quota_exceeded")
