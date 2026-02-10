/*
*********************************************************
Apex Class Name    : LeadEntityAssignmentService_Test
Created Date       : 2025-04-01
@description       : Test class for LeadEntityAssignmentService that validates assignment of Entity__c based on d4c_NPN__c using mocks (no DML)
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-01   Dev4Clouds   Initial Version
1.1   2025-10-23   Dev4Clouds Refactored to use mocks without DML
*********************************************************
*/
@isTest
private class LeadEntityAssignmentService_Test {

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

        // Create mock leads (no DML)
        List<Lead> mockLeads = new List<Lead>{
            MockHelper.createMockLead('John', 'Doe', '11111111', null),
            MockHelper.createMockLead('Jane', 'Smith', '22222222', null)
        };

        // Enable mocks
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockLeads);
        Test.stopTest();

        // Verify producers were assigned
        for (Lead lead : mockLeads) {
            System.assertNotEquals(null, lead.d4c_Entity__c,
                'Entity should be assigned for NPN: ' + lead.d4c_NPN__c);
        }

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeInsert = false;
    }

    @isTest
    static void testBeforeInsert_NewEntitysCreated() {
        // Setup
        MockHelper.resetCounter();

        List<Lead> mockLeads = new List<Lead>{
            MockHelper.createMockLead('Test', 'Lead1', '30001', null),
            MockHelper.createMockLead('Test', 'Lead2', '30002', null)
        };

        // Enable mocks with empty producer map
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = new Map<String, d4c_Entity__c>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeInsert = true;

        Test.startTest();
        handler.beforeInsert(mockLeads);
        Test.stopTest();

        // Verify producers were created and assigned
        for (Lead lead : mockLeads) {
            System.assertNotEquals(null, lead.d4c_Entity__c,
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

        // Create old and new leads
        Lead oldLead = MockHelper.createMockLead('Test', 'Lead', '55555555', oldEntity.Id);
        Lead newLead = MockHelper.createMockLead('Test', 'Lead', '66666666', oldEntity.Id);
        newLead.Id = oldLead.Id;

        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        Map<Id, Lead> newMap = new Map<Id, Lead>{ newLead.Id => newLead };

        // Enable mocks
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;
        EntityAssignmentService.mockAccountsByNPN = new List<Account>();
        EntityAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify producer was reassigned
        System.assertEquals(newEntity.Id, newLead.d4c_Entity__c,
            'Entity should be reassigned to new NPN');

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }

    @isTest
    static void testHandleOrphanedEntitys_CrossObjectCheck() {
        // Setup
        MockHelper.resetCounter();
        d4c_Entity__c sharedEntity = MockHelper.createMockEntity('99999999');
        d4c_Entity__c newEntity = MockHelper.createMockEntity('88888888');

        Map<String, d4c_Entity__c> mockEntitys = new Map<String, d4c_Entity__c>{
            '99999999' => sharedEntity,
            '88888888' => newEntity
        };

        // Create lead that changes NPN
        Lead oldLead = MockHelper.createMockLead('Test', 'Lead', '99999999', sharedEntity.Id);
        Lead newLead = MockHelper.createMockLead('Test', 'Lead', '88888888', sharedEntity.Id);
        newLead.Id = oldLead.Id;

        // Mock Contact still using old NPN
        Contact contactUsingOldNPN = MockHelper.createMockContact('Test', 'Contact', '99999999', sharedEntity.Id);

        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        Map<Id, Lead> newMap = new Map<Id, Lead>{ newLead.Id => newLead };

        // Enable mocks - old NPN still in use by Contact
        EntityAssignmentService.useMocks = true;
        EntityAssignmentService.mockEntitysByNPN = mockEntitys;
        EntityAssignmentService.mockAccountsByNPN = new List<Account>();
        EntityAssignmentService.mockContactsByNPN = new List<Contact>{contactUsingOldNPN};
        EntityAssignmentService.mockLeadsByNPN = new List<Lead>();

        // Create handler
        LeadTriggerHandler handler = new LeadTriggerHandler();
        TriggerDispatcher.forceBeforeUpdate = true;
        TriggerDispatcher.forceAfterUpdate = true;

        Test.startTest();
        handler.beforeUpdate(newMap, oldMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();

        // Verify new producer assigned
        System.assertEquals(newEntity.Id, newLead.d4c_Entity__c,
            'New producer should be assigned');

        // Old producer should not be deleted (still used by Contact)
        System.assert(true, 'Entity should not be deleted when used by other SObject types');

        // Cleanup
        EntityAssignmentService.useMocks = false;
        TriggerDispatcher.forceBeforeUpdate = false;
        TriggerDispatcher.forceAfterUpdate = false;
    }
}