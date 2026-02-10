/*
*********************************************************
Apex Class Name    : LeadSelector
Created Date       : 2025-04-25
@description       : Selector class for querying Lead records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-25   Dev4Clouds   Initial Version
*********************************************************
*/
public without sharing class LeadSelector {

    /*********************************************************
     @Method Name    : getLeadsByNPNs
     @description    : Returns list of Leads by d4c_NPN__c field
     @author         : Dev4Clouds
     @param          : npns - Set of unique NPN values
     @return         : List<Lead> - list of Lead records
     *********************************************************
    **/
    public List<Lead> getLeadsByNPNs(Set<String> npns) {
        return [
            SELECT 
                Id, 
                d4c_NPN__c
            FROM 
                Lead
            WHERE 
                d4c_NPN__c IN :npns
        ];
    }
}