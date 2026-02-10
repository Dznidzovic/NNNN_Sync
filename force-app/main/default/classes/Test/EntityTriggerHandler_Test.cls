/**
 *********************************************************
 * Apex Class Name    : EntityTriggerHandler_Test
 * Created Date       : 04-15-2025
 * @description       : Test Class used for EntityTriggerHandler class.
 *                      Tests only the business logic found in the Entity Trigger Handler and mocks any other services called from inside
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-15-2025   Dev4Clouds          Initial Version
 * 1.1   04-22-2025   Dev4Clouds          Added additional test methods for complete coverage
 * 1.2   04-25-2025   Dev4Clouds          Added tests for NPN removal logic
 * 2.0   10-27-2025   Dev4Clouds          Updated for new SubscriptionServiceExecutorQueueable architecture
 * 2.1   12-17-2025   Dev4Clouds                   Added tests for smart scheduling logic
 *********************************************************
 **/
@isTest
private class EntityTriggerHandler_Test {
    @isTest
    private static void afterInsert_testEligibleEntitys() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Set SyncRecordToNIPR__c to 'On' to make them eligible
        for (d4c_Entity__c entity : entitys) {
            entity.d4c_SyncRecordToNIPR__c = 'On';
        }
        
        // Execute
        Test.startTest();
        insert entitys;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> insertedEntitys = queryEntitys(npns);

        System.assertEquals(2, insertedEntitys.size(), 'Should have inserted 2 entitys');
        System.assertEquals(2, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(), 'Should have collected 2 NPNs');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should contain NPN 987654321');
    }
    
    @isTest
    private static void afterInsert_testIneligibleEntitys() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', ''};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Mix of On, Off and empty NPN scenarios
        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[1].d4c_SyncRecordToNIPR__c = 'Off';
        entitys[2].d4c_SyncRecordToNIPR__c = 'On';
        
        // Execute
        Test.startTest();
        insert entitys;
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(), 'Should have collected 1 NPN');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(!EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should not contain NPN 987654321');
    }
    
    @isTest
    private static void afterUpdate_testNPNChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Set initial state
        for (d4c_Entity__c entity : entitys) {
            entity.d4c_SyncRecordToNIPR__c = 'On';
        }
        
        EntityTriggerHandler.triggerDisabled = true;
        insert entitys;
        
        // Update the NPNs for testing update scenario
        entitys[0].d4c_NPN__c = '111222333';
        entitys[1].d4c_SyncRecordToNIPR__c = 'Off';
        
        EntityTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(), 'Should have collected 1 changed NPN');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('111222333'), 'Should contain updated NPN 111222333');
    }

    @isTest
    private static void afterUpdate_testSubscriptionEligibility() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        EntityTriggerHandler.triggerDisabled = true;

        insert entitys;

        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[0].d4c_NPNStatus__c = 'Active';

        entitys[1].d4c_SyncRecordToNIPR__c = 'On';
        entitys[1].d4c_NPNStatus__c = 'Inactive';

        entitys[2].d4c_SyncRecordToNIPR__c = 'Off';
        entitys[2].d4c_NPNStatus__c = 'Active';

        EntityTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();

        // Assert - ADD_TO_SUBSCRIPTION is now handled in RunEntityInfoReportBatchable.finish()
        // The trigger no longer handles ADD_TO_SUBSCRIPTION, so no subscription operation should be set
        System.assertEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
        System.assertEquals(null, EntityTriggerHandler.subscriptionOperationForTest, 'Subscription operation should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
    }
    
    @isTest
    private static void isDisabled_testTriggerDisabled() {
        // Set trigger disabled flag
        EntityTriggerHandler.triggerDisabled = true;
        
        // Execute
        Test.startTest();
        Boolean isDisabled = new EntityTriggerHandler().isDisabled();
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, isDisabled, 'The trigger should be disabled');
    }
    
    @isTest
    private static void testCombinedScenarios() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        for (d4c_Entity__c entity : entitys) {
            entity.d4c_SyncRecordToNIPR__c = 'Off';
        }

        EntityTriggerHandler.triggerdisabled = true;

        insert entitys;

        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[0].d4c_NPNStatus__c = 'Active';

        entitys[1].d4c_SyncRecordToNIPR__c = 'On';
        entitys[1].d4c_NPNStatus__c = 'Inactive';

        entitys[2].d4c_NPN__c = '999888777';

        EntityTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();

        // Assert
        System.assertEquals(1, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(), 'Wrong amount of NPNs');
        // ADD_TO_SUBSCRIPTION is now handled in RunEntityInfoReportBatchable.finish()
        // The trigger no longer handles ADD_TO_SUBSCRIPTION, so no subscription operation should be set
        System.assertEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
        System.assertEquals(null, EntityTriggerHandler.subscriptionOperationForTest, 'Subscription operation should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
    }
    
    @isTest
    private static void beforeInsert_testNPNStatusChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Test different scenarios
        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[0].d4c_NPNStatus__c = null;
        
        entitys[1].d4c_SyncRecordToNIPR__c = 'Off';
        entitys[1].d4c_NPNStatus__c = null;
        
        entitys[2].d4c_SyncRecordToNIPR__c = 'On';
        entitys[2].d4c_NPNStatus__c = 'Active';
        
        // Execute
        Test.startTest();
        insert entitys;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> insertedEntitys = queryEntitys(npns);
        
        System.assertEquals('Processing', insertedEntitys[0].d4c_NPNStatus__c, 'First entity should have NPNStatus set to Processing');
        System.assertNotEquals('Processing', insertedEntitys[1].d4c_NPNStatus__c, 'Second entity should not have NPNStatus set to Processing');
        System.assertEquals('Active', insertedEntitys[2].d4c_NPNStatus__c, 'Third entity should maintain Active status');
    }
    
    @isTest
    private static void beforeUpdate_testNPNStatusChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        EntityTriggerHandler.triggerDisabled = true;
        insert entitys;
        EntityTriggerHandler.triggerDisabled = false;
        
        // Test different update scenarios
        entitys[0].d4c_NPN__c = '111222333';
        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[0].d4c_NPNStatus__c = 'Inactive';
        
        entitys[1].d4c_NPN__c = '987654321'; // No change
        entitys[1].d4c_SyncRecordToNIPR__c = 'On';
        
        entitys[2].d4c_NPN__c = '999888777';
        entitys[2].d4c_SyncRecordToNIPR__c = 'Off';
        
        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> updatedEntitys = queryEntitys(new Set<String>{'111222333', '987654321', '999888777'});
        
        // Find each entity by its NPN
        d4c_Entity__c entity1 = null;
        d4c_Entity__c entity2 = null;
        d4c_Entity__c entity3 = null;
        
        for (d4c_Entity__c p : updatedEntitys) {
            if (p.d4c_NPN__c == '111222333') entity1 = p;
            if (p.d4c_NPN__c == '987654321') entity2 = p;
            if (p.d4c_NPN__c == '999888777') entity3 = p;
        }
        
        System.assertEquals('Processing', entity1.d4c_NPNStatus__c, 'First entity should have NPNStatus changed to Processing');
        System.assertNotEquals('Processing', entity2.d4c_NPNStatus__c, 'Second entity should not have NPNStatus changed to Processing');
        System.assertNotEquals('Processing', entity3.d4c_NPNStatus__c, 'Third entity should not have NPNStatus changed to Processing');
    }
    
    @isTest
    private static void beforeUpdate_testSyncDisabled() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Set initial state - both with Sync On
        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[0].d4c_NPNStatus__c = 'Active';
        entitys[0].d4c_NPNSyncError__c = 'Some error message';
        
        entitys[1].d4c_SyncRecordToNIPR__c = 'On';
        entitys[1].d4c_NPNStatus__c = 'Processing';
        entitys[1].d4c_NPNSyncError__c = 'Another error message';
        
        EntityTriggerHandler.triggerDisabled = true;
        insert entitys;
        EntityTriggerHandler.triggerDisabled = false;
        
        // Update scenario - turning sync off
        entitys[0].d4c_SyncRecordToNIPR__c = 'Off';
        
        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> updatedEntitys = queryEntitys(npns);
        
        System.assertEquals('Sync Disabled', updatedEntitys[0].d4c_NPNStatus__c, 'First entity should have NPNStatus set to Sync Disabled');
        System.assertEquals(null, updatedEntitys[0].d4c_NPNSyncError__c, 'First entity should have error message cleared');
        System.assertNotEquals('Sync Disabled', updatedEntitys[1].d4c_NPNStatus__c, 'Second entity should not have NPNStatus changed to Sync Disabled');
    }
    
    @isTest
    private static void afterUpdate_testSyncStatusChange() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);
        
        // Set initial state - both with Sync Off
        for (d4c_Entity__c entity : entitys) {
            entity.d4c_SyncRecordToNIPR__c = 'Off';
        }
        
        EntityTriggerHandler.triggerDisabled = true;
        insert entitys;
        EntityTriggerHandler.triggerDisabled = false;
        
        // Update to turn sync on
        entitys[0].d4c_SyncRecordToNIPR__c = 'On';
        entitys[1].d4c_SyncRecordToNIPR__c = 'On';
        
        // Execute
        Test.startTest();
        update entitys;
        Test.stopTest();
        
        // Assert
        System.assertEquals(2, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(), 'Should have collected 2 NPNs');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should contain NPN 987654321');
    }
    
    /**
     * Test for the scenario where a entity's sync status is changed from 'On' to 'Off',
     * which should make the entity eligible for NPN removal from subscriptions
     * NEW: Tests single REMOVE_NPN_AFTER_UPDATE operation
     */
    @isTest
    private static void afterUpdate_testNPNRemovalEligibility() {
        // Create Data - entity with subscription and Active status
        d4c_Entity__c entity = TestDataFactory.createEntity('123456789');

        // Create a mock subscription record
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        // Set initial state
        entity.d4c_SyncRecordToNIPR__c = 'On';
        entity.d4c_NPNStatus__c = 'Active';
        entity.d4c_Subscription__c = subscription.Id;

        EntityTriggerHandler.triggerDisabled = true;
        insert entity;
        EntityTriggerHandler.triggerDisabled = false;

        // Update scenario - turning sync off (triggers REMOVE_NPN_AFTER_UPDATE)
        entity.d4c_SyncRecordToNIPR__c = 'Off';

        // Execute
        Test.startTest();
        update entity;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('123456789', EntityTriggerHandler.subscriptionNPNForTest, 'Should have NPN 123456789 for removal');
        System.assertEquals(NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE, EntityTriggerHandler.subscriptionOperationForTest, 'Operation should be REMOVE_NPN_AFTER_UPDATE');
    }
    
    /**
     * Test for the afterDelete method to verify entitys are correctly identified for NPN removal
     * NEW: Tests bulkified Map<String, Id> deletedEntityNPNToSubscriptionMapForTest
     */
    @isTest
    private static void afterDelete_testNPNRemovalFromDeletedEntitys() {
        // Create Data - entitys with subscriptions and Active status
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> entitys = TestDataFactory.createEntitys(npns);

        // Create a mock subscription record
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        // Set entitys with different statuses
        // Entity 0: Active with subscription - should be eligible for removal
        entitys[0].d4c_NPNStatus__c = 'Active';
        entitys[0].d4c_Subscription__c = subscription.Id;

        // Entity 1: Not Active but with subscription - should not be eligible
        entitys[1].d4c_NPNStatus__c = 'Inactive';
        entitys[1].d4c_Subscription__c = subscription.Id;

        // Entity 2: Active but no subscription - should not be eligible
        entitys[2].d4c_NPNStatus__c = 'Active';
        entitys[2].d4c_Subscription__c = null;

        EntityTriggerHandler.triggerDisabled = true;
        insert entitys;
        EntityTriggerHandler.triggerDisabled = false;

        // Execute - delete the entitys
        Test.startTest();
        delete entitys;
        Test.stopTest();

        // Assert - NEW: Use deletedEntityNPNToSubscriptionMapForTest
        System.assertEquals(1, EntityTriggerHandler.deletedEntitysForTest.size(),
                          'Should have collected 1 entity for NPN removal after delete');

        System.assertEquals('123456789', EntityTriggerHandler.deletedEntitysForTest[0].d4c_NPN__c,
                          'The eligible entity should have NPN 123456789');

        // NEW: Assert the bulkified Map property
        System.assertNotEquals(null, EntityTriggerHandler.deletedEntityNPNToSubscriptionMapForTest, 'Map should be populated');
        System.assertEquals(1, EntityTriggerHandler.deletedEntityNPNToSubscriptionMapForTest.size(), 'Map should have 1 entry');
        System.assertEquals(subscription.Id, EntityTriggerHandler.deletedEntityNPNToSubscriptionMapForTest.get('123456789'), 'NPN should map to subscription ID');
    }
    
    /**
     * Test that verifies bulk update triggers validation error for multiple subscription operations
     * NEW: Tests that only 1 subscription operation allowed per transaction
     */
    @isTest
    private static void afterUpdate_testBulkSubscriptionOperationValidation() {
        // Create Data - 2 entitys that will both trigger subscription operations
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        d4c_Entity__c entity1 = TestDataFactory.createEntity('123456789');
        entity1.d4c_SyncRecordToNIPR__c = 'On';
        entity1.d4c_NPNStatus__c = 'Active';
        entity1.d4c_Subscription__c = subscription.Id;

        d4c_Entity__c entity2 = TestDataFactory.createEntity('987654321');
        entity2.d4c_SyncRecordToNIPR__c = 'On';
        entity2.d4c_NPNStatus__c = 'Active';
        entity2.d4c_Subscription__c = subscription.Id;

        EntityTriggerHandler.triggerDisabled = true;
        insert new List<d4c_Entity__c>{entity1, entity2};
        EntityTriggerHandler.triggerDisabled = false;

        // Try to trigger subscription operations on both (should fail)
        entity1.d4c_SyncRecordToNIPR__c = 'Off'; // Trigger REMOVE_NPN_AFTER_UPDATE
        entity2.d4c_SyncRecordToNIPR__c = 'Off'; // Trigger REMOVE_NPN_AFTER_UPDATE

        // Execute
        Test.startTest();
        try {
            update new List<d4c_Entity__c>{entity1, entity2};
            System.assert(false, 'Expected DmlException was not thrown');
        } catch (DmlException e) {
            // Assert the error message contains our validation message
            System.assert(e.getMessage().contains('subscription operations'),
                         'Error message should mention subscription operations');
            System.assert(e.getMessage().contains('more than 1 entity'),
                         'Error message should mention bulk restriction');
        }
        Test.stopTest();
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_FromFalseToTrue() {
        // Create a subscription and an active entity with exclude flag = false
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);
        subscription.d4c_ExcludeCarrierAppointments__c = false;
        update subscription;

        d4c_Entity__c entity = TestDataFactory.createEntity('12345678');
        entity.d4c_SyncRecordToNIPR__c = 'On';
        entity.d4c_NPNStatus__c = 'Active';
        entity.d4c_ExcludeCarrierAppointments__c = false;
        entity.d4c_Subscription__c = subscription.Id;
        insert entity;

        // Update entity to change exclude flag from false to true
        entity.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update entity;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('12345678', EntityTriggerHandler.subscriptionNPNForTest, 'Should have NPN 12345678');
        System.assertEquals(NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL, EntityTriggerHandler.subscriptionOperationForTest, 'Operation should be RESUBSCRIBE_TO_DIFFERENT_POOL');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_FromTrueToFalse() {
        // Create a subscription and an active entity with exclude flag = true
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);
        subscription.d4c_ExcludeCarrierAppointments__c = true;
        update subscription;

        d4c_Entity__c entity = TestDataFactory.createEntity('87654321');
        entity.d4c_SyncRecordToNIPR__c = 'On';
        entity.d4c_NPNStatus__c = 'Active';
        entity.d4c_ExcludeCarrierAppointments__c = true;
        entity.d4c_Subscription__c = subscription.Id;
        insert entity;

        // Update entity to change exclude flag from true to false
        entity.d4c_ExcludeCarrierAppointments__c = false;

        // Execute
        Test.startTest();
        update entity;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('87654321', EntityTriggerHandler.subscriptionNPNForTest, 'Should have NPN 87654321');
        System.assertEquals(NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL, EntityTriggerHandler.subscriptionOperationForTest, 'Operation should be RESUBSCRIBE_TO_DIFFERENT_POOL');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_NotActiveOrNotSubscribed() {
        // Test that entitys not active or not subscribed are NOT flagged for re-subscription

        // Create entity 1 - Not Active
        d4c_Entity__c entity1 = TestDataFactory.createEntity('11111111');
        entity1.d4c_SyncRecordToNIPR__c = 'On';
        entity1.d4c_NPNStatus__c = 'Processing'; // Not Active
        entity1.d4c_ExcludeCarrierAppointments__c = false;
        entity1.d4c_Subscription__c = null;
        insert entity1;

        // Create entity 2 - Active but not subscribed
        d4c_Entity__c entity2 = TestDataFactory.createEntity('22222222');
        entity2.d4c_SyncRecordToNIPR__c = 'On';
        entity2.d4c_NPNStatus__c = 'Active'; // Active but not subscribed
        entity2.d4c_ExcludeCarrierAppointments__c = false;
        entity2.d4c_Subscription__c = null; // No subscription
        insert entity2;

        // Update entity 1 to change exclude flag (not active, should not be flagged)
        entity1.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update entity1;

        // Assert - entity1 should NOT be flagged for re-subscription (not active)
        System.assertEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'No subscription operation should be triggered for inactive entity');

        // Update entity 2 to change exclude flag (active but no subscription, should not be flagged)
        entity2.d4c_ExcludeCarrierAppointments__c = true;
        update entity2;
        Test.stopTest();

        // Assert - entity2 should NOT be flagged for re-subscription (no subscription)
        System.assertEquals(null, EntityTriggerHandler.subscriptionNPNForTest, 'No subscription operation should be triggered for entity without subscription');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagNoChange() {
        // Test that entitys whose exclude flag doesn't change are NOT flagged

        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);

        d4c_Entity__c entity = TestDataFactory.createEntity('99999999');
        entity.d4c_SyncRecordToNIPR__c = 'On';
        entity.d4c_NPNStatus__c = 'Active';
        entity.d4c_ExcludeCarrierAppointments__c = false;
        entity.d4c_Subscription__c = subscription.Id;
        insert entity;

        // Update entity but keep exclude flag the same
        entity.d4c_SyncRecordToNIPR__c = 'Off'; // Change something else

        // Execute
        Test.startTest();
        update entity;
        Test.stopTest();

        // Assert - entity should NOT be flagged for re-subscription (sync was turned off, triggers REMOVE operation instead)
        System.assertEquals(NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE, EntityTriggerHandler.subscriptionOperationForTest, 'Should trigger REMOVE_NPN_AFTER_UPDATE since sync was disabled');
    }

    @isTest
    private static void beforeUpdate_testBulkExcludeFlagChangeValidation() {
        // Test that bulk updates of exclude flag are blocked

        // Create 3 entitys
        d4c_Entity__c entity1 = TestDataFactory.createEntity('11111111');
        entity1.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c entity2 = TestDataFactory.createEntity('22222222');
        entity2.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c entity3 = TestDataFactory.createEntity('33333333');
        entity3.d4c_ExcludeCarrierAppointments__c = false;

        insert new List<d4c_Entity__c>{entity1, entity2, entity3};

        // Try to update exclude flag on 2 entitys at once (should fail)
        entity1.d4c_ExcludeCarrierAppointments__c = true;
        entity2.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        try {
            update new List<d4c_Entity__c>{entity1, entity2};
            System.assert(false, 'Expected DmlException was not thrown');
        } catch (DmlException e) {
            // Assert the error message contains our validation message
            System.assert(e.getMessage().contains('Exclude Carrier Appointments'),
                         'Error message should mention Exclude Carrier Appointments');
            System.assert(e.getMessage().contains('more than 1 entity'),
                         'Error message should mention bulk update restriction');
        }
        Test.stopTest();

        // Verify entitys were not updated
        List<d4c_Entity__c> updatedEntitys = [
            SELECT Id, d4c_ExcludeCarrierAppointments__c
            FROM d4c_Entity__c
            WHERE Id IN :new List<Id>{entity1.Id, entity2.Id}
        ];

        for (d4c_Entity__c p : updatedEntitys) {
            System.assertEquals(false, p.d4c_ExcludeCarrierAppointments__c,
                              'Entitys should not have been updated due to validation error');
        }
    }

    @isTest
    private static void beforeUpdate_testSingleExcludeFlagChangeAllowed() {
        // Test that single entity exclude flag change is allowed

        // Create 2 entitys
        d4c_Entity__c entity1 = TestDataFactory.createEntity('44444444');
        entity1.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c entity2 = TestDataFactory.createEntity('55555555');
        entity2.d4c_ExcludeCarrierAppointments__c = false;

        insert new List<d4c_Entity__c>{entity1, entity2};

        // Update exclude flag on only 1 entity (should succeed)
        entity1.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update entity1; // Single update should work
        Test.stopTest();

        // Verify entity was updated
        d4c_Entity__c updatedEntity = [
            SELECT Id, d4c_ExcludeCarrierAppointments__c
            FROM d4c_Entity__c
            WHERE Id = :entity1.Id
        ];

        System.assertEquals(true, updatedEntity.d4c_ExcludeCarrierAppointments__c,
                          'Single entity should be allowed to update exclude flag');
    }

    // ==========================================
    // ORCHESTRATOR SERVICE TESTS
    // ==========================================

    /**
     * Test that afterInsert calls EntityInfoOrchestratorService with correct NPNs
     */
    @isTest
    private static void afterInsert_callsOrchestratorService() {
        // Arrange: Create entity with sync On
        d4c_Entity__c entity = new d4c_Entity__c(
            d4c_NPN__c = '777888999',
            d4c_SyncRecordToNIPR__c = 'On'
        );

        // Act
        Test.startTest();
        insert entity;
        Test.stopTest();

        // Assert: NPN should be collected for EntityInfoOrchestratorService
        System.assertEquals(1, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(),
            'Should have collected 1 NPN for orchestrator');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('777888999'),
            'Should contain the correct NPN');
    }

    /**
     * Test that afterUpdate calls EntityInfoOrchestratorService when sync is turned on
     */
    @isTest
    private static void afterUpdate_callsOrchestratorService() {
        // Arrange: Create entity with sync Off
        d4c_Entity__c entity = new d4c_Entity__c(
            d4c_NPN__c = '888999000',
            d4c_SyncRecordToNIPR__c = 'Off'
        );

        EntityTriggerHandler.triggerDisabled = true;
        insert entity;
        EntityTriggerHandler.triggerDisabled = false;

        // Update to turn sync on
        entity.d4c_SyncRecordToNIPR__c = 'On';

        // Act
        Test.startTest();
        update entity;
        Test.stopTest();

        // Assert: NPN should be collected for EntityInfoOrchestratorService
        System.assertEquals(1, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(),
            'Should have collected 1 NPN for orchestrator');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('888999000'),
            'Should contain the correct NPN');
    }

    /**
     * Test that multiple entitys in same transaction collect all NPNs correctly
     * (NPNs are accumulated in the trigger for batch processing)
     */
    @isTest
    private static void afterInsert_collectsMultipleNPNs() {
        // Arrange: Insert multiple eligible entitys in same transaction
        List<d4c_Entity__c> entitys = new List<d4c_Entity__c>{
            new d4c_Entity__c(
                d4c_NPN__c = '111000111',
                d4c_SyncRecordToNIPR__c = 'On'
            ),
            new d4c_Entity__c(
                d4c_NPN__c = '222000222',
                d4c_SyncRecordToNIPR__c = 'On'
            ),
            new d4c_Entity__c(
                d4c_NPN__c = '333000333',
                d4c_SyncRecordToNIPR__c = 'On'
            )
        };

        // Act
        Test.startTest();
        insert entitys;
        Test.stopTest();

        // Assert: All 3 NPNs should be collected for processing
        System.assertEquals(3, EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.size(),
                          'Should have collected 3 NPNs');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('111000111'),
                     'Should contain NPN 111000111');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('222000222'),
                     'Should contain NPN 222000222');
        System.assert(EntityTriggerHandler.entityNPNsForEntityInfoAPIForTest.contains('333000333'),
                     'Should contain NPN 333000333');
    }

    // ==========================================
    // SELECTOR METHODS
    // ==========================================

    private static List<d4c_Entity__c> queryEntitys(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_NPN__c,
                d4c_SyncRecordToNIPR__c,
                d4c_NPNStatus__c,
                d4c_NPNSyncError__c
            FROM
                d4c_Entity__c
            WHERE
                d4c_NPN__c IN :npns
        ];
    }
}