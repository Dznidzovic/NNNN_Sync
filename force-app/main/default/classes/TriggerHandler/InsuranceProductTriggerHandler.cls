/*
*********************************************************
Apex Class Name    : InsuranceProductTriggerHandler
Created Date       : 2025-12-15
@description       : Handles logic for Insurance Product trigger events.
                     Delegates to UniqueIdentifierService for unique identifier generation.
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
1.1   2025-12-15   Dev4Clouds         Refactored to use UniqueIdentifierService
*********************************************************
*/
public with sharing class InsuranceProductTriggerHandler extends BaseTriggerHandler {

    @TestVisible
    public static Boolean triggerDisabled = false;

    private UniqueIdentifierService service = new UniqueIdentifierService();
    private InsuranceProductLOAMappingSelector productLOAMappingSelector = new InsuranceProductLOAMappingSelector();
    private LicenseInsuranceProductSelector licenseProductSelector = new LicenseInsuranceProductSelector();

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    /*********************************************************
    @Method Name    : beforeInsert
    @description    : Generates unique identifier for Insurance Product records.
    @param          : newItems - List of new Insurance Product records being inserted
    *********************************************************/
    public override void beforeInsert(List<SObject> newItems) {
        List<d4c_Insurance_Product__c> products = (List<d4c_Insurance_Product__c>) newItems;
        service.populateInsuranceProductUniqueId(products);
    }

    /*********************************************************
    @Method Name    : beforeUpdate
    @description    : Recalculates unique identifier when key fields change.
    @param          : newItems - Map of updated records (new values)
    @param          : oldItems - Map of updated records (old values)
    *********************************************************/
    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<d4c_Insurance_Product__c> products = (List<d4c_Insurance_Product__c>) newItems.values();
        service.populateInsuranceProductUniqueId(products);
    }

    /*********************************************************
    @Method Name    : beforeDelete
    @description    : Manually deletes child junction records before cascade delete
    @param          : oldItems - Map of records being deleted
    *********************************************************/
    public override void beforeDelete(Map<Id, SObject> oldItems) {
        Set<Id> productIds = oldItems.keySet();

        // Query and delete d4c_Insurance_Product_LOA_Mapping__c junctions
        // When these are deleted, the InsuranceProductLOAMappingTriggerHandler.afterDelete()
        // will handle deleting the related d4c_License_Insurance_Product__c junctions
        List<d4c_Insurance_Product_LOA_Mapping__c> productLoaMappings =
            productLOAMappingSelector.getJunctionsByInsuranceProductIds(productIds);

        if (!productLoaMappings.isEmpty()) {
            delete productLoaMappings;
        }
    }
}