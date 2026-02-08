/**
 *********************************************************
 * Apex Class Name    : RunPDBAlert_Test
 * Created Date       : 03-30-2025
 * @description       : Test Class used for RunPDBAlert queueable class.
 *                      This test ensures the queueable can be enqueued properly.
 *                      No logic is tested here because the inner service class is
 *                      already unit tested separately.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
@isTest
public class RunPDBAlert_Test {
    
    @isTest
    static void testRunPDBAlertEnqueue() {
        // Prepare Mock
        HttpSoapMultiMockFactory mockFactory = new HttpSoapMultiMockFactory()
            .addMock(
                'ind:receiveSpecificReportForSubscription', 
                200, 
                TestDataFactory.getPDBSpecificAlertResponse(),
                false
            );

        Test.setMock(HttpCalloutMock.class, mockFactory);

        Test.startTest();
        RunPDBAlert job = new RunPDBAlert('2025-03-30', 'Test_Subscription');
        Id jobId = System.enqueueJob(job);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Queueable Job ID should not be null.');
    }
}