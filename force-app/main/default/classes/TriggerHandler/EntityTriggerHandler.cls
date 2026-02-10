/*********************************************************
 * Apex Class Name    : EntityTriggerHandler
 * Created Date       : 04-15-2025
 * @description       : Trigger handler class that gets invoked from the d4c_Entity__c trigger and covers all DML Operation scenarios
 *                    : Invokes the Entity Info API to download NIPR data for entitys and if successfull invokes the Add Target Subscription service of the NIPR API
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Dev4Clouds          Initial Version
 * 1.1   04-25-2025   Dev4Clouds          Added support for removing NPNs from subscriptions
 * 1.2   04-25-2025   Dev4Clouds          Added handler for deleted entitys
 * 1.3   10-24-2025   Dev4Clouds          Added re-subscription logic for Exclude Carrier Appointments flag changes
 * 2.0   10-24-2025   Dev4Clouds          Complete refactor - SubscriptionOrchestratorQueueable architecture
 *********************************************************
 **/
public with sharing class EntityTriggerHandler extends BaseTriggerHandler {
    @TestVisible
    private static Boolean triggerDisabled = false;

    // Test-visible flag to force production logic in tests
    @TestVisible
    private static Boolean forceProductionLogic = false;

    // Properties used only for asserting from withing the test class to test the business logic
    @TestVisible
    private static Set<String> entityNPNsForEntityInfoAPIForTest;
    @TestVisible
    private static List<d4c_Entity__c> deletedEntitysForTest;

    // NEW: Properties for testing subscription operations (afterUpdate)
    @TestVisible
    private static String subscriptionNPNForTest;
    @TestVisible
    private static NIPREnums.SubscriptionOperation subscriptionOperationForTest;

    // NEW: Property for testing bulk delete subscription operations (afterDelete)
    @TestVisible
    private static Map<String, Id> deletedEntityNPNToSubscriptionMapForTest;

    // Property to disable subscription validation for bulk data import tests
    @TestVisible
    private static Boolean disableSubscriptionValidation = false;

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    public override void beforeInsert(List<SObject> newItems) {
        for (SObject obj : newItems) {
            d4c_Entity__c entity = (d4c_Entity__c) obj;

            String entityNPN = entity.d4c_NPN__c;
            Boolean entitySyncStatus = entity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty and entity sync status must be "ON"
            if (!String.isBlank(entityNPN) && entitySyncStatus && entity.d4c_NPNStatus__c != 'Active') {
                entity.d4c_NPNStatus__c = 'Processing';
            }
        }
    }

    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Validation: Prevent bulk updates of Exclude Carrier Appointments flag
        Integer excludeFlagChanges = 0;

        for (Id entityId : newItems.keySet()) {
            d4c_Entity__c oldEntity = (d4c_Entity__c) oldItems.get(entityId);
            d4c_Entity__c newEntity = (d4c_Entity__c) newItems.get(entityId);

            // Check if exclude flag changed
            if (oldEntity.d4c_ExcludeCarrierAppointments__c != newEntity.d4c_ExcludeCarrierAppointments__c) {
                excludeFlagChanges++;
            }
        }

        // If more than 1 entity is changing the exclude flag, block the transaction
        if (excludeFlagChanges > 1) {
            for (Id entityId : newItems.keySet()) {
                d4c_Entity__c oldEntity = (d4c_Entity__c) oldItems.get(entityId);
                d4c_Entity__c newEntity = (d4c_Entity__c) newItems.get(entityId);

                if (oldEntity.d4c_ExcludeCarrierAppointments__c != newEntity.d4c_ExcludeCarrierAppointments__c) {
                    newEntity.addError('You cannot change the "Exclude Carrier Appointments" setting for more than 1 entity in the same transaction. Please update entitys individually.');
                }
            }
            return; // Exit early to prevent further processing
        }

        for (Id entityId : newItems.keySet()) {
            d4c_Entity__c oldEntity = (d4c_Entity__c) oldItems.get(entityId);
            d4c_Entity__c newEntity = (d4c_Entity__c) newItems.get(entityId);

            String oldEntityNPN = oldEntity.d4c_NPN__c;
            String newEntityNPN = newEntity.d4c_NPN__c;
            Boolean oldEntitySyncStatus = oldEntity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean entitySyncStatus = newEntity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty, must be different from the previous NPN value and entity sync status must be "ON"
            if (!String.isBlank(newEntityNPN) && (newEntityNPN != oldEntityNPN) && entitySyncStatus &&  newEntity.d4c_NPNStatus__c != 'Active') {
                newEntity.d4c_NPNStatus__c = 'Processing';
            }

            if (oldEntitySyncStatus && !entitySyncStatus) {
                newEntity.d4c_NPNStatus__c = 'Sync Disabled';
                newEntity.d4c_NPNSyncError__c = '';
            }
        }
    }

    public override void afterInsert(Map<Id, SObject> newItems) {
        // Stores npn values which the full EntityInfoAPI report will be downloaded for
        Set<String> entityNpnsForEntityInfoAPI = new Set<String>();


        for (Id entityId : newItems.keySet()) {
            d4c_Entity__c entity = (d4c_Entity__c) newItems.get(entityId);

            String entityNPN = entity.d4c_NPN__c;
            Boolean entitySyncStatus = entity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;

            // NPN must not be empty, entity sync status must be "ON", and status must not already be Active
            // (Entitys created with Active status come from PDB Alert and don't need Entity Info API sync)
            if (!String.isBlank(entityNPN) && entitySyncStatus && entity.d4c_NPNStatus__c != 'Active') {
                entityNpnsForEntityInfoAPI.add(entityNPN);
            }
        }

        // Do not allow Queuable classes to execute from within the Test, their logic will be tested in their appropriate test classes
        if (!Test.isRunningTest() || forceProductionLogic) {
            if (!entityNpnsForEntityInfoAPI.isEmpty()) {
                // Use orchestrator service to decide whether to execute immediately or schedule
                EntityInfoOrchestratorService.execute(entityNpnsForEntityInfoAPI);
            }
        } else {
            entityNPNsForEntityInfoAPIForTest = entityNpnsForEntityInfoAPI;
        }
    }

    public override void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Stores npn values which the full EntityInfoAPI report will be downloaded for
        Set<String> entityNpnsForEntityInfoAPI = new Set<String>();

        // Track subscription operations
        String subscriptionNPN = null;
        NIPREnums.SubscriptionOperation subscriptionOperation = null;
        Integer subscriptionOperationCount = 0;

        for (Id entityId : newItems.keySet()) {
            d4c_Entity__c oldEntity = (d4c_Entity__c) oldItems.get(entityId);
            d4c_Entity__c newEntity = (d4c_Entity__c) newItems.get(entityId);

            String oldEntityNPN = oldEntity.d4c_NPN__c;
            String newEntityNPN = newEntity.d4c_NPN__c;
            Boolean oldEntitySyncStatus = oldEntity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean entitySyncStatus = newEntity.d4c_SyncRecordToNIPR__c == 'On' ? true : false;
            Boolean statusChangedToActive = oldEntity.d4c_NPNStatus__c != 'Active' && newEntity.d4c_NPNStatus__c == 'Active';
            Boolean statusActiveStatic = oldEntity.d4c_NPNStatus__c == 'Active' && newEntity.d4c_NPNStatus__c == 'Active';
            Boolean syncDisabled = oldEntitySyncStatus && !entitySyncStatus && newEntity.d4c_NPNStatus__c == 'Sync Disabled';
            Boolean excludeFlagChanged = oldEntity.d4c_ExcludeCarrierAppointments__c != newEntity.d4c_ExcludeCarrierAppointments__c;
            Boolean isActiveAndSubscribed = newEntity.d4c_NPNStatus__c == 'Active' && newEntity.d4c_Subscription__c != null;

            // EntityInfo API logic (unchanged)
            if ((!String.isBlank(newEntityNPN) && (newEntityNPN != oldEntityNPN) && entitySyncStatus) || (!oldEntitySyncStatus && entitySyncStatus && newEntity.d4c_NPNStatus__c != 'Active')) {
                entityNpnsForEntityInfoAPI.add(newEntity.d4c_NPN__c);
            }


            // REMOVE_NPN_AFTER_UPDATE
            if (syncDisabled && !String.isBlank(newEntityNPN) && newEntity.d4c_Subscription__c != null) {
                subscriptionOperationCount++;
                subscriptionNPN = newEntityNPN;
                subscriptionOperation = NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_UPDATE;
            }
            // RESUBSCRIBE_TO_DIFFERENT_POOL
            else if (isActiveAndSubscribed && excludeFlagChanged) {
                subscriptionOperationCount++;
                subscriptionNPN = newEntityNPN;
                subscriptionOperation = NIPREnums.SubscriptionOperation.RESUBSCRIBE_TO_DIFFERENT_POOL;
            }
        }

        // Validate that only 1 entity can have subscription operation in same transaction
        // Skip validation if disabled for bulk data import tests
        if (!disableSubscriptionValidation && subscriptionOperationCount > 1) {
            for (Id entityId : newItems.keySet()) {
                d4c_Entity__c newEntity = (d4c_Entity__c) newItems.get(entityId);
                newEntity.addError('You cannot perform subscription operations for more than 1 entity in the same transaction. Please update entitys individually.');
            }
        }

        // Execute queueables after validation
        if (!Test.isRunningTest() || forceProductionLogic) {
            // Use orchestrator service to decide whether to execute immediately or schedule
            if (!entityNpnsForEntityInfoAPI.isEmpty()) {
                EntityInfoOrchestratorService.execute(entityNpnsForEntityInfoAPI);
            }

            // Execute subscription operation if needed (not in test mode)
            if (!Test.isRunningTest() && subscriptionOperationCount == 1) {
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(subscriptionNPN, subscriptionOperation));
            }
        } else {
            entityNPNsForEntityInfoAPIForTest = entityNpnsForEntityInfoAPI;
            subscriptionNPNForTest = subscriptionNPN;
            subscriptionOperationForTest = subscriptionOperation;
        }
    }

     /**
     ********************************************************
     * @Method Name    : afterDelete
     * @description    : Handles entitys after they've been deleted from the database
     *                   BULKIFIED - collects all eligible entitys and makes single orchestrator call
     * @param          : oldItems - Map of entity records that were deleted
     * @return         : void
     ********************************************************
     **/
    public override void afterDelete(Map<Id, SObject> oldItems) {
        List<d4c_Entity__c> oldEntitys = (List<d4c_Entity__c>) oldItems.values();

        // BULKIFIED - collect all NPNs and their subscriptions for single orchestrator call
        Map<String, Id> npnToSubscriptionMap = new Map<String, Id>();

        for (d4c_Entity__c entity : oldEntitys) {
            // Only remove from subscription if entity was active and subscribed
            if (entity.d4c_NPNStatus__c == 'Active' && entity.d4c_Subscription__c != null && String.isNotBlank(entity.d4c_NPN__c)) {
                npnToSubscriptionMap.put(entity.d4c_NPN__c, entity.d4c_Subscription__c);
            }
        }

        if (!Test.isRunningTest()) {
            // Single enqueue for ALL deleted entitys (bulkified)
            if (!npnToSubscriptionMap.isEmpty()) {
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(npnToSubscriptionMap, NIPREnums.SubscriptionOperation.REMOVE_NPN_AFTER_DELETE));
            }
        } else {
            deletedEntitysForTest = new List<d4c_Entity__c>();
            for (d4c_Entity__c entity : oldEntitys) {
                if (entity.d4c_NPNStatus__c == 'Active' && entity.d4c_Subscription__c != null) {
                    deletedEntitysForTest.add(entity);
                }
            }
            deletedEntityNPNToSubscriptionMapForTest = npnToSubscriptionMap;
        }
    }
}