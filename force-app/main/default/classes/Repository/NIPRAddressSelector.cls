/**
 *********************************************************
 * Apex Class Name    : ProducerAddressSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_ProducerAddress__c object
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
     * @description    : Returns list of d4c_ProducerAddress__c by d4c_NPN__C field of d4c_Entity__c object
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_ProducerAddress__c> - list of Producer Address records
     *******************************************************
     **/
    public List<d4c_ProducerAddress__c> getProducerAddressByProducerNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_Entity__r.d4c_NPN__c
            FROM
                d4c_ProducerAddress__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }
}