/**
 *********************************************************
 * Apex Class Name    : LOAProductCategorizationBatchable
 * Created Date       : 2025-12-13
 * @description       : Batchable class that processes LOA changes and manages
 *                      License-Insurance Product junctions. Delegates to
 *                      LicenseProductCategorizationService for business logic.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-13   Dev4Clouds         Initial Version
 * 1.1   2025-12-15   Dev4Clouds         Refactored to use services and selectors
 *********************************************************
**/
public with sharing class LOAProductCategorizationBatchable implements Database.Batchable<SObject>, Database.Stateful {

    private final String CLASS_NAME = 'LOAProductCategorizationBatchable';

    private NIPREnums.OperationMode operationMode;
    private List<d4c_LineOfAuthority__c> loaRecords;
    private Map<Id, d4c_LineOfAuthority__c> oldLoaMap;  // For UPDATE mode: stores old LOA values

    private LicenseProductCategorizationService categorizationService = new LicenseProductCategorizationService();

    /**
     *********************************************************
     * @description    : Constructor for CREATE and DELETE modes
     * @param          : loas - List of LOA records to process
     * @param          : mode - Operation mode (CREATE_MODE or DELETE_MODE)
     *********************************************************
     */
    public LOAProductCategorizationBatchable(List<d4c_LineOfAuthority__c> loas, NIPREnums.OperationMode mode) {
        this.loaRecords = loas;
        this.operationMode = mode;
        this.oldLoaMap = null;
    }

    /**
     *********************************************************
     * @description    : Constructor for UPDATE mode (requires both old and new values)
     * @param          : newLoas - List of new LOA record values
     * @param          : oldLoas - Map of old LOA record values (keyed by Id)
     *********************************************************
     */
    public LOAProductCategorizationBatchable(List<d4c_LineOfAuthority__c> newLoas, Map<Id, d4c_LineOfAuthority__c> oldLoas) {
        this.loaRecords = newLoas;
        this.operationMode = NIPREnums.OperationMode.UPDATE_MODE;
        this.oldLoaMap = oldLoas;
    }

    /**
     *********************************************************
     * @Method Name    : start
     * @description    : Returns the list of LOA records to process
     * @param          : context - Batch context
     * @return         : Iterable of LOA records
     *********************************************************
     */
    public Iterable<SObject> start(Database.BatchableContext context) {
        String methodName = 'start';

        Logger.info(CLASS_NAME, methodName, 'Starting LOA Product Categorization batch',
                  'LOA count: ' + loaRecords.size() + ', Mode: ' + operationMode.name(), null);

        return loaRecords;
    }

    /**
     *********************************************************
     * @Method Name    : execute
     * @description    : Processes each batch of LOA records based on operation mode.
     *                   Delegates to LicenseProductCategorizationService for business logic.
     * @param          : context - Batch context
     * @param          : scope - List of LOA records to process in this batch
     *********************************************************
     */
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        String methodName = 'execute';

        List<d4c_LineOfAuthority__c> loasToProcess = (List<d4c_LineOfAuthority__c>) scope;

        Logger.info(CLASS_NAME, methodName, 'Processing batch of LOAs',
                  'Batch size: ' + loasToProcess.size() + ', Mode: ' + operationMode.name(), null);

        try {
            switch on operationMode {
                when CREATE_MODE {
                    processCreateMode(loasToProcess);
                }
                when UPDATE_MODE {
                    processUpdateMode(loasToProcess);
                }
                when DELETE_MODE {
                    processDeleteMode(loasToProcess);
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /**
     *********************************************************
     * @Method Name    : processCreateMode
     * @description    : Creates License-Insurance Product junctions for LOAs with mappings.
     * @param          : loas - LOA records with populated d4c_LOAMapping__c
     *********************************************************
     */
    private void processCreateMode(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'processCreateMode';

        // Use service to create junctions
        List<d4c_License_Insurance_Product__c> junctionsToUpsert = categorizationService.createJunctionsForLoas(loas);

        // Upsert junctions using External ID to prevent duplicates
        if (!junctionsToUpsert.isEmpty()) {
            ListUtils.deduplicateByField(junctionsToUpsert, 'd4c_UniqueIdentifier__c');
            upsert junctionsToUpsert d4c_UniqueIdentifier__c;
        }

        Logger.debug(CLASS_NAME, methodName, 'Processing CREATE mode',
                   'LOA count: ' + loas.size() + ', Junctions created: ' + junctionsToUpsert.size(), null);
    }

    /**
     *********************************************************
     * @Method Name    : processUpdateMode
     * @description    : Updates License-Insurance Product junctions when LOA mapping changes.
     * @param          : loas - LOA records with changed d4c_LOAMapping__c
     *********************************************************
     */
    private void processUpdateMode(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'processUpdateMode';

        // Use service to calculate changes
        Map<String, Object> changes = categorizationService.calculateJunctionChangesForLoaUpdates(loas, oldLoaMap);
        List<d4c_License_Insurance_Product__c> junctionsToCreate = (List<d4c_License_Insurance_Product__c>) changes.get('toCreate');
        Set<String> junctionKeysToDelete = (Set<String>) changes.get('keysToDelete');

        // Delete junctions FIRST (before creating new ones)
        if (!junctionKeysToDelete.isEmpty()) {
            List<d4c_License_Insurance_Product__c> junctionsToDelete = categorizationService.getJunctionsToDeleteByKeys(junctionKeysToDelete);
            if (!junctionsToDelete.isEmpty()) {
                delete junctionsToDelete;
            }
        }

        // Upsert new junctions
        if (!junctionsToCreate.isEmpty()) {
            ListUtils.deduplicateByField(junctionsToCreate, 'd4c_UniqueIdentifier__c');
            upsert junctionsToCreate d4c_UniqueIdentifier__c;
        }

        Logger.debug(CLASS_NAME, methodName, 'Processing UPDATE mode',
                   'LOA count: ' + loas.size() + ', Junctions deleted: ' + junctionKeysToDelete.size() +
                   ', Junctions created: ' + junctionsToCreate.size(), null);
    }

    /**
     *********************************************************
     * @Method Name    : processDeleteMode
     * @description    : Deletes License-Insurance Product junctions for deleted LOAs.
     * @param          : loas - Deleted LOA records
     *********************************************************
     */
    private void processDeleteMode(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'processDeleteMode';

        // Use service to get junction keys to delete
        Set<String> junctionKeysToDelete = categorizationService.getJunctionKeysToDeleteForLoas(loas);

        // Query and delete junctions
        if (!junctionKeysToDelete.isEmpty()) {
            List<d4c_License_Insurance_Product__c> junctionsToDelete = categorizationService.getJunctionsToDeleteByKeys(junctionKeysToDelete);
            if (!junctionsToDelete.isEmpty()) {
                delete junctionsToDelete;
            }
        }

        Logger.debug(CLASS_NAME, methodName, 'Processing DELETE mode',
                   'LOA count: ' + loas.size() + ', Junctions deleted: ' + junctionKeysToDelete.size(), null);
    }

    /**
     *********************************************************
     * @Method Name    : finish
     * @description    : Called after all batches complete. Commits any pending logs.
     * @param          : context - Batch context
     *********************************************************
     */
    public void finish(Database.BatchableContext context) {
        String methodName = 'finish';

        Logger.info(CLASS_NAME, methodName, 'Finished LOA Product Categorization batch',
                  'Total LOAs processed: ' + loaRecords.size() + ', Mode: ' + operationMode.name(), null);

        Logger.commitSync();
    }
}