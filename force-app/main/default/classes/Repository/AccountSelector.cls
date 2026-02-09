/*
*********************************************************
Apex Class Name    : AccountSelector
Created Date       : 2025-04-25
@description       : Selector class for querying Account records
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-25   Stefan Nidzovic   Initial Version
*********************************************************
*/
public without sharing class AccountSelector {

    /*********************************************************
     @Method Name    : getAccountsByNPNs
     @description    : Returns list of Accounts by d4c_NPN__c field
     @author         : Stefan Nidzovic
     @param          : npns - Set of unique NPN values
     @return         : List<Account> - list of Account records
     *********************************************************
    **/
    public List<Account> getAccountsByNPNs(Set<String> npns) {
        return [
            SELECT 
                Id, 
                d4c_NPN__c
            FROM 
                Account
            WHERE 
                d4c_NPN__c IN :npns
        ];
    }
}