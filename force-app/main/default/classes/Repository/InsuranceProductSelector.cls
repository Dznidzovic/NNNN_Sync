/*
*********************************************************
Apex Class Name    : InsuranceProductSelector
Created Date       : 2025-12-15
@description       : Selector class for querying d4c_Insurance_Product__c records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
public with sharing class InsuranceProductSelector {

    /**
     ********************************************************
     * @Method Name    : getProductsByIds
     * @description    : Returns list of Insurance Products by Id
     * @param          : productIds - Set of Insurance Product IDs
     * @return         : List<d4c_Insurance_Product__c> - list of Insurance Product records
     *******************************************************
     **/
    public List<d4c_Insurance_Product__c> getProductsByIds(Set<Id> productIds) {
        return [
            SELECT
                Id,
                d4c_ProductName__c,
                d4c_StateOrProvince__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_Insurance_Product__c
            WHERE
                Id IN :productIds
        ];
    }
}