/**
 *********************************************************
 * Apex Class Name    : EntityAddressSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_EntityAddress__c object
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
public with sharing class EntityAddressSelector {
    /**
     ********************************************************
     * @Method Name    : getEntityAddressByEntityNPNs
     * @description    : Returns list of d4c_EntityAddress__c by d4c_NPN__C field of d4c_Entity__c object
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_EntityAddress__c> - list of Entity Address records
     *******************************************************
     **/
    public List<d4c_EntityAddress__c> getEntityAddressByEntityNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__r.d4c_NPN__c
            FROM
                d4c_EntityAddress__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }
}