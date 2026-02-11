/*
*********************************************************
Apex Class Name    : EntityAddressJunctionSelector
Created Date       : 2026-02-11
@description       : Selector class for querying d4c_Entity_Address_Junction__c records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2026-02-11   Dev4Clouds   Initial Version - Created for junction model refactoring
*********************************************************
*/
public with sharing class EntityAddressJunctionSelector {

    /*********************************************************
     @Method Name    : getJunctionsByEntityNPNs
     @description    : Returns list of junction records with related Entity and Address data
     @author         : Dev4Clouds
     @param          : entityNpns - Set of Entity NPN values
     @return         : List<d4c_Entity_Address_Junction__c> - list of junction records
     *********************************************************
    **/
    public List<d4c_Entity_Address_Junction__c> getJunctionsByEntityNPNs(Set<String> entityNpns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__c,
                d4c_Entity__r.d4c_NPN__c,
                d4c_NIPR_Address__c,
                d4c_NIPR_Address__r.Id,
                d4c_NIPR_Address__r.d4c_UniqueIdentifier__c,
                d4c_NIPR_Address__r.d4c_AddressType__c,
                d4c_NIPR_Address__r.d4c_AddressLineOne__c,
                d4c_NIPR_Address__r.d4c_AddressLineTwo__c,
                d4c_NIPR_Address__r.d4c_City__c,
                d4c_NIPR_Address__r.d4c_PostalCode__c,
                d4c_NIPR_Address__r.d4c_CountryCode__c,
                d4c_NIPR_Address__r.d4c_State__c
            FROM
                d4c_Entity_Address_Junction__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :entityNpns
        ];
    }
}
