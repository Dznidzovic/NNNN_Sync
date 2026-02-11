/**
 *********************************************************
 * Apex Class Name    : EntityAddressJunctionTriggerHandler_Test
 * Created Date       : 02-10-2026
 * @description       : Test class for EntityAddressJunctionTriggerHandler
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   02-10-2026   Dev4Clouds          Initial Version
 *********************************************************
 **/
@isTest
private class EntityAddressJunctionTriggerHandler_Test {

    /**
     ********************************************************
     * @Method Name    : setup
     * @description    : Creates test data - Entity and Addresses
     *******************************************************
     **/
    @TestSetup
    static void setup() {
        // Create Entity
        d4c_Entity__c entity = new d4c_Entity__c(
            d4c_NPN__c = '12345678'
        );
        insert entity;

        // Create Addresses (standalone objects)
        List<d4c_NIPR_Address__c> addresses = new List<d4c_NIPR_Address__c>{
            new d4c_NIPR_Address__c(
                d4c_UniqueIdentifier__c = 'HOME-123-MAIN-ST',
                d4c_AddressType__c = 'Home',
                d4c_AddressLineOne__c = '123 Main St'
            ),
            new d4c_NIPR_Address__c(
                d4c_UniqueIdentifier__c = 'WORK-456-OAK-AVE',
                d4c_AddressType__c = 'Work',
                d4c_AddressLineOne__c = '456 Oak Ave'
            )
        };
        insert addresses;
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
        d4c_NIPR_Address__c address = [SELECT Id FROM d4c_NIPR_Address__c WHERE d4c_AddressType__c = 'Home' LIMIT 1];

        Test.startTest();

        // Create junction
        d4c_Entity_Address_Junction__c junction = new d4c_Entity_Address_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Address__c = address.Id
        );
        insert junction;

        Test.stopTest();

        // Verify unique identifier was populated
        d4c_Entity_Address_Junction__c result = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
            FROM d4c_Entity_Address_Junction__c
            WHERE Id = :junction.Id
        ];

        String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(address.Id);
        System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
            'Unique identifier should be Entity ID + Address ID');
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

        // Create 200 addresses
        List<d4c_NIPR_Address__c> addresses = new List<d4c_NIPR_Address__c>();
        for (Integer i = 0; i < 200; i++) {
            addresses.add(new d4c_NIPR_Address__c(
                d4c_UniqueIdentifier__c = 'BULK-' + i + '-ADDRESS',
                d4c_AddressType__c = 'Business',
                d4c_AddressLineOne__c = i + ' Test St'
            ));
        }
        insert addresses;

        Test.startTest();

        // Create 200 junctions
        List<d4c_Entity_Address_Junction__c> junctions = new List<d4c_Entity_Address_Junction__c>();
        for (d4c_NIPR_Address__c address : addresses) {
            junctions.add(new d4c_Entity_Address_Junction__c(
                d4c_Entity__c = entity.Id,
                d4c_NIPR_Address__c = address.Id
            ));
        }
        insert junctions;

        Test.stopTest();

        // Verify all unique identifiers were populated
        List<d4c_Entity_Address_Junction__c> results = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
            FROM d4c_Entity_Address_Junction__c
            WHERE d4c_Entity__c = :entity.Id
        ];

        System.assertEquals(200, results.size(), 'Should have 200 junctions');

        for (d4c_Entity_Address_Junction__c result : results) {
            String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(result.d4c_NIPR_Address__c);
            System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
                'Each junction should have unique identifier populated');
        }
    }

    /**
     ********************************************************
     * @Method Name    : testBeforeUpdate_UpdatesUniqueIdentifier
     * @description    : Tests that unique identifier is repopulated if cleared/corrupted
     *******************************************************
     **/
    @isTest
    static void testBeforeUpdate_UpdatesUniqueIdentifier() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];
        d4c_NIPR_Address__c address = [SELECT Id FROM d4c_NIPR_Address__c LIMIT 1];

        // Create junction
        d4c_Entity_Address_Junction__c junction = new d4c_Entity_Address_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Address__c = address.Id
        );
        insert junction;

        // Verify initial unique identifier
        junction = [SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
                    FROM d4c_Entity_Address_Junction__c WHERE Id = :junction.Id];
        String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(address.Id);
        System.assertEquals(expectedUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should be populated on insert');

        Test.startTest();

        // Simulate clearing the unique identifier (data corruption scenario)
        junction.d4c_UniqueIdentifier__c = null;
        update junction;

        Test.stopTest();

        // Verify unique identifier was repopulated by beforeUpdate trigger
        junction = [SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
                    FROM d4c_Entity_Address_Junction__c WHERE Id = :junction.Id];

        System.assertEquals(expectedUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should be repopulated on update');
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
        d4c_NIPR_Address__c address = [SELECT Id FROM d4c_NIPR_Address__c LIMIT 1];

        Test.startTest();

        // Create junction with null Entity (will fail on required field, but trigger shouldn't error)
        d4c_Entity_Address_Junction__c junction = new d4c_Entity_Address_Junction__c(
            d4c_Entity__c = null,
            d4c_NIPR_Address__c = address.Id
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
     * @Method Name    : testBeforeInsert_NullSafety_NullAddress
     * @description    : Tests that handler gracefully handles null Address
     *******************************************************
     **/
    @isTest
    static void testBeforeInsert_NullSafety_NullAddress() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];

        Test.startTest();

        // Create junction with null Address (will fail on required field, but trigger shouldn't error)
        d4c_Entity_Address_Junction__c junction = new d4c_Entity_Address_Junction__c(
            d4c_Entity__c = entity.Id,
            d4c_NIPR_Address__c = null
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
     * @description    : Tests that unique identifier is repopulated for bulk updates
     *******************************************************
     **/
    @isTest
    static void testBeforeUpdate_BulkUpdate() {
        // Get test data
        d4c_Entity__c entity = [SELECT Id FROM d4c_Entity__c LIMIT 1];

        // Create multiple addresses
        List<d4c_NIPR_Address__c> addresses = new List<d4c_NIPR_Address__c>();
        for (Integer i = 0; i < 50; i++) {
            addresses.add(new d4c_NIPR_Address__c(
                d4c_UniqueIdentifier__c = 'UPDATE-' + i + '-ADDRESS',
                d4c_AddressType__c = 'Business',
                d4c_AddressLineOne__c = i + ' Update St'
            ));
        }
        insert addresses;

        // Create junctions pointing to addresses
        List<d4c_Entity_Address_Junction__c> junctions = new List<d4c_Entity_Address_Junction__c>();
        for (Integer i = 0; i < 25; i++) {
            junctions.add(new d4c_Entity_Address_Junction__c(
                d4c_Entity__c = entity.Id,
                d4c_NIPR_Address__c = addresses[i].Id
            ));
        }
        insert junctions;

        // Query to get IDs and verify initial state
        junctions = [SELECT Id, d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
                     FROM d4c_Entity_Address_Junction__c
                     WHERE Id IN :junctions];

        Test.startTest();

        // Simulate clearing unique identifiers (data corruption scenario)
        for (d4c_Entity_Address_Junction__c junction : junctions) {
            junction.d4c_UniqueIdentifier__c = null;
        }
        update junctions;

        Test.stopTest();

        // Verify all unique identifiers were repopulated
        List<d4c_Entity_Address_Junction__c> results = [
            SELECT d4c_UniqueIdentifier__c, d4c_Entity__c, d4c_NIPR_Address__c
            FROM d4c_Entity_Address_Junction__c
            WHERE Id IN :junctions
        ];

        System.assertEquals(25, results.size(), 'Should have 25 updated junctions');

        for (d4c_Entity_Address_Junction__c result : results) {
            String expectedUniqueId = String.valueOf(entity.Id) + '-' + String.valueOf(result.d4c_NIPR_Address__c);
            System.assertEquals(expectedUniqueId, result.d4c_UniqueIdentifier__c,
                'Each junction should have repopulated unique identifier');
        }
    }
}
