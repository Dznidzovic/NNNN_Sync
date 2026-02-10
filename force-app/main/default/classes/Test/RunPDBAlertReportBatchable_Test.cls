/**
 *********************************************************
 * Apex Class Name    : RunPDBAlertReportBatchable_Test
 * Created Date       : 04-29-2025
 * @description       : Test Class used for RunPDBAlertReportBatchable
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-29-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
@isTest
private class RunPDBAlertReportBatchable_Test {

    @isTest
    static void testStartMethod() {
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(String.valueOf(Date.today()), 3);

        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'Expected QueryLocator not to be null');
    }

    @isTest
    static void testExecuteMethod_withEmptyList() {
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(String.valueOf(Date.today()), 3);

        Test.startTest();
        batch.execute(null, new List<d4c_Subscription__c>());
        Test.stopTest();

        System.assertEquals(false, batch.reportNotAvailable, 'Expected reportNotAvailable to remain false');
        System.assertEquals(false, batch.noAlertsToday, 'Expected noAlertsToday to remain false');
    }

    @isTest
    static void testExecuteMethod_reportNotFinished() {
        d4c_Subscription__c sub = TestDataFactory.createSubscription(true);

        d4c_Entity__c prod = TestDataFactory.createEntity('11111');
        prod.d4c_Subscription__c = sub.Id;

        insert prod;
        
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(String.valueOf(Date.today()), 3);
        
        Test.startTest();
        batch.execute(null, new List<d4c_Subscription__c>{ getSubscription(sub.Id) });
        Test.stopTest();
        
        System.assertEquals(true, batch.reportNotAvailable, 'Expected reportNotAvailable set when report not finished');
        System.assertEquals(false, batch.noAlertsToday, 'Expected noAlertsToday to remain false');
    }

    @isTest
    static void testFinishMethod_retryScheduled() {
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(String.valueOf(Date.today()), 2);
        batch.reportNotAvailable = true;

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(true, batch.testRetryScheduled, 'Expected retry to be scheduled');
        System.assertEquals(1, batch.testRetryAttemptsRemaining, 'Expected retryAttemptsRemaining decremented by 1');
        System.assertNotEquals(null, batch.testScheduledJobId, 'Expected a scheduled Job Id');
    }

    @isTest
    static void testFinishMethod_noRetryScheduled() {
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(String.valueOf(Date.today()), 0);
        batch.reportNotAvailable = true;

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(false, batch.testRetryScheduled, 'Expected no retry scheduled when no attempts remain');
    }

    private static d4c_Subscription__c getSubscription(Id id) {
        return [
            SELECT
                Id,
                Name,
                d4c_Subscription_Name__c,
                (SELECT Id FROM Entitys__r)
            FROM d4c_Subscription__c WHERE Id = :id
        ];
    }
}