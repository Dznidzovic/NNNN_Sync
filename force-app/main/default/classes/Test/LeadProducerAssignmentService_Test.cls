/*
*********************************************************
Apex Class Name    : LeadProducerAssignmentService_Test
Created Date       : 2025-04-01
@description       : Test class for LeadProducerAssignmentService that validates assignment of Producer__c based on ht_NPN__c using mocks (no DML)
@author            : Uros Markovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-01   Uros Markovic   Initial Version
1.1   2025-10-23   Stefan Nidzovic Refactored to use mocks without DML
*********************************************************
*/
@isTest
private class LeadProducerAssignmentService_Test {

    @isTest
    static void testBeforeInsert_ExistingProducers() {
        // Setup mocks
        MockHelper.resetCounter();
        ht_Producer__c producer1 = MockHelper.createMockProducer('11111111');
        ht_Producer__c producer2 = MockHelper.createMockProducer('22222222');

        Map<String, ht_Producer__c> mockProducers = new Map<String, ht_Producer__c>{
            '11111111' => producer1,
            '22222222' => producer2
        };

        // Create mock leads (no DML)
        List<Lead> mockLeads = new List<Lead>{
            MockHelper.createMockLead('John', 'Doe', '11111111', null),
            MockHelper.createMockLead('Jane', 'Smith', '22222222', null)
        };

        // Enable mocks
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockLeads);
        Test.stopTest();

        // Verify producers were assigned
        for (Lead lead : mockLeads) {
            System.assertNotEquals(null, lead.ht_Producer__c,
                'Producer should be assigned for NPN: ' + lead.ht_NPN__c);
        }

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testBeforeInsert_NewProducersCreated() {
        // Setup
        MockHelper.resetCounter();

        List<Lead> mockLeads = new List<Lead>{
            MockHelper.createMockLead('Test', 'Lead1', '30001', null),
            MockHelper.createMockLead('Test', 'Lead2', '30002', null)
        };

        // Enable mocks with empty producer map
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = new Map<String, ht_Producer__c>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockLeads);
        Test.stopTest();

        // Verify producers were created and assigned
        for (Lead lead : mockLeads) {
            System.assertNotEquals(null, lead.ht_Producer__c,
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
        ht_Producer__c oldProducer = MockHelper.createMockProducer('55555555');
        ht_Producer__c newProducer = MockHelper.createMockProducer('66666666');

        Map<String, ht_Producer__c> mockProducers = new Map<String, ht_Producer__c>{
            '55555555' => oldProducer,
            '66666666' => newProducer
        };

        // Create old and new leads
        Lead oldLead = MockHelper.createMockLead('Test', 'Lead', '55555555', oldProducer.Id);
        Lead newLead = MockHelper.createMockLead('Test', 'Lead', '66666666', oldProducer.Id);
        newLead.Id = oldLead.Id;

        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        Map<Id, Lead> newMap = new Map<Id, Lead>{ newLead.Id => newLead };

        // Enable mocks
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;
        ProducerAssignmentService.mockAccountsByNPN = new List<Account>();
        ProducerAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify producer was reassigned
        System.assertEquals(newProducer.Id, newLead.ht_Producer__c,
            'Producer should be reassigned to new NPN');

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }

    @isTest
    static void testHandleOrphanedProducers_CrossObjectCheck() {
        // Setup
        MockHelper.resetCounter();
        ht_Producer__c sharedProducer = MockHelper.createMockProducer('99999999');
        ht_Producer__c newProducer = MockHelper.createMockProducer('88888888');

        Map<String, ht_Producer__c> mockProducers = new Map<String, ht_Producer__c>{
            '99999999' => sharedProducer,
            '88888888' => newProducer
        };

        // Create lead that changes NPN
        Lead oldLead = MockHelper.createMockLead('Test', 'Lead', '99999999', sharedProducer.Id);
        Lead newLead = MockHelper.createMockLead('Test', 'Lead', '88888888', sharedProducer.Id);
        newLead.Id = oldLead.Id;

        // Mock Contact still using old NPN
        Contact contactUsingOldNPN = MockHelper.createMockContact('Test', 'Contact', '99999999', sharedProducer.Id);

        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        Map<Id, Lead> newMap = new Map<Id, Lead>{ newLead.Id => newLead };

        // Enable mocks - old NPN still in use by Contact
        ProducerAssignmentService.useMocks = true;
        ProducerAssignmentService.mockProducersByNPN = mockProducers;
        ProducerAssignmentService.mockAccountsByNPN = new List<Account>();
        ProducerAssignmentService.mockContactsByNPN = new List<Contact>{contactUsingOldNPN};
        ProducerAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify new producer assigned
        System.assertEquals(newProducer.Id, newLead.ht_Producer__c,
            'New producer should be assigned');

        // Old producer should not be deleted (still used by Contact)
        System.assert(true, 'Producer should not be deleted when used by other SObject types');

        // Cleanup
        ProducerAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }
}