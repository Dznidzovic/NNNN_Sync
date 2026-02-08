/*
*********************************************************
Apex Class Name    : ContactSelector
Created Date       : 2025-04-25
@description       : Selector class for querying Contact records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-25   Stefan Nidzovic   Initial Version
*********************************************************
*/
public without sharing class ContactSelector {

    /*********************************************************
     @Method Name    : getContactsByNPNs
     @description    : Returns list of Contacts by ht_NPN__c field
     @author         : Stefan Nidzovic
     @param          : npns - Set of unique NPN values
     @return         : List<Contact> - list of Contact records
     *********************************************************
    **/
    public List<Contact> getContactsByNPNs(Set<String> npns) {
        return [
            SELECT 
                Id, 
                ht_NPN__c
            FROM 
                Contact
            WHERE 
                ht_NPN__c IN :npns
        ];
    }
}