/*
*********************************************************
Apex Class Name    : LineOfAuthoritySelector
Created Date       : 2025-04-09
@description       : Selector class for querying d4c_LineOfAuthority__c records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-04-09   Dev4Clouds  Initial Version
*********************************************************
*/
public virtual class LineOfAuthoritySelector {
    /**
     ********************************************************
     * @Method Name    : getLOAByLicenseNumber
     * @description    : Returns list of d4c_LineOfAuthority__c by d4c_UniqueIdentifier__c field of d4c_License__c object
     * @param          : licenseUniqueIdentifiers - Set of unique license identifiers values
     * @return         : List<d4c_LineOfAuthority__c> - list of LOA records
     *******************************************************
     **/
    public List<d4c_LineOfAuthority__c> getLOAByUniqueIdentifier(Set<String> licenseUniqueIdentifiers) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_License__r.d4c_LicenseNumber__c,
                d4c_License__r.d4c_UniqueIdentifier__c
            FROM
                d4c_LineOfAuthority__c
            WHERE
                d4c_License__r.d4c_UniqueIdentifier__c IN :licenseUniqueIdentifiers
        ];
    }

    /*********************************************************
    @Method Name    : getOrphanLoasByStateCodeDesc
    @description    : Retrieves "orphan" LOA records where d4c_LOAMapping__c is null
                      and matching state/code/description values exist
    @author         : Dev4Clouds
    @param          : states - Set of state/province codes
    @param          : codes - Set of LOA codes
    @param          : descriptions - Set of LOA descriptions
    @return         : List<d4c_LineOfAuthority__c> - List of orphan LOA records
    *********************************************************/
    public List<d4c_LineOfAuthority__c> getOrphanLoasByStateCodeDesc(
        Set<String> states,
        Set<String> codes,
        Set<String> descriptions
    ) {
        return [
            SELECT
                Id,
                d4c_StateOrProvinceCode__c,
                d4c_LineOfAuthorityCode__c,
                d4c_LineOfAuthorityDescription__c,
                d4c_LOAMapping__c,
                d4c_UniqueIdentifier__c
            FROM
                d4c_LineOfAuthority__c
            WHERE
                d4c_LOAMapping__c = null
                AND d4c_StateOrProvinceCode__c IN :states
                AND d4c_LineOfAuthorityCode__c IN :codes
                AND d4c_LineOfAuthorityDescription__c IN :descriptions
        ];
    }

    /*********************************************************
    @Method Name    : getLoasByMappingIds
    @description    : Retrieves LOA records linked to specific LOA Insurance Product Mapping IDs
    @author         : Dev4Clouds
    @param          : mappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
    @return         : List<d4c_LineOfAuthority__c> - List of LOA records
    *********************************************************/
    public List<d4c_LineOfAuthority__c> getLoasByMappingIds(Set<Id> mappingIds) {
        return [
            SELECT
                Id,
                d4c_LOAMapping__c,
                d4c_License__c
            FROM
                d4c_LineOfAuthority__c
            WHERE
                d4c_LOAMapping__c IN :mappingIds
        ];
    }
}