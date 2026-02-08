/*
*********************************************************
Apex Class Name    : ProducerSelector
Created Date       : 2025-03-28
@description       : Selector class for querying ht_Producer__c records
@author            : Uros Markovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-03-28   Uros Markovic   Initial Version
1.1   2025-03-31   Uros Markovic   Modified to return List instead of Map, remove business logic from selector
1.2   2025-10-24   Stefan Nidzovic Added ht_ExcludeCarrierAppointments__c field to queries
*********************************************************
*/
public with sharing class ProducerSelector {

    /*********************************************************
     @Method Name    : getProducersByNPNs
     @description    : Returns list of ht_Producer__c by ht_NPN__c field
     @author         : Uros Markovic
     @param          : npns - Set of unique NPN values
     @return         : List<ht_Producer__c> - list of Producer records
     *********************************************************
    **/
    public List<ht_Producer__c> getProducersByNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                ht_NPN__c,
                ht_NPNStatus__c,
                ht_Subscription__c,
                ht_ExcludeCarrierAppointments__c
            FROM 
                ht_Producer__c
            WHERE 
                ht_NPN__c IN :npns
        ];
    }
}