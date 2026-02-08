/**
 *********************************************************
 * Apex Class Name    : ProducerCommunicationSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for ht_ProducerCommunication__c object
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
     * @description    : Returns list of ht_ProducerCommunication__c by ht_NPN__C field of ht_Producer__c object
     * @param          : npns - Set of unique NPN values
     * @return         : List<ht_ProducerCommunication__c> - list of Producer Communication records
     *******************************************************
     **/
    public List<ht_ProducerCommunication__c> getProducerCommsByProducerNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                ht_UniqueIdentifier__c,
                ht_PhoneType__c,
                ht_PhoneNumber__c,
                ht_EmailType__c,
                ht_EmailAddress__c,
                ht_Producer__r.ht_NPN__c
            FROM
                ht_ProducerCommunication__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
        ];
    }
}