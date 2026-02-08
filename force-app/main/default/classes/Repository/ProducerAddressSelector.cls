/**
 *********************************************************
 * Apex Class Name    : ProducerAddressSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for ht_ProducerAddress__c object
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class ProducerAddressSelector {
    /**
     ********************************************************
     * @Method Name    : getProducerAddressByProducerNPNs
     * @description    : Returns list of ht_ProducerAddress__c by ht_NPN__C field of ht_Producer__c object
     * @param          : npns - Set of unique NPN values
     * @return         : List<ht_ProducerAddress__c> - list of Producer Address records
     *******************************************************
     **/
    public List<ht_ProducerAddress__c> getProducerAddressByProducerNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                ht_UniqueIdentifier__c,
                ht_Producer__r.ht_NPN__c
            FROM
                ht_ProducerAddress__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
        ];
    }
}