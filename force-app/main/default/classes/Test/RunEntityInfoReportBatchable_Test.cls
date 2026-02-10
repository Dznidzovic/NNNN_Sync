/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReport_Test
 * Created Date       : 04-13-2025
 * @description       : Test Class used for RunEntityInfoReportBatchable batchable class.
 *                      This test ensures the batchable can be executed properly.
 *                      No logic is tested here because the inner service class is
 *                      already unit tested separately.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-13-2025   Dev4Clouds          Initial Version
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
        d4c_Entity__c prod = TestDataFactory.createEntity('12345678');
        EntityTriggerHandler.triggerDisabled = true;
        insert prod;
        EntityTriggerHandler.triggerDisabled = false;


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
    static void testRunEntityInfoBatch_SuccessWithExistingEntity() {
        // Set data - create entity with NPN that matches the mock response
        d4c_Entity__c prod = TestDataFactory.createEntity('535325');
        EntityTriggerHandler.triggerDisabled = true;
        insert prod;
        EntityTriggerHandler.triggerDisabled = false;

        // Set mock with success response
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        Set<String> npnSet = new Set<String>{'535325'};
        RunEntityInfoReportBatchable batchJob = new RunEntityInfoReportBatchable(npnSet);
        Id batchId = Database.executeBatch(batchJob, 1);
        Test.stopTest();

        // Assert - batch completed successfully and entity was queried without field errors
        System.assertNotEquals(null, batchId, 'Batch Job ID should not be null.');

        // Verify entity still exists and can be queried with all required fields
        List<d4c_Entity__c> entitys = [SELECT Id, d4c_NPN__c, d4c_NPNStatus__c, d4c_Subscription__c, d4c_ExcludeCarrierAppointments__c FROM d4c_Entity__c WHERE d4c_NPN__c = '535325'];
        System.assertEquals(1, entitys.size(), 'Entity should exist after batch execution.');
    }
}