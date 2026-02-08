/*
*********************************************************
Apex Class Name    : LOAInsuranceProductMappingTriggerHandler
Created Date       : 2025-12-15
@description       : Handles logic for LOA Insurance Product Mapping trigger events.
                     Delegates to UniqueIdentifierService for unique identifier generation.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
1.1   2025-12-15   Stefan Nidzovic         Refactored to use UniqueIdentifierService
*********************************************************
*/
public with sharing class LOAInsuranceProductMappingTriggerHandler extends BaseTriggerHandler {

    @TestVisible
    public static Boolean triggerDisabled = false;

    private UniqueIdentifierService service = new UniqueIdentifierService();
    private LOAInsuranceProductMappingSelector loaMappingSelector = new LOAInsuranceProductMappingSelector();

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    /*********************************************************
    @Method Name    : beforeInsert
    @description    : Generates unique identifier for LOA Insurance Product Mapping records.
    @param          : newItems - List of new LOA Mapping records being inserted
    *********************************************************/
    public override void beforeInsert(List<SObject> newItems) {
        List<ht_LOA_Insurance_Product_Mapping__c> mappings = (List<ht_LOA_Insurance_Product_Mapping__c>) newItems;
        service.populateLOAMappingUniqueId(mappings);
    }

    /*********************************************************
    @Method Name    : beforeUpdate
    @description    : Recalculates unique identifier when key fields change.
    @param          : newItems - Map of updated records (new values)
    @param          : oldItems - Map of updated records (old values)
    *********************************************************/
    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<ht_LOA_Insurance_Product_Mapping__c> mappings = (List<ht_LOA_Insurance_Product_Mapping__c>) newItems.values();
        service.populateLOAMappingUniqueId(mappings);
    }

    /*********************************************************
    @Method Name    : beforeDelete
    @description    : Handles cleanup when mapping is deleted:
                      1. Sets ht_IsProductMatched__c = false on related LOAs
                      2. Deletes child junction records
                      Note: ht_LOAMapping__c will be auto-nulled by Salesforce's SetNull cascade.
                      Since mappings are unique by state/code/description, no other mapping
                      can match these LOAs, so we set IsProductMatched directly.
    @param          : oldItems - Map of records being deleted
    *********************************************************/
    public override void beforeDelete(Map<Id, SObject> oldItems) {
        Set<Id> mappingIds = oldItems.keySet();

        // 1. Update related LOAs - set ht_IsProductMatched__c = false directly
        // (No need to fire LOA trigger since no other mapping can match - mappings are unique)
        LineOfAuthoritySelector loaSelector = new LineOfAuthoritySelector();
        List<ht_LineOfAuthority__c> relatedLoas = loaSelector.getLoasByMappingIds(mappingIds);

        if (!relatedLoas.isEmpty()) {
            for (ht_LineOfAuthority__c loa : relatedLoas) {
                loa.ht_IsProductMatched__c = false;
            }

            // Disable LOA trigger to avoid unnecessary processing
            LineOfAuthorityTriggerHandler.triggerDisabled = true;
            try {
                update relatedLoas;
            } catch (Exception e) {
                // If synchronous update fails (e.g., row lock from cascade delete),
                // enqueue asynchronously
                System.enqueueJob(new DMLExecutor(relatedLoas, null, null, 'LOAInsuranceProductMappingTriggerHandler'));
            }
            LineOfAuthorityTriggerHandler.triggerDisabled = false;
        }

        // 2. Delete child ht_Insurance_Product_LOA_Mapping__c junctions
        List<ht_Insurance_Product_LOA_Mapping__c> productLoaMappings =
            loaMappingSelector.getProductLOAJunctionsByLoaMappingIds(mappingIds);

        if (!productLoaMappings.isEmpty()) {
            delete productLoaMappings;
        }
    }
}