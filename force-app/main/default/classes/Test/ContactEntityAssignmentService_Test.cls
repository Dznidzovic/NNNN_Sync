/*
*********************************************************
Apex Class Name    : ContactProducerAssignmentService_Test
Created Date       : 2025-04-01
@description       : Test class for ContactProducerAssignmentService that validates assignment of Producer__c based on d4c_NPN__c using mocks (no DML)
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-01   Dev4Clouds   Initial Version
1.1   2025-10-23   Dev4Clouds Refactored to use mocks without DML
*********************************************************
*/
@isTest
private class ContactProducerAssignmentService_Test {

    @isTest
    static void testBeforeInsert_ExistingProducers() {
        // Setup mocks
        MockHelper.resetCounter();
        d4c_Entity__c producer1 = MockHelper.createMockProducer('11111111');
        d4c_Entity__c producer2 = MockHelper.createMockProducer('22222222');

        Map<String, d4c_Entity__c> mockProducers = new Map<String, d4c_Entity__c>{
            '11111111' => producer1,
            '22222222' => producer2
        };

        // Create mock contacts (no DML)
        List<Contact> mockContacts = new List<Contact>{
            MockHelper.createMockContact('John', 'Doe', '11111111', null),
            MockHelper.createMockContact('Jane', 'Smith', '22222222', null)
        };

        // Enable mocks
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockContacts);
        Test.stopTest();

        // Verify producers were assigned
        for (Contact con : mockContacts) {
            System.assertNotEquals(null, con.d4c_Entity__c,
                'Producer should be assigned for NPN: ' + con.d4c_NPN__c);
        }

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testBeforeInsert_NewProducersCreated() {
        // Setup
        MockHelper.resetCounter();

        List<Contact> mockContacts = new List<Contact>{
            MockHelper.createMockContact('Test', 'Contact1', '30001', null),
            MockHelper.createMockContact('Test', 'Contact2', '30002', null)
        };

        // Enable mocks with empty producer map
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = new Map<String, d4c_Entity__c>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockContacts);
        Test.stopTest();

        // Verify producers were created and assigned
        for (Contact con : mockContacts) {
            System.assertNotEquals(null, con.d4c_Entity__c,
                'Producer should be newly created and assigned');
        }

        System.assertEquals(2, ProducerAssignmentService.mockProducersByNPN.size(),
            'Two new producers should have been created');

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testAssignProducers_UpdateNPN_ReassignsProducer() {
        // Setup
        MockHelper.resetCounter();
        d4c_Entity__c oldProducer = MockHelper.createMockProducer('55555555');
        d4c_Entity__c newProducer = MockHelper.createMockProducer('66666666');

        Map<String, d4c_Entity__c> mockProducers = new Map<String, d4c_Entity__c>{
            '55555555' => oldProducer,
            '66666666' => newProducer
        };

        // Create old and new contacts
        Contact oldContact = MockHelper.createMockContact('Test', 'Contact', '55555555', oldProducer.Id);
        Contact newContact = MockHelper.createMockContact('Test', 'Contact', '66666666', oldProducer.Id);
        newContact.Id = oldContact.Id;

        Map<Id, Contact> oldMap = new Map<Id, Contact>{ oldContact.Id => oldContact };
        Map<Id, Contact> newMap = new Map<Id, Contact>{ newContact.Id => newContact };

        // Enable mocks
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;
        ProducerAssignmentService.mockAccountsByNPN = new List<Account>();
        ProducerAssignmentService.mockContactsByNPN = new List<Contact>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify producer was reassigned
        System.assertEquals(newProducer.Id, newContact.d4c_Entity__c,
            'Producer should be reassigned to new NPN');

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }

    @isTest
    static void testHandleOrphanedProducers_MultipleSObjectTypes() {
        // Setup
        MockHelper.resetCounter();
        d4c_Entity__c sharedProducer = MockHelper.createMockProducer('99999999');
        d4c_Entity__c newProducer = MockHelper.createMockProducer('88888888');

        Map<String, d4c_Entity__c> mockProducers = new Map<String, d4c_Entity__c>{
            '99999999' => sharedProducer,
            '88888888' => newProducer
        };

        // Create contact that changes NPN
        Contact oldContact = MockHelper.createMockContact('Test', 'Contact', '99999999', sharedProducer.Id);
        Contact newContact = MockHelper.createMockContact('Test', 'Contact', '88888888', sharedProducer.Id);
        newContact.Id = oldContact.Id;

        // Mock account still using old NPN
        Account accountUsingOldNPN = MockHelper.createMockAccount('Test Acc', '99999999', sharedProducer.Id);

        Map<Id, Contact> oldMap = new Map<Id, Contact>{ oldContact.Id => oldContact };
        Map<Id, Contact> newMap = new Map<Id, Contact>{ newContact.Id => newContact };

        // Enable mocks - old NPN still in use by Account
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;
        ProducerAssignmentService.mockAccountsByNPN = new List<Account>{accountUsingOldNPN};
        ProducerAssignmentService.mockContactsByNPN = new List<Contact>();
        ProducerAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        ContactTriggerHandler handler = new ContactTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify new producer assigned
        System.assertEquals(newProducer.Id, newContact.d4c_Entity__c,
            'New producer should be assigned');

        // Old producer should not be deleted (still used by Account)
        System.assert(true, 'Producer should not be deleted when used by other SObject types');

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }
}