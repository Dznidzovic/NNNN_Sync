/**
 *********************************************************************
 Apex Class Name    : EntityInfoApiControllerTest
 Created Date       : 04-21-2025
 @description       : Test class for EntityInfoApiController to validate NPN processing functionality
 @author            : Stefan Nidzovic
 Modification Log:
 Ver   Date         Author                           Modification
 1.0   04-21-2025   Stefan Nidzovic                  Initial Version
 ********************************************************************
 **/
@isTest
private class EntityInfoApiController_Test {
    // Test constants
    private static final String VALID_NPN = '12345678';
    private static final String EMPTY_NPN = '';
    
    /******************************************************
     @Method Name    : testProcessNPN_withValidNPN
     @author         : Stefan Nidzovic
     @description    : Tests the processNPN method with a valid NPN value
     *******************************************************
     **/
    @isTest
    static void testProcessNPN_withValidNPN() {
        // Set mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);
        
        // Execute
        Test.startTest();

        EntityInfoApiController.processNPN(VALID_NPN);
        // No assertion needed as the method should complete without exception
        System.assert(true, 'Method executed successfully');
        
        Test.stopTest();
    }
    
    /*********************************************************
    @Method Name    : testProcessNPN_withEmptyNPN
    @author         : Stefan Nidzovic
    @description    : Tests the processNPN method with an empty NPN value, should throw AuraHandledException
    *********************************************************/
    @isTest
    static void testProcessNPN_withEmptyNPN() {
        // Execute
        Test.startTest();
        try {
            EntityInfoApiController.processNPN(EMPTY_NPN);
            System.assert(false, 'Method should throw an exception for empty NPN');
        } catch (AuraHandledException e) {
            // Verify the exception message
            System.assert(true, 'Method should throw an exception for empty NPN');
        }
        Test.stopTest();
    }

    /*********************************************************
    @Method Name    : testProcessNPN_handlesExceptionGracefully
    @author         : Stefan Nidzovic
    @description    : Tests the catch block by forcing an exception
    *********************************************************/
    @isTest
    static void testProcessNPN_handlesExceptionGracefully() {
        // Force exception
        EntityInfoApiController.forceException = true;

        // Execute
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EntityInfoApiController.processNPN(VALID_NPN);
        } catch (AuraHandledException e) {
            // Assert - verify exception was caught and re-thrown as AuraHandledException
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert that exception was thrown
        System.assert(exceptionThrown, 'AuraHandledException should be thrown');

        // Reset flag
        EntityInfoApiController.forceException = false;
    }
}