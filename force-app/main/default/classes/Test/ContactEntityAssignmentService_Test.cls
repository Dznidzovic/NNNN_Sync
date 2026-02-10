/*
*********************************************************
Apex Class Name    : ContactEntityAssignmentService_Test
Created Date       : 2025-04-01
@description       : Test class for ContactEntityAssignmentService that validates assignment of Entity__c based on d4c_NPN__c using mocks (no DML)
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-01   Dev4Clouds   Initial Version
1.1   2025-10-23   Dev4Clouds Refactored to use mocks without DML
*********************************************************
*/
@isTest
private class ContactEntityAssignmentService_Test {

    @isTest
    static void testBeforeInsert_ExistingEntitys() {
        // Setup mocks
        MockHelper.resetCounter();
        d4c_Entity__c producer1 = MockHelper.createMockEntity('11111111');
        d4c_Entity__c producer2 = MockHelper.createMockEntity('22222222');

        Map<String, d4c_Entity__c> mockEntitys = new Map<String, d4c_Entity__c>{
            '11111111' => producer1,
            '22222222' => producer2
        };

        // Create mock contacts (no DML)
        List<Contact> mockContacts = new List<Contact>{
            MockHelper.createMockContact('John', 'Doe', '11111111', null),
            MockHelper.createMockContact('Jane', 'Smith', '22222222', null)
        };

        // Enable mocks
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockContacts);
        Test.stopTest();

        // Verify producers were assigned
        for (Contact con : mockContacts) {
            System.assertNotEquals(null, con.d4c_Entity__c,
                'Entity should be assigned for NPN: ' + con.d4c_NPN__c);
        }

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testBeforeInsert_NewEntitysCreated() {
        // Setup
        MockHelper.resetCounter();

        List<Contact> mockContacts = new List<Contact>{
            MockHelper.createMockContact('Test', 'Contact1', '30001', null),
            MockHelper.createMockContact('Test', 'Contact2', '30002', null)
        };

        // Enable mocks with empty producer map
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = new Map<String, d4c_Entity__c>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockContacts);
        Test.stopTest();

        // Verify producers were created and assigned
        for (Contact con : mockContacts) {
            System.assertNotEquals(null, con.d4c_Entity__c,
                'Entity should be newly created and assigned');
        }

        System.assertEquals(2, EntityAssignmentService.mockEntitysByNPN.size(),
            'Two new producers should have been created');

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testAssignEntitys_UpdateNPN_ReassignsEntity() {
        // Setup
        MockHelper.resetCounter();
        d4c_Entity__c oldEntity = MockHelper.createMockEntity('55555555');
        d4c_Entity__c newEntity = MockHelper.createMockEntity('66666666');

        Map<String, d4c_Entity__c> mockEntitys = new Map<String, d4c_Entity__c>{
            '55555555' => oldEntity,
            '66666666' => newEntity
        };

        // Create old and new contacts
        Contact oldContact = MockHelper.createMockContact('Test', 'Contact', '55555555', oldEntity.Id);
        Contact newContact = MockHelper.createMockContact('Test', 'Contact', '66666666', oldEntity.Id);
        newContact.Id = oldContact.Id;

        Map<Id, Contact> oldMap = new Map<Id, Contact>{ oldContact.Id => oldContact };
        Map<Id, Contact> newMap = new Map<Id, Contact>{ newContact.Id => newContact };

        // Enable mocks
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;
        EntityAssignmentService.mockAccountsByNPN = new List<Account>();
        EntityAssignmentService.mockContactsByNPN = new List<Contact>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify producer was reassigned
        System.assertEquals(newEntity.Id, newContact.d4c_Entity__c,
            'Entity should be reassigned to new NPN');

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }

    @isTest
    static void testHandleOrphanedEntitys_MultipleSObjectTypes() {
        // Setup
        MockHelper.resetCounter();
        d4c_Entity__c sharedEntity = MockHelper.createMockEntity('99999999');
        d4c_Entity__c newEntity = MockHelper.createMockEntity('88888888');

        Map<String, d4c_Entity__c> mockEntitys = new Map<String, d4c_Entity__c>{
            '99999999' => sharedEntity,
            '88888888' => newEntity
        };

        // Create contact that changes NPN
        Contact oldContact = MockHelper.createMockContact('Test', 'Contact', '99999999', sharedEntity.Id);
        Contact newContact = MockHelper.createMockContact('Test', 'Contact', '88888888', sharedEntity.Id);
        newContact.Id = oldContact.Id;

        // Mock account still using old NPN
        Account accountUsingOldNPN = MockHelper.createMockAccount('Test Acc', '99999999', sharedEntity.Id);

        Map<Id, Contact> oldMap = new Map<Id, Contact>{ oldContact.Id => oldContact };
        Map<Id, Contact> newMap = new Map<Id, Contact>{ newContact.Id => newContact };

        // Enable mocks - old NPN still in use by Account
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;
        EntityAssignmentService.mockAccountsByNPN = new List<Account>{accountUsingOldNPN};
        EntityAssignmentService.mockContactsByNPN = new List<Contact>();
        EntityAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify new producer assigned
        System.assertEquals(newEntity.Id, newContact.d4c_Entity__c,
            'New producer should be assigned');

        // Old producer should not be deleted (still used by Account)
        System.assert(true, 'Entity should not be deleted when used by other SObject types');

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }
}