/*
*********************************************************
Apex Class Name    : ProducerSelector
Created Date       : 2025-03-28
@description       : Selector class for querying d4c_Entity__c records
@author            : Uros Markovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-03-28   Uros Markovic   Initial Version
1.1   2025-03-31   Uros Markovic   Modified to return List instead of Map, remove business logic from selector
1.2   2025-10-24   Stefan Nidzovic Added d4c_ExcludeCarrierAppointments__c field to queries
*********************************************************
*/
public with sharing class ProducerSelector {

    /*********************************************************
     @Method Name    : getProducersByNPNs
     @description    : Returns list of d4c_Entity__c by d4c_NPN__c field
     @author         : Uros Markovic
     @param          : npns - Set of unique NPN values
     @return         : List<d4c_Entity__c> - list of Producer records
     *********************************************************
    **/
    public List<d4c_Entity__c> getProducersByNPNs(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_NPN__c,
                d4c_NPNStatus__c,
                d4c_Subscription__c,
                d4c_ExcludeCarrierAppointments__c
            FROM 
                d4c_Entity__c
            WHERE 
                d4c_NPN__c IN :npns
        ];
    }
}