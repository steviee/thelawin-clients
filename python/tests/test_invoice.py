"""Tests for the InvoiceBuilder."""

import base64
import tempfile
from datetime import date
from pathlib import Path

import pytest

from envoice import (
    EnvoiceClient,
    InvoiceBuilder,
    InvoiceSuccess,
    InvoiceFailure,
    Party,
    LineItem,
)


class TestInvoiceBuilder:
    """Tests for the InvoiceBuilder class."""

    @pytest.fixture
    def client(self) -> EnvoiceClient:
        """Create a test client."""
        return EnvoiceClient("env_sandbox_test")

    @pytest.fixture
    def builder(self, client: EnvoiceClient) -> InvoiceBuilder:
        """Create a test builder."""
        return client.invoice()

    def test_fluent_interface(self, builder: InvoiceBuilder) -> None:
        """Test that all methods return self for chaining."""
        result = (
            builder
            .number("2026-001")
            .date("2026-01-15")
            .due_date("2026-02-15")
            .currency("EUR")
            .template("minimal")
            .locale("de")
        )
        assert result is builder

    def test_date_with_string(self, builder: InvoiceBuilder) -> None:
        """Test setting date with string."""
        builder.date("2026-01-15")
        assert builder._date == "2026-01-15"

    def test_date_with_date_object(self, builder: InvoiceBuilder) -> None:
        """Test setting date with date object."""
        builder.date(date(2026, 1, 15))
        assert builder._date == "2026-01-15"

    def test_due_date_with_date_object(self, builder: InvoiceBuilder) -> None:
        """Test setting due date with date object."""
        builder.due_date(date(2026, 2, 15))
        assert builder._due_date == "2026-02-15"

    def test_seller_with_kwargs(self, builder: InvoiceBuilder) -> None:
        """Test setting seller with keyword arguments."""
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
        assert builder._seller.city == "Berlin"

    def test_seller_party(self, builder: InvoiceBuilder) -> None:
        """Test setting seller from Party object."""
        party = Party(name="Acme GmbH", city="Berlin", country="DE")
        builder.seller_party(party)
        assert builder._seller == party

    def test_buyer_with_kwargs(self, builder: InvoiceBuilder) -> None:
        """Test setting buyer with keyword arguments."""
        builder.buyer("Customer AG", city="München", country="DE")
        assert builder._buyer is not None
        assert builder._buyer.name == "Customer AG"
        assert builder._buyer.city == "München"

    def test_add_item(self, builder: InvoiceBuilder) -> None:
        """Test adding a line item."""
        builder.add_item("Consulting", quantity=8, unit_price=150.0, unit="HUR", vat_rate=19.0)
        assert len(builder._items) == 1
        assert builder._items[0].description == "Consulting"
        assert builder._items[0].quantity == 8
        assert builder._items[0].unit_price == 150.0
        assert builder._items[0].unit == "HUR"
        assert builder._items[0].vat_rate == 19.0

    def test_add_item_defaults(self, builder: InvoiceBuilder) -> None:
        """Test add_item with default values."""
        builder.add_item("Item", quantity=1, unit_price=100.0)
        assert builder._items[0].unit == "C62"
        assert builder._items[0].vat_rate == 19.0

    def test_add_multiple_items(self, builder: InvoiceBuilder) -> None:
        """Test adding multiple items."""
        builder.add_item("Item 1", quantity=1, unit_price=100.0)
        builder.add_item("Item 2", quantity=2, unit_price=200.0)
        assert len(builder._items) == 2

    def test_items_replaces_all(self, builder: InvoiceBuilder) -> None:
        """Test that items() replaces all items."""
        builder.add_item("Old Item", quantity=1, unit_price=50.0)
        builder.items([
            LineItem(description="New Item 1", quantity=1, unit_price=100.0),
            LineItem(description="New Item 2", quantity=2, unit_price=200.0),
        ])
        assert len(builder._items) == 2
        assert builder._items[0].description == "New Item 1"

    def test_payment(self, builder: InvoiceBuilder) -> None:
        """Test setting payment info."""
        builder.payment(iban="DE89370400440532013000", bic="COBADEFFXXX", terms="Net 30")
        assert builder._payment is not None
        assert builder._payment.iban == "DE89370400440532013000"
        assert builder._payment.bic == "COBADEFFXXX"
        assert builder._payment.terms == "Net 30"

    def test_logo_base64(self, builder: InvoiceBuilder) -> None:
        """Test setting logo from base64."""
        builder.logo_base64("iVBORw0KGgoAAAANS...", width_mm=30)
        assert builder._customization.logo_base64 == "iVBORw0KGgoAAAANS..."
        assert builder._customization.logo_width_mm == 30

    def test_logo_file(self, builder: InvoiceBuilder) -> None:
        """Test setting logo from file."""
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            f.write(b"\x89PNG\r\n\x1a\n")
            temp_path = f.name

        try:
            builder.logo_file(temp_path, width_mm=25)
            expected_base64 = base64.b64encode(b"\x89PNG\r\n\x1a\n").decode("utf-8")
            assert builder._customization.logo_base64 == expected_base64
            assert builder._customization.logo_width_mm == 25
        finally:
            Path(temp_path).unlink()

    def test_footer_text(self, builder: InvoiceBuilder) -> None:
        """Test setting footer text."""
        builder.footer_text("Thank you for your business!")
        assert builder._customization.footer_text == "Thank you for your business!"

    def test_accent_color(self, builder: InvoiceBuilder) -> None:
        """Test setting accent color."""
        builder.accent_color("#8b5cf6")
        assert builder._customization.accent_color == "#8b5cf6"

    def test_template_options(self, builder: InvoiceBuilder) -> None:
        """Test different template options."""
        for template in ["minimal", "classic", "compact"]:
            builder.template(template)  # type: ignore
            assert builder._template == template


class TestInvoiceSuccess:
    """Tests for the InvoiceSuccess class."""

    @pytest.fixture
    def success_result(self) -> InvoiceSuccess:
        """Create a test success result."""
        from envoice import ValidationResult
        return InvoiceSuccess(
            pdf_base64="JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            filename="invoice-2026-001.pdf",
            validation=ValidationResult(status="valid", profile="EN16931", version="2.3.2"),
        )

    def test_success_property(self, success_result: InvoiceSuccess) -> None:
        """Test success property."""
        assert success_result.success is True

    def test_to_bytes(self, success_result: InvoiceSuccess) -> None:
        """Test converting to bytes."""
        pdf_bytes = success_result.to_bytes()
        assert isinstance(pdf_bytes, bytes)
        assert pdf_bytes.startswith(b"%PDF")

    def test_to_data_url(self, success_result: InvoiceSuccess) -> None:
        """Test converting to data URL."""
        data_url = success_result.to_data_url()
        assert data_url.startswith("data:application/pdf;base64,")

    def test_save_pdf(self, success_result: InvoiceSuccess) -> None:
        """Test saving PDF to file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = Path(temp_dir) / "subdir" / "invoice.pdf"
            success_result.save_pdf(file_path)

            assert file_path.exists()
            content = file_path.read_bytes()
            assert content.startswith(b"%PDF")


class TestInvoiceFailure:
    """Tests for the InvoiceFailure class."""

    def test_failure_property(self) -> None:
        """Test failure property."""
        from envoice import ValidationError
        failure = InvoiceFailure(errors=[
            ValidationError(path="$.invoice.number", code="REQUIRED", message="Required"),
        ])
        assert failure.success is False
        assert len(failure.errors) == 1
