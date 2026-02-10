/*
*********************************************************
Apex Class Name    : InsuranceProductLOAMappingSelector
Created Date       : 2025-12-15
@description       : Selector class for querying d4c_Insurance_Product_LOA_Mapping__c junction records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
public with sharing class InsuranceProductLOAMappingSelector {

    /**
     ********************************************************
     * @Method Name    : getJunctionsByLoaMappingIds
     * @description    : Returns list of junctions by parent LOA Mapping IDs
     * @param          : loaMappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : List<d4c_Insurance_Product_LOA_Mapping__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_Insurance_Product_LOA_Mapping__c> getJunctionsByLoaMappingIds(Set<Id> loaMappingIds) {
        return [
            SELECT
                Id,
                d4c_LOAMapping__c,
                d4c_InsuranceProduct__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_Insurance_Product_LOA_Mapping__c
            WHERE
                d4c_LOAMapping__c IN :loaMappingIds
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getJunctionsByInsuranceProductIds
     * @description    : Returns list of junctions by Insurance Product IDs
     * @param          : productIds - Set of d4c_Insurance_Product__c IDs
     * @return         : List<d4c_Insurance_Product_LOA_Mapping__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_Insurance_Product_LOA_Mapping__c> getJunctionsByInsuranceProductIds(Set<Id> productIds) {
        return [
            SELECT
                Id,
                d4c_LOAMapping__c,
                d4c_InsuranceProduct__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_Insurance_Product_LOA_Mapping__c
            WHERE
                d4c_InsuranceProduct__c IN :productIds
        ];
    }

    /**
     ********************************************************
     * @Method Name    : countJunctionsByLoaMappingIds
     * @description    : Returns count of junctions per LOA Mapping ID
     * @param          : loaMappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : Map<Id, Integer> - map of LOA Mapping ID to junction count
     *******************************************************
     **/
    public Map<Id, Integer> countJunctionsByLoaMappingIds(Set<Id> loaMappingIds) {
        Map<Id, Integer> countMap = new Map<Id, Integer>();

        // Initialize all to 0
        for (Id loaMappingId : loaMappingIds) {
            countMap.put(loaMappingId, 0);
        }

        // Count remaining junctions
        List<AggregateResult> results = [
            SELECT
                d4c_LOAMapping__c loaMappingId,
                COUNT(Id) junctionCount
            FROM
                d4c_Insurance_Product_LOA_Mapping__c
            WHERE
                d4c_LOAMapping__c IN :loaMappingIds
            GROUP BY
                d4c_LOAMapping__c
        ];

        for (AggregateResult ar : results) {
            Id loaMappingId = (Id) ar.get('loaMappingId');
            Integer count = (Integer) ar.get('junctionCount');
            countMap.put(loaMappingId, count);
        }

        return countMap;
    }
}