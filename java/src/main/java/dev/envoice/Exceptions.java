package dev.envoice;

import java.util.List;

/**
 * Exception classes for the envoice SDK
 */
public final class Exceptions {

    private Exceptions() {}

    /**
     * Base exception for all envoice SDK errors
     */
    public static class EnvoiceException extends RuntimeException {
        public EnvoiceException(String message) {
            super(message);
        }

        public EnvoiceException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    /**
     * Exception thrown when the API returns validation errors
     */
    public static class EnvoiceValidationException extends EnvoiceException {
        private final List<Types.ValidationError> errors;
        private final int statusCode;

        public EnvoiceValidationException(List<Types.ValidationError> errors, int statusCode) {
            super("Validation failed: " + formatErrors(errors));
            this.errors = errors;
            this.statusCode = statusCode;
        }

        public List<Types.ValidationError> getErrors() {
            return errors;
        }

        public int getStatusCode() {
            return statusCode;
        }

        public String toUserMessage() {
            return errors.stream()
                .map(e -> "- " + e.path() + ": " + e.message())
                .reduce((a, b) -> a + "\n" + b)
                .orElse("");
        }

        private static String formatErrors(List<Types.ValidationError> errors) {
            return errors.stream()
                .map(e -> e.path() + ": " + e.message())
                .reduce((a, b) -> a + "; " + b)
                .orElse("");
        }
    }

    /**
     * Exception thrown when the API returns an HTTP error
     */
    public static class EnvoiceApiException extends EnvoiceException {
        private final int statusCode;
        private final String code;

        public EnvoiceApiException(String message, int statusCode, String code) {
            super(message);
            this.statusCode = statusCode;
            this.code = code;
        }

        public int getStatusCode() {
            return statusCode;
        }

        public String getCode() {
            return code;
        }
    }

    /**
     * Exception thrown when a network request fails
     */
    public static class EnvoiceNetworkException extends EnvoiceException {
        public EnvoiceNetworkException(String message) {
            super(message);
        }

        public EnvoiceNetworkException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    /**
     * Exception thrown when quota is exceeded
     */
    public static class EnvoiceQuotaExceededException extends EnvoiceApiException {
        public EnvoiceQuotaExceededException(String message) {
            super(message, 402, "quota_exceeded");
        }
    }
}
