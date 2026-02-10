/*
*********************************************************
Apex Class Name    : EntitySelector
Created Date       : 2025-03-28
@description       : Selector class for querying d4c_Entity__c records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-03-28   Dev4Clouds   Initial Version
1.1   2025-03-31   Dev4Clouds   Modified to return List instead of Map, remove business logic from selector
1.2   2025-10-24   Dev4Clouds Added d4c_ExcludeCarrierAppointments__c field to queries
*********************************************************
*/
public with sharing class EntitySelector {

    /*********************************************************
     @Method Name    : getEntitiesByNPNs
     @description    : Returns list of d4c_Entity__c by d4c_NPN__c field
     @author         : Dev4Clouds
     @param          : npns - Set of unique NPN values
     @return         : List<d4c_Entity__c> - list of Entity records
     *********************************************************
    **/
    public List<d4c_Entity__c> getEntitiesByNPNs(Set<String> npns) {
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