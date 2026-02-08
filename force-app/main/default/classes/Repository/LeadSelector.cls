/*
*********************************************************
Apex Class Name    : LeadSelector
Created Date       : 2025-04-25
@description       : Selector class for querying Lead records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-25   Stefan Nidzovic   Initial Version
*********************************************************
*/
public without sharing class LeadSelector {

    /*********************************************************
     @Method Name    : getLeadsByNPNs
     @description    : Returns list of Leads by ht_NPN__c field
     @author         : Stefan Nidzovic
     @param          : npns - Set of unique NPN values
     @return         : List<Lead> - list of Lead records
     *********************************************************
    **/
    public List<Lead> getLeadsByNPNs(Set<String> npns) {
        return [
            SELECT 
                Id, 
                ht_NPN__c
            FROM 
                Lead
            WHERE 
                ht_NPN__c IN :npns
        ];
    }
}