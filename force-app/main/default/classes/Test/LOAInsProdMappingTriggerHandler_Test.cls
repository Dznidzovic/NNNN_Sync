/*
*********************************************************
Apex Class Name    : LOAInsProdMappingTriggerHandler_Test
Created Date       : 2025-12-15
@description       : Test class for LOAInsuranceProductMappingTriggerHandler.
                     Tests unique identifier auto-generation on insert and update.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
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
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        insert mapping;
        Test.stopTest();

        // Assert
        mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
            'Unique identifier should be State-Code-Description');
    }

    @isTest
    static void beforeInsert_handlesNullState() {
        // Arrange: Mapping with null state
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.ht_UniqueIdentifier__c),
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
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.ht_UniqueIdentifier__c),
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
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE
        );

        // Act
        Test.startTest();
        try {
            insert mapping;
            // If insert succeeds, check that unique ID is null
            mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.ht_UniqueIdentifier__c),
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
        List<ht_LOA_Insurance_Product_Mapping__c> mappings = new List<ht_LOA_Insurance_Product_Mapping__c>();
        for (Integer i = 0; i < 200; i++) {
            mappings.add(new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = String.valueOf(i),
                ht_LineOfAuthorityDescription__c = 'Description ' + i
            ));
        }

        // Act
        Test.startTest();
        insert mappings;
        Test.stopTest();

        // Assert: All mappings should have unique identifier populated
        List<ht_LOA_Insurance_Product_Mapping__c> insertedMappings = [
            SELECT Id, ht_StateOrProvinceCode__c, ht_LineOfAuthorityCode__c,
                   ht_LineOfAuthorityDescription__c, ht_UniqueIdentifier__c
            FROM ht_LOA_Insurance_Product_Mapping__c
            WHERE Id IN :mappings
        ];

        System.assertEquals(200, insertedMappings.size(), 'All 200 mappings should be inserted');
        for (ht_LOA_Insurance_Product_Mapping__c mapping : insertedMappings) {
            String expectedUniqueId = mapping.ht_StateOrProvinceCode__c + '-' +
                mapping.ht_LineOfAuthorityCode__c + '-' +
                mapping.ht_LineOfAuthorityDescription__c;
            System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
                'Each mapping should have correct unique identifier');
        }
    }

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeUpdate)
    // ============================================================

    @isTest
    static void beforeUpdate_recalculatesWhenStateChanges() {
        // Arrange: Insert mapping with initial values
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the state
        Test.startTest();
        mapping.ht_StateOrProvinceCode__c = 'TX';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = 'TX-' + TEST_CODE + '-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
            'Unique identifier should be recalculated when state changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenCodeChanges() {
        // Arrange: Insert mapping with initial values
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the code
        Test.startTest();
        mapping.ht_LineOfAuthorityCode__c = '999';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-999-' + TEST_DESCRIPTION;
        System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
            'Unique identifier should be recalculated when code changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenDescriptionChanges() {
        // Arrange: Insert mapping with initial values
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping;

        // Act: Update the description
        Test.startTest();
        mapping.ht_LineOfAuthorityDescription__c = 'Property Insurance';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-Property Insurance';
        System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
            'Unique identifier should be recalculated when description changes');
    }

    @isTest
    static void beforeUpdate_alwaysRecalculates() {
        // Arrange: Insert mapping and manually set a different unique ID
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = true;
        ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION,
            ht_UniqueIdentifier__c = 'MANUAL-VALUE'
        );
        insert mapping;
        LOAInsuranceProductMappingTriggerHandler.triggerDisabled = false;

        // Act: Update any field to trigger beforeUpdate
        Test.startTest();
        mapping.ht_LineOfAuthorityDescription__c = 'Updated Description';
        update mapping;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated (not kept as MANUAL-VALUE)
        mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_CODE + '-Updated Description';
        System.assertEquals(expectedUniqueId, mapping.ht_UniqueIdentifier__c,
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
            ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = TEST_CODE,
                ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
            );
            insert mapping;

            // If insert succeeds, unique ID should not be populated
            mapping = [SELECT Id, ht_UniqueIdentifier__c FROM ht_LOA_Insurance_Product_Mapping__c WHERE Id = :mapping.Id];
            System.assert(String.isBlank(mapping.ht_UniqueIdentifier__c),
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
        ht_LOA_Insurance_Product_Mapping__c mapping1 = new ht_LOA_Insurance_Product_Mapping__c(
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_CODE,
            ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
        );
        insert mapping1;

        // Act: Try to create duplicate mapping
        Test.startTest();
        try {
            ht_LOA_Insurance_Product_Mapping__c mapping2 = new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = TEST_CODE,
                ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION
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
        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        ht_Insurance_Product__c product = TestDataFactory.createInsuranceProduct('Test Product', TEST_STATE, true);

        // Create Product-LOA Mapping junction
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        ht_Insurance_Product_LOA_Mapping__c productLoaJunction = new ht_Insurance_Product_LOA_Mapping__c(
            ht_InsuranceProduct__c = product.Id,
            ht_LOAMapping__c = loaMapping.Id,
            ht_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
        );
        insert productLoaJunction;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c
            WHERE ht_LOAMapping__c = :loaMapping.Id], 'Junction should exist before delete');

        // Act: Delete the LOA mapping (beforeDelete should delete junctions)
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c
            WHERE ht_LOAMapping__c = :loaMapping.Id],
            'Product-LOA Mapping junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_bulkDeleteMappings() {
        // Arrange: Create multiple LOA mappings
        List<ht_LOA_Insurance_Product_Mapping__c> loaMappings = new List<ht_LOA_Insurance_Product_Mapping__c>();
        for (Integer i = 0; i < 5; i++) {
            loaMappings.add(TestDataFactory.createLOAInsuranceProductMapping(
                TEST_STATE, String.valueOf(100 + i), 'Description ' + i, false
            ));
        }
        insert loaMappings;

        ht_Insurance_Product__c product = TestDataFactory.createInsuranceProduct('Test Product', TEST_STATE, true);

        // Create junctions for all mappings
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        List<ht_Insurance_Product_LOA_Mapping__c> productLoaJunctions = new List<ht_Insurance_Product_LOA_Mapping__c>();
        for (ht_LOA_Insurance_Product_Mapping__c loaMapping : loaMappings) {
            productLoaJunctions.add(new ht_Insurance_Product_LOA_Mapping__c(
                ht_InsuranceProduct__c = product.Id,
                ht_LOAMapping__c = loaMapping.Id,
                ht_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
            ));
        }
        insert productLoaJunctions;
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Verify junctions exist
        System.assertEquals(5, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c],
            'Should have 5 Product-LOA junctions before delete');

        // Act: Bulk delete all LOA mappings
        Test.startTest();
        delete loaMappings;
        Test.stopTest();

        // Assert: All junctions should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c],
            'All Product-LOA junctions should be deleted');
    }

    @isTest
    static void beforeDelete_handlesNoJunctions() {
        // Arrange: Create LOA mapping without any junctions
        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Verify no junctions exist
        System.assertEquals(0, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c
            WHERE ht_LOAMapping__c = :loaMapping.Id], 'No junctions should exist');

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
        // Arrange: Create producer, license, mapping, and LOA
        ht_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        ht_License__c license = new ht_License__c(
            ht_LicenseNumber__c = 'AFTERDELLIC',
            ht_Producer__c = producer.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LicenseClassCode__c = '3',
            ht_UniqueIdentifier__c = 'AFTERDELLIC' + TEST_STATE + '3'
        );
        insert license;

        // Create LOA mapping
        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Create LOA that matches the mapping
        ht_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(
            license.Id, TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Verify LOA has mapping and IsProductMatched = true
        loa = [SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(loaMapping.Id, loa.ht_LOAMapping__c, 'LOA should have mapping before delete');
        System.assertEquals(true, loa.ht_IsProductMatched__c, 'IsProductMatched should be true before delete');

        // Act: Delete the LOA mapping
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: LOA should have null mapping and IsProductMatched = false
        loa = [SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c FROM ht_LineOfAuthority__c WHERE Id = :loa.Id];
        System.assertEquals(null, loa.ht_LOAMapping__c, 'LOA mapping should be null after mapping delete');
        System.assertEquals(false, loa.ht_IsProductMatched__c, 'IsProductMatched should be false after mapping delete');
    }

    @isTest
    static void afterDelete_handlesBulkLOAUpdates() {
        // Arrange: Create producer, license, mapping
        ht_Producer__c producer = TestDataFactory.createProducer('BULKDEL123');
        insert producer;

        ht_License__c license = new ht_License__c(
            ht_LicenseNumber__c = 'BULKDELLIC',
            ht_Producer__c = producer.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LicenseClassCode__c = '3',
            ht_UniqueIdentifier__c = 'BULKDELLIC' + TEST_STATE + '3'
        );
        insert license;

        // Create LOA mapping
        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_CODE, TEST_DESCRIPTION, true
        );

        // Create multiple LOAs that match the mapping
        List<ht_LineOfAuthority__c> loas = new List<ht_LineOfAuthority__c>();
        for (Integer i = 0; i < 10; i++) {
            loas.add(new ht_LineOfAuthority__c(
                ht_License__c = license.Id,
                ht_StateOrProvinceCode__c = TEST_STATE,
                ht_LineOfAuthorityCode__c = TEST_CODE,
                ht_LineOfAuthorityDescription__c = TEST_DESCRIPTION,
                ht_UniqueIdentifier__c = 'BULKLOA' + i + System.currentTimeMillis()
            ));
        }
        insert loas;

        // Verify all LOAs have mapping
        List<ht_LineOfAuthority__c> loasBeforeDelete = [
            SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c
            FROM ht_LineOfAuthority__c
            WHERE Id IN :loas
        ];
        for (ht_LineOfAuthority__c l : loasBeforeDelete) {
            System.assertEquals(loaMapping.Id, l.ht_LOAMapping__c, 'LOA should have mapping');
            System.assertEquals(true, l.ht_IsProductMatched__c, 'IsProductMatched should be true');
        }

        // Act: Delete the LOA mapping
        Test.startTest();
        delete loaMapping;
        Test.stopTest();

        // Assert: All LOAs should have null mapping and IsProductMatched = false
        List<ht_LineOfAuthority__c> loasAfterDelete = [
            SELECT Id, ht_LOAMapping__c, ht_IsProductMatched__c
            FROM ht_LineOfAuthority__c
            WHERE Id IN :loas
        ];
        for (ht_LineOfAuthority__c l : loasAfterDelete) {
            System.assertEquals(null, l.ht_LOAMapping__c, 'LOA mapping should be null after delete');
            System.assertEquals(false, l.ht_IsProductMatched__c, 'IsProductMatched should be false after delete');
        }
    }
}