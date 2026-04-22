from __future__ import annotations

from typing import Any

import httpx

from .errors import (
    ThelawinApiError,
    ThelawinNetworkError,
    ThelawinQuotaExceededError,
)
from .invoice import InvoiceBuilder, InvoiceFailure, InvoiceResult, InvoiceSuccess
from .types import (
    AccountInfo,
    DryRunResponse,
    ErrorResponse,
    FormatInfo,
    GenerateRequest,
    GenerateResponse,
    RetrieveResponse,
)

DEFAULT_API_URL = "https://api.thelawin.dev"
DEFAULT_TIMEOUT = 30.0


class ThelawinClient:
    def __init__(
        self,
        api_key: str,
        *,
        api_url: str = DEFAULT_API_URL,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        if not api_key:
            raise ValueError("API key is required")

        self._api_key = api_key
        self._api_url = api_url.rstrip("/")
        self._timeout = timeout
        self._sync_client: httpx.Client | None = None
        self._async_client: httpx.AsyncClient | None = None

    def _get_sync_client(self) -> httpx.Client:
        if self._sync_client is None:
            self._sync_client = httpx.Client(
                base_url=self._api_url,
                timeout=self._timeout,
                headers={"X-API-Key": self._api_key},
            )
        return self._sync_client

    def _get_async_client(self) -> httpx.AsyncClient:
        if self._async_client is None:
            self._async_client = httpx.AsyncClient(
                base_url=self._api_url,
                timeout=self._timeout,
                headers={"X-API-Key": self._api_key},
            )
        return self._async_client

    def close(self) -> None:
        if self._sync_client is not None:
            self._sync_client.close()
            self._sync_client = None

    async def aclose(self) -> None:
        if self._async_client is not None:
            await self._async_client.aclose()
            self._async_client = None

    def __enter__(self) -> "ThelawinClient":
        return self

    def __exit__(self, *args: Any) -> None:
        self.close()

    async def __aenter__(self) -> "ThelawinClient":
        return self

    async def __aexit__(self, *args: Any) -> None:
        await self.aclose()

    def invoice(self) -> InvoiceBuilder:
        return InvoiceBuilder(_client=self)

    # -------------------------------------------------------------------------
    # Generate
    # -------------------------------------------------------------------------

    def _generate_sync(self, request: GenerateRequest | InvoiceFailure) -> InvoiceResult:
        if isinstance(request, InvoiceFailure):
            return request
        try:
            response = self._get_sync_client().post(
                "/v1/generate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            return self._handle_generate_response(response)
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    async def _generate_async(self, request: GenerateRequest | InvoiceFailure) -> InvoiceResult:
        if isinstance(request, InvoiceFailure):
            return request
        try:
            response = await self._get_async_client().post(
                "/v1/generate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            return self._handle_generate_response(response)
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    def _handle_generate_response(self, response: httpx.Response) -> InvoiceResult:
        if response.status_code == 200:
            data = GenerateResponse.model_validate(response.json())
            return InvoiceSuccess(
                pdf_base64=data.pdf_base64,
                filename=data.filename,
                format=data.format,
                account=data.account,
            )

        try:
            error_data = ErrorResponse.model_validate(response.json())
        except Exception:
            error_data = ErrorResponse(error="unknown_error", message=f"HTTP {response.status_code}")

        if response.status_code == 402:
            raise ThelawinQuotaExceededError(error_data.message or "Quota exceeded")

        if response.status_code == 422 and error_data.details:
            return InvoiceFailure(errors=error_data.details)

        raise ThelawinApiError(
            error_data.message or error_data.error or "Unknown error",
            response.status_code,
            error_data.error,
        )

    def generate_invoice(self, request: GenerateRequest) -> InvoiceResult:
        return self._generate_sync(request)

    async def generate_invoice_async(self, request: GenerateRequest) -> InvoiceResult:
        return await self._generate_async(request)

    # -------------------------------------------------------------------------
    # Validate
    # -------------------------------------------------------------------------

    def validate(self, request: GenerateRequest) -> DryRunResponse:
        try:
            response = self._get_sync_client().post(
                "/v1/validate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            if not response.is_success:
                self._raise_api_error(response)
            return DryRunResponse.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    async def validate_async(self, request: GenerateRequest) -> DryRunResponse:
        try:
            response = await self._get_async_client().post(
                "/v1/validate",
                json=request.model_dump(by_alias=True, exclude_none=True),
            )
            if not response.is_success:
                self._raise_api_error(response)
            return DryRunResponse.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    # -------------------------------------------------------------------------
    # Retrieve
    # -------------------------------------------------------------------------

    def retrieve(
        self,
        data_base64: str,
        *,
        content_type: str | None = None,
        include_source_xml: bool = False,
    ) -> RetrieveResponse:
        body: dict[str, Any] = {"data_base64": data_base64}
        if content_type:
            body["content_type"] = content_type
        if include_source_xml:
            body["include_source_xml"] = True

        try:
            response = self._get_sync_client().post("/v1/retrieve", json=body)
            if not response.is_success:
                self._raise_api_error(response)
            return RetrieveResponse.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    async def retrieve_async(
        self,
        data_base64: str,
        *,
        content_type: str | None = None,
        include_source_xml: bool = False,
    ) -> RetrieveResponse:
        body: dict[str, Any] = {"data_base64": data_base64}
        if content_type:
            body["content_type"] = content_type
        if include_source_xml:
            body["include_source_xml"] = True

        try:
            response = await self._get_async_client().post("/v1/retrieve", json=body)
            if not response.is_success:
                self._raise_api_error(response)
            return RetrieveResponse.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    # -------------------------------------------------------------------------
    # Account
    # -------------------------------------------------------------------------

    def get_account(self) -> AccountInfo:
        try:
            response = self._get_sync_client().get("/v1/account")
            if not response.is_success:
                self._raise_api_error(response)
            return AccountInfo.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    async def get_account_async(self) -> AccountInfo:
        try:
            response = await self._get_async_client().get("/v1/account")
            if not response.is_success:
                self._raise_api_error(response)
            return AccountInfo.model_validate(response.json())
        except httpx.TimeoutException:
            raise ThelawinNetworkError("Request timeout")
        except httpx.RequestError as e:
            raise ThelawinNetworkError(str(e), cause=e)

    # -------------------------------------------------------------------------
    # Helpers
    # -------------------------------------------------------------------------

    def _raise_api_error(self, response: httpx.Response) -> None:
        try:
            error_data = ErrorResponse.model_validate(response.json())
        except Exception:
            error_data = ErrorResponse(error="unknown_error", message=f"HTTP {response.status_code}")

        if response.status_code == 402:
            raise ThelawinQuotaExceededError(error_data.message or "Quota exceeded")

        raise ThelawinApiError(
            error_data.message or error_data.error or "Unknown error",
            response.status_code,
            error_data.error,
        )
