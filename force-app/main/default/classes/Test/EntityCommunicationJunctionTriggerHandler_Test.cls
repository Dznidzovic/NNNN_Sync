/**
 *********************************************************
 * Apex Class Name    : EntityCommunicationJunctionTriggerHandler_Test
 * Created Date       : 02-10-2026
 * @description       : Test class for EntityCommunicationJunctionTriggerHandler
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   02-10-2026   Dev4Clouds          Initial Version
 *********************************************************
 **/
@isTest
private class EntityCommunicationJunctionTriggerHandler_Test {

    /**
     ********************************************************
     * @Method Name    : setup
     * @description    : Creates test data - Entity and Communications
     *******************************************************
     **/
    @TestSetup
    static void setup() {
        // Create Entity
        d4c_Entity__c entity = new d4c_Entity__c(
            d4c_NPN__c = '87654321',
            d4c_FirstName__c = 'Jane',
            d4c_LastName__c = 'Smith'
        );
        insert entity;

        // Create Communications (standalone objects)
        List<d4c_ProducerCommunication__c> communications = new List<d4c_ProducerCommunication__c>{
            new d4c_ProducerCommunication__c(
                d4c_UniqueIdentifier__c = 'PHONE-555-1234',
                d4c_PhoneType__c = 'Mobile',
                d4c_PhoneNumber__c = '555-1234'
            ),
            new d4c_ProducerCommunication__c(
                d4c_UniqueIdentifier__c = 'EMAIL-test@example.com',
                d4c_EmailType__c = 'Work',
                d4c_EmailAddress__c = 'test@example.com'
            )
        };
        insert communications;
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeInsert_SingleRecord
     * @description    : Tests that unique identifier is populated on insert for single record
     *******************************************************
     **/
    @isTest
    static void testBeforeInsert_SingleRecord() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];
        d4c_ProducerCommunication__c communication = [SELECT Id FROM d4c_ProducerCommunication__c WHERE d4c_PhoneType__c = 'Mobile' LIMIT 1];

        Test.startTest();

        // Create junction
        d4c_Entity_Communication_Junction__c junction = new d4c_Entity_Communication_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Communication__c = communication.Id
        );
        insert junction;

        Test.stopTest();

        // Verify unique identifier was populated
        d4c_Entity_Communication_Junction__c result = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Communication__c
            FROM d4c_Entity_Communication_Junction__c
            WHERE Id = :junction.Id
        ];

        String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(communication.Id);
        System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
            'Unique identifier should be Entity ID + Communication ID');
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeInsert_BulkRecords
     * @description    : Tests that unique identifier is populated for bulk insert (200+ records)
     *******************************************************
     **/
    @isTest
    static void testBeforeInsert_BulkRecords() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];

        // Create 200 communications
        List<d4c_ProducerCommunication__c> communications = new List<d4c_ProducerCommunication__c>();
        for (Integer i = 0; i < 200; i++) {
            communications.add(new d4c_ProducerCommunication__c(
                d4c_UniqueIdentifier__c = 'BULK-EMAIL-' + i + '@test.com',
                d4c_EmailType__c = 'Business',
                d4c_EmailAddress__c = 'bulk' + i + '@test.com'
            ));
        }
        insert communications;

        Test.startTest();

        // Create 200 junctions
        List<d4c_Entity_Communication_Junction__c> junctions = new List<d4c_Entity_Communication_Junction__c>();
        for (d4c_ProducerCommunication__c communication : communications) {
            junctions.add(new d4c_Entity_Communication_Junction__c(
                d4c_Entity__c = entity.Id,
                d4c_NIPR_Communication__c = communication.Id
            ));
        }
        insert junctions;

        Test.stopTest();

        // Verify all unique identifiers were populated
        List<d4c_Entity_Communication_Junction__c> results = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Communication__c
            FROM d4c_Entity_Communication_Junction__c
            WHERE d4c_Entity__c = :entity.Id
        ];

        System.assertEquals(200, results.size(), 'Should have 200 junctions');

        for (d4c_Entity_Communication_Junction__c result : results) {
            String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(result.d4c_NIPR_Communication__c);
            System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
                'Each junction should have unique identifier populated');
        }
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeUpdate_UpdatesUniqueIdentifier
     * @description    : Tests that unique identifier is updated when Entity or Communication changes
     *******************************************************
     **/
    @isTest
    static void testBeforeUpdate_UpdatesUniqueIdentifier() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];
        List<d4c_ProducerCommunication__c> communications = [SELECT Id FROM d4c_ProducerCommunication__c ORDER BY d4c_PhoneType__c];

        // Create junction with first communication
        d4c_Entity_Communication_Junction__c junction = new d4c_Entity_Communication_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Communication__c = communications[0].Id
        );
        insert junction;

        // Verify initial unique identifier
        junction = [SELECT d4c_UniqueIdentifier__c FROM d4c_Entity_Communication_Junction__c WHERE Id = :junction.Id];
        String originalUniqueId = junction.d4c_UniqueIdentifier__c;

        Test.startTest();

        // Update junction to point to different communication
        junction.d4c_NIPR_Communication__c = communications[1].Id;
        update junction;

        Test.stopTest();

        // Verify unique identifier was updated
        junction = [SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Communication__c
                    FROM d4c_Entity_Communication_Junction__c WHERE Id = :junction.Id];

        String expectedNewUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(communications[1].Id);
        System.assertNotEquals(originalUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should have changed');
        System.assertEquals(expectedNewUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should match new Entity and Communication IDs');
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeInsert_NullSafety_NullEntity
     * @description    : Tests that handler gracefully handles null Entity
     *******************************************************
     **/
    @isTest
    static void testBeforeInsert_NullSafety_NullEntity() {
        // Get test data
        d4c_ProducerCommunication__c communication = [SELECT Id FROM d4c_ProducerCommunication__c LIMIT 1];

        Test.startTest();

        // Create junction with null Entity (will fail on required field, but trigger shouldn't error)
        d4c_Entity_Communication_Junction__c junction = new d4c_Entity_Communication_Junction__c(
            d4c_Entity__c = null,
            d4c_NIPR_Communication__c = communication.Id
        );

        try {
            insert junction;
            System.assert(false, 'Insert should fail due to required Master-Detail field');
        } catch (DmlException e) {
            // Expected - Master-Detail field is required
            System.assert(e.getMessage().contains('Required fields are missing') ||
                         e.getMessage().contains('REQUIRED_FIELD_MISSING'),
                'Should fail with required field error');
        }

        Test.stopTest();
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeInsert_NullSafety_NullCommunication
     * @description    : Tests that handler gracefully handles null Communication
     *******************************************************
     **/
    @isTest
    static void testBeforeInsert_NullSafety_NullCommunication() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];

        Test.startTest();

        // Create junction with null Communication (will fail on required field, but trigger shouldn't error)
        d4c_Entity_Communication_Junction__c junction = new d4c_Entity_Communication_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Communication__c = null
        );

        try {
            insert junction;
            System.assert(false, 'Insert should fail due to required Master-Detail field');
        } catch (DmlException e) {
            // Expected - Master-Detail field is required
            System.assert(e.getMessage().contains('Required fields are missing') ||
                         e.getMessage().contains('REQUIRED_FIELD_MISSING'),
                'Should fail with required field error');
        }

        Test.stopTest();
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeUpdate_BulkUpdate
     * @description    : Tests that unique identifier is updated for bulk updates
     *******************************************************
     **/
    @isTest
    static void testBeforeUpdate_BulkUpdate() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];

        // Create multiple communications
        List<d4c_ProducerCommunication__c> communications = new List<d4c_ProducerCommunication__c>();
        for (Integer i = 0; i < 50; i++) {
            communications.add(new d4c_ProducerCommunication__c(
                d4c_UniqueIdentifier__c = 'UPDATE-EMAIL-' + i + '@test.com',
                d4c_EmailType__c = 'Business',
                d4c_EmailAddress__c = 'update' + i + '@test.com'
            ));
        }
        insert communications;

        // Create junctions pointing to first 25 communications
        List<d4c_Entity_Communication_Junction__c> junctions = new List<d4c_Entity_Communication_Junction__c>();
        for (Integer i = 0; i < 25; i++) {
            junctions.add(new d4c_Entity_Communication_Junction__c(
                d4c_Entity__c = entity.Id,
                d4c_NIPR_Communication__c = communications[i].Id
            ));
        }
        insert junctions;

        Test.startTest();

        // Update all junctions to point to the next 25 communications
        for (Integer i = 0; i < junctions.size(); i++) {
            junctions[i].d4c_NIPR_Communication__c = communications[i + 25].Id;
        }
        update junctions;

        Test.stopTest();

        // Verify all unique identifiers were updated
        List<d4c_Entity_Communication_Junction__c> results = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Communication__c
            FROM d4c_Entity_Communication_Junction__c
            WHERE Id IN :junctions
        ];

        System.assertEquals(25, results.size(), 'Should have 25 updated junctions');

        for (d4c_Entity_Communication_Junction__c result : results) {
            String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(result.d4c_NIPR_Communication__c);
            System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
                'Each junction should have updated unique identifier');
        }
    }
}
