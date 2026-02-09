/*
*********************************************************
Apex Class Name    : InsProdLOAMappingHandler_Test
Created Date       : 2025-12-13
@description       : Test class for InsuranceProductLOAMappingTriggerHandler.
                     Tests unique identifier generation and orphan LOA matching.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan Nidzovic         Initial Version
*********************************************************
*/
@isTest
private class InsProdLOAMappingHandler_Test {

    private static final String TEST_STATE = 'CA';
    private static final String TEST_LOA_CODE = '935';
    private static final String TEST_LOA_DESCRIPTION = 'Accident & Health';

    @TestSetup
    static void setupTestData() {
        // Disable all LOA-related triggers during test setup
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;

        // Create Producer
        d4c_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        // Create License
        d4c_License__c license = TestDataFactory.createLicense('IPMTEST123', producer.Id);
        license.d4c_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        // Create Insurance Product
        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(
            'Life Insurance', TEST_STATE, true
        );

        // Create LOA Mapping (parent record)
        d4c_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Create second LOA Mapping for multi-mapping tests
        d4c_LOA_Insurance_Product_Mapping__c mapping2 = TestDataFactory.createLOAInsuranceProductMapping(
            'TX', '100', 'Property Insurance', true
        );

        // Create orphan LOA (no d4c_LOAMapping__c set) - to be matched later
        d4c_LineOfAuthority__c orphanLoa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_UniqueIdentifier__c = 'ORPHAN-LOA-' + String.valueOf(license.Id).left(10)
        );
        insert orphanLoa;

        // Re-enable triggers
        LineOfAuthorityTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;
    }

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeInsert)
    // ============================================================

    @isTest
    static void beforeInsert_populatesUniqueIdentifier() {
        // Arrange
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];


        // Act
        Test.startTest();
        d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: Unique identifier should be populated
        junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product_LOA_Mapping__c WHERE Id = :junction.Id];
        String expectedUniqueId = String.valueOf(product.Id) + '-' + String.valueOf(mapping.Id);
        System.assertEquals(expectedUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should be ProductId-MappingId');
    }

    @isTest
    static void beforeInsert_handlesNullProductId() {
        // Arrange: Create junction without Insurance Product (edge case)
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];


        // Act: Try to insert junction without Insurance Product
        Test.startTest();
        try {
            d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_LOAMapping__c = mapping.Id
            );
            insert junction;
            // If we get here, check that unique ID is null or empty
            junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product_LOA_Mapping__c WHERE Id = :junction.Id];
            System.assert(String.isBlank(junction.d4c_UniqueIdentifier__c),
                'Unique identifier should be blank when Insurance Product is null');
        } catch (DmlException e) {
            // Expected: Master-Detail might require Insurance Product
            System.assert(true, 'Master-Detail field requires parent, DML failed as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_preventsDuplicateJunctions() {
        // Arrange
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        // Create first junction
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c junction1 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert junction1;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;


        // Act: Try to insert duplicate junction
        Test.startTest();
        try {
            d4c_Insurance_Product_LOA_Mapping__c junction2 = new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = mapping.Id
            );
            insert junction2;
            System.assert(false, 'Should have thrown duplicate value exception');
        } catch (DmlException e) {
            // Expected: Duplicate value on external ID field
            System.assert(e.getMessage().containsIgnoreCase('DUPLICATE_VALUE') ||
                         e.getMessage().containsIgnoreCase('duplicate'),
                'Should fail with duplicate value error: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ============================================================
    // ORPHAN LOA MATCHING TESTS (afterInsert)
    // ============================================================

    @isTest
    static void afterInsert_findsAndUpdatesOrphanLoas() {
        // Arrange
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        // Verify orphan LOA exists without mapping
        d4c_LineOfAuthority__c orphanLoa = [
            SELECT Id, d4c_LOAMapping__c
            FROM d4c_LineOfAuthority__c
            WHERE d4c_StateOrProvinceCode__c = :TEST_STATE
            AND d4c_LineOfAuthorityCode__c = :TEST_LOA_CODE
            LIMIT 1
        ];
        System.assertEquals(null, orphanLoa.d4c_LOAMapping__c, 'Orphan LOA should not have mapping set');


        // Act: Insert junction which should trigger orphan LOA matching
        Test.startTest();
        d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: Orphan LOA should now be linked to the mapping
        orphanLoa = [
            SELECT Id, d4c_LOAMapping__c
            FROM d4c_LineOfAuthority__c
            WHERE Id = :orphanLoa.Id
        ];
        System.assertEquals(mapping.Id, orphanLoa.d4c_LOAMapping__c,
            'Orphan LOA should now have mapping set');
    }

    @isTest
    static void afterInsert_noMatchingOrphanLoas() {
        // Arrange: Use a different state mapping that has no orphan LOAs
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = 'TX' LIMIT 1];


        // Act: Insert junction for TX state (no orphan LOAs exist for TX)
        Test.startTest();
        d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: No errors should occur, orphan list should be empty or null
        // The test simply verifies no exceptions were thrown
        System.assert(true, 'No exception thrown when no orphan LOAs match');
    }

    @isTest
    static void afterInsert_updatesExistingLinkedLoas() {
        // Arrange: Create a scenario where LOAs are already linked to a mapping,
        // then a new product junction is added to that mapping
        d4c_Insurance_Product__c product1 = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct('Health Insurance', TEST_STATE, true);
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        // Create first junction (product1 -> mapping)
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c junction1 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product1.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product1.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert junction1;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Link LOA to the mapping (simulating an LOA that's already matched)
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = [
            SELECT Id, d4c_LOAMapping__c, d4c_License__c
            FROM d4c_LineOfAuthority__c
            WHERE d4c_StateOrProvinceCode__c = :TEST_STATE
            LIMIT 1
        ];
        loa.d4c_LOAMapping__c = mapping.Id;
        update loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Verify LOA is linked to mapping
        loa = [SELECT Id, d4c_LOAMapping__c FROM d4c_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(mapping.Id, loa.d4c_LOAMapping__c, 'LOA should be linked to mapping');

        // Act: Insert second junction (product2 -> mapping) which should enqueue batch for existing LOA
        Test.startTest();
        d4c_Insurance_Product_LOA_Mapping__c junction2 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product2.Id,
            d4c_LOAMapping__c = mapping.Id
        );
        insert junction2;
        Test.stopTest();

        // Assert: LOA should still be linked
        loa = [SELECT Id, d4c_LOAMapping__c FROM d4c_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(mapping.Id, loa.d4c_LOAMapping__c,
            'LOA should still be linked to mapping after new junction insert');

        // Assert: Batch should have been enqueued for the existing linked LOA
        System.assertNotEquals(null, InsuranceProductLOAMappingTriggerHandler.loasEnqueuedForBatch,
            'LOAs should have been captured for batch processing');
        System.assertEquals(1, InsuranceProductLOAMappingTriggerHandler.loasEnqueuedForBatch.size(),
            'Should have 1 LOA enqueued for batch');
        System.assertEquals(loa.Id, InsuranceProductLOAMappingTriggerHandler.loasEnqueuedForBatch[0].Id,
            'The existing linked LOA should be enqueued for batch');
    }

    // ============================================================
    // CASCADE DELETE CLEANUP TESTS (afterDelete)
    // ============================================================

    @isTest
    static void afterDelete_deletesLicenseProductJunctions() {
        // Arrange
        d4c_Insurance_Product__c product1 = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct('Health Insurance', TEST_STATE, true);
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        // Create TWO Insurance Product LOA Mapping junctions (so parent won't be orphaned when we delete one)
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c mappingJunction1 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product1.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product1.Id) + '-' + String.valueOf(mapping.Id)
        );
        d4c_Insurance_Product_LOA_Mapping__c mappingJunction2 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product2.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product2.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert new List<d4c_Insurance_Product_LOA_Mapping__c>{mappingJunction1, mappingJunction2};
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Link the LOA to the mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = [
            SELECT Id, d4c_LOAMapping__c, d4c_License__c
            FROM d4c_LineOfAuthority__c
            WHERE d4c_StateOrProvinceCode__c = :TEST_STATE
            LIMIT 1
        ];
        loa.d4c_LOAMapping__c = mapping.Id;
        update loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create License-Product junction (simulating what would be created by LOA mapping)
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c licenseProductJunction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product1.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product1.Id)
        );
        insert licenseProductJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        List<d4c_License_Insurance_Product__c> junctionsBeforeDelete = [
            SELECT Id FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id AND d4c_InsuranceProduct__c = :product1.Id
        ];
        System.assertEquals(1, junctionsBeforeDelete.size(), 'License-Product junction should exist before delete');

        // Act: Delete the first mapping junction (should delete License-Product junction for product1)
        Test.startTest();
        delete mappingJunction1;
        Test.stopTest();

        // Assert: License-Product junction should be deleted
        List<d4c_License_Insurance_Product__c> junctionsAfterDelete = [
            SELECT Id FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id AND d4c_InsuranceProduct__c = :product1.Id
        ];
        System.assertEquals(0, junctionsAfterDelete.size(),
            'License-Product junction should be deleted when mapping junction is deleted');

        // Assert: LOA mapping should NOT be cleared (parent mapping still has junction2)
        loa = [SELECT Id, d4c_LOAMapping__c FROM d4c_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(mapping.Id, loa.d4c_LOAMapping__c,
            'LOA mapping lookup should NOT be cleared when parent mapping still has other junctions');
    }

    @isTest
    static void afterDelete_onlyDeletesRelatedJunctions() {
        // Arrange: Create two products and two mappings
        d4c_Insurance_Product__c product1 = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        // Create second product
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct('Health Insurance', TEST_STATE, true);

        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        // Create mapping junction for product1
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c mappingJunction1 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product1.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product1.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert mappingJunction1;

        // Create mapping junction for product2
        d4c_Insurance_Product_LOA_Mapping__c mappingJunction2 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product2.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product2.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert mappingJunction2;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Link LOA to mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = [
            SELECT Id, d4c_LOAMapping__c, d4c_License__c
            FROM d4c_LineOfAuthority__c
            WHERE d4c_StateOrProvinceCode__c = :TEST_STATE
            LIMIT 1
        ];
        loa.d4c_LOAMapping__c = mapping.Id;
        update loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create License-Product junctions for both products
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        List<d4c_License_Insurance_Product__c> licenseProductJunctions = new List<d4c_License_Insurance_Product__c>{
            new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product1.Id,
                d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product1.Id)
            ),
            new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product2.Id,
                d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product2.Id)
            )
        };
        insert licenseProductJunctions;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify both junctions exist
        System.assertEquals(2, [SELECT COUNT() FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id],
            'Should have 2 License-Product junctions before delete');

        // Act: Delete only the first mapping junction
        Test.startTest();
        delete mappingJunction1;
        Test.stopTest();

        // Assert: Only product1 junction should be deleted, product2 should remain
        List<d4c_License_Insurance_Product__c> remainingJunctions = [
            SELECT Id, d4c_InsuranceProduct__c
            FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(1, remainingJunctions.size(),
            'Should have 1 License-Product junction after deleting one mapping');
        System.assertEquals(product2.Id, remainingJunctions[0].d4c_InsuranceProduct__c,
            'Remaining junction should be for product2');
    }

    @isTest
    static void afterDelete_bulkDeleteMultipleMappings() {
        // Arrange: Create products and mappings
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping1 = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping2 = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = 'TX' LIMIT 1];

        // Create multiple producers and licenses
        d4c_Producer__c producer2 = TestDataFactory.createProducer('9876543210');
        insert producer2;

        d4c_License__c license1 = [SELECT Id FROM d4c_License__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        d4c_License__c license2 = TestDataFactory.createLicense('LIC456', producer2.Id);
        license2.d4c_StateOrProvinceCode__c = 'TX';
        insert license2;

        // Create mapping junctions
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        List<d4c_Insurance_Product_LOA_Mapping__c> mappingJunctions = new List<d4c_Insurance_Product_LOA_Mapping__c>{
            new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = mapping1.Id,
                d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(mapping1.Id)
            ),
            new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = mapping2.Id,
                d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(mapping2.Id)
            )
        };
        insert mappingJunctions;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create LOAs and link to mappings
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        List<d4c_LineOfAuthority__c> loas = new List<d4c_LineOfAuthority__c>{
            new d4c_LineOfAuthority__c(
                d4c_License__c = license1.Id,
                d4c_LOAMapping__c = mapping1.Id,
                d4c_StateOrProvinceCode__c = TEST_STATE,
                d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
                d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
                d4c_UniqueIdentifier__c = 'LOA1-' + String.valueOf(license1.Id).left(10)
            ),
            new d4c_LineOfAuthority__c(
                d4c_License__c = license2.Id,
                d4c_LOAMapping__c = mapping2.Id,
                d4c_StateOrProvinceCode__c = 'TX',
                d4c_LineOfAuthorityCode__c = '100',
                d4c_LineOfAuthorityDescription__c = 'Property Insurance',
                d4c_UniqueIdentifier__c = 'LOA2-' + String.valueOf(license2.Id).left(10)
            )
        };
        insert loas;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create License-Product junctions
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        List<d4c_License_Insurance_Product__c> licenseProductJunctions = new List<d4c_License_Insurance_Product__c>{
            new d4c_License_Insurance_Product__c(
                d4c_License__c = license1.Id,
                d4c_InsuranceProduct__c = product.Id,
                d4c_UniqueIdentifier__c = String.valueOf(license1.Id) + '-' + String.valueOf(product.Id)
            ),
            new d4c_License_Insurance_Product__c(
                d4c_License__c = license2.Id,
                d4c_InsuranceProduct__c = product.Id,
                d4c_UniqueIdentifier__c = String.valueOf(license2.Id) + '-' + String.valueOf(product.Id)
            )
        };
        insert licenseProductJunctions;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junctions exist
        System.assertEquals(2, [SELECT COUNT() FROM d4c_License_Insurance_Product__c],
            'Should have 2 License-Product junctions before bulk delete');

        // Act: Bulk delete both mapping junctions
        Test.startTest();
        delete mappingJunctions;
        Test.stopTest();

        // Assert: All License-Product junctions should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_License_Insurance_Product__c],
            'All License-Product junctions should be deleted after bulk mapping delete');
    }

    @isTest
    static void afterDelete_handlesNoRelatedLoas() {
        // Arrange: Create junction but don't link any LOAs to the mapping
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = 'TX' LIMIT 1];

        // Create junction with trigger disabled
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert junction;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Act: Delete the junction (no LOAs means no License-Product junctions to delete)
        Test.startTest();
        delete junction;
        Test.stopTest();

        // Assert: No errors should occur
        System.assert(true, 'No exception thrown when no LOAs are affected');
    }

    @isTest
    static void afterDelete_deletesOrphanedParentLoaMapping() {
        // Arrange: Create a parent LOA Mapping with a single junction
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        Id mappingId = mapping.Id;

        // Create junction with trigger disabled (so we control setup)
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert junction;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify the parent mapping exists
        System.assertEquals(1, [SELECT COUNT() FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mappingId],
            'Parent LOA Mapping should exist before junction delete');

        // Act: Delete the only junction - parent should become orphaned and deleted
        Test.startTest();
        delete junction;
        Test.stopTest();

        // Assert: Parent LOA Mapping should be deleted since it has no more junctions
        System.assertEquals(0, [SELECT COUNT() FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mappingId],
            'Orphaned parent LOA Mapping should be deleted when last junction is removed');
    }

    @isTest
    static void afterDelete_doesNotDeleteParentWithRemainingJunctions() {
        // Arrange: Create a parent LOA Mapping with two junctions
        d4c_Insurance_Product__c product1 = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct('Auto Insurance', TEST_STATE, true);
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];
        Id mappingId = mapping.Id;

        // Create two junctions for the same parent mapping
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c junction1 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product1.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product1.Id) + '-' + String.valueOf(mapping.Id)
        );
        d4c_Insurance_Product_LOA_Mapping__c junction2 = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product2.Id,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product2.Id) + '-' + String.valueOf(mapping.Id)
        );
        insert new List<d4c_Insurance_Product_LOA_Mapping__c>{junction1, junction2};
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify parent and both junctions exist
        System.assertEquals(1, [SELECT COUNT() FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mappingId],
            'Parent LOA Mapping should exist before delete');
        System.assertEquals(2, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c WHERE d4c_LOAMapping__c = :mappingId],
            'Should have 2 junctions before delete');

        // Act: Delete only one junction - parent should NOT be deleted
        Test.startTest();
        delete junction1;
        Test.stopTest();

        // Assert: Parent should still exist because junction2 remains
        System.assertEquals(1, [SELECT COUNT() FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mappingId],
            'Parent LOA Mapping should NOT be deleted when other junctions remain');
        System.assertEquals(1, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c WHERE d4c_LOAMapping__c = :mappingId],
            'Should have 1 junction remaining after delete');
    }

    // ============================================================
    // TRIGGER DISABLED TEST
    // ============================================================

    @isTest
    static void triggerDisabled_skipsAllProcessing() {
        // Arrange
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c WHERE d4c_StateOrProvinceCode__c = :TEST_STATE LIMIT 1];

        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;

        // Act: When trigger is disabled, UniqueIdentifier won't be populated by the trigger
        Test.startTest();
        try {
            d4c_Insurance_Product_LOA_Mapping__c junction = new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = mapping.Id
            );
            insert junction;
            // If insert succeeds, the trigger was bypassed (no unique ID populated)
            junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product_LOA_Mapping__c WHERE Id = :junction.Id];
            System.assert(String.isBlank(junction.d4c_UniqueIdentifier__c),
                'UniqueIdentifier should be blank when trigger is disabled');
        } catch (DmlException e) {
            // Expected: The trigger is disabled so UniqueIdentifier won't be populated
            System.assert(e.getMessage().containsIgnoreCase('REQUIRED_FIELD_MISSING') ||
                         e.getMessage().containsIgnoreCase('UniqueIdentifier'),
                'Insert should fail due to missing required field when trigger is disabled: ' + e.getMessage());
        }
        Test.stopTest();
    }
}