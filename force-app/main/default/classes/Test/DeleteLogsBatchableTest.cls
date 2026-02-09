/**
 * @description       : 
 * @author            : Stefan Nidzovic
 * @group             : 
 * @last modified on  : 02-09-2026
 * @last modified by  : Stefan Nidzovic
**/
@isTest
public class DeleteLogsBatchableTest {
    
    @testSetup
    static void setupTestData() {
        // Insert test d4c_Logger__c records
        List<d4c_Logger__c> logRecords = new List<d4c_Logger__c>();
        for (Integer i = 0; i < 10; i++) {
            d4c_Logger__c log = new d4c_Logger__c();

            log.d4c_LogLevel__c = 'Info';
            log.d4c_Message__c = 'Test Message ' + i;
            log.d4c_Details__c = 'Test Details ' + i;

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
        Integer initialCount = [SELECT COUNT() FROM d4c_Logger__c];
        System.assertEquals(10, initialCount, 'Initial count of d4c_Logger__c records should be 10');

        // execute
        Test.startTest();
        new DeleteLogsScheduleable().execute(null);
        Test.stopTest();

        // assert
        Integer finalCount = [SELECT COUNT() FROM d4c_Logger__c];
        System.assertEquals(5, finalCount, 'All d4c_Logger__c records should be deleted');
    }

    @isTest
    static void testScheduleMethod() {
        Id jobId = DeleteLogsScheduleable.scheduleTwiceMonthly();

        System.assert(jobId == null);
    }
}