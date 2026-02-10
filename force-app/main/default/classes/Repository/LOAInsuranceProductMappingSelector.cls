/*
*********************************************************
Apex Class Name    : LOAInsuranceProductMappingSelector
Created Date       : 2025-12-15
@description       : Selector class for querying d4c_LOA_Insurance_Product_Mapping__c records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
public with sharing class LOAInsuranceProductMappingSelector {

    /**
     ********************************************************
     * @Method Name    : getMappingsByIds
     * @description    : Returns list of LOA Insurance Product Mappings by Id
     * @param          : mappingIds - Set of LOA Mapping IDs
     * @return         : List<d4c_LOA_Insurance_Product_Mapping__c> - list of LOA Mapping records
     *******************************************************
     **/
    public List<d4c_LOA_Insurance_Product_Mapping__c> getMappingsByIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id,
                d4c_StateOrProvinceCode__c,
                d4c_LineOfAuthorityCode__c,
                d4c_LineOfAuthorityDescription__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_LOA_Insurance_Product_Mapping__c
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
     * @return         : List<d4c_LOA_Insurance_Product_Mapping__c> - list of LOA Mapping records
     *******************************************************
     **/
    public List<d4c_LOA_Insurance_Product_Mapping__c> getMappingsByUniqueIdentifiers(Set<String> keys) {
        return [
            SELECT
                Id,
                d4c_StateOrProvinceCode__c,
                d4c_LineOfAuthorityCode__c,
                d4c_LineOfAuthorityDescription__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_LOA_Insurance_Product_Mapping__c
            WHERE
                d4c_UniqueIdentifier__c IN :keys
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getProductLOAJunctionsByLoaMappingIds
     * @description    : Returns list of Insurance Product LOA Mapping junction records by parent LOA Mapping IDs
     * @param          : mappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : List<d4c_Insurance_Product_LOA_Mapping__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_Insurance_Product_LOA_Mapping__c> getProductLOAJunctionsByLoaMappingIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id
            FROM
                d4c_Insurance_Product_LOA_Mapping__c
            WHERE
                d4c_LOAMapping__c IN :mappingIds
        ];
    }
}