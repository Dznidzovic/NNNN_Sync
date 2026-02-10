/*********************************************************
 * Apex Class Name    : ProducerTriggerHandler
 * Created Date       : 04-15-2025
 * @description       : Trigger handler class that gets invoked from the d4c_Entity__c trigger and covers all DML Operation scenarios
 *                    : Invokes the Entity Info API to download NIPR data for producers and if successfull invokes the Add Target Subscription service of the NIPR API
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 * 1.1   04-25-2025   Stefan Nidzovic          Added support for removing NPNs from subscriptions
 * 1.2   04-25-2025   Stefan Nidzovic          Added handler for deleted producers
 * 1.3   10-24-2025   Stefan Nidzovic          Added re-subscription logic for Exclude Carrier Appointments flag changes
 * 2.0   10-24-2025   Stefan Nidzovic          Complete refactor - SubscriptionOrchestratorQueueable architecture
 *********************************************************
 **/
public with sharing class ProducerTriggerHandler extends BaseTriggerHandler {
    @TestVisible
    private static Boolean triggerDisabled = false;

    // Test-visible flag to force production logic in tests
    @TestVisible
    private static Boolean forceProductionLogic = false;

    // Properties used only for asserting from withing the test class to test the business logic
    @TestVisible
    private static Set<String> producerNPNsForEntityInfoAPIForTest;
    @TestVisible
    private static List<d4c_Entity__c> deletedProducersForTest;

    // NEW: Properties for testing subscription operations (afterUpdate)
    @TestVisible
    private static String subscriptionNPNForTest;
    @TestVisible
    private static NIPREnums.SubscriptionOperation subscriptionOperationForTest;

    // NEW: Property for testing bulk delete subscription operations (afterDelete)
    @TestVisible
    private static Map<String, Id> deletedProducerNPNToSubscriptionMapForTest;

    // Property to disable subscription validation for bulk data import tests
    @TestVisible
    private static Boolean disableSubscriptionValidation = false;

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    public override void beforeInsert(List<SObject> newItems) {
        for (SObject obj : newItems) {
            d4c_Entity__c producer = (d4c_Entity__c) obj;

            String producerNPN = producer.d4c_NPN__c;
            Boolean producerSyncStatus = producer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty and producer sync status must be "ON"
            if (!String.isBlank(producerNPN) && producerSyncStatus && producer.d4c_NPNStatus__c != 'Active') {
                producer.d4c_NPNStatus__c = 'Processing';
            }
        }
    }

    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Validation: Prevent bulk updates of Exclude Carrier Appointments flag
        Integer excludeFlagChanges = 0;

        for (Id producerId : newItems.keySet()) {
            d4c_Entity__c oldProducer = (d4c_Entity__c) oldItems.get(producerId);
            d4c_Entity__c newProducer = (d4c_Entity__c) newItems.get(producerId);

            // Check if exclude flag changed
            if (oldProducer.d4c_ExcludeCarrierAppointments__c != newProducer.d4c_ExcludeCarrierAppointments__c) {
                excludeFlagChanges++;
            }
        }

        // If more than 1 producer is changing the exclude flag, block the transaction
        if (excludeFlagChanges > 1) {
            for (Id producerId : newItems.keySet()) {
                d4c_Entity__c oldProducer = (d4c_Entity__c) oldItems.get(producerId);
                d4c_Entity__c newProducer = (d4c_Entity__c) newItems.get(producerId);

                if (oldProducer.d4c_ExcludeCarrierAppointments__c != newProducer.d4c_ExcludeCarrierAppointments__c) {
                    newProducer.addError('You cannot change the "Exclude Carrier Appointments" setting for more than 1 producer in the same transaction. Please update producers individually.');
                }
            }
            return; // Exit early to prevent further processing
        }

        for (Id producerId : newItems.keySet()) {
            d4c_Entity__c oldProducer = (d4c_Entity__c) oldItems.get(producerId);
            d4c_Entity__c newProducer = (d4c_Entity__c) newItems.get(producerId);

            String oldProducerNPN = oldProducer.d4c_NPN__c;
            String newProducerNPN = newProducer.d4c_NPN__c;
            Boolean oldProducerSyncStatus = oldProducer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean producerSyncStatus = newProducer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty, must be different from the previous NPN value and producer sync status must be "ON"
            if (!String.isBlank(newProducerNPN) && (newProducerNPN != oldProducerNPN) && producerSyncStatus &&  newProducer.d4c_NPNStatus__c != 'Active') {
                newProducer.d4c_NPNStatus__c = 'Processing';
            }

            if (oldProducerSyncStatus && !producerSyncStatus) {
                newProducer.d4c_NPNStatus__c = 'Sync Disabled';
                newProducer.d4c_NPNSyncError__c = '';
            }
        }
    }

    public override void afterInsert(Map<Id, SObject> newItems) {
        // Stores npn values which the full EntityInfoAPI report will be downloaded for
        Set<String> producerNpnsForEntityInfoAPI = new Set<String>();


        for (Id producerId : newItems.keySet()) {
            d4c_Entity__c producer = (d4c_Entity__c) newItems.get(producerId);

            String producerNPN = producer.d4c_NPN__c;
            Boolean producerSyncStatus = producer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty, producer sync status must be "ON", and status must not already be Active
            // (Producers created with Active status come from PDB Alert and don't need Entity Info API sync)
            if (!String.isBlank(producerNPN) && producerSyncStatus && producer.d4c_NPNStatus__c != 'Active') {
                producerNpnsForEntityInfoAPI.add(producerNPN);
            }
        }

        // Do not allow Queuable classes to execute from within the Test, their logic will be tested in their appropriate test classes
        if (!Test.isRunningTest() || forceProductionLogic) {
            if (!producerNpnsForEntityInfoAPI.isEmpty()) {
                // Use orchestrator service to decide whether to execute immediately or schedule
                EntityInfoOrchestratorService.execute(producerNpnsForEntityInfoAPI);
            }
        } else {
            producerNPNsForEntityInfoAPIForTest = producerNpnsForEntityInfoAPI;
        }
    }

    public override void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Stores npn values which the full EntityInfoAPI report will be downloaded for
        Set<String> producerNpnsForEntityInfoAPI = new Set<String>();

        // Track subscription operations
        String subscriptionNPN = null;
        NIPREnums.SubscriptionOperation subscriptionOperation = null;
        Integer subscriptionOperationCount = 0;

        for (Id producerId : newItems.keySet()) {
            d4c_Entity__c oldProducer = (d4c_Entity__c) oldItems.get(producerId);
            d4c_Entity__c newProducer = (d4c_Entity__c) newItems.get(producerId);

            String oldProducerNPN = oldProducer.d4c_NPN__c;
            String newProducerNPN = newProducer.d4c_NPN__c;
            Boolean oldProducerSyncStatus = oldProducer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean producerSyncStatus = newProducer.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean statusChangedToActive = oldProducer.d4c_NPNStatus__c != 'Active' && newProducer.d4c_NPNStatus__c == 'Active';
            Boolean statusActiveStatic = oldProducer.d4c_NPNStatus__c == 'Active' && newProducer.d4c_NPNStatus__c == 'Active';
            Boolean syncDisabled = oldProducerSyncStatus && !producerSyncStatus && newProducer.d4c_NPNStatus__c == 'Sync Disabled';
            Boolean excludeFlagChanged = oldProducer.d4c_ExcludeCarrierAppointments__c != newProducer.d4c_ExcludeCarrierAppointments__c;
            Boolean isActiveAndSubscribed = newProducer.d4c_NPNStatus__c == 'Active' && newProducer.d4c_Subscription__c != null;

            // EntityInfo API logic (unchanged)
            if ((!String.isBlank(newProducerNPN) && (newProducerNPN != oldProducerNPN) && producerSyncStatus) || (!oldProducerSyncStatus && producerSyncStatus && newProducer.d4c_NPNStatus__c != 'Active')) {
                producerNpnsForEntityInfoAPI.add(newProducer.d4c_NPN__c);
            }


            // REMOVE_NPN_AFTER_UPDATE
            if (syncDisabled && !String.isBlank(newProducerNPN) && newProducer.d4c_Subscription__c != null) {
                subscriptionOperationCount++;
                subscriptionNPN = newProducerNPN;
                subscriptionOperation = NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE;
            }
            // RESUBSCRIBE_TO_DIFFERENT_POOL
            else if (isActiveAndSubscribed && excludeFlagChanged) {
                subscriptionOperationCount++;
                subscriptionNPN = newProducerNPN;
                subscriptionOperation = NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL;
            }
        }

        // Validate that only 1 producer can have subscription operation in same transaction
        // Skip validation if disabled for bulk data import tests
        if (!disableSubscriptionValidation && subscriptionOperationCount > 1) {
            for (Id producerId : newItems.keySet()) {
                d4c_Entity__c newProducer = (d4c_Entity__c) newItems.get(producerId);
                newProducer.addError('You cannot perform subscription operations for more than 1 producer in the same transaction. Please update producers individually.');
            }
        }

        // Execute queueables after validation
        if (!Test.isRunningTest() || forceProductionLogic) {
            // Use orchestrator service to decide whether to execute immediately or schedule
            if (!producerNpnsForEntityInfoAPI.isEmpty()) {
                EntityInfoOrchestratorService.execute(producerNpnsForEntityInfoAPI);
            }

            // Execute subscription operation if needed (not in test mode)
            if (!Test.isRunningTest() && subscriptionOperationCount == 1) {
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(subscriptionNPN, subscriptionOperation));
            }
        } else {
            producerNPNsForEntityInfoAPIForTest = producerNpnsForEntityInfoAPI;
            subscriptionNPNForTest = subscriptionNPN;
            subscriptionOperationForTest = subscriptionOperation;
        }
    }

     /**
     ********************************************************
     * @Method Name    : afterDelete
     * @description    : Handles producers after they've been deleted from the database
     *                   BULKIFIED - collects all eligible producers and makes single orchestrator call
     * @param          : oldItems - Map of producer records that were deleted
     * @return         : void
     ********************************************************
     **/
    public override void afterDelete(Map<Id, SObject> oldItems) {
        List<d4c_Entity__c> oldProducers = (List<d4c_Entity__c>) oldItems.values();

        // BULKIFIED - collect all NPNs and their subscriptions for single orchestrator call
        Map<String, Id> npnToSubscriptionMap = new Map<String, Id>();

        for (d4c_Entity__c producer : oldProducers) {
            // Only remove from subscription if producer was active and subscribed
            if (producer.d4c_NPNStatus__c == 'Active' && producer.d4c_Subscription__c != null && String.isNotBlank(producer.d4c_NPN__c)) {
                npnToSubscriptionMap.put(producer.d4c_NPN__c, producer.d4c_Subscription__c);
            }
        }

        if (!Test.isRunningTest()) {
            // Single enqueue for ALL deleted producers (bulkified)
            if (!npnToSubscriptionMap.isEmpty()) {
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(npnToSubscriptionMap, NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_DELETE));
            }
        } else {
            deletedProducersForTest = new List<d4c_Entity__c>();
            for (d4c_Entity__c producer : oldProducers) {
                if (producer.d4c_NPNStatus__c == 'Active' && producer.d4c_Subscription__c != null) {
                    deletedProducersForTest.add(producer);
                }
            }
            deletedProducerNPNToSubscriptionMapForTest = npnToSubscriptionMap;
        }
    }
}