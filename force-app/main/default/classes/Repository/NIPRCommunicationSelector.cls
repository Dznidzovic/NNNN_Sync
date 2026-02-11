/**
 *********************************************************
 * Apex Class Name    : NIPRCommunicationSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_NIPR_Communication__c object
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
public with sharing class NIPRCommunicationSelector {
    /**
     ********************************************************
     * @Method Name    : getEntityCommsByEntityNPNs
     * @description    : Returns list of d4c_NIPR_Communication__c by Entity NPN via junction records.
     *                   Communications are now standalone objects - queried through junctions.
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_NIPR_Communication__c> - list of Entity Communication records
     *******************************************************
     **/
    public List<d4c_NIPR_Communication__c> getEntityCommsByEntityNPNs(Set<String> npns) {
        // Query junctions to get communications for these entities
        List<d4c_Entity_Communication_Junction__c> junctions = [
            SELECT
                d4c_NIPR_Communication__c,
                d4c_NIPR_Communication__r.Id,
                d4c_NIPR_Communication__r.d4c_UniqueIdentifier__c
            FROM
                d4c_Entity_Communication_Junction__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];

        // Extract unique communication IDs
        Set<Id> communicationIds = new Set<Id>();
        for (d4c_Entity_Communication_Junction__c junction : junctions) {
            if (junction.d4c_NIPR_Communication__c != null) {
                communicationIds.add(junction.d4c_NIPR_Communication__c);
            }
        }

        // Query and return communications
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_PhoneType__c,
                d4c_PhoneNumber__c,
                d4c_EmailType__c,
                d4c_EmailAddress__c
            FROM
                d4c_NIPR_Communication__c
            WHERE
                Id IN :communicationIds
        ];
    }
}