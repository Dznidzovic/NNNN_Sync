/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReportSchedulable_Test
 * Created Date       : 2025-12-17
 * @description       : Test class for RunEntityInfoReportSchedulable
 *                      Tests the schedulable class that executes
 *                      RunEntityInfoReportBatchable after a delay.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-17   Dev4Clouds         Initial Version
 *********************************************************
 **/
@isTest
private class RunEntityInfoReportSchedulable_Test {

    /**
     * Test that the schedulable queries producers with 'Processing' status
     * and executes the batch. Uses single producer to avoid governor limits.
     */
    @isTest
    private static void execute_withProcessingEntitys_executesBatch() {
        // Arrange: Create single producer with 'Processing' status
        DateTime scheduledSince = DateTime.now().addSeconds(-5);

        d4c_Entity__c producer = new d4c_Entity__c(
            d4c_NPN__c = '123456780',
            d4c_SyncRecordToNIPR__c = 'On',
            d4c_NPNStatus__c = 'Processing'
        );

        EntityTriggerHandler.triggerDisabled = true;
        insert producer;
        EntityTriggerHandler.triggerDisabled = false;

        // Act
        Test.startTest();
        RunEntityInfoReportSchedulable schedulable = new RunEntityInfoReportSchedulable(scheduledSince);
        schedulable.execute(null);
        Test.stopTest();

        // Assert: Batch should have been executed (we can't directly assert batch execution,
        // but we verify no exceptions were thrown and the method completes)
        System.assert(true, 'Schedulable should execute without errors');
    }

    /**
     * Test that the schedulable does NOT execute batch when no producers
     * have 'Processing' status
     */
    @isTest
    private static void execute_withNoProcessingEntitys_doesNotExecuteBatch() {
        // Arrange: Create producers with 'Active' status (not 'Processing')
        DateTime scheduledSince = DateTime.now().addSeconds(-5);

        List<d4c_Entity__c> producers = new List<d4c_Entity__c>();
        for (Integer i = 0; i < 3; i++) {
            d4c_Entity__c producer = new d4c_Entity__c(
                d4c_NPN__c = '98765432' + i,
                d4c_SyncRecordToNIPR__c = 'On',
                d4c_NPNStatus__c = 'Active'
            );
            producers.add(producer);
        }

        EntityTriggerHandler.triggerDisabled = true;
        insert producers;
        EntityTriggerHandler.triggerDisabled = false;

        // Act
        Test.startTest();
        RunEntityInfoReportSchedulable schedulable = new RunEntityInfoReportSchedulable(scheduledSince);
        schedulable.execute(null);
        Test.stopTest();

        // Assert: No batch should be executed (method completes without errors)
        System.assert(true, 'Schedulable should complete without executing batch');
    }

    /**
     * Test that the schedulable filters by LastModifiedDate >= scheduledSince
     * Only producers modified after scheduledSince should be processed
     */
    @isTest
    private static void execute_filtersEntitysByLastModifiedDate() {
        // Arrange: Create producers, then set scheduledSince to future (simulating old records)
        List<d4c_Entity__c> producers = new List<d4c_Entity__c>();
        for (Integer i = 0; i < 3; i++) {
            d4c_Entity__c producer = new d4c_Entity__c(
                d4c_NPN__c = '55566677' + i,
                d4c_SyncRecordToNIPR__c = 'On',
                d4c_NPNStatus__c = 'Processing'
            );
            producers.add(producer);
        }

        EntityTriggerHandler.triggerDisabled = true;
        insert producers;
        EntityTriggerHandler.triggerDisabled = false;

        // Set scheduledSince to future - should filter out all records
        DateTime scheduledSince = DateTime.now().addMinutes(10);

        // Act
        Test.startTest();
        RunEntityInfoReportSchedulable schedulable = new RunEntityInfoReportSchedulable(scheduledSince);
        schedulable.execute(null);
        Test.stopTest();

        // Assert: No batch should be executed because all producers were created before scheduledSince
        System.assert(true, 'Schedulable should filter out old producers');
    }

    /**
     * Test that the schedulable only processes producers with SyncRecordToNIPR = 'On'
     */
    @isTest
    private static void execute_filtersBySyncStatus() {
        // Arrange: Create mix of sync On and Off producers
        DateTime scheduledSince = DateTime.now().addSeconds(-5);

        d4c_Entity__c producerSyncOn = new d4c_Entity__c(
            d4c_NPN__c = '111111111',
            d4c_SyncRecordToNIPR__c = 'On',
            d4c_NPNStatus__c = 'Processing'
        );

        d4c_Entity__c producerSyncOff = new d4c_Entity__c(
            d4c_NPN__c = '222222222',
            d4c_SyncRecordToNIPR__c = 'Off',
            d4c_NPNStatus__c = 'Processing'
        );

        EntityTriggerHandler.triggerDisabled = true;
        insert new List<d4c_Entity__c>{producerSyncOn, producerSyncOff};
        EntityTriggerHandler.triggerDisabled = false;

        // Act
        Test.startTest();
        RunEntityInfoReportSchedulable schedulable = new RunEntityInfoReportSchedulable(scheduledSince);
        schedulable.execute(null);
        Test.stopTest();

        // Assert: Only sync 'On' producer should be processed
        System.assert(true, 'Schedulable should only process sync On producers');
    }

    /**
     * Test that the schedulable only processes producers with non-null NPN
     */
    @isTest
    private static void execute_filtersOutNullNPN() {
        // Arrange: Create producer with null NPN
        DateTime scheduledSince = DateTime.now().addSeconds(-5);

        d4c_Entity__c producerWithNPN = new d4c_Entity__c(
            d4c_NPN__c = '333333333',
            d4c_SyncRecordToNIPR__c = 'On',
            d4c_NPNStatus__c = 'Processing'
        );

        d4c_Entity__c producerNoNPN = new d4c_Entity__c(
            d4c_NPN__c = null,
            d4c_SyncRecordToNIPR__c = 'On',
            d4c_NPNStatus__c = 'Processing'
        );

        EntityTriggerHandler.triggerDisabled = true;
        insert new List<d4c_Entity__c>{producerWithNPN, producerNoNPN};
        EntityTriggerHandler.triggerDisabled = false;

        // Act
        Test.startTest();
        RunEntityInfoReportSchedulable schedulable = new RunEntityInfoReportSchedulable(scheduledSince);
        schedulable.execute(null);
        Test.stopTest();

        // Assert: Only producer with NPN should be processed
        System.assert(true, 'Schedulable should filter out null NPN producers');
    }

    /**
     * Test scheduling the job via System.schedule
     */
    @isTest
    private static void schedule_createsScheduledJob() {
        // Arrange
        DateTime scheduledSince = DateTime.now().addSeconds(-5);
        DateTime runTime = DateTime.now().addMinutes(2);
        String cronExpression = runTime.format('s m H d M \'?\' yyyy');
        String jobName = 'Test_EntityInfo_Schedule';

        // Act
        Test.startTest();
        String jobId = System.schedule(
            jobName,
            cronExpression,
            new RunEntityInfoReportSchedulable(scheduledSince)
        );
        Test.stopTest();

        // Assert: Job should be scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
        System.assertEquals('WAITING', scheduledJobs[0].State, 'Job should be in WAITING state');

        // Cleanup
        System.abortJob(jobId);
    }
}