"""Tests for the ThelawinClient."""

import pytest
from pytest_httpx import HTTPXMock

from thelawin import (
    ThelawinClient,
    ThelawinApiError,
    ThelawinNetworkError,
    ThelawinQuotaExceededError,
)

API_URL = "https://api.thelawin.dev"


class TestThelawinClient:
    def test_client_requires_api_key(self) -> None:
        with pytest.raises(ValueError, match="API key is required"):
            ThelawinClient("")

    def test_client_creation(self) -> None:
        client = ThelawinClient("env_sandbox_test")
        assert client._api_key == "env_sandbox_test"
        assert client._api_url == API_URL
        assert client._timeout == 30.0

    def test_client_custom_options(self) -> None:
        client = ThelawinClient(
            "env_sandbox_test",
            api_url="https://api.preview.thelawin.dev/",
            timeout=60.0,
        )
        assert client._api_url == "https://api.preview.thelawin.dev"
        assert client._timeout == 60.0

    def test_client_context_manager(self) -> None:
        with ThelawinClient("env_sandbox_test") as client:
            assert client._api_key == "env_sandbox_test"

    def test_invoice_builder_creation(self) -> None:
        client = ThelawinClient("env_sandbox_test")
        builder = client.invoice()
        assert builder._client == client


class TestGenerateInvoice:
    def test_successful_generation(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            json={
                "pdf_base64": "JVBERi0xLjQK...",
                "filename": "invoice-2026-001.pdf",
                "format": {
                    "format_used": "zugferd",
                    "profile": "EN16931",
                    "version": "2.3",
                },
                "account": {"remaining": 499, "plan": "starter"},
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
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
        assert result.format.format_used == "zugferd"
        assert result.format.profile == "EN16931"
        assert result.account.remaining == 499

    def test_validation_errors(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            status_code=422,
            json={
                "error": "validation_failed",
                "message": "Validation failed",
                "details": [
                    {"path": "invoice.seller.vat_id", "code": "REQUIRED", "message": "VAT ID required"},
                ],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            result = (
                client.invoice()
                .number("2026-001").date("2026-01-15")
                .seller("Acme GmbH", vat_id="INVALID")
                .buyer("Customer AG")
                .add_item("Consulting", quantity=8, unit_price=150.0)
                .generate()
            )

        assert result.success is False
        assert len(result.errors) == 1
        assert result.errors[0].path == "invoice.seller.vat_id"

    def test_quota_exceeded(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            status_code=402,
            json={"error": "quota_exceeded", "message": "Monthly quota exceeded"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            with pytest.raises(ThelawinQuotaExceededError, match="Monthly quota exceeded"):
                (
                    client.invoice()
                    .number("2026-001").date("2026-01-15")
                    .seller("Acme GmbH").buyer("Customer AG")
                    .add_item("Consulting", quantity=8, unit_price=150.0)
                    .generate()
                )

    def test_api_error_500(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            status_code=500,
            json={"error": "internal_error", "message": "Internal server error"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            with pytest.raises(ThelawinApiError) as exc_info:
                (
                    client.invoice()
                    .number("2026-001").date("2026-01-15")
                    .seller("Acme GmbH").buyer("Customer AG")
                    .add_item("Item", quantity=1, unit_price=100.0)
                    .generate()
                )

        assert exc_info.value.status_code == 500
        assert exc_info.value.code == "internal_error"

    def test_api_error_401(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            status_code=401,
            json={"error": "unauthorized", "message": "Invalid API key"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            with pytest.raises(ThelawinApiError) as exc_info:
                (
                    client.invoice()
                    .number("2026-001").date("2026-01-15")
                    .seller("Acme GmbH").buyer("Customer AG")
                    .add_item("Item", quantity=1, unit_price=100.0)
                    .generate()
                )

        assert exc_info.value.status_code == 401

    def test_missing_required_fields(self) -> None:
        client = ThelawinClient("env_sandbox_test")

        result = client.invoice().date("2026-01-15").seller("Acme").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.number" for e in result.errors)

        result = client.invoice().number("001").seller("Acme").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.date" for e in result.errors)

        result = client.invoice().number("001").date("2026-01-15").buyer("Customer").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.seller" for e in result.errors)

        result = client.invoice().number("001").date("2026-01-15").seller("Acme").add_item("Item", 1, 100).generate()
        assert result.success is False
        assert any(e.path == "$.invoice.buyer" for e in result.errors)

        result = client.invoice().number("001").date("2026-01-15").seller("Acme").buyer("Customer").generate()
        assert result.success is False
        assert any(e.path == "$.invoice.items" for e in result.errors)


class TestValidate:
    def test_valid_invoice(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/validate",
            json={
                "valid": True,
                "format": {"format_used": "zugferd", "profile": "EN16931", "version": "2.3"},
                "errors": [],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            from thelawin import GenerateRequest, InvoiceData, Party, LineItem
            request = GenerateRequest(
                invoice=InvoiceData(
                    number="001", date="2026-01-15",
                    seller=Party(name="S"), buyer=Party(name="B"),
                    items=[LineItem(description="Item", quantity=1, unit_price=100)],
                )
            )
            result = client.validate(request)

        assert result.valid is True
        assert result.format.format_used == "zugferd"

    def test_invalid_invoice(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/validate",
            json={
                "valid": False,
                "format": {"format_used": "zugferd", "profile": "EN16931"},
                "errors": ["invoice.seller.vat_id: VAT ID required"],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            from thelawin import GenerateRequest, InvoiceData, Party, LineItem
            request = GenerateRequest(
                invoice=InvoiceData(
                    number="001", date="2026-01-15",
                    seller=Party(name="S"), buyer=Party(name="B"),
                    items=[LineItem(description="Item", quantity=1, unit_price=100)],
                )
            )
            result = client.validate(request)

        assert result.valid is False
        assert len(result.errors) == 1


class TestRetrieve:
    def test_retrieve_from_pdf(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            json={
                "valid": True,
                "format": {"detected_format": "zugferd", "profile": "EN16931", "xml_type": "CII", "has_pdf": True},
                "invoice": {
                    "number": "RE-2026-001", "date": "2026-01-15",
                    "seller": {"name": "Acme GmbH"}, "buyer": {"name": "Customer AG"},
                    "items": [{"description": "Consulting", "quantity": 8, "unitPrice": 150}],
                },
                "transaction_id": "tx_abc123",
                "errors": [],
                "warnings": [],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            result = client.retrieve("JVBERi0xLjQK...")

        assert result.valid is True
        assert result.format.detected_format == "zugferd"
        assert result.format.has_pdf is True
        assert result.invoice.number == "RE-2026-001"
        assert result.transaction_id == "tx_abc123"

    def test_retrieve_from_xml(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            json={
                "valid": True,
                "format": {"detected_format": "ubl", "xml_type": "UBL", "has_pdf": False},
                "invoice": {
                    "number": "UBL-001", "date": "2026-01-15",
                    "seller": {"name": "Test"}, "buyer": {"name": "Buyer"},
                    "items": [{"description": "Item", "quantity": 1, "unitPrice": 100}],
                },
                "transaction_id": "tx_def456",
                "errors": [],
                "warnings": [],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            result = client.retrieve("PHhtbD4...", content_type="application/xml")

        assert result.format.detected_format == "ubl"
        assert result.format.has_pdf is False

    def test_retrieve_with_source_xml(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            json={
                "valid": True,
                "format": {"detected_format": "zugferd", "has_pdf": True},
                "invoice": {
                    "number": "001", "date": "2026-01-01",
                    "seller": {"name": "S"}, "buyer": {"name": "B"},
                    "items": [{"description": "I", "quantity": 1, "unitPrice": 1}],
                },
                "source_xml_base64": "PHhtbCB2ZXJzaW9uPQ==",
                "transaction_id": "tx_ghi789",
                "errors": [],
                "warnings": [],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            result = client.retrieve("JVBERi0...", include_source_xml=True)

        assert result.source_xml_base64 == "PHhtbCB2ZXJzaW9uPQ=="

    def test_retrieve_invalid_file(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            json={
                "valid": False,
                "format": {"detected_format": "unknown"},
                "invoice": None,
                "transaction_id": "tx_err",
                "errors": [{"code": "INVALID_FILE", "message": "No e-invoice data found", "severity": "error"}],
                "warnings": [],
            },
        )

        with ThelawinClient("env_sandbox_test") as client:
            result = client.retrieve("notapdf")

        assert result.valid is False
        assert len(result.errors) == 1
        assert result.errors[0].code == "INVALID_FILE"

    def test_retrieve_quota_exceeded(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            status_code=402,
            json={"error": "quota_exceeded", "message": "Quota exceeded"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            with pytest.raises(ThelawinQuotaExceededError):
                client.retrieve("JVBERi0...")


class TestGetAccount:
    def test_get_account(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="GET",
            url=f"{API_URL}/v1/account",
            json={"plan": "starter", "remaining": 450, "overageCount": 0, "overageAllowed": 75},
        )

        with ThelawinClient("env_sandbox_test") as client:
            account = client.get_account()

        assert account.plan == "starter"
        assert account.remaining == 450
        assert account.overage_count == 0

    def test_sandbox_account(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="GET",
            url=f"{API_URL}/v1/account",
            json={"plan": "sandbox", "remaining": 2147483647},
        )

        with ThelawinClient("env_sandbox_test") as client:
            account = client.get_account()

        assert account.plan == "sandbox"

    def test_account_with_warning(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="GET",
            url=f"{API_URL}/v1/account",
            json={"plan": "starter", "remaining": 10, "warning": "Quota running low"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            account = client.get_account()

        assert account.warning == "Quota running low"

    def test_account_unauthorized(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="GET",
            url=f"{API_URL}/v1/account",
            status_code=401,
            json={"error": "unauthorized", "message": "Invalid API key"},
        )

        with ThelawinClient("env_sandbox_test") as client:
            with pytest.raises(ThelawinApiError) as exc_info:
                client.get_account()

        assert exc_info.value.status_code == 401


class TestAsyncClient:
    @pytest.mark.asyncio
    async def test_async_generation(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/generate",
            json={
                "pdf_base64": "JVBERi0xLjQK...",
                "filename": "invoice-2026-001.pdf",
                "format": {"format_used": "zugferd", "profile": "EN16931", "version": "2.3"},
            },
        )

        async with ThelawinClient("env_sandbox_test") as client:
            result = await (
                client.invoice()
                .number("2026-001").date("2026-01-15")
                .seller("Acme GmbH", vat_id="DE123456789")
                .buyer("Customer AG")
                .add_item("Consulting", quantity=8, unit_price=150.0)
                .generate_async()
            )

        assert result.success is True
        assert result.filename == "invoice-2026-001.pdf"

    @pytest.mark.asyncio
    async def test_async_retrieve(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="POST",
            url=f"{API_URL}/v1/retrieve",
            json={
                "valid": True,
                "format": {"detected_format": "zugferd", "has_pdf": True},
                "invoice": {
                    "number": "RE-001", "date": "2026-01-01",
                    "seller": {"name": "S"}, "buyer": {"name": "B"},
                    "items": [{"description": "I", "quantity": 1, "unitPrice": 1}],
                },
                "transaction_id": "tx_async",
                "errors": [],
                "warnings": [],
            },
        )

        async with ThelawinClient("env_sandbox_test") as client:
            result = await client.retrieve_async("JVBERi0...")

        assert result.valid is True

    @pytest.mark.asyncio
    async def test_async_get_account(self, httpx_mock: HTTPXMock) -> None:
        httpx_mock.add_response(
            method="GET",
            url=f"{API_URL}/v1/account",
            json={"plan": "pro", "remaining": 1800},
        )

        async with ThelawinClient("env_sandbox_test") as client:
            account = await client.get_account_async()

        assert account.plan == "pro"
        assert account.remaining == 1800
