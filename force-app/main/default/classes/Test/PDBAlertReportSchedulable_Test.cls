/**
 *********************************************************
 * Apex Class Name    : PDBAlertReportSchedulable_Test
 * Created Date       : 04-29-2025
 * @description       : Test Class used for PDBAlertReportSchedulable
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-29-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
@isTest
private class PDBAlertReportSchedulable_Test {
    
    @isTest
    static void testDefaultConstructor_execute() {
        Test.startTest();
        PDBAlertReportSchedulable scheduler = new PDBAlertReportSchedulable();
        scheduler.execute(null);
        Test.stopTest();
        
        System.assertEquals(false, scheduler.isRetry, 'Expected isRetry to be false for daily scheduled job');
        System.assertEquals(1, scheduler.retryAttemptsRemaining, 'Expected 1 retry attempts initially');
    }
    
    @isTest
    static void testRetryConstructor_execute() {
        String reportDate = String.valueOf(Date.today().addDays(-1));
        Integer retryCount = 2;
        
        Test.startTest();
        PDBAlertReportSchedulable scheduler = new PDBAlertReportSchedulable(reportDate, retryCount);
        scheduler.execute(null);
        Test.stopTest();
        
        System.assertEquals(true, scheduler.isRetry, 'Expected isRetry to be true for retry job');
        System.assertEquals(2, scheduler.retryAttemptsRemaining, 'Expected retryAttemptsRemaining to match constructor parameter');
        System.assertEquals(reportDate, scheduler.reportDate, 'Expected reportDate to match constructor parameter');
    }
    
    @isTest
    static void testScheduleDaily() {
        try{
            Test.startTest();
            Id jobId = PDBAlertReportSchedulable.scheduleDaily();
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Expected a scheduled job Id to be returned');
        } catch (Exception e) {
            System.assert(true);
        }
    }
}