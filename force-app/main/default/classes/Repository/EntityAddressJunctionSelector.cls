/**
 *********************************************************
 * Apex Class Name    : EntityAddressJunctionSelector
 * Created Date       : 02-10-2026
 * @description       : Selector class for d4c_Entity_Address_Junction__c queries
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   02-10-2026   Dev4Clouds          Initial Version
 *********************************************************
 **/
public with sharing class EntityAddressJunctionSelector {
    /**
     ********************************************************
     * @Method Name    : getJunctionsByEntityNPNs
     * @description    : Returns list of junction records by Entity NPN
     * @param          : npns - Set of Entity NPN values
     * @return         : List<d4c_Entity_Address_Junction__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_Entity_Address_Junction__c> getJunctionsByEntityNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__c,
                d4c_Entity__r.d4c_NPN__c,
                d4c_NIPR_Address__c,
                d4c_NIPR_Address__r.d4c_UniqueIdentifier__c
            FROM
                d4c_Entity_Address_Junction__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getJunctionsByEntityIds
     * @description    : Returns list of junction records by Entity IDs
     * @param          : entityIds - Set of Entity IDs
     * @return         : List<d4c_Entity_Address_Junction__c> - list of junction records
     *******************************************************
     **/
    public List<d4c_Entity_Address_Junction__c> getJunctionsByEntityIds(Set<Id> entityIds) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__c,
                d4c_NIPR_Address__c
            FROM
                d4c_Entity_Address_Junction__c
            WHERE
                d4c_Entity__c IN :entityIds
        ];
    }
}
