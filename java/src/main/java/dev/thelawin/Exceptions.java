package dev.thelawin;

import java.util.List;

/**
 * Exception classes for the thelawin SDK
 */
public final class Exceptions {

    private Exceptions() {}

    /**
     * Base exception for all thelawin SDK errors
     */
    public static class ThelawinException extends RuntimeException {
        public ThelawinException(String message) {
            super(message);
        }

        public ThelawinException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    /**
     * Exception thrown when the API returns validation errors
     */
    public static class ThelawinValidationException extends ThelawinException {
        private final List<Types.ValidationError> errors;
        private final int statusCode;

        public ThelawinValidationException(List<Types.ValidationError> errors, int statusCode) {
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
    public static class ThelawinApiException extends ThelawinException {
        private final int statusCode;
        private final String code;

        public ThelawinApiException(String message, int statusCode, String code) {
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
    public static class ThelawinNetworkException extends ThelawinException {
        public ThelawinNetworkException(String message) {
            super(message);
        }

        public ThelawinNetworkException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    /**
     * Exception thrown when quota is exceeded
     */
    public static class ThelawinQuotaExceededException extends ThelawinApiException {
        public ThelawinQuotaExceededException(String message) {
            super(message, 402, "quota_exceeded");
        }
    }
}
