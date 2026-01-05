"""Tests for the EnvoiceClient."""

import pytest
from pytest_httpx import HTTPXMock

from envoice import (
    EnvoiceClient,
    EnvoiceApiError,
    EnvoiceNetworkError,
    EnvoiceQuotaExceededError,
)


class TestEnvoiceClient:
    """Tests for the EnvoiceClient class."""

    def test_client_requires_api_key(self) -> None:
        """Test that client requires an API key."""
        with pytest.raises(ValueError, match="API key is required"):
            EnvoiceClient("")

    def test_client_creation(self) -> None:
        """Test client creation with valid API key."""
        client = EnvoiceClient("env_sandbox_test")
        assert client._api_key == "env_sandbox_test"
        assert client._api_url == "https://api.envoice.dev"
        assert client._timeout == 30.0

    def test_client_custom_options(self) -> None:
        """Test client creation with custom options."""
        client = EnvoiceClient(
            "env_sandbox_test",
            api_url="https://custom.api.url/",
            timeout=60.0,
        )
        assert client._api_url == "https://custom.api.url"
        assert client._timeout == 60.0

    def test_client_context_manager(self) -> None:
        """Test client as context manager."""
        with EnvoiceClient("env_sandbox_test") as client:
            assert client._api_key == "env_sandbox_test"

    def test_invoice_builder_creation(self) -> None:
        """Test creating an invoice builder."""
        client = EnvoiceClient("env_sandbox_test")
        builder = client.invoice()
        assert builder._client == client


class TestGenerateInvoice:
    """Tests for invoice generation."""

    def test_successful_generation(self, httpx_mock: HTTPXMock) -> None:
        """Test successful invoice generation."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/generate",
            json={
                "pdf_base64": "JVBERi0xLjQK...",
                "filename": "invoice-2026-001.pdf",
                "validation": {
                    "status": "valid",
                    "profile": "EN16931",
                    "version": "2.3.2",
                },
                "account": {
                    "remaining": 499,
                    "plan": "starter",
                },
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            result = (
                client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller("Acme GmbH", vat_id="DE123456789", city="Berlin", country="DE")
                .buyer("Customer AG", city="München", country="DE")
                .add_item("Consulting", quantity=8, unit_price=150.0)
                .generate()
            )

        assert result.success is True
        assert result.pdf_base64 == "JVBERi0xLjQK..."
        assert result.filename == "invoice-2026-001.pdf"
        assert result.validation.profile == "EN16931"
        assert result.account.remaining == 499

    def test_validation_errors(self, httpx_mock: HTTPXMock) -> None:
        """Test handling of validation errors."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/generate",
            status_code=422,
            json={
                "error": "validation_error",
                "message": "Validation failed",
                "details": [
                    {
                        "path": "$.invoice.seller.vatId",
                        "code": "INVALID_FORMAT",
                        "message": "Invalid VAT ID format",
                    }
                ],
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            result = (
                client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller("Acme GmbH", vat_id="INVALID", city="Berlin", country="DE")
                .buyer("Customer AG", city="München", country="DE")
                .add_item("Consulting", quantity=8, unit_price=150.0)
                .generate()
            )

        assert result.success is False
        assert len(result.errors) == 1
        assert result.errors[0].path == "$.invoice.seller.vatId"
        assert result.errors[0].code == "INVALID_FORMAT"

    def test_quota_exceeded(self, httpx_mock: HTTPXMock) -> None:
        """Test handling of quota exceeded error."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/generate",
            status_code=402,
            json={
                "error": "quota_exceeded",
                "message": "Monthly quota exceeded",
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            with pytest.raises(EnvoiceQuotaExceededError, match="Monthly quota exceeded"):
                (
                    client.invoice()
                    .number("2026-001")
                    .date("2026-01-15")
                    .seller("Acme GmbH", vat_id="DE123456789")
                    .buyer("Customer AG")
                    .add_item("Consulting", quantity=8, unit_price=150.0)
                    .generate()
                )

    def test_api_error(self, httpx_mock: HTTPXMock) -> None:
        """Test handling of API errors."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/generate",
            status_code=500,
            json={
                "error": "internal_error",
                "message": "Internal server error",
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            with pytest.raises(EnvoiceApiError) as exc_info:
                (
                    client.invoice()
                    .number("2026-001")
                    .date("2026-01-15")
                    .seller("Acme GmbH", vat_id="DE123456789")
                    .buyer("Customer AG")
                    .add_item("Consulting", quantity=8, unit_price=150.0)
                    .generate()
                )

        assert exc_info.value.status_code == 500
        assert exc_info.value.code == "internal_error"

    def test_missing_required_fields(self) -> None:
        """Test client-side validation for missing fields."""
        client = EnvoiceClient("env_sandbox_test")

        # Missing number
        result = client.invoice().date("2026-01-15").seller("Acme").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.number" for e in result.errors)

        # Missing date
        result = client.invoice().number("001").seller("Acme").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.date" for e in result.errors)

        # Missing seller
        result = client.invoice().number("001").date("2026-01-15").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.seller" for e in result.errors)

        # Missing buyer
        result = client.invoice().number("001").date("2026-01-15").seller("Acme").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.buyer" for e in result.errors)

        # Missing items
        result = client.invoice().number("001").date("2026-01-15").seller("Acme").buyer("Customer").generate()
        assert result.success is False
        assert any(e.path == "$.invoice.items" for e in result.errors)


class TestValidate:
    """Tests for PDF validation."""

    def test_successful_validation(self, httpx_mock: HTTPXMock) -> None:
        """Test successful PDF validation."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/validate",
            json={
                "valid": True,
                "profile": "EN16931",
                "version": "2.3.2",
                "errors": [],
                "warnings": [],
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            result = client.validate("JVBERi0xLjQK...")

        assert result["valid"] is True
        assert result["profile"] == "EN16931"


class TestGetAccount:
    """Tests for account information."""

    def test_get_account(self, httpx_mock: HTTPXMock) -> None:
        """Test getting account information."""
        httpx_mock.add_response(
            method="GET",
            url="https://api.envoice.dev/v1/account",
            json={
                "plan": "starter",
                "remaining": 450,
                "used": 50,
                "limit": 500,
            },
        )

        with EnvoiceClient("env_sandbox_test") as client:
            account = client.get_account()

        assert account.plan == "starter"
        assert account.remaining == 450


class TestAsyncClient:
    """Tests for async client methods."""

    @pytest.mark.asyncio
    async def test_async_generation(self, httpx_mock: HTTPXMock) -> None:
        """Test async invoice generation."""
        httpx_mock.add_response(
            method="POST",
            url="https://api.envoice.dev/v1/generate",
            json={
                "pdf_base64": "JVBERi0xLjQK...",
                "filename": "invoice-2026-001.pdf",
                "validation": {
                    "status": "valid",
                    "profile": "EN16931",
                    "version": "2.3.2",
                },
            },
        )

        async with EnvoiceClient("env_sandbox_test") as client:
            result = await (
                client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller("Acme GmbH", vat_id="DE123456789")
                .buyer("Customer AG")
                .add_item("Consulting", quantity=8, unit_price=150.0)
                .generate_async()
            )

        assert result.success is True
        assert result.filename == "invoice-2026-001.pdf"

    @pytest.mark.asyncio
    async def test_async_get_account(self, httpx_mock: HTTPXMock) -> None:
        """Test async account retrieval."""
        httpx_mock.add_response(
            method="GET",
            url="https://api.envoice.dev/v1/account",
            json={
                "plan": "pro",
                "remaining": 1800,
                "used": 200,
                "limit": 2000,
            },
        )

        async with EnvoiceClient("env_sandbox_test") as client:
            account = await client.get_account_async()

        assert account.plan == "pro"
        assert account.remaining == 1800
