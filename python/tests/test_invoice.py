"""Tests for the InvoiceBuilder."""

import base64
import tempfile
from datetime import date
from pathlib import Path

import pytest

from thelawin import (
    ThelawinClient,
    InvoiceBuilder,
    InvoiceSuccess,
    InvoiceFailure,
    Party,
    LineItem,
    FormatInfo,
)


class TestInvoiceBuilder:
    @pytest.fixture
    def client(self) -> ThelawinClient:
        return ThelawinClient("env_sandbox_test")

    @pytest.fixture
    def builder(self, client: ThelawinClient) -> InvoiceBuilder:
        return client.invoice()

    def test_fluent_interface(self, builder: InvoiceBuilder) -> None:
        result = (
            builder
            .number("2026-001")
            .date("2026-01-15")
            .due_date("2026-02-15")
            .currency("EUR")
            .notes("Thank you")
            .format("zugferd")
            .profile("en16931")
            .template("minimal")
            .locale("de")
            .leitweg_id("04011000-12345-67")
            .buyer_reference("PO-123")
            .tipo_documento("TD01")
        )
        assert result is builder

    def test_date_with_string(self, builder: InvoiceBuilder) -> None:
        builder.date("2026-01-15")
        assert builder._date == "2026-01-15"

    def test_date_with_date_object(self, builder: InvoiceBuilder) -> None:
        builder.date(date(2026, 1, 15))
        assert builder._date == "2026-01-15"

    def test_due_date_with_date_object(self, builder: InvoiceBuilder) -> None:
        builder.due_date(date(2026, 2, 15))
        assert builder._due_date == "2026-02-15"

    def test_seller_with_kwargs(self, builder: InvoiceBuilder) -> None:
        builder.seller(
            "Acme GmbH",
            vat_id="DE123456789",
            street="Hauptstraße 1",
            city="Berlin",
            postal_code="10115",
            country="DE",
        )
        assert builder._seller is not None
        assert builder._seller.name == "Acme GmbH"
        assert builder._seller.vat_id == "DE123456789"

    def test_seller_with_peppol(self, builder: InvoiceBuilder) -> None:
        builder.seller("EU Ltd", peppol_id="0088:1234567890123")
        assert builder._seller.peppol_id == "0088:1234567890123"

    def test_buyer_with_fatturapa(self, builder: InvoiceBuilder) -> None:
        builder.buyer(
            "Italian SPA",
            codice_fiscale="12345678901",
            codice_destinatario="ABCDEFG",
            pec="test@pec.it",
        )
        assert builder._buyer.codice_fiscale == "12345678901"
        assert builder._buyer.codice_destinatario == "ABCDEFG"
        assert builder._buyer.pec == "test@pec.it"

    def test_seller_party(self, builder: InvoiceBuilder) -> None:
        party = Party(name="Acme GmbH", city="Berlin", country="DE")
        builder.seller_party(party)
        assert builder._seller == party

    def test_add_item(self, builder: InvoiceBuilder) -> None:
        builder.add_item("Consulting", quantity=8, unit_price=150.0, unit="HUR", vat_rate=19.0)
        assert len(builder._items) == 1
        assert builder._items[0].description == "Consulting"
        assert builder._items[0].unit == "HUR"

    def test_add_item_defaults(self, builder: InvoiceBuilder) -> None:
        builder.add_item("Item", quantity=1, unit_price=100.0)
        assert builder._items[0].unit == "C62"
        assert builder._items[0].vat_rate == 19.0

    def test_add_item_with_natura(self, builder: InvoiceBuilder) -> None:
        builder.add_item("Service", quantity=1, unit_price=100.0, vat_rate=0, natura="N4")
        assert builder._items[0].natura == "N4"

    def test_add_multiple_items(self, builder: InvoiceBuilder) -> None:
        builder.add_item("Item 1", quantity=1, unit_price=100.0)
        builder.add_item("Item 2", quantity=2, unit_price=200.0)
        assert len(builder._items) == 2

    def test_items_replaces_all(self, builder: InvoiceBuilder) -> None:
        builder.add_item("Old Item", quantity=1, unit_price=50.0)
        builder.items([
            LineItem(description="New Item 1", quantity=1, unit_price=100.0),
            LineItem(description="New Item 2", quantity=2, unit_price=200.0),
        ])
        assert len(builder._items) == 2
        assert builder._items[0].description == "New Item 1"

    def test_payment(self, builder: InvoiceBuilder) -> None:
        builder.payment(iban="DE89370400440532013000", bic="COBADEFFXXX", terms="Net 30")
        assert builder._payment is not None
        assert builder._payment.iban == "DE89370400440532013000"

    def test_logo_base64(self, builder: InvoiceBuilder) -> None:
        builder.logo_base64("iVBORw0KGgoAAAANS...", width_mm=30)
        assert builder._customization.logo_base64 == "iVBORw0KGgoAAAANS..."
        assert builder._customization.logo_width_mm == 30

    def test_logo_file(self, builder: InvoiceBuilder) -> None:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            f.write(b"\x89PNG\r\n\x1a\n")
            temp_path = f.name

        try:
            builder.logo_file(temp_path, width_mm=25)
            expected = base64.b64encode(b"\x89PNG\r\n\x1a\n").decode("utf-8")
            assert builder._customization.logo_base64 == expected
        finally:
            Path(temp_path).unlink()

    def test_footer_text(self, builder: InvoiceBuilder) -> None:
        builder.footer_text("Thank you!")
        assert builder._customization.footer_text == "Thank you!"

    def test_accent_color(self, builder: InvoiceBuilder) -> None:
        builder.accent_color("#8b5cf6")
        assert builder._customization.accent_color == "#8b5cf6"

    def test_template_options(self, builder: InvoiceBuilder) -> None:
        for tmpl in ["minimal", "classic", "compact"]:
            builder.template(tmpl)  # type: ignore
            assert builder._template == tmpl

    def test_format_options(self, builder: InvoiceBuilder) -> None:
        for fmt in ["auto", "zugferd", "facturx", "xrechnung", "ubl", "cii", "peppol", "fatturapa", "pdf"]:
            builder.format(fmt)  # type: ignore
            assert builder._format == fmt

    def test_profile_options(self, builder: InvoiceBuilder) -> None:
        for prof in ["minimum", "basic_wl", "basic", "en16931", "extended"]:
            builder.profile(prof)  # type: ignore
            assert builder._profile == prof


class TestInvoiceSuccess:
    @pytest.fixture
    def success_result(self) -> InvoiceSuccess:
        return InvoiceSuccess(
            pdf_base64="JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            filename="invoice-2026-001.pdf",
            format=FormatInfo(format_used="zugferd", profile="EN16931", version="2.3"),
        )

    def test_success_property(self, success_result: InvoiceSuccess) -> None:
        assert success_result.success is True

    def test_to_bytes(self, success_result: InvoiceSuccess) -> None:
        pdf_bytes = success_result.to_bytes()
        assert isinstance(pdf_bytes, bytes)
        assert pdf_bytes.startswith(b"%PDF")

    def test_to_data_url(self, success_result: InvoiceSuccess) -> None:
        data_url = success_result.to_data_url()
        assert data_url.startswith("data:application/pdf;base64,")

    def test_save_pdf(self, success_result: InvoiceSuccess) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = Path(temp_dir) / "subdir" / "invoice.pdf"
            success_result.save_pdf(file_path)
            assert file_path.exists()
            assert file_path.read_bytes().startswith(b"%PDF")

    def test_format_info(self, success_result: InvoiceSuccess) -> None:
        assert success_result.format.format_used == "zugferd"
        assert success_result.format.profile == "EN16931"


class TestInvoiceFailure:
    def test_failure_property(self) -> None:
        from thelawin import ValidationError
        failure = InvoiceFailure(errors=[
            ValidationError(path="$.invoice.number", code="REQUIRED", message="Required"),
        ])
        assert failure.success is False
        assert len(failure.errors) == 1
