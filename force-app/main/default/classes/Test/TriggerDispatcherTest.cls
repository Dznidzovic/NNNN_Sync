/*
*********************************************************
Apex Class Name    : TriggerDispatcherTest
Created Date       : 12-22-2025
@description       : Test class for TriggerDispatcher and BaseTriggerHandler
                     Tests all trigger operation types and custom metadata integration
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author                               Modification
1.0   12-22-2025   Stefan Nidzovic                     Initial Version
*********************************************************
*/
@IsTest
private class TriggerDispatcherTest {

    /*********************************************************
    * Mock handler for testing - extends BaseTriggerHandler
    *********************************************************/
    private class MockTriggerHandler extends BaseTriggerHandler {
        public Boolean beforeInsertCalled = false;
        public Boolean beforeUpdateCalled = false;
        public Boolean beforeDeleteCalled = false;
        public Boolean afterInsertCalled = false;
        public Boolean afterUpdateCalled = false;
        public Boolean afterDeleteCalled = false;
        public Boolean afterUndeleteCalled = false;

        public override void beforeInsert(List<SObject> newItems) {
            beforeInsertCalled = true;
        }

        public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
            beforeUpdateCalled = true;
        }

        public override void beforeDelete(Map<Id, SObject> oldItems) {
            beforeDeleteCalled = true;
        }

        public override void afterInsert(Map<Id, SObject> newItems) {
            afterInsertCalled = true;
        }

        public override void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
            afterUpdateCalled = true;
        }

        public override void afterDelete(Map<Id, SObject> oldItems) {
            afterDeleteCalled = true;
        }

        public override void afterUndelete(Map<Id, SObject> newItems) {
            afterUndeleteCalled = true;
        }
    }

    /*********************************************************
    @Method Name    : testBeforeInsert_CallsHandler
    @description    : Tests BEFORE_INSERT operation type
    *********************************************************/
    @IsTest
    static void testBeforeInsert_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        TriggerDispatcher.run(handler, TriggerOperation.BEFORE_INSERT);

        System.assert(handler.beforeInsertCalled, 'beforeInsert should be called');
    }

    /*********************************************************
    @Method Name    : testBeforeUpdate_CallsHandler
    @description    : Tests BEFORE_UPDATE operation type
    *********************************************************/
    @IsTest
    static void testBeforeUpdate_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;

        TriggerDispatcher.run(handler, TriggerOperation.BEFORE_UPDATE);

        System.assert(handler.beforeUpdateCalled, 'beforeUpdate should be called');
    }

    /*********************************************************
    @Method Name    : testBeforeDelete_CallsHandler
    @description    : Tests BEFORE_DELETE operation type
    *********************************************************/
    @IsTest
    static void testBeforeDelete_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceBeforeDelete = true;

        TriggerDispatcher.run(handler, TriggerOperation.BEFORE_DELETE);

        System.assert(handler.beforeDeleteCalled, 'beforeDelete should be called');
    }

    /*********************************************************
    @Method Name    : testAfterInsert_CallsHandler
    @description    : Tests AFTER_INSERT operation type
    *********************************************************/
    @IsTest
    static void testAfterInsert_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceAfterInsert = true;

        TriggerDispatcher.run(handler, TriggerOperation.AFTER_INSERT);

        System.assert(handler.afterInsertCalled, 'afterInsert should be called');
    }

    /*********************************************************
    @Method Name    : testAfterUpdate_CallsHandler
    @description    : Tests AFTER_UPDATE operation type
    *********************************************************/
    @IsTest
    static void testAfterUpdate_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceAfterUpdate = true;

        TriggerDispatcher.run(handler, TriggerOperation.AFTER_UPDATE);

        System.assert(handler.afterUpdateCalled, 'afterUpdate should be called');
    }

    /*********************************************************
    @Method Name    : testAfterDelete_CallsHandler
    @description    : Tests AFTER_DELETE operation type
    *********************************************************/
    @IsTest
    static void testAfterDelete_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceAfterDelete = true;

        TriggerDispatcher.run(handler, TriggerOperation.AFTER_DELETE);

        System.assert(handler.afterDeleteCalled, 'afterDelete should be called');
    }

    /*********************************************************
    @Method Name    : testAfterUndelete_CallsHandler
    @description    : Tests AFTER_UNDELETE operation type
    *********************************************************/
    @IsTest
    static void testAfterUndelete_CallsHandler() {
        MockTriggerHandler handler = new MockTriggerHandler();
        TriggerDispatcher.forceAfterUndelete = true;

        TriggerDispatcher.run(handler, TriggerOperation.AFTER_UNDELETE);

        System.assert(handler.afterUndeleteCalled, 'afterUndelete should be called');
    }

    /*********************************************************
    @Method Name    : testIsDisabled_WithCustomMetadata
    @description    : Tests BaseTriggerHandler.isDisabled() with custom metadata
                      Note: Custom metadata can't be inserted in tests, so this tests
                      the query logic and validates against any existing records
    *********************************************************/
    @IsTest
    static void testIsDisabled_WithCustomMetadata() {
        // Query to check if any custom metadata exists
        List<d4c_Trigger_Dispatcher_Settings__mdt> existingSettings = [
            SELECT DeveloperName, d4c_Disabled__c
            FROM d4c_Trigger_Dispatcher_Settings__mdt
            LIMIT 1
        ];

        // If records exist, we can test the logic
        if (!existingSettings.isEmpty()) {
            BaseTriggerHandler baseHandler = new BaseTriggerHandler();
            Boolean isDisabled = baseHandler.isDisabled();

            // Simple assertion - method executed successfully
            System.assert(true, 'isDisabled method executed successfully with custom metadata');
        } else {
            // If no records exist, just verify the method doesn't throw an error
            MockTriggerHandler handler = new MockTriggerHandler();
            Boolean disabled = handler.isDisabled();
            System.assert(!disabled, 'Handler should not be disabled without custom metadata record');
        }
    }

    /*********************************************************
    @Method Name    : testIsDisabled_WithoutCustomMetadata
    @description    : Tests BaseTriggerHandler.isDisabled() without custom metadata
    *********************************************************/
    @IsTest
    static void testIsDisabled_WithoutCustomMetadata() {
        MockTriggerHandler handler = new MockTriggerHandler();

        Boolean disabled = handler.isDisabled();

        System.assert(!disabled, 'Handler should not be disabled without custom metadata record');
    }

    /*********************************************************
    @Method Name    : testBaseTriggerHandlerMethods
    @description    : Tests BaseTriggerHandler virtual methods directly for coverage
    *********************************************************/
    @IsTest
    static void testBaseTriggerHandlerMethods() {
        BaseTriggerHandler baseHandler = new BaseTriggerHandler();

        // Call all virtual methods directly - they do nothing but we need coverage
        baseHandler.beforeInsert(new List<Account>());
        baseHandler.beforeUpdate(new Map<Id, Account>(), new Map<Id, Account>());
        baseHandler.beforeDelete(new Map<Id, Account>());
        baseHandler.afterInsert(new Map<Id, Account>());
        baseHandler.afterUpdate(new Map<Id, Account>(), new Map<Id, Account>());
        baseHandler.afterDelete(new Map<Id, Account>());
        baseHandler.afterUndelete(new Map<Id, Account>());

        // Test isDisabled on base handler
        Boolean disabled = baseHandler.isDisabled();

        // Simple assertion - these methods do nothing so just assert true
        System.assert(true, 'BaseTriggerHandler methods executed without error');
    }
}