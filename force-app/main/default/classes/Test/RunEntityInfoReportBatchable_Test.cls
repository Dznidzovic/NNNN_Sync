/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReport_Test
 * Created Date       : 04-13-2025
 * @description       : Test Class used for RunEntityInfoReportBatchable batchable class.
 *                      This test ensures the batchable can be executed properly.
 *                      No logic is tested here because the inner service class is
 *                      already unit tested separately.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-13-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
@isTest
public class RunEntityInfoReportBatchable_Test {
    @isTest
    static void testRunEntityInfoBatchExecution() {
        // Set mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        Set<String> npnSet = new Set<String>{'535325'};
        RunEntityInfoReportBatchable batchJob = new RunEntityInfoReportBatchable(npnSet);
        Id batchId = Database.executeBatch(batchJob, 1);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, batchId, 'Batch Job ID should not be null.');
    }

    @isTest
    static void testRunEntityInfoBatch_Error() {
        // Set data
        ht_Producer__c prod = TestDataFactory.createProducer('12345678');
        ProducerTriggerHandler.triggerDisabled = true;
        insert prod;
        ProducerTriggerHandler.triggerDisabled = false;


        // Set mock
        HttpMockFactory mockFactory = new HttpMockFactory(500, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        Set<String> npnSet = new Set<String>{'12345678'};
        RunEntityInfoReportBatchable batchJob = new RunEntityInfoReportBatchable(npnSet);
        Id batchId = Database.executeBatch(batchJob, 1);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, batchId, 'Batch Job ID should not be null.');
    }

    @isTest
    static void testRunEntityInfoBatch_SuccessWithExistingProducer() {
        // Set data - create producer with NPN that matches the mock response
        ht_Producer__c prod = TestDataFactory.createProducer('535325');
        ProducerTriggerHandler.triggerDisabled = true;
        insert prod;
        ProducerTriggerHandler.triggerDisabled = false;

        // Set mock with success response
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        Set<String> npnSet = new Set<String>{'535325'};
        RunEntityInfoReportBatchable batchJob = new RunEntityInfoReportBatchable(npnSet);
        Id batchId = Database.executeBatch(batchJob, 1);
        Test.stopTest();

        // Assert - batch completed successfully and producer was queried without field errors
        System.assertNotEquals(null, batchId, 'Batch Job ID should not be null.');

        // Verify producer still exists and can be queried with all required fields
        List<ht_Producer__c> producers = [SELECT Id, ht_NPN__c, ht_NPNStatus__c, ht_Subscription__c, ht_ExcludeCarrierAppointments__c FROM ht_Producer__c WHERE ht_NPN__c = '535325'];
        System.assertEquals(1, producers.size(), 'Producer should exist after batch execution.');
    }
}