/*
*********************************************************
Apex Class Name    : InsuranceProductSelector
Created Date       : 2025-12-15
@description       : Selector class for querying ht_Insurance_Product__c records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
public with sharing class InsuranceProductSelector {

    /**
     ********************************************************
     * @Method Name    : getProductsByIds
     * @description    : Returns list of Insurance Products by Id
     * @param          : productIds - Set of Insurance Product IDs
     * @return         : List<ht_Insurance_Product__c> - list of Insurance Product records
     *******************************************************
     **/
    public List<ht_Insurance_Product__c> getProductsByIds(Set<Id> productIds) {
        return [
            SELECT
                Id,
                ht_ProductName__c,
                ht_StateOrProvince__c,
                ht_UniqueIdentifier__c
            FROM
                ht_Insurance_Product__c
            WHERE
                Id IN :productIds
        ];
    }
}