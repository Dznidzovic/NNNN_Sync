/*
*********************************************************
Apex Class Name    : LicenseInsuranceProductSelector
Created Date       : 2025-12-15
@description       : Selector class for querying ht_License_Insurance_Product__c junction records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
public with sharing class LicenseInsuranceProductSelector {

    /**
     ********************************************************
     * @Method Name    : getJunctionsByUniqueIdentifiers
     * @description    : Returns list of junctions by UniqueIdentifier (External ID)
     *                   UniqueIdentifier format: LicenseId-ProductId
     * @param          : identifiers - Set of unique identifier values
     * @return         : List<ht_License_Insurance_Product__c> - list of junction records
     *******************************************************
     **/
    public List<ht_License_Insurance_Product__c> getJunctionsByUniqueIdentifiers(Set<String> identifiers) {
        return [
            SELECT
                Id,
                ht_License__c,
                ht_InsuranceProduct__c,
                ht_UniqueIdentifier__c
            FROM
                ht_License_Insurance_Product__c
            WHERE
                ht_UniqueIdentifier__c IN :identifiers
        ];
    }
}