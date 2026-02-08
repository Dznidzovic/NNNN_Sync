/**
 *********************************************************
 * Apex Class Name    : CorrelationIdUtils
 * Created Date       : 11-02-2025
 * @description       : Utility class for managing correlation IDs across NIPR transactions
 *                      to track related operations through the entire flow
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author             Modification
 * 1.0   11-02-2025   Stefan Nidzovic    Initial Version
 *********************************************************
 **/
public with sharing class CorrelationIdUtils {
    // Store correlation ID in a static variable for the transaction
    private static String currentCorrelationId;

    /**
     * Generate a new correlation ID for the current transaction
     * Format: YYYYMMDD-HHMMSS-RandomId
     */
    public static String generateCorrelationId(String prefix) {
        if (currentCorrelationId == null) {
            DateTime now = DateTime.now();
            String timestamp = now.format('yyyyMMdd-HHmmss');
            String randomId = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
            currentCorrelationId = prefix + '-' + timestamp + '-' + randomId;
        }
        return currentCorrelationId;
    }

    /**
     * Get the current correlation ID for this transaction
     */
    public static String getCurrentCorrelationId() {
        return currentCorrelationId;
    }

    /**
     * Set correlation ID (useful when continuing from a previous transaction)
     */
    public static void setCorrelationId(String correlationId) {
        currentCorrelationId = correlationId;
    }

    /**
     * Clear the correlation ID (useful for testing)
     */
    public static void clearCorrelationId() {
        currentCorrelationId = null;
    }

    /**
     * Format log message with correlation ID
     */
    public static String formatLogMessage(String message) {
        if (currentCorrelationId != null) {
            return '[' + currentCorrelationId + '] ' + message;
        }
        return message;
    }
}