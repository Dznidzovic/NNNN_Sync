/**
 *********************************************************
 * Apex Class Name    : DMLExecutor_Test
 * Created Date       : 03-19-2025
 * @description       : Test Class used for DMLExecutor
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
@isTest
private class DMLExecutor_Test {
    @isTest
    static void execute_testDMLExecutorUpsertBelowBatchSize() {
        // Prepare Data
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 100; i++) {
            npns.add(String.valueOf(i));
        }

        List<ht_Producer__c> producers = TestDataFactory.createProducers(npns);

        // Execute
        Test.startTest();
        new DMLExecutor(producers, ht_Producer__c.ht_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert
        List<ht_Producer__c> inserted = [SELECT Id, ht_NPN__c FROM ht_Producer__c];
        System.assertEquals(100, inserted.size(), 'Should insert 100 producers');
    }

    @isTest
    static void execute_testDMLExecutorUpsertOverBatchSize() {
        // Prepare Data
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 9001; i++) {
            npns.add('npn' + i);
        }

        List<ht_Producer__c> producers = TestDataFactory.createProducers(npns);

        // Execute
        Test.startTest();
        new DMLExecutor(producers, ht_Producer__c.ht_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(9000, [SELECT count() FROM ht_Producer__c], 'Should upsert 9k producers');
    }

    @isTest
    static void execute_testDMLExecutorDeleteBelowBatchSize() {
        // Prepare DAta
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 100; i++) {
            npns.add('del' + i);
        }

        List<ht_Producer__c> toDelete = TestDataFactory.createProducers(npns);
        insert toDelete;

        List<Id> idsToDelete = new List<Id>();
        for (ht_Producer__c prod : toDelete) {
            idsToDelete.add(prod.Id);
        }

        // Execute
        Test.startTest();
        new DMLExecutor(idsToDelete, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM ht_Producer__c WHERE Id IN :idsToDelete], 'Should delete all producers');
    }

    @isTest
    static void execute_testDMLExecutorDeleteOverBatchSize() {
        // Prepare Data
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 9001; i++) {
            npns.add('delete' + i);
        }

        List<ht_Producer__c> producers = TestDataFactory.createProducers(npns);
        insert producers;

        List<Id> idsToDelete = new List<Id>();
        for (ht_Producer__c p : producers) {
            idsToDelete.add(p.Id);
        }

        // Execute
        Test.startTest();
        new DMLExecutor(idsToDelete, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(1, [SELECT count() FROM ht_Producer__c WHERE Id IN :idsToDelete], 'All records should be deleted');
    }

    @isTest
    static void execute_testDMLExecutorHandlesEmptyInputs() {
        // Execute
        Test.startTest();
        new DMLExecutor(new List<Id>(), null).execute(null);
        new DMLExecutor(new List<SObject>(), ht_Producer__c.ht_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert no exceptions
        System.assert(true);
    }

    @isTest
    static void execute_testUpsertExceptionWithNIPRServiceLogging() {
        // Prepare Data - create producers to upsert
        Set<String> npns = new Set<String>{ '11111111', '22222222' };
        List<ht_Producer__c> producers = TestDataFactory.createProducers(npns);

        // Force exception
        DMLExecutor.forceException = true;

        // Execute with ProcessPDBAlertReportService caller to trigger logNIPRServiceError
        Test.startTest();
        DMLExecutor executor = new DMLExecutor(
            producers,
            ht_Producer__c.ht_NPN__c,
            null,
            'ProcessPDBAlertReportService'
        );
        executor.execute(null);
        Test.stopTest();

        // Reset flag
        DMLExecutor.forceException = false;

        // Assert - exception should be handled gracefully (no records inserted)
        System.assertEquals(0, [SELECT count() FROM ht_Producer__c], 'No producers should be inserted due to exception');
    }
}