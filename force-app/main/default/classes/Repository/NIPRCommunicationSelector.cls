/**
 *********************************************************
 * Apex Class Name    : ProducerCommunicationSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_ProducerCommunication__c object
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class ProducerCommunicationSelector {
    /**
     ********************************************************
     * @Method Name    : getProducerCommsByProducerNPNs
     * @description    : Returns list of d4c_ProducerCommunication__c by d4c_NPN__C field of d4c_Entity__c object
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_ProducerCommunication__c> - list of Producer Communication records
     *******************************************************
     **/
    public List<d4c_ProducerCommunication__c> getProducerCommsByProducerNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_PhoneType__c,
                d4c_PhoneNumber__c,
                d4c_EmailType__c,
                d4c_EmailAddress__c,
                d4c_Entity__r.d4c_NPN__c
            FROM
                d4c_ProducerCommunication__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }
}