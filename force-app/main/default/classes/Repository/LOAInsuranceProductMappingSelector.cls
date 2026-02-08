/*
*********************************************************
Apex Class Name    : LOAInsuranceProductMappingSelector
Created Date       : 2025-12-15
@description       : Selector class for querying ht_LOA_Insurance_Product_Mapping__c records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
public with sharing class LOAInsuranceProductMappingSelector {

    /**
     ********************************************************
     * @Method Name    : getMappingsByIds
     * @description    : Returns list of LOA Insurance Product Mappings by Id
     * @param          : mappingIds - Set of LOA Mapping IDs
     * @return         : List<ht_LOA_Insurance_Product_Mapping__c> - list of LOA Mapping records
     *******************************************************
     **/
    public List<ht_LOA_Insurance_Product_Mapping__c> getMappingsByIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id,
                ht_StateOrProvinceCode__c,
                ht_LineOfAuthorityCode__c,
                ht_LineOfAuthorityDescription__c,
                ht_UniqueIdentifier__c
            FROM
                ht_LOA_Insurance_Product_Mapping__c
            WHERE
                Id IN :mappingIds
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getMappingsByUniqueIdentifiers
     * @description    : Returns list of LOA Mappings by UniqueIdentifier (External ID)
     *                   UniqueIdentifier format: State-Code-Description
     * @param          : keys - Set of unique identifier values
     * @return         : List<ht_LOA_Insurance_Product_Mapping__c> - list of LOA Mapping records
     *******************************************************
     **/
    public List<ht_LOA_Insurance_Product_Mapping__c> getMappingsByUniqueIdentifiers(Set<String> keys) {
        return [
            SELECT
                Id,
                ht_StateOrProvinceCode__c,
                ht_LineOfAuthorityCode__c,
                ht_LineOfAuthorityDescription__c,
                ht_UniqueIdentifier__c
            FROM
                ht_LOA_Insurance_Product_Mapping__c
            WHERE
                ht_UniqueIdentifier__c IN :keys
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getProductLOAJunctionsByLoaMappingIds
     * @description    : Returns list of Insurance Product LOA Mapping junction records by parent LOA Mapping IDs
     * @param          : mappingIds - Set of ht_LOA_Insurance_Product_Mapping__c IDs
     * @return         : List<ht_Insurance_Product_LOA_Mapping__c> - list of junction records
     *******************************************************
     **/
    public List<ht_Insurance_Product_LOA_Mapping__c> getProductLOAJunctionsByLoaMappingIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id
            FROM
                ht_Insurance_Product_LOA_Mapping__c
            WHERE
                ht_LOAMapping__c IN :mappingIds
        ];
    }
}