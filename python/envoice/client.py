"""Main client for the envoice SDK."""

from __future__ import annotations

from typing import Any

import httpx

from .errors import (
    EnvoiceApiError,
    EnvoiceNetworkError,
    EnvoiceQuotaExceededError,
)
from .invoice import InvoiceBuilder, InvoiceFailure, InvoiceResult, InvoiceSuccess
from .types import (
    AccountInfo,
    ErrorResponse,
    GenerateRequest,
    GenerateResponse,
    ValidationError,
    ValidationResult,
)


class EnvoiceClient:
    """Main client for interacting with the envoice.dev API."""

    def __init__(
        self,
        api_key: str,
        *,
        api_url: str = "https://api.envoice.dev",
        timeout: float = 30.0,
    ) -> None:
        """
        Create a new EnvoiceClient.

        Args:
            api_key: Your API key (env_sandbox_* or env_live_*)
            api_url: API base URL (default: https://api.envoice.dev)
            timeout: Request timeout in seconds (default: 30)
        """
        if not api_key:
            raise ValueError("API key is required")

        self._api_key = api_key
        self._api_url = api_url.rstrip("/")
        self._timeout = timeout
        self._sync_client: httpx.Client | None = None
        self._async_client: httpx.AsyncClient | None = None

    def _get_sync_client(self) -> httpx.Client:
        """Get or create the synchronous HTTP client."""
        if self._sync_client is None:
            self._sync_client = httpx.Client(
                base_url=self._api_url,
                timeout=self._timeout,
                headers={"X-API-Key": self._api_key},
            )
        return self._sync_client

    def _get_async_client(self) -> httpx.AsyncClient:
        """Get or create the asynchronous HTTP client."""
        if self._async_client is None:
            self._async_client = httpx.AsyncClient(
                base_url=self._api_url,
                timeout=self._timeout,
                headers={"X-API-Key": self._api_key},
            )
        return self._async_client

    def close(self) -> None:
        """Close the synchronous HTTP client."""
        if self._sync_client is not None:
            self._sync_client.close()
            self._sync_client = None

    async def aclose(self) -> None:
        """Close the asynchronous HTTP client."""
        if self._async_client is not None:
            await self._async_client.aclose()
            self._async_client = None

    def __enter__(self) -> "EnvoiceClient":
        """Context manager entry."""
        return self

    def __exit__(self, *args: Any) -> None:
        """Context manager exit."""
        self.close()

    async def __aenter__(self) -> "EnvoiceClient":
        """Async context manager entry."""
        return self

    async def __aexit__(self, *args: Any) -> None:
        """Async context manager exit."""
        await self.aclose()

    def invoice(self) -> InvoiceBuilder:
        """Create a new invoice builder with fluent API."""
        return InvoiceBuilder(_client=self)

    def _generate_sync(self, request: GenerateRequest | InvoiceFailure) -> InvoiceResult:
        """Generate an invoice synchronously (internal)."""
        if isinstance(request, InvoiceFailure):
            return request

        try:
            client = self._get_sync_client()
            response = client.post(
                "/v1/generate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            return self._handle_response(response)
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)

    async def _generate_async(self, request: GenerateRequest | InvoiceFailure) -> InvoiceResult:
        """Generate an invoice asynchronously (internal)."""
        if isinstance(request, InvoiceFailure):
            return request

        try:
            client = self._get_async_client()
            response = await client.post(
                "/v1/generate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            return self._handle_response(response)
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)

    def _handle_response(self, response: httpx.Response) -> InvoiceResult:
        """Handle the API response."""
        if response.status_code == 200:
            data = GenerateResponse.model_validate(response.json())
            return InvoiceSuccess(
                pdf_base64=data.pdf_base64,
                filename=data.filename,
                validation=data.validation,
                account=data.account,
            )

        # Handle errors
        try:
            error_data = ErrorResponse.model_validate(response.json())
        except Exception:
            error_data = ErrorResponse(error="unknown_error", message=f"HTTP {response.status_code}")

        if response.status_code == 402:
            raise EnvoiceQuotaExceededError(error_data.message or "Quota exceeded")

        if response.status_code == 422 and error_data.details:
            return InvoiceFailure(errors=error_data.details)

        raise EnvoiceApiError(
            error_data.message or error_data.error or "Unknown error",
            response.status_code,
            error_data.error,
        )

    def generate_invoice(self, request: GenerateRequest) -> InvoiceResult:
        """Generate an invoice directly (without builder)."""
        return self._generate_sync(request)

    async def generate_invoice_async(self, request: GenerateRequest) -> InvoiceResult:
        """Generate an invoice directly asynchronously."""
        return await self._generate_async(request)

    def validate(self, pdf_base64: str) -> dict[str, Any]:
        """Validate an existing PDF for ZUGFeRD/Factur-X compliance."""
        try:
            client = self._get_sync_client()
            response = client.post(
                "/v1/validate",
                json={"pdf_base64": pdf_base64},
            )

            if not response.is_success:
                error_data = ErrorResponse.model_validate(response.json())
                raise EnvoiceApiError(
                    error_data.message or error_data.error,
                    response.status_code,
                    error_data.error,
                )

            return response.json()
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)

    async def validate_async(self, pdf_base64: str) -> dict[str, Any]:
        """Validate an existing PDF asynchronously."""
        try:
            client = self._get_async_client()
            response = await client.post(
                "/v1/validate",
                json={"pdf_base64": pdf_base64},
            )

            if not response.is_success:
                error_data = ErrorResponse.model_validate(response.json())
                raise EnvoiceApiError(
                    error_data.message or error_data.error,
                    response.status_code,
                    error_data.error,
                )

            return response.json()
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)

    def get_account(self) -> AccountInfo:
        """Get account information (quota, plan, etc.)."""
        try:
            client = self._get_sync_client()
            response = client.get("/v1/account")

            if not response.is_success:
                error_data = ErrorResponse.model_validate(response.json())
                raise EnvoiceApiError(
                    error_data.message or error_data.error,
                    response.status_code,
                    error_data.error,
                )

            return AccountInfo.model_validate(response.json())
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)

    async def get_account_async(self) -> AccountInfo:
        """Get account information asynchronously."""
        try:
            client = self._get_async_client()
            response = await client.get("/v1/account")

            if not response.is_success:
                error_data = ErrorResponse.model_validate(response.json())
                raise EnvoiceApiError(
                    error_data.message or error_data.error,
                    response.status_code,
                    error_data.error,
                )

            return AccountInfo.model_validate(response.json())
        except httpx.TimeoutException:
            raise EnvoiceNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise EnvoiceNetworkError(str(e), cause=e)
