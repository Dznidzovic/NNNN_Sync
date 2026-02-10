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

}