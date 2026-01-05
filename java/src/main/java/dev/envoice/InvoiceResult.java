package dev.envoice;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.List;

/**
 * Result of an invoice generation
 */
public sealed interface InvoiceResult {

    boolean isSuccess();

    /**
     * Successful invoice generation
     */
    record Success(
        String pdfBase64,
        String filename,
        Types.ValidationResult validation,
        Types.AccountInfo account
    ) implements InvoiceResult {

        @Override
        public boolean isSuccess() {
            return true;
        }

        /**
         * Save the PDF to a file
         */
        public void savePdf(String path) throws IOException {
            savePdf(Path.of(path));
        }

        /**
         * Save the PDF to a file
         */
        public void savePdf(Path path) throws IOException {
            Files.createDirectories(path.getParent());
            Files.write(path, toBytes());
        }

        /**
         * Get the PDF as bytes
         */
        public byte[] toBytes() {
            return Base64.getDecoder().decode(pdfBase64);
        }

        /**
         * Get the PDF as a data URL
         */
        public String toDataUrl() {
            return "data:application/pdf;base64," + pdfBase64;
        }
    }

    /**
     * Failed invoice generation
     */
    record Failure(List<Types.ValidationError> errors) implements InvoiceResult {

        @Override
        public boolean isSuccess() {
            return false;
        }
    }
}
