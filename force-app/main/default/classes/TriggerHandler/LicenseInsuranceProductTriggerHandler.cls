/*
*********************************************************
Apex Class Name    : LicenseInsuranceProductTriggerHandler
Created Date       : 2025-12-13
@description       : Handles logic for License Insurance Product junction trigger events.
                     Delegates to services for unique identifier generation and License picklist updates.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan Nidzovic         Initial Version
1.1   2025-12-15   Stefan Nidzovic         Refactored to use services and selectors
*********************************************************
*/
public with sharing class LicenseInsuranceProductTriggerHandler extends BaseTriggerHandler {

    private static final String CLASS_NAME = 'LicenseInsuranceProductTriggerHandler';

    @TestVisible
    public static Boolean triggerDisabled = false;

    @TestVisible
    private static UniqueIdentifierService mockUniqueIdService;
    @TestVisible
    private static LicenseProductPicklistService mockPicklistService;

    private UniqueIdentifierService uniqueIdService {
        get {
            if (mockUniqueIdService != null) {
                return mockUniqueIdService;
            }
            if (uniqueIdService == null) {
                uniqueIdService = new UniqueIdentifierService();
            }
            return uniqueIdService;
        }
        set;
    }

    private LicenseProductPicklistService picklistService {
        get {
            if (mockPicklistService != null) {
                return mockPicklistService;
            }
            if (picklistService == null) {
                picklistService = new LicenseProductPicklistService();
            }
            return picklistService;
        }
        set;
    }

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
        List<ht_License_Insurance_Product__c> junctions = (List<ht_License_Insurance_Product__c>) newItems;
        uniqueIdService.populateLicenseInsProdUniqueId(junctions);
    }

    /*********************************************************
    @Method Name    : afterInsert
    @description    : Adds insurance product names to License picklist field.
    @param          : newItems - Map of newly inserted junction records
    *********************************************************/
    public override void afterInsert(Map<Id, SObject> newItems) {
        List<ht_License_Insurance_Product__c> junctions = (List<ht_License_Insurance_Product__c>) newItems.values();
        addProductNamesToLicenses(junctions);
    }

    /*********************************************************
    @Method Name    : afterDelete
    @description    : Removes insurance product names from License picklist field.
    @param          : oldItems - Map of deleted junction records
    *********************************************************/
    public override void afterDelete(Map<Id, SObject> oldItems) {
        List<ht_License_Insurance_Product__c> deletedJunctions = (List<ht_License_Insurance_Product__c>) oldItems.values();
        removeProductNamesFromLicenses(deletedJunctions);
    }

    /*********************************************************
    @Method Name    : addProductNamesToLicenses
    @description    : Uses service to add product names to License picklist and performs update.
    @param          : junctions - List of newly inserted junction records
    *********************************************************/
    private void addProductNamesToLicenses(List<ht_License_Insurance_Product__c> junctions) {
        String methodName = 'addProductNamesToLicenses';

        try {
            List<ht_License__c> licensesToUpdate = picklistService.addProductNamesToLicenses(junctions);
            if (!licensesToUpdate.isEmpty()) {
                update licensesToUpdate;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /*********************************************************
    @Method Name    : removeProductNamesFromLicenses
    @description    : Uses service to remove product names from License picklist and performs update.
    @param          : deletedJunctions - List of deleted junction records
    *********************************************************/
    private void removeProductNamesFromLicenses(List<ht_License_Insurance_Product__c> deletedJunctions) {
        String methodName = 'removeProductNamesFromLicenses';

        try {
            List<ht_License__c> licensesToUpdate = picklistService.removeProductNamesFromLicenses(deletedJunctions);
            if (!licensesToUpdate.isEmpty()) {
                update licensesToUpdate;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }
}