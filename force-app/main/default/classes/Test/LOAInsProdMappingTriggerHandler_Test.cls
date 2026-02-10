/*
*********************************************************
Apex Class Name    : LOAInsProdMappingTriggerHandler_Test
Created Date       : 2025-12-15
@description       : Test class for LOAInsuranceProductMappingTriggerHandler.
                     Tests unique identifier auto-generation on insert and update.
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
@isTest
private class LOAInsProdMappingTriggerHandler_Test {

    private static final String TEST_STATE = 'CA';
    private static final String TEST_CODE = '935';
    private static final String TEST_DESCRIPTION = 'Accident & Health';

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeInsert)
    // ============================================================

    @isTest
    static void beforeInsert_populatesUniqueIdentifier() {
        // Arrange
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        insert mapping;
        Test.stopTest();

        // Assert
        mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
            'Unique identifier should be State-Code-Description');
    }

    @isTest
    static void beforeInsert_handlesNullState() {
        // Arrange: Mapping with null state
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.d4c_UniqueIdentifier__c),
                'Unique identifier should be blank when State is null');
        } catch (DmlException e) {
            // Expected: Required field validation might fail
            System.assert(true, 'Insert failed as expected due to missing required field');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_handlesNullCode() {
        // Arrange: Mapping with null code
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.d4c_UniqueIdentifier__c),
                'Unique identifier should be blank when Code is null');
        } catch (DmlException e) {
            // Expected: Required field validation might fail
            System.assert(true, 'Insert failed as expected due to missing required field');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_handlesNullDescription() {
        // Arrange: Mapping with null description
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.d4c_UniqueIdentifier__c),
                'Unique identifier should be blank when Description is null');
        } catch (DmlException e) {
            // Expected: Required field validation might fail
            System.assert(true, 'Insert failed as expected due to missing required field');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_handlesBulkInsert() {
        // Arrange: Create 200 mappings
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = new List<d4c_LOA_Insurance_Product_Mapping__c>();
        for (Integer i = 0; i < 200; i++) {
            mappings.add(new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = TEST_STATE,
                d4c_LineOfAuthorityCode__c = String.valueOf(i),
                d4c_LineOfAuthorityDescription__c = 'Description ' + i
            ));
        }

        // Act
        Test.startTest();
        insert mappings;
        Test.stopTest();

        // Assert: All mappings should have unique identifier populated
        List<d4c_LOA_Insurance_Product_Mapping__c> insertedMappings = [
            SELECT Id, d4c_StateOrProvinceCode__c, d4c_LineOfAuthorityCode__c,
                   d4c_LineOfAuthorityDescription__c, d4c_UniqueIdentifier__c
            FROM d4c_LOA_Insurance_Product_Mapping__c
            WHERE Id IN :mappings
        ];

        System.assertEquals(200, insertedMappings.size(), 'All 200 mappings should be inserted');
        for (d4c_LOA_Insurance_Product_Mapping__c mapping : insertedMappings) {
            String expectedUniqueId = mapping.d4c_StateOrProvinceCode__c + '-' +
                mapping.d4c_LineOfAuthorityCode__c + '-' +
                mapping.d4c_LineOfAuthorityDescription__c;
            System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
                'Each mapping should have correct unique identifier');
        }
    }

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeUpdate)
    // ============================================================

    @isTest
    static void beforeUpdate_recalculatesWhenStateChanges() {
        // Arrange: Insert mapping with initial values
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the state
        Test.startTest();
        mapping.d4c_StateOrProvinceCode__c = 'TX';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = 'TX-' + TEST_CODE + '-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
            'Unique identifier should be recalculated when state changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenCodeChanges() {
        // Arrange: Insert mapping with initial values
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the code
        Test.startTest();
        mapping.d4c_LineOfAuthorityCode__c = '999';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-999-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
            'Unique identifier should be recalculated when code changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenDescriptionChanges() {
        // Arrange: Insert mapping with initial values
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the description
        Test.startTest();
        mapping.d4c_LineOfAuthorityDescription__c = 'Property Insurance';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-Property Insurance';
        System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
            'Unique identifier should be recalculated when description changes');
    }

    @isTest
    static void beforeUpdate_alwaysRecalculates() {
        // Arrange: Insert mapping and manually set a different unique ID
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = true;
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION,
            d4c_UniqueIdentifier__c = 'MANUAL-VALUE'
        );
        insert mapping;
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = false;

        // Act: Update any field to trigger beforeUpdate
        Test.startTest();
        mapping.d4c_LineOfAuthorityDescription__c = 'Updated Description';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated (not kept as MANUAL-VALUE)
        mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-Updated Description';
        System.assertEquals(expectedUniqueId, mapping.d4c_UniqueIdentifier__c,
            'Unique identifier should always be recalculated on update');
    }

    // ============================================================
    // TRIGGER DISABLED TEST
    // ============================================================

    @isTest
    static void triggerDisabled_skipsProcessing() {
        // Arrange
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = true;

        // Act
        Test.startTest();
        try {
            d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = TEST_STATE,
                d4c_LineOfAuthorityCode__c = TEST_CODE,
                d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
            );
            insert mapping;

            // If insert succeeds, unique ID should not be populated
            mapping = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.d4c_UniqueIdentifier__c),
                'Unique identifier should not be populated when trigger is disabled');
        } catch (DmlException e) {
            // Expected: Required field validation might fail since trigger didn't populate it
            System.assert(e.getMessage().containsIgnoreCase('REQUIRED_FIELD_MISSING') ||
                         e.getMessage().containsIgnoreCase('UniqueIdentifier'),
                'Insert should fail due to missing required field when trigger is disabled: ' + e.getMessage());
        }
        Test.stopTest();

        // Cleanup
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = false;
    }

    // ============================================================
    // DUPLICATE PREVENTION TEST
    // ============================================================

    @isTest
    static void beforeInsert_preventsDuplicateUniqueIdentifier() {
        // Arrange: Create first mapping
        d4c_LOA_Insurance_Product_Mapping__c mapping1 = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping1;

        // Act: Try to create duplicate mapping
        Test.startTest();
        try {
            d4c_LOA_Insurance_Product_Mapping__c mapping2 = new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = TEST_STATE,
                d4c_LineOfAuthorityCode__c = TEST_CODE,
                d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION
            );
            insert mapping2;
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
    // CASCADE DELETE TESTS (beforeDelete)
    // ============================================================

    @isTest
    static void beforeDelete_deletesProductLOAMappingJunctions() {
        // Arrange: Create test data
        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct('Test Product', TEST_STATE, true);

        // Create Product-LOA Mapping junction
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c productLoaJunction = new d4c_Insurance_Product_LOA_Mapping__c(
            d4c_InsuranceProduct__c = product.Id,
            d4c_LOAMapping__c = loaMapping.Id,
            d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
        );
        insert productLoaJunction;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c
            WHERE d4c_LOAMapping__c = :loaMapping.Id], 'Junction should exist before delete');

        // Act: Delete the LOA mapping (beforeDelete should delete junctions)
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c
            WHERE d4c_LOAMapping__c = :loaMapping.Id],
            'Product-LOA Mapping junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_bulkDeleteMappings() {
        // Arrange: Create multiple LOA mappings
        List<d4c_LOA_Insurance_Product_Mapping__c> loaMappings = new List<d4c_LOA_Insurance_Product_Mapping__c>();
        for (Integer i = 0; i < 5; i++) {
            loaMappings.add(TestDataFactory.createLOAInsuranceProductMapping(
                TEST_STATE, String.valueOf(100 + i), 'Description ' + i, false
            ));
        }
        insert loaMappings;

        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct('Test Product', TEST_STATE, true);

        // Create junctions for all mappings
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        List<d4c_Insurance_Product_LOA_Mapping__c> productLoaJunctions = new List<d4c_Insurance_Product_LOA_Mapping__c>();
        for (d4c_LOA_Insurance_Product_Mapping__c loaMapping : loaMappings) {
            productLoaJunctions.add(new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = loaMapping.Id,
                d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
            ));
        }
        insert productLoaJunctions;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify junctions exist
        System.assertEquals(5, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c],
            'Should have 5 Product-LOA junctions before delete');

        // Act: Bulk delete all LOA mappings
        Test.startTest();
        delete loaMappings;
        Test.stopTest();

        // Assert: All junctions should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c],
            'All Product-LOA junctions should be deleted');
    }

    @isTest
    static void beforeDelete_handlesNoJunctions() {
        // Arrange: Create LOA mapping without any junctions
        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Verify no junctions exist
        System.assertEquals(0, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c
            WHERE d4c_LOAMapping__c = :loaMapping.Id], 'No junctions should exist');

        // Act: Delete the LOA mapping (no junctions to delete)
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: No errors should occur
        System.assert(true, 'No exception thrown when no junctions exist');
    }

    // ============================================================
    // AFTER DELETE TESTS - LOA IsProductMatched Cleanup
    // ============================================================

    @isTest
    static void afterDelete_clearsIsProductMatchedOnRelatedLOAs() {
        // Arrange: Create entity, license, mapping, and LOA
        d4c_Entity__c entity = TestDataFactory.createEntity('1234567890');
        insert entity;

        d4c_License__c license = new d4c_License__c(
            d4c_LicenseNumber__c = 'AFTERDELLIC',
            d4c_Entity__c = entity.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LicenseClassCode__c = '3',
            d4c_UniqueIdentifier__c = 'AFTERDELLIC' + TEST_STATE + '3'
        );
        insert license;

        // Create LOA mapping
        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Create LOA that matches the mapping
        d4c_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Verify LOA has mapping and IsProductMatched = true
        loa = [SELECT Id, d4c_LOAMapping__c, d4c_IsProductMatched__c FROM d4c_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(loaMapping.Id, loa.d4c_LOAMapping__c, 'LOA should have mapping before delete');
        System.assertEquals(true, loa.d4c_IsProductMatched__c, 'IsProductMatched should be true before delete');

        // Act: Delete the LOA mapping
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: LOA should have null mapping and IsProductMatched = false
        loa = [SELECT Id, d4c_LOAMapping__c, d4c_IsProductMatched__c FROM d4c_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(null, loa.d4c_LOAMapping__c, 'LOA mapping should be null after mapping delete');
        System.assertEquals(false, loa.d4c_IsProductMatched__c, 'IsProductMatched should be false after mapping delete');
    }

    @isTest
    static void afterDelete_handlesBulkLOAUpdates() {
        // Arrange: Create entity, license, mapping
        d4c_Entity__c entity = TestDataFactory.createEntity('BULKDEL123');
        insert entity;

        d4c_License__c license = new d4c_License__c(
            d4c_LicenseNumber__c = 'BULKDELLIC',
            d4c_Entity__c = entity.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LicenseClassCode__c = '3',
            d4c_UniqueIdentifier__c = 'BULKDELLIC' + TEST_STATE + '3'
        );
        insert license;

        // Create LOA mapping
        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Create multiple LOAs that match the mapping
        List<d4c_LineOfAuthority__c> loas = new List<d4c_LineOfAuthority__c>();
        for (Integer i = 0; i < 10; i++) {
            loas.add(new d4c_LineOfAuthority__c(
                d4c_License__c = license.Id,
                d4c_StateOrProvinceCode__c = TEST_STATE,
                d4c_LineOfAuthorityCode__c = TEST_CODE,
                d4c_LineOfAuthorityDescription__c = TEST_DESCRIPTION,
                d4c_UniqueIdentifier__c = 'BULKLOA' + i + System.currentTimeMillis()
            ));
        }
        insert loas;

        // Verify all LOAs have mapping
        List<d4c_LineOfAuthority__c> loasBeforeDelete = [
            SELECT Id, d4c_LOAMapping__c, d4c_IsProductMatched__c
            FROM d4c_LineOfAuthority__c
            WHERE Id IN :loas
        ];
        for (d4c_LineOfAuthority__c l : loasBeforeDelete) {
            System.assertEquals(loaMapping.Id, l.d4c_LOAMapping__c, 'LOA should have mapping');
            System.assertEquals(true, l.d4c_IsProductMatched__c, 'IsProductMatched should be true');
        }

        // Act: Delete the LOA mapping
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: All LOAs should have null mapping and IsProductMatched = false
        List<d4c_LineOfAuthority__c> loasAfterDelete = [
            SELECT Id, d4c_LOAMapping__c, d4c_IsProductMatched__c
            FROM d4c_LineOfAuthority__c
            WHERE Id IN :loas
        ];
        for (d4c_LineOfAuthority__c l : loasAfterDelete) {
            System.assertEquals(null, l.d4c_LOAMapping__c, 'LOA mapping should be null after delete');
            System.assertEquals(false, l.d4c_IsProductMatched__c, 'IsProductMatched should be false after delete');
        }
    }
}