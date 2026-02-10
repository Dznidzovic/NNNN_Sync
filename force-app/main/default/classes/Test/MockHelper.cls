/*
*********************************************************
Apex Class Name    : MockHelper
Created Date       : 2025-10-23
@description       : Helper class for creating mock data in tests without DML
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author                               Modification
1.0   2025-10-23   Dev4Clouds                     Initial Version
*********************************************************
*/
@isTest
public class MockHelper {

    private static Integer counter = 1;

    /*********************************************************
    @Method Name    : generateId
    @description    : Generates a fake Salesforce ID for testing
    @param          : sObjectType - The SObject type to generate ID for
    @return         : Id - A fake but valid Salesforce ID
    *********************************************************/
    public static Id generateId(Schema.SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe().getKeyPrefix();
        String fakeId = keyPrefix + '0'.repeat(12 - String.valueOf(counter).length()) + counter;
        counter++;
        return Id.valueOf(fakeId);
    }

    /*********************************************************
    @Method Name    : resetCounter
    @description    : Resets the ID counter for tests
    *********************************************************/
    public static void resetCounter() {
        counter = 1;
    }

    /*********************************************************
    @Method Name    : createMockAccount
    @description    : Creates a mock Account with optional Entity relationship
    @param          : name - Account name
    @param          : npn - NPN value
    @param          : producerId - Entity ID (optional)
    @return         : Account - Mock account with fields set
    *********************************************************/
    public static Account createMockAccount(String name, String npn, Id producerId) {
        Account acc = new Account();
        acc.Id = generateId(Account.SObjectType);
        acc.Name = name;
        acc.d4c_NPN__c = npn;
        acc.d4c_Entity__c = producerId;
        return acc;
    }

    /*********************************************************
    @Method Name    : createMockContact
    @description    : Creates a mock Contact with optional Entity relationship
    @param          : firstName - Contact first name
    @param          : lastName - Contact last name
    @param          : npn - NPN value
    @param          : producerId - Entity ID (optional)
    @return         : Contact - Mock contact with fields set
    *********************************************************/
    public static Contact createMockContact(String firstName, String lastName, String npn, Id producerId) {
        Contact con = new Contact();
        con.Id = generateId(Contact.SObjectType);
        con.FirstName = firstName;
        con.LastName = lastName;
        con.d4c_NPN__c = npn;
        con.d4c_Entity__c = producerId;
        return con;
    }

    /*********************************************************
    @Method Name    : createMockLead
    @description    : Creates a mock Lead with optional Entity relationship
    @param          : firstName - Lead first name
    @param          : lastName - Lead last name
    @param          : npn - NPN value
    @param          : producerId - Entity ID (optional)
    @return         : Lead - Mock lead with fields set
    *********************************************************/
    public static Lead createMockLead(String firstName, String lastName, String npn, Id producerId) {
        Lead ld = new Lead();
        ld.Id = generateId(Lead.SObjectType);
        ld.FirstName = firstName;
        ld.LastName = lastName;
        ld.Company = 'Test Company';
        ld.d4c_NPN__c = npn;
        ld.d4c_Entity__c = producerId;
        return ld;
    }

    /*********************************************************
    @Method Name    : createMockEntity
    @description    : Creates a mock Entity with NPN
    @param          : npn - NPN value
    @return         : d4c_Entity__c - Mock producer with fields set
    *********************************************************/
    public static d4c_Entity__c createMockEntity(String npn) {
        d4c_Entity__c prod = new d4c_Entity__c();
        prod.Id = generateId(d4c_Entity__c.SObjectType);
        prod.d4c_NPN__c = npn;
        // Name is an auto-number field, cannot be set directly
        return prod;
    }
}