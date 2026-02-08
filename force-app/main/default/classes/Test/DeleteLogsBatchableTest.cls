/**
 * @description       : 
 * @author            : Stefan Nidzovic
 * @group             : 
 * @last modified on  : 04-30-2025
 * @last modified by  : Stefan Nidzovic
**/
@isTest
public class DeleteLogsBatchableTest {
    
    @testSetup
    static void setupTestData() {
        // Insert test ht_Logger__c records
        List<ht_Logger__c> logRecords = new List<ht_Logger__c>();
        for (Integer i = 0; i < 10; i++) {
            ht_Logger__c log = new ht_Logger__c();

            log.ht_LogLevel__c = 'Info';
            log.ht_Message__c = 'Test Message ' + i;
            log.ht_Details__c = 'Test Details ' + i;

            logRecords.add(log);
        }

        insert logRecords;

        for (Integer i = 0; i < 10; i++) {
            if (Math.mod(i, 2) == 0) {
                Test.setCreatedDate(logRecords[i].Id, Datetime.now().addDays(-14));
            }
        }

        update logRecords;
    }

    @isTest
    static void testDeleteLogsBatch() {
        // create data
        Integer initialCount = [SELECT COUNT() FROM ht_Logger__c];
        System.assertEquals(10, initialCount, 'Initial count of ht_Logger__c records should be 10');

        // execute
        Test.startTest();
        new DeleteLogsScheduleable().execute(null);
        Test.stopTest();

        // assert
        Integer finalCount = [SELECT COUNT() FROM ht_Logger__c];
        System.assertEquals(5, finalCount, 'All ht_Logger__c records should be deleted');
    }

    @isTest
    static void testScheduleMethod() {
        Id jobId = DeleteLogsScheduleable.scheduleTwiceMonthly();

        System.assert(jobId == null);
    }
}