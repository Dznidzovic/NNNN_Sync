/*
*********************************************************
Apex Class Name    : ContactSelector
Created Date       : 2025-04-25
@description       : Selector class for querying Contact records
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-25   Dev4Clouds   Initial Version
*********************************************************
*/
public without sharing class ContactSelector {

    /*********************************************************
     @Method Name    : getContactsByNPNs
     @description    : Returns list of Contacts by d4c_NPN__c field
     @author         : Dev4Clouds
     @param          : npns - Set of unique NPN values
     @return         : List<Contact> - list of Contact records
     *********************************************************
    **/
    public List<Contact> getContactsByNPNs(Set<String> npns) {
        return [
            SELECT 
                Id, 
                d4c_NPN__c
            FROM 
                Contact
            WHERE 
                d4c_NPN__c IN :npns
        ];
    }
}