/*
*********************************************************
Apex Class Name    : InsuranceProductLOAMappingTriggerHandler
Created Date       : 2025-12-13
@description       : Handles logic for Insurance Product LOA Mapping junction trigger events.
                     Delegates to services for unique identifier generation, orphan LOA matching,
                     and cascade delete cleanup.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan Nidzovic         Initial Version
1.1   2025-12-15   Stefan Nidzovic         Refactored to use services and selectors
*********************************************************
*/
public with sharing class InsuranceProductLOAMappingTriggerHandler extends BaseTriggerHandler {

    private static final String CLASS_NAME = 'InsuranceProductLOAMappingTriggerHandler';

    @TestVisible
    public static Boolean triggerDisabled = false;

    private UniqueIdentifierService uniqueIdService = new UniqueIdentifierService();
    private LOAProductMappingService mappingService = new LOAProductMappingService();

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    /*********************************************************
    @Method Name    : beforeInsert
    @description    : Generates unique identifier for junction records.
    @param          : newItems - List of new junction records being inserted
    *********************************************************/
    public override void beforeInsert(List<SObject> newItems) {
        List<ht_Insurance_Product_LOA_Mapping__c> junctions = (List<ht_Insurance_Product_LOA_Mapping__c>) newItems;
        uniqueIdService.populateInsProdLOAMappingUniqueId(junctions);
    }

    /*********************************************************
    @Method Name    : afterInsert
    @description    : Triggers LOA processing for both orphan LOAs and existing LOAs linked to the mapping.
    @param          : newItems - Map of newly inserted junction records
    *********************************************************/
    public override void afterInsert(Map<Id, SObject> newItems) {
        List<ht_Insurance_Product_LOA_Mapping__c> junctions = (List<ht_Insurance_Product_LOA_Mapping__c>) newItems.values();
        processLoasForNewJunctions(junctions);
    }

    /*********************************************************
    @Method Name    : afterDelete
    @description    : Handles cleanup when junction is deleted (directly or via cascade).
    @param          : oldItems - Map of deleted junction records
    *********************************************************/
    public override void afterDelete(Map<Id, SObject> oldItems) {
        List<ht_Insurance_Product_LOA_Mapping__c> deletedJunctions = (List<ht_Insurance_Product_LOA_Mapping__c>) oldItems.values();
        handleCascadeDeleteCleanup(deletedJunctions);
    }

    // Captures LOAs for test verification
    @TestVisible
    private static List<ht_LineOfAuthority__c> loasEnqueuedForBatch;

    /*********************************************************
    @Method Name    : processLoasForNewJunctions
    @description    : Processes LOAs when new junctions are created. Handles two scenarios:
                      1. Orphan LOAs that match the mapping but weren't linked yet - updates them to set mapping
                      2. LOAs already linked to the mapping - runs batch to create License-Product junctions
    @param          : junctions - List of newly inserted junction records
    *********************************************************/
    private void processLoasForNewJunctions(List<ht_Insurance_Product_LOA_Mapping__c> junctions) {
        String methodName = 'processLoasForNewJunctions';

        try {
            // Extract LOA Mapping IDs from new junctions
            Set<Id> loaMappingIds = new Set<Id>();
            for (ht_Insurance_Product_LOA_Mapping__c junction : junctions) {
                if (junction.ht_LOAMapping__c != null) {
                    loaMappingIds.add(junction.ht_LOAMapping__c);
                }
            }

            if (loaMappingIds.isEmpty()) {
                return;
            }

            // 1. Find and update orphan LOAs (these will get ht_LOAMapping__c set by findOrphanLoasForMappings)
            // The update will fire the LOA trigger which handles creating License-Product junctions
            List<ht_LineOfAuthority__c> orphanLoas = mappingService.findOrphanLoasForMappings(loaMappingIds);
            if (!orphanLoas.isEmpty()) {
                DMLExecutor loaUpsert = new DMLExecutor(
                    orphanLoas,
                    ht_LineOfAuthority__c.ht_UniqueIdentifier__c,
                    null,
                    CLASS_NAME
                );

                AsyncOptions asyncOptions = new AsyncOptions();
                asyncOptions.MaximumQueueableStackDepth = 50;
        
                System.enqueueJob(loaUpsert, asyncOptions);

            }

            // 2. Find LOAs already linked to these mappings and run batch for them directly
            LineOfAuthoritySelector loaSelector = new LineOfAuthoritySelector();
            List<ht_LineOfAuthority__c> existingLinkedLoas = loaSelector.getLoasByMappingIds(loaMappingIds);

            // Exclude orphan LOAs (they were just processed above via update)
            Set<Id> orphanLoaIds = new Set<Id>();
            for (ht_LineOfAuthority__c loa : orphanLoas) {
                orphanLoaIds.add(loa.Id);
            }

            List<ht_LineOfAuthority__c> loasForBatch = new List<ht_LineOfAuthority__c>();
            for (ht_LineOfAuthority__c loa : existingLinkedLoas) {
                if (!orphanLoaIds.contains(loa.Id)) {
                    loasForBatch.add(loa);
                }
            }

            // Run batch directly for existing linked LOAs to create License-Product junctions
            if (!loasForBatch.isEmpty()) {
                if (Test.isRunningTest()) {
                    loasEnqueuedForBatch = loasForBatch;
                } else {
                    // Execute batch in CREATE_MODE - uses upsert so duplicates won't be created
                    LOAProductCategorizationBatchable batchable = new LOAProductCategorizationBatchable(
                        loasForBatch,
                        NIPREnums.OperationMode.CREATE_MODE
                    );

                    batchable.execute(null, loasForBatch);
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /*********************************************************
    @Method Name    : handleCascadeDeleteCleanup
    @description    : Handles cleanup when junction records are deleted.
    @param          : deletedJunctions - List of deleted junction records
    *********************************************************/
    private void handleCascadeDeleteCleanup(List<ht_Insurance_Product_LOA_Mapping__c> deletedJunctions) {
        String methodName = 'handleCascadeDeleteCleanup';

        try {
            // Use service to delete License-Product junctions that were granted by these mappings
            Integer deletedCount = mappingService.deleteLicenseProductsForDeletedMappingJunctions(deletedJunctions);
            if (deletedCount > 0) {
                Logger.info(CLASS_NAME, methodName,
                    'Successfully deleted License-Product junctions',
                    'Count: ' + deletedCount, null);
            }

            // Delete orphaned parent LOA Mappings (those with no remaining junctions)
            deleteOrphanedParentMappings(deletedJunctions);

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /*********************************************************
    @Method Name    : deleteOrphanedParentMappings
    @description    : Deletes parent LOA Mapping records that have no remaining junctions.
    @param          : deletedJunctions - List of deleted junction records
    *********************************************************/
    private void deleteOrphanedParentMappings(List<ht_Insurance_Product_LOA_Mapping__c> deletedJunctions) {
        String methodName = 'deleteOrphanedParentMappings';

        // Collect parent LOA Mapping IDs from deleted junctions
        Set<Id> parentMappingIds = new Set<Id>();
        Set<Id> orphanedMappingIds = new Set<Id>();
        for (ht_Insurance_Product_LOA_Mapping__c junction : deletedJunctions) {
            if (junction.ht_LOAMapping__c != null) {
                parentMappingIds.add(junction.ht_LOAMapping__c);
            }
        }

        if (parentMappingIds.isEmpty()) {
            return;
        }

        // Count remaining junctions for each parent mapping
        InsuranceProductLOAMappingSelector junctionSelector = new InsuranceProductLOAMappingSelector();
        Map<Id, Integer> junctionCounts = junctionSelector.countJunctionsByLoaMappingIds(parentMappingIds);

        // Find parent mappings with zero remaining junctions
        List<ht_LOA_Insurance_Product_Mapping__c> orphanedMappings = new List<ht_LOA_Insurance_Product_Mapping__c>();
        for (Id mappingId : parentMappingIds) {
            Integer count = junctionCounts.get(mappingId);
            if (count == null || count == 0) {
                orphanedMappings.add(new ht_LOA_Insurance_Product_Mapping__c(Id = mappingId));
                orphanedMappingIds.add(mappingId);
            }
        }

        // Delete orphaned parent mappings
        if (!orphanedMappings.isEmpty()) {

            if (!Test.isRunningTest()) {
                DMLExecutor deleteExecutor = new DMLExecutor(new List<Id>(orphanedMappingIds), null, CLASS_NAME);

                AsyncOptions asyncOptions = new AsyncOptions();
                asyncOptions.MaximumQueueableStackDepth = 50;
        
                System.enqueueJob(deleteExecutor, asyncOptions);

                return;
            }

            delete orphanedMappings;
            
            Logger.info(CLASS_NAME, methodName,
                'Deleted orphaned parent LOA Mappings',
                'Count: ' + orphanedMappings.size(), null);
        }
    }
}