/*
*********************************************************
Apex Class Name    : LineOfAuthorityTriggerHandler
Created Date       : 2025-12-13
@description       : Handles logic for Line of Authority trigger events.
                     Delegates to LOAProductMappingService for matching LOAs to mappings.
                     Enqueues batch jobs for License-Product junction management.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan Nidzovic         Initial Version
1.1   2025-12-15   Stefan Nidzovic         Refactored to use services and selectors
*********************************************************
*/
public with sharing class LineOfAuthorityTriggerHandler extends BaseTriggerHandler {

    private static final Integer BATCH_SIZE = 100;
    private static final String CLASS_NAME = 'LineOfAuthorityTriggerHandler';

    public static Boolean runCategorizationBatchAsync = false;

    // Note: triggerDisabled is public to allow other handlers to temporarily
    // disable LOA processing during cross-trigger operations (e.g., cascade delete cleanup)
    @TestVisible
    public static Boolean triggerDisabled = false;

    // Test flag to force exception for coverage
    @TestVisible
    private static Boolean forceException = false;

    // Captures LOAs for test verification (prevents async batch in tests)
    @TestVisible
    private static List<d4c_LineOfAuthority__c> loasEnqueuedForBatchCreate;
    @TestVisible
    private static List<d4c_LineOfAuthority__c> loasEnqueuedForBatchUpdate;
    @TestVisible
    private static Map<Id, d4c_LineOfAuthority__c> oldLoasEnqueuedForBatchUpdate;
    @TestVisible
    private static List<d4c_LineOfAuthority__c> loasEnqueuedForBatchDelete;

    @TestVisible
    private static LOAProductMappingService mockMappingService;

    private LOAProductMappingService mappingService {
        get {
            if (mockMappingService != null) {
                return mockMappingService;
            }
            if (mappingService == null) {
                mappingService = new LOAProductMappingService();
            }
            return mappingService;
        }
        set;
    }

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    /*********************************************************
    @Method Name    : beforeInsert
    @description    : Matches LOA records to Insurance Product mappings on insert.
    @param          : newItems - List of new LOA records being inserted
    *********************************************************/
    public override void beforeInsert(List<SObject> newItems) {
        List<d4c_LineOfAuthority__c> loas = (List<d4c_LineOfAuthority__c>) newItems;
        mappingService.matchLoasToMappings(loas);
    }

    /*********************************************************
    @Method Name    : beforeUpdate
    @description    : Re-matches LOA records to Insurance Product mappings on update.
    @param          : newItems - Map of updated LOA records (new values)
    @param          : oldItems - Map of updated LOA records (old values)
    *********************************************************/
    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<d4c_LineOfAuthority__c> loas = (List<d4c_LineOfAuthority__c>) newItems.values();
        mappingService.matchLoasToMappings(loas);
    }

    /*********************************************************
    @Method Name    : afterInsert
    @description    : Enqueues batch job to create License-Insurance Product junctions.
    @param          : newItems - Map of newly inserted LOA records
    *********************************************************/
    public override void afterInsert(Map<Id, SObject> newItems) {
        List<d4c_LineOfAuthority__c> loas = (List<d4c_LineOfAuthority__c>) newItems.values();
        enqueueCreateBatch(loas);
    }

    /*********************************************************
    @Method Name    : afterUpdate
    @description    : Enqueues batch job to update License-Insurance Product junctions.
    @param          : newItems - Map of updated LOA records (new values)
    @param          : oldItems - Map of updated LOA records (old values)
    *********************************************************/
    public override void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, d4c_LineOfAuthority__c> newLoaMap = (Map<Id, d4c_LineOfAuthority__c>) newItems;
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = (Map<Id, d4c_LineOfAuthority__c>) oldItems;
        enqueueUpdateBatch(newLoaMap, oldLoaMap);
    }

    /*********************************************************
    @Method Name    : afterDelete
    @description    : Enqueues batch job to delete License-Insurance Product junctions.
    @param          : oldItems - Map of deleted LOA records
    *********************************************************/
    public override void afterDelete(Map<Id, SObject> oldItems) {
        List<d4c_LineOfAuthority__c> deletedLoas = (List<d4c_LineOfAuthority__c>) oldItems.values();
        enqueueDeleteBatch(deletedLoas);
    }

    /*********************************************************
    @Method Name    : enqueueCreateBatch
    @description    : Filters LOAs with mappings and enqueues batch to create junctions.
    @param          : loas - List of newly inserted LOA records
    *********************************************************/
    private void enqueueCreateBatch(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'enqueueCreateBatch';

        try {
            // Test coverage: Force exception if flag is set
            if (forceException) {
                throw new DmlException('Forced exception for test coverage');
            }

            // Use service to filter LOAs with mappings
            List<d4c_LineOfAuthority__c> loasWithMapping = mappingService.filterLoasWithMappings(loas);

            if (!loasWithMapping.isEmpty()) {
                // TESTABILITY: In tests, capture data instead of enqueueing async job
                if (Test.isRunningTest()) {
                    loasEnqueuedForBatchCreate = loasWithMapping;
                } else {
                    // Execute synchronously to avoid "batch-in-batch" error
                    LOAProductCategorizationBatchable batchable = new LOAProductCategorizationBatchable(
                        loasWithMapping,
                        NIPREnums.OperationMode.CREATE_MODE
                    );
                    batchable.execute(null, loasWithMapping);
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /*********************************************************
    @Method Name    : enqueueUpdateBatch
    @description    : Filters LOAs where mapping changed and enqueues batch to update junctions.
    @param          : newLoaMap - Map of new LOA values
    @param          : oldLoaMap - Map of old LOA values
    *********************************************************/
    private void enqueueUpdateBatch(
        Map<Id, d4c_LineOfAuthority__c> newLoaMap,
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap
    ) {
        String methodName = 'enqueueUpdateBatch';

        try {
            // Test coverage: Force exception if flag is set
            if (forceException) {
                throw new DmlException('Forced exception for test coverage');
            }

            // Only process LOAs where mapping changed
            Map<String, Object> filterResult = mappingService.filterLoasWithChangedMappings(newLoaMap, oldLoaMap);
            List<d4c_LineOfAuthority__c> loasToProcess = (List<d4c_LineOfAuthority__c>) filterResult.get('changed');
            Map<Id, d4c_LineOfAuthority__c> oldLoasForBatch = (Map<Id, d4c_LineOfAuthority__c>) filterResult.get('old');

            if (!loasToProcess.isEmpty()) {
                // TESTABILITY: In tests, capture data instead of enqueueing async job
                if (Test.isRunningTest()) {
                    loasEnqueuedForBatchUpdate = loasToProcess;
                    oldLoasEnqueuedForBatchUpdate = oldLoasForBatch;
                } else {
                    // Execute synchronously to avoid "batch-in-batch" error
                    LOAProductCategorizationBatchable batchable = new LOAProductCategorizationBatchable(
                        loasToProcess,
                        oldLoasForBatch
                    );

                    if (!runCategorizationBatchAsync) {
                        batchable.execute(null, loasToProcess);
                    } else {
                        Database.executeBatch(batchable, 100);
                    }
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /*********************************************************
    @Method Name    : enqueueDeleteBatch
    @description    : Filters deleted LOAs with mappings and enqueues batch to delete junctions.
    @param          : deletedLoas - List of deleted LOA records
    *********************************************************/
    private void enqueueDeleteBatch(List<d4c_LineOfAuthority__c> deletedLoas) {
        String methodName = 'enqueueDeleteBatch';

        try {
            // Use service to filter LOAs with mappings
            List<d4c_LineOfAuthority__c> loasWithMapping = mappingService.filterLoasWithMappings(deletedLoas);

            if (!loasWithMapping.isEmpty()) {
                // TESTABILITY: In tests, capture data instead of enqueueing async job
                if (Test.isRunningTest()) {
                    loasEnqueuedForBatchDelete = loasWithMapping;
                } else {
                    // FIX: Execute synchronously to avoid "batch-in-batch" error
                    LOAProductCategorizationBatchable batchable = new LOAProductCategorizationBatchable(
                        loasWithMapping,
                        NIPREnums.OperationMode.DELETE_MODE
                    );
                    batchable.execute(null, loasWithMapping);
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }
}