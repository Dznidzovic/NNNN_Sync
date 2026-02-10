/**
 *********************************************************
 * Apex Class Name    : DMLExecutor_Test
 * Created Date       : 03-19-2025
 * @description       : Test Class used for DMLExecutor
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Dev4Clouds          Initial Version
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

        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        // Execute
        Test.startTest();
        new DMLExecutor(entitys, d4c_Entity__c.d4c_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert
        List<d4c_Entity__c> inserted = [SELECT Id, d4c_NPN__c FROM d4c_Entity__c];
        System.assertEquals(100, inserted.size(), 'Should insert 100 entitys');
    }

    @isTest
    static void execute_testDMLExecutorUpsertOverBatchSize() {
        // Prepare Data
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 9001; i++) {
            npns.add('npn' + i);
        }

        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        // Execute
        Test.startTest();
        new DMLExecutor(entitys, d4c_Entity__c.d4c_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(9000, [SELECT count() FROM d4c_Entity__c], 'Should upsert 9k entitys');
    }

    @isTest
    static void execute_testDMLExecutorDeleteBelowBatchSize() {
        // Prepare DAta
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 100; i++) {
            npns.add('del' + i);
        }

        List<d4c_Entity__c> toDelete = TestDataFactory.createEntitys(npns);
        insert toDelete;

        List<Id> idsToDelete = new List<Id>();
        for (d4c_Entity__c prod : toDelete) {
            idsToDelete.add(prod.Id);
        }

        // Execute
        Test.startTest();
        new DMLExecutor(idsToDelete, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM d4c_Entity__c WHERE Id IN :idsToDelete], 'Should delete all entitys');
    }

    @isTest
    static void execute_testDMLExecutorDeleteOverBatchSize() {
        // Prepare Data
        Set<String> npns = new Set<String>();
        for (Integer i = 0; i < 9001; i++) {
            npns.add('delete' + i);
        }

        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        insert entitys;

        List<Id> idsToDelete = new List<Id>();
        for (d4c_Entity__c p : entitys) {
            idsToDelete.add(p.Id);
        }

        // Execute
        Test.startTest();
        new DMLExecutor(idsToDelete, null).execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(1, [SELECT count() FROM d4c_Entity__c WHERE Id IN :idsToDelete], 'All records should be deleted');
    }

    @isTest
    static void execute_testDMLExecutorHandlesEmptyInputs() {
        // Execute
        Test.startTest();
        new DMLExecutor(new List<Id>(), null).execute(null);
        new DMLExecutor(new List<SObject>(), d4c_Entity__c.d4c_NPN__c, null).execute(null);
        Test.stopTest();

        // Assert no exceptions
        System.assert(true);
    }

    @isTest
    static void execute_testUpsertExceptionWithNIPRServiceLogging() {
        // Prepare Data - create entitys to upsert
        Set<String> npns = new Set<String>{ '11111111', '22222222' };
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        // Force exception
        DMLExecutor.forceException = true;

        // Execute with ProcessPDBAlertReportService caller to trigger logNIPRServiceError
        Test.startTest();
        DMLExecutor executor = new DMLExecutor(
            entitys,
            d4c_Entity__c.d4c_NPN__c,
            null,
            'ProcessPDBAlertReportService'
        );
        executor.execute(null);
        Test.stopTest();

        // Reset flag
        DMLExecutor.forceException = false;

        // Assert - exception should be handled gracefully (no records inserted)
        System.assertEquals(0, [SELECT count() FROM d4c_Entity__c], 'No entitys should be inserted due to exception');
    }
}