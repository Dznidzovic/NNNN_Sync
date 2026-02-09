/*
*********************************************************
Apex Class Name    : LicenseInsuranceProductSelector
Created Date       : 2025-12-15
@description       : Selector class for querying d4c_License_Insurance_Product__c junction records
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
     * @return         : List<d4c_License_Insurance_Product__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_License_Insurance_Product__c> getJunctionsByUniqueIdentifiers(Set<String> identifiers) {
        return [
            SELECT
                Id,
                d4c_License__c,
                d4c_InsuranceProduct__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_License_Insurance_Product__c
            WHERE
                d4c_UniqueIdentifier__c IN :identifiers
        ];
    }
}