/**
 *********************************************************
 * Apex Class Name    : NIPRAddressSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_NIPR_Address__c object
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
public with sharing class NIPRAddressSelector {
    /**
     ********************************************************
     * @Method Name    : getProducerAddressByEntityNPNs
     * @description    : Returns list of d4c_NIPR_Address__c by Entity NPN via junction records.
     *                   Addresses are now standalone objects - queried through junctions.
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_NIPR_Address__c> - list of Entity Address records
     *******************************************************
     **/
    public List<d4c_NIPR_Address__c> getProducerAddressByEntityNPNs(Set<String> npns) {
        // Query junctions to get addresses for these entities
        List<d4c_Entity_Address_Junction__c> junctions = [
            SELECT
                d4c_NIPR_Address__c,
                d4c_NIPR_Address__r.Id,
                d4c_NIPR_Address__r.d4c_UniqueIdentifier__c
            FROM
                d4c_Entity_Address_Junction__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];

        // Extract unique address IDs
        Set<Id> addressIds = new Set<Id>();
        for (d4c_Entity_Address_Junction__c junction : junctions) {
            if (junction.d4c_NIPR_Address__c != null) {
                addressIds.add(junction.d4c_NIPR_Address__c);
            }
        }

        // Query and return addresses
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c
            FROM
                d4c_NIPR_Address__c
            WHERE
                Id IN :addressIds
        ];
    }
}