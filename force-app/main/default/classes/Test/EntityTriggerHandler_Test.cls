/**
 *********************************************************
 * Apex Class Name    : ProducerTriggerHandler_Test
 * Created Date       : 04-15-2025
 * @description       : Test Class used for ProducerTriggerHandler class.
 *                      Tests only the business logic found in the Producer Trigger Handler and mocks any other services called from inside
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-15-2025   Stefan Nidzovic          Initial Version
 * 1.1   04-22-2025   Stefan Nidzovic          Added additional test methods for complete coverage
 * 1.2   04-25-2025   Stefan Nidzovic          Added tests for NPN removal logic
 * 2.0   10-27-2025   Stefan Nidzovic          Updated for new SubscriptionServiceExecutorQueueable architecture
 * 2.1   12-17-2025   Stefan Nidzovic                   Added tests for smart scheduling logic
 *********************************************************
 **/
@isTest
private class ProducerTriggerHandler_Test {
    @isTest
    private static void afterInsert_testEligibleProducers() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Set SyncRecordToNIPR__c to 'On' to make them eligible
        for (d4c_Entity__c producer : producers) {
            producer.d4c_SyncRecordToNIPR__c = 'On';
        }
        
        // Execute
        Test.startTest();
        insert producers;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> insertedProducers = queryProducers(npns);

        System.assertEquals(2, insertedProducers.size(), 'Should have inserted 2 producers');
        System.assertEquals(2, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(), 'Should have collected 2 NPNs');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should contain NPN 987654321');
    }
    
    @isTest
    private static void afterInsert_testIneligibleProducers() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', ''};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Mix of On, Off and empty NPN scenarios
        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[1].d4c_SyncRecordToNIPR__c = 'Off';
        producers[2].d4c_SyncRecordToNIPR__c = 'On';
        
        // Execute
        Test.startTest();
        insert producers;
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(), 'Should have collected 1 NPN');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(!ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should not contain NPN 987654321');
    }
    
    @isTest
    private static void afterUpdate_testNPNChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Set initial state
        for (d4c_Entity__c producer : producers) {
            producer.d4c_SyncRecordToNIPR__c = 'On';
        }
        
        ProducerTriggerHandler.triggerDisabled = true;
        insert producers;
        
        // Update the NPNs for testing update scenario
        producers[0].d4c_NPN__c = '111222333';
        producers[1].d4c_SyncRecordToNIPR__c = 'Off';
        
        ProducerTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(), 'Should have collected 1 changed NPN');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('111222333'), 'Should contain updated NPN 111222333');
    }

    @isTest
    private static void afterUpdate_testSubscriptionEligibility() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);

        ProducerTriggerHandler.triggerDisabled = true;

        insert producers;

        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[0].d4c_NPNStatus__c = 'Active';

        producers[1].d4c_SyncRecordToNIPR__c = 'On';
        producers[1].d4c_NPNStatus__c = 'Inactive';

        producers[2].d4c_SyncRecordToNIPR__c = 'Off';
        producers[2].d4c_NPNStatus__c = 'Active';

        ProducerTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();

        // Assert - ADD_TO_SUBSCRIPTION is now handled in RunEntityInfoReportBatchable.finish()
        // The trigger no longer handles ADD_TO_SUBSCRIPTION, so no subscription operation should be set
        System.assertEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
        System.assertEquals(null, ProducerTriggerHandler.subscriptionOperationForTest, 'Subscription operation should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
    }
    
    @isTest
    private static void isDisabled_testTriggerDisabled() {
        // Set trigger disabled flag
        ProducerTriggerHandler.triggerDisabled = true;
        
        // Execute
        Test.startTest();
        Boolean isDisabled = new ProducerTriggerHandler().isDisabled();
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, isDisabled, 'The trigger should be disabled');
    }
    
    @isTest
    private static void testCombinedScenarios() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);

        for (d4c_Entity__c producer : producers) {
            producer.d4c_SyncRecordToNIPR__c = 'Off';
        }

        ProducerTriggerHandler.triggerdisabled = true;

        insert producers;

        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[0].d4c_NPNStatus__c = 'Active';

        producers[1].d4c_SyncRecordToNIPR__c = 'On';
        producers[1].d4c_NPNStatus__c = 'Inactive';

        producers[2].d4c_NPN__c = '999888777';

        ProducerTriggerHandler.triggerDisabled = false;

        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();

        // Assert
        System.assertEquals(1, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(), 'Wrong amount of NPNs');
        // ADD_TO_SUBSCRIPTION is now handled in RunEntityInfoReportBatchable.finish()
        // The trigger no longer handles ADD_TO_SUBSCRIPTION, so no subscription operation should be set
        System.assertEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
        System.assertEquals(null, ProducerTriggerHandler.subscriptionOperationForTest, 'Subscription operation should be null - ADD_TO_SUBSCRIPTION moved to batch finish');
    }
    
    @isTest
    private static void beforeInsert_testNPNStatusChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Test different scenarios
        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[0].d4c_NPNStatus__c = null;
        
        producers[1].d4c_SyncRecordToNIPR__c = 'Off';
        producers[1].d4c_NPNStatus__c = null;
        
        producers[2].d4c_SyncRecordToNIPR__c = 'On';
        producers[2].d4c_NPNStatus__c = 'Active';
        
        // Execute
        Test.startTest();
        insert producers;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> insertedProducers = queryProducers(npns);
        
        System.assertEquals('Processing', insertedProducers[0].d4c_NPNStatus__c, 'First producer should have NPNStatus set to Processing');
        System.assertNotEquals('Processing', insertedProducers[1].d4c_NPNStatus__c, 'Second producer should not have NPNStatus set to Processing');
        System.assertEquals('Active', insertedProducers[2].d4c_NPNStatus__c, 'Third producer should maintain Active status');
    }
    
    @isTest
    private static void beforeUpdate_testNPNStatusChanges() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        ProducerTriggerHandler.triggerDisabled = true;
        insert producers;
        ProducerTriggerHandler.triggerDisabled = false;
        
        // Test different update scenarios
        producers[0].d4c_NPN__c = '111222333';
        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[0].d4c_NPNStatus__c = 'Inactive';
        
        producers[1].d4c_NPN__c = '987654321'; // No change
        producers[1].d4c_SyncRecordToNIPR__c = 'On';
        
        producers[2].d4c_NPN__c = '999888777';
        producers[2].d4c_SyncRecordToNIPR__c = 'Off';
        
        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> updatedProducers = queryProducers(new Set<String>{'111222333', '987654321', '999888777'});
        
        // Find each producer by its NPN
        d4c_Entity__c producer1 = null;
        d4c_Entity__c producer2 = null;
        d4c_Entity__c producer3 = null;
        
        for (d4c_Entity__c p : updatedProducers) {
            if (p.d4c_NPN__c == '111222333') producer1 = p;
            if (p.d4c_NPN__c == '987654321') producer2 = p;
            if (p.d4c_NPN__c == '999888777') producer3 = p;
        }
        
        System.assertEquals('Processing', producer1.d4c_NPNStatus__c, 'First producer should have NPNStatus changed to Processing');
        System.assertNotEquals('Processing', producer2.d4c_NPNStatus__c, 'Second producer should not have NPNStatus changed to Processing');
        System.assertNotEquals('Processing', producer3.d4c_NPNStatus__c, 'Third producer should not have NPNStatus changed to Processing');
    }
    
    @isTest
    private static void beforeUpdate_testSyncDisabled() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Set initial state - both with Sync On
        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[0].d4c_NPNStatus__c = 'Active';
        producers[0].d4c_NPNSyncError__c = 'Some error message';
        
        producers[1].d4c_SyncRecordToNIPR__c = 'On';
        producers[1].d4c_NPNStatus__c = 'Processing';
        producers[1].d4c_NPNSyncError__c = 'Another error message';
        
        ProducerTriggerHandler.triggerDisabled = true;
        insert producers;
        ProducerTriggerHandler.triggerDisabled = false;
        
        // Update scenario - turning sync off
        producers[0].d4c_SyncRecordToNIPR__c = 'Off';
        
        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();
        
        // Assert
        List<d4c_Entity__c> updatedProducers = queryProducers(npns);
        
        System.assertEquals('Sync Disabled', updatedProducers[0].d4c_NPNStatus__c, 'First producer should have NPNStatus set to Sync Disabled');
        System.assertEquals(null, updatedProducers[0].d4c_NPNSyncError__c, 'First producer should have error message cleared');
        System.assertNotEquals('Sync Disabled', updatedProducers[1].d4c_NPNStatus__c, 'Second producer should not have NPNStatus changed to Sync Disabled');
    }
    
    @isTest
    private static void afterUpdate_testSyncStatusChange() {
        // Create Data
        Set<String> npns = new Set<String>{'123456789', '987654321'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);
        
        // Set initial state - both with Sync Off
        for (d4c_Entity__c producer : producers) {
            producer.d4c_SyncRecordToNIPR__c = 'Off';
        }
        
        ProducerTriggerHandler.triggerDisabled = true;
        insert producers;
        ProducerTriggerHandler.triggerDisabled = false;
        
        // Update to turn sync on
        producers[0].d4c_SyncRecordToNIPR__c = 'On';
        producers[1].d4c_SyncRecordToNIPR__c = 'On';
        
        // Execute
        Test.startTest();
        update producers;
        Test.stopTest();
        
        // Assert
        System.assertEquals(2, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(), 'Should have collected 2 NPNs');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('123456789'), 'Should contain NPN 123456789');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('987654321'), 'Should contain NPN 987654321');
    }
    
    /**
     * Test for the scenario where a producer's sync status is changed from 'On' to 'Off',
     * which should make the producer eligible for NPN removal from subscriptions
     * NEW: Tests single REMOVE_NPN_AFTER_UPDATE operation
     */
    @isTest
    private static void afterUpdate_testNPNRemovalEligibility() {
        // Create Data - producer with subscription and Active status
        d4c_Entity__c producer = TestDataFactory.createProducer('123456789');

        // Create a mock subscription record
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        // Set initial state
        producer.d4c_SyncRecordToNIPR__c = 'On';
        producer.d4c_NPNStatus__c = 'Active';
        producer.d4c_Subscription__c = subscription.Id;

        ProducerTriggerHandler.triggerDisabled = true;
        insert producer;
        ProducerTriggerHandler.triggerDisabled = false;

        // Update scenario - turning sync off (triggers REMOVE_NPN_AFTER_UPDATE)
        producer.d4c_SyncRecordToNIPR__c = 'Off';

        // Execute
        Test.startTest();
        update producer;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('123456789', ProducerTriggerHandler.subscriptionNPNForTest, 'Should have NPN 123456789 for removal');
        System.assertEquals(NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE, ProducerTriggerHandler.subscriptionOperationForTest, 'Operation should be REMOVE_NPN_AFTER_UPDATE');
    }
    
    /**
     * Test for the afterDelete method to verify producers are correctly identified for NPN removal
     * NEW: Tests bulkified Map<String, Id> deletedProducerNPNToSubscriptionMapForTest
     */
    @isTest
    private static void afterDelete_testNPNRemovalFromDeletedProducers() {
        // Create Data - producers with subscriptions and Active status
        Set<String> npns = new Set<String>{'123456789', '987654321', '555666777'};
        List<d4c_Entity__c> producers = TestDataFactory.createProducers(npns);

        // Create a mock subscription record
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        // Set producers with different statuses
        // Producer 0: Active with subscription - should be eligible for removal
        producers[0].d4c_NPNStatus__c = 'Active';
        producers[0].d4c_Subscription__c = subscription.Id;

        // Producer 1: Not Active but with subscription - should not be eligible
        producers[1].d4c_NPNStatus__c = 'Inactive';
        producers[1].d4c_Subscription__c = subscription.Id;

        // Producer 2: Active but no subscription - should not be eligible
        producers[2].d4c_NPNStatus__c = 'Active';
        producers[2].d4c_Subscription__c = null;

        ProducerTriggerHandler.triggerDisabled = true;
        insert producers;
        ProducerTriggerHandler.triggerDisabled = false;

        // Execute - delete the producers
        Test.startTest();
        delete producers;
        Test.stopTest();

        // Assert - NEW: Use deletedProducerNPNToSubscriptionMapForTest
        System.assertEquals(1, ProducerTriggerHandler.deletedProducersForTest.size(),
                          'Should have collected 1 producer for NPN removal after delete');

        System.assertEquals('123456789', ProducerTriggerHandler.deletedProducersForTest[0].d4c_NPN__c,
                          'The eligible producer should have NPN 123456789');

        // NEW: Assert the bulkified Map property
        System.assertNotEquals(null, ProducerTriggerHandler.deletedProducerNPNToSubscriptionMapForTest, 'Map should be populated');
        System.assertEquals(1, ProducerTriggerHandler.deletedProducerNPNToSubscriptionMapForTest.size(), 'Map should have 1 entry');
        System.assertEquals(subscription.Id, ProducerTriggerHandler.deletedProducerNPNToSubscriptionMapForTest.get('123456789'), 'NPN should map to subscription ID');
    }
    
    /**
     * Test that verifies bulk update triggers validation error for multiple subscription operations
     * NEW: Tests that only 1 subscription operation allowed per transaction
     */
    @isTest
    private static void afterUpdate_testBulkSubscriptionOperationValidation() {
        // Create Data - 2 producers that will both trigger subscription operations
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(false);
        insert subscription;

        d4c_Entity__c producer1 = TestDataFactory.createProducer('123456789');
        producer1.d4c_SyncRecordToNIPR__c = 'On';
        producer1.d4c_NPNStatus__c = 'Active';
        producer1.d4c_Subscription__c = subscription.Id;

        d4c_Entity__c producer2 = TestDataFactory.createProducer('987654321');
        producer2.d4c_SyncRecordToNIPR__c = 'On';
        producer2.d4c_NPNStatus__c = 'Active';
        producer2.d4c_Subscription__c = subscription.Id;

        ProducerTriggerHandler.triggerDisabled = true;
        insert new List<d4c_Entity__c>{producer1, producer2};
        ProducerTriggerHandler.triggerDisabled = false;

        // Try to trigger subscription operations on both (should fail)
        producer1.d4c_SyncRecordToNIPR__c = 'Off'; // Trigger REMOVE_NPN_AFTER_UPDATE
        producer2.d4c_SyncRecordToNIPR__c = 'Off'; // Trigger REMOVE_NPN_AFTER_UPDATE

        // Execute
        Test.startTest();
        try {
            update new List<d4c_Entity__c>{producer1, producer2};
            System.assert(false, 'Expected DmlException was not thrown');
        } catch (DmlException e) {
            // Assert the error message contains our validation message
            System.assert(e.getMessage().contains('subscription operations'),
                         'Error message should mention subscription operations');
            System.assert(e.getMessage().contains('more than 1 producer'),
                         'Error message should mention bulk restriction');
        }
        Test.stopTest();
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_FromFalseToTrue() {
        // Create a subscription and an active producer with exclude flag = false
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);
        subscription.d4c_ExcludeCarrierAppointments__c = false;
        update subscription;

        d4c_Entity__c producer = TestDataFactory.createProducer('12345678');
        producer.d4c_SyncRecordToNIPR__c = 'On';
        producer.d4c_NPNStatus__c = 'Active';
        producer.d4c_ExcludeCarrierAppointments__c = false;
        producer.d4c_Subscription__c = subscription.Id;
        insert producer;

        // Update producer to change exclude flag from false to true
        producer.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update producer;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('12345678', ProducerTriggerHandler.subscriptionNPNForTest, 'Should have NPN 12345678');
        System.assertEquals(NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL, ProducerTriggerHandler.subscriptionOperationForTest, 'Operation should be RESUBSCRIBE_TO_DIFFERENT_POOL');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_FromTrueToFalse() {
        // Create a subscription and an active producer with exclude flag = true
        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);
        subscription.d4c_ExcludeCarrierAppointments__c = true;
        update subscription;

        d4c_Entity__c producer = TestDataFactory.createProducer('87654321');
        producer.d4c_SyncRecordToNIPR__c = 'On';
        producer.d4c_NPNStatus__c = 'Active';
        producer.d4c_ExcludeCarrierAppointments__c = true;
        producer.d4c_Subscription__c = subscription.Id;
        insert producer;

        // Update producer to change exclude flag from true to false
        producer.d4c_ExcludeCarrierAppointments__c = false;

        // Execute
        Test.startTest();
        update producer;
        Test.stopTest();

        // Assert - NEW: Use subscriptionNPNForTest and subscriptionOperationForTest
        System.assertNotEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'Subscription NPN should be set');
        System.assertEquals('87654321', ProducerTriggerHandler.subscriptionNPNForTest, 'Should have NPN 87654321');
        System.assertEquals(NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL, ProducerTriggerHandler.subscriptionOperationForTest, 'Operation should be RESUBSCRIBE_TO_DIFFERENT_POOL');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagChange_NotActiveOrNotSubscribed() {
        // Test that producers not active or not subscribed are NOT flagged for re-subscription

        // Create producer 1 - Not Active
        d4c_Entity__c producer1 = TestDataFactory.createProducer('11111111');
        producer1.d4c_SyncRecordToNIPR__c = 'On';
        producer1.d4c_NPNStatus__c = 'Processing'; // Not Active
        producer1.d4c_ExcludeCarrierAppointments__c = false;
        producer1.d4c_Subscription__c = null;
        insert producer1;

        // Create producer 2 - Active but not subscribed
        d4c_Entity__c producer2 = TestDataFactory.createProducer('22222222');
        producer2.d4c_SyncRecordToNIPR__c = 'On';
        producer2.d4c_NPNStatus__c = 'Active'; // Active but not subscribed
        producer2.d4c_ExcludeCarrierAppointments__c = false;
        producer2.d4c_Subscription__c = null; // No subscription
        insert producer2;

        // Update producer 1 to change exclude flag (not active, should not be flagged)
        producer1.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update producer1;

        // Assert - producer1 should NOT be flagged for re-subscription (not active)
        System.assertEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'No subscription operation should be triggered for inactive producer');

        // Update producer 2 to change exclude flag (active but no subscription, should not be flagged)
        producer2.d4c_ExcludeCarrierAppointments__c = true;
        update producer2;
        Test.stopTest();

        // Assert - producer2 should NOT be flagged for re-subscription (no subscription)
        System.assertEquals(null, ProducerTriggerHandler.subscriptionNPNForTest, 'No subscription operation should be triggered for producer without subscription');
    }

    @isTest
    private static void afterUpdate_testExcludeFlagNoChange() {
        // Test that producers whose exclude flag doesn't change are NOT flagged

        d4c_Subscription__c subscription = TestDataFactory.createSubscription(true);

        d4c_Entity__c producer = TestDataFactory.createProducer('99999999');
        producer.d4c_SyncRecordToNIPR__c = 'On';
        producer.d4c_NPNStatus__c = 'Active';
        producer.d4c_ExcludeCarrierAppointments__c = false;
        producer.d4c_Subscription__c = subscription.Id;
        insert producer;

        // Update producer but keep exclude flag the same
        producer.d4c_SyncRecordToNIPR__c = 'Off'; // Change something else

        // Execute
        Test.startTest();
        update producer;
        Test.stopTest();

        // Assert - producer should NOT be flagged for re-subscription (sync was turned off, triggers REMOVE operation instead)
        System.assertEquals(NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE, ProducerTriggerHandler.subscriptionOperationForTest, 'Should trigger REMOVE_NPN_AFTER_UPDATE since sync was disabled');
    }

    @isTest
    private static void beforeUpdate_testBulkExcludeFlagChangeValidation() {
        // Test that bulk updates of exclude flag are blocked

        // Create 3 producers
        d4c_Entity__c producer1 = TestDataFactory.createProducer('11111111');
        producer1.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c producer2 = TestDataFactory.createProducer('22222222');
        producer2.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c producer3 = TestDataFactory.createProducer('33333333');
        producer3.d4c_ExcludeCarrierAppointments__c = false;

        insert new List<d4c_Entity__c>{producer1, producer2, producer3};

        // Try to update exclude flag on 2 producers at once (should fail)
        producer1.d4c_ExcludeCarrierAppointments__c = true;
        producer2.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        try {
            update new List<d4c_Entity__c>{producer1, producer2};
            System.assert(false, 'Expected DmlException was not thrown');
        } catch (DmlException e) {
            // Assert the error message contains our validation message
            System.assert(e.getMessage().contains('Exclude Carrier Appointments'),
                         'Error message should mention Exclude Carrier Appointments');
            System.assert(e.getMessage().contains('more than 1 producer'),
                         'Error message should mention bulk update restriction');
        }
        Test.stopTest();

        // Verify producers were not updated
        List<d4c_Entity__c> updatedProducers = [
            SELECT Id, d4c_ExcludeCarrierAppointments__c
            FROM d4c_Entity__c
            WHERE Id IN :new List<Id>{producer1.Id, producer2.Id}
        ];

        for (d4c_Entity__c p : updatedProducers) {
            System.assertEquals(false, p.d4c_ExcludeCarrierAppointments__c,
                              'Producers should not have been updated due to validation error');
        }
    }

    @isTest
    private static void beforeUpdate_testSingleExcludeFlagChangeAllowed() {
        // Test that single producer exclude flag change is allowed

        // Create 2 producers
        d4c_Entity__c producer1 = TestDataFactory.createProducer('44444444');
        producer1.d4c_ExcludeCarrierAppointments__c = false;

        d4c_Entity__c producer2 = TestDataFactory.createProducer('55555555');
        producer2.d4c_ExcludeCarrierAppointments__c = false;

        insert new List<d4c_Entity__c>{producer1, producer2};

        // Update exclude flag on only 1 producer (should succeed)
        producer1.d4c_ExcludeCarrierAppointments__c = true;

        // Execute
        Test.startTest();
        update producer1; // Single update should work
        Test.stopTest();

        // Verify producer was updated
        d4c_Entity__c updatedProducer = [
            SELECT Id, d4c_ExcludeCarrierAppointments__c
            FROM d4c_Entity__c
            WHERE Id = :producer1.Id
        ];

        System.assertEquals(true, updatedProducer.d4c_ExcludeCarrierAppointments__c,
                          'Single producer should be allowed to update exclude flag');
    }

    // ==========================================
    // ORCHESTRATOR SERVICE TESTS
    // ==========================================

    /**
     * Test that afterInsert calls EntityInfoOrchestratorService with correct NPNs
     */
    @isTest
    private static void afterInsert_callsOrchestratorService() {
        // Arrange: Create producer with sync On
        d4c_Entity__c producer = new d4c_Entity__c(
            d4c_NPN__c = '777888999',
            d4c_SyncRecordToNIPR__c = 'On'
        );

        // Act
        Test.startTest();
        insert producer;
        Test.stopTest();

        // Assert: NPN should be collected for EntityInfoOrchestratorService
        System.assertEquals(1, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(),
            'Should have collected 1 NPN for orchestrator');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('777888999'),
            'Should contain the correct NPN');
    }

    /**
     * Test that afterUpdate calls EntityInfoOrchestratorService when sync is turned on
     */
    @isTest
    private static void afterUpdate_callsOrchestratorService() {
        // Arrange: Create producer with sync Off
        d4c_Entity__c producer = new d4c_Entity__c(
            d4c_NPN__c = '888999000',
            d4c_SyncRecordToNIPR__c = 'Off'
        );

        ProducerTriggerHandler.triggerDisabled = true;
        insert producer;
        ProducerTriggerHandler.triggerDisabled = false;

        // Update to turn sync on
        producer.d4c_SyncRecordToNIPR__c = 'On';

        // Act
        Test.startTest();
        update producer;
        Test.stopTest();

        // Assert: NPN should be collected for EntityInfoOrchestratorService
        System.assertEquals(1, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(),
            'Should have collected 1 NPN for orchestrator');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('888999000'),
            'Should contain the correct NPN');
    }

    /**
     * Test that multiple producers in same transaction collect all NPNs correctly
     * (NPNs are accumulated in the trigger for batch processing)
     */
    @isTest
    private static void afterInsert_collectsMultipleNPNs() {
        // Arrange: Insert multiple eligible producers in same transaction
        List<d4c_Entity__c> producers = new List<d4c_Entity__c>{
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
        insert producers;
        Test.stopTest();

        // Assert: All 3 NPNs should be collected for processing
        System.assertEquals(3, ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.size(),
                          'Should have collected 3 NPNs');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('111000111'),
                     'Should contain NPN 111000111');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('222000222'),
                     'Should contain NPN 222000222');
        System.assert(ProducerTriggerHandler.producerNPNsForEntityInfoAPIForTest.contains('333000333'),
                     'Should contain NPN 333000333');
    }

    // ==========================================
    // SELECTOR METHODS
    // ==========================================

    private static List<d4c_Entity__c> queryProducers(Set<String> npns) {
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