/*
*********************************************************
Apex Class Name    : LineOfAuthoritySelector
Created Date       : 2025-04-09
@description       : Selector class for querying ht_LineOfAuthority__c records
@author            : Uros Markovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-04-09   Uros Markovic  Initial Version
*********************************************************
*/
public virtual class LineOfAuthoritySelector {
    /**
     ********************************************************
     * @Method Name    : getLOAByLicenseNumber
     * @description    : Returns list of ht_LineOfAuthority__c by ht_UniqueIdentifier__c field of ht_License__c object
     * @param          : licenseUniqueIdentifiers - Set of unique license identifiers values
     * @return         : List<ht_LineOfAuthority__c> - list of LOA records
     *******************************************************
     **/
    public List<ht_LineOfAuthority__c> getLOAByUniqueIdentifier(Set<String> licenseUniqueIdentifiers) {
        return [
            SELECT
                Id,
                ht_UniqueIdentifier__c,
                ht_License__r.ht_LicenseNumber__c,
                ht_License__r.ht_UniqueIdentifier__c
            FROM
                ht_LineOfAuthority__c
            WHERE
                ht_License__r.ht_UniqueIdentifier__c IN :licenseUniqueIdentifiers
        ];
    }

    /*********************************************************
    @Method Name    : getOrphanLoasByStateCodeDesc
    @description    : Retrieves "orphan" LOA records where ht_LOAMapping__c is null
                      and matching state/code/description values exist
    @author         : Stefan Nidzovic
    @param          : states - Set of state/province codes
    @param          : codes - Set of LOA codes
    @param          : descriptions - Set of LOA descriptions
    @return         : List<ht_LineOfAuthority__c> - List of orphan LOA records
    *********************************************************/
    public List<ht_LineOfAuthority__c> getOrphanLoasByStateCodeDesc(
        Set<String> states,
        Set<String> codes,
        Set<String> descriptions
    ) {
        return [
            SELECT
                Id,
                ht_StateOrProvinceCode__c,
                ht_LineOfAuthorityCode__c,
                ht_LineOfAuthorityDescription__c,
                ht_LOAMapping__c,
                ht_UniqueIdentifier__c
            FROM
                ht_LineOfAuthority__c
            WHERE
                ht_LOAMapping__c = null
                AND ht_StateOrProvinceCode__c IN :states
                AND ht_LineOfAuthorityCode__c IN :codes
                AND ht_LineOfAuthorityDescription__c IN :descriptions
        ];
    }

    /*********************************************************
    @Method Name    : getLoasByMappingIds
    @description    : Retrieves LOA records linked to specific LOA Insurance Product Mapping IDs
    @author         : Stefan Nidzovic
    @param          : mappingIds - Set of ht_LOA_Insurance_Product_Mapping__c IDs
    @return         : List<ht_LineOfAuthority__c> - List of LOA records
    *********************************************************/
    public List<ht_LineOfAuthority__c> getLoasByMappingIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id,
                ht_LOAMapping__c,
                ht_License__c
            FROM
                ht_LineOfAuthority__c
            WHERE
                ht_LOAMapping__c IN :mappingIds
        ];
    }
}