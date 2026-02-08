/**
 *********************************************************
 * Apex Class Name    : CorrelationIdUtils_Test
 * Created Date       : 2025-12-24
 * @description       : Test class for CorrelationIdUtils
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author             Modification
 * 1.0   2025-12-24   Stefan Nidzovic             Initial Version
 *********************************************************
 **/
@isTest
private class CorrelationIdUtils_Test {

    @isTest
    static void generateCorrelationId_createsValidId() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String prefix = 'NIPR';

        // Act
        Test.startTest();
        String correlationId = CorrelationIdUtils.generateCorrelationId(prefix);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, correlationId, 'Correlation ID should not be null');
        System.assert(correlationId.startsWith(prefix), 'Correlation ID should start with prefix');
        System.assert(correlationId.contains('-'), 'Correlation ID should contain hyphens');
    }

    @isTest
    static void generateCorrelationId_returnsSameIdInSameTransaction() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String prefix = 'TEST';

        // Act
        Test.startTest();
        String firstId = CorrelationIdUtils.generateCorrelationId(prefix);
        String secondId = CorrelationIdUtils.generateCorrelationId(prefix);
        Test.stopTest();

        // Assert
        System.assertEquals(firstId, secondId, 'Should return same ID in same transaction');
    }

    @isTest
    static void getCurrentCorrelationId_returnsNull_whenNoneSet() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();

        // Act
        Test.startTest();
        String correlationId = CorrelationIdUtils.getCurrentCorrelationId();
        Test.stopTest();

        // Assert
        System.assertEquals(null, correlationId, 'Should return null when no correlation ID is set');
    }

    @isTest
    static void getCurrentCorrelationId_returnsSetId() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String prefix = 'API';
        CorrelationIdUtils.generateCorrelationId(prefix);

        // Act
        Test.startTest();
        String correlationId = CorrelationIdUtils.getCurrentCorrelationId();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, correlationId, 'Should return the generated correlation ID');
        System.assert(correlationId.startsWith(prefix), 'Should start with the prefix');
    }

    @isTest
    static void setCorrelationId_setsCustomId() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String customId = 'CUSTOM-20250101-123456';

        // Act
        Test.startTest();
        CorrelationIdUtils.setCorrelationId(customId);
        String retrievedId = CorrelationIdUtils.getCurrentCorrelationId();
        Test.stopTest();

        // Assert
        System.assertEquals(customId, retrievedId, 'Should set and retrieve custom correlation ID');
    }

    @isTest
    static void clearCorrelationId_resetsId() {
        // Arrange
        CorrelationIdUtils.generateCorrelationId('TEST');
        System.assertNotEquals(null, CorrelationIdUtils.getCurrentCorrelationId(), 'ID should be set initially');

        // Act
        Test.startTest();
        CorrelationIdUtils.clearCorrelationId();
        String clearedId = CorrelationIdUtils.getCurrentCorrelationId();
        Test.stopTest();

        // Assert
        System.assertEquals(null, clearedId, 'Correlation ID should be null after clearing');
    }

    @isTest
    static void formatLogMessage_withCorrelationId_prependsId() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String correlationId = CorrelationIdUtils.generateCorrelationId('LOG');
        String message = 'Test log message';

        // Act
        Test.startTest();
        String formattedMessage = CorrelationIdUtils.formatLogMessage(message);
        Test.stopTest();

        // Assert
        System.assert(formattedMessage.startsWith('['), 'Should start with bracket');
        System.assert(formattedMessage.contains(correlationId), 'Should contain correlation ID');
        System.assert(formattedMessage.contains(message), 'Should contain original message');
    }

    @isTest
    static void formatLogMessage_withoutCorrelationId_returnsUnmodified() {
        // Arrange
        CorrelationIdUtils.clearCorrelationId();
        String message = 'Test log message';

        // Act
        Test.startTest();
        String formattedMessage = CorrelationIdUtils.formatLogMessage(message);
        Test.stopTest();

        // Assert
        System.assertEquals(message, formattedMessage, 'Should return unmodified message when no correlation ID');
    }
}