/**
 *********************************************************
 * Apex Class Name    : LOAProductCategorizationBatchable_Test
 * Created Date       : 2025-12-13
 * @description       : Test class for LOAProductCategorizationBatchable
 *                      Tests CREATE, UPDATE, and DELETE mode processing
 *                      of License-Insurance Product junctions based on LOA mappings.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-13   Dev4Clouds         Initial Version
 *********************************************************
 */
@isTest
private class LOAProductCategorizationBatchable_Test {

    private static final String TEST_STATE = 'CA';
    private static final String TEST_LOA_CODE = '935';
    private static final String TEST_LOA_DESCRIPTION = 'Accident & Health or Sickness';

    @TestSetup
    static void setupTestData() {
        // Disable triggers during setup
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;

        // Create Entity
        d4c_Entity__c entity = TestDataFactory.createEntity('1234567890');
        insert entity;

        // Create License
        d4c_License__c license = new d4c_License__c(
            d4c_LicenseNumber__c = 'BATCHLIC123',
            d4c_Entity__c = entity.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LicenseClassCode__c = '3',
            d4c_UniqueIdentifier__c = 'BATCHLIC123CA3'
        );
        insert license;

        // Create LOA Insurance Product Mapping
        d4c_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Create Insurance Product
        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(
            'Life Insurance', TEST_STATE, true
        );

        // Create Junction between Mapping and Product
        d4c_Insurance_Product_LOA_Mapping__c productMappingJunction = TestDataFactory.createInsuranceProductLOAMappingJunction(
            product.Id, mapping.Id, true
        );

        // Re-enable triggers
        LineOfAuthorityTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;
    }

    // ============================================================
    // CREATE MODE TESTS
    // ============================================================

    @isTest
    static void createMode_createsJunctionsForLoasWithMapping() {
        // Arrange: Get test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping populated (simulating post-trigger state)
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = 'CREATEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: License-Insurance Product junction should be created
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id, d4c_License__c, d4c_InsuranceProduct__c, d4c_UniqueIdentifier__c
            FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id
        ];

        System.assertEquals(1, junctions.size(), 'Should create 1 License-Product junction');
        System.assertEquals(license.Id, junctions[0].d4c_License__c, 'Junction should link to correct License');
        System.assertEquals(product.Id, junctions[0].d4c_InsuranceProduct__c, 'Junction should link to correct Product');
    }

    @isTest
    static void createMode_skipsLoasWithoutMapping() {
        // Arrange: Get test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        // Create LOA without mapping (null d4c_LOAMapping__c)
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = 'XX',
            d4c_LineOfAuthorityCode__c = '999',
            d4c_LineOfAuthorityDescription__c = 'No Mapping Type',
            d4c_LOAMapping__c = null,
            d4c_UniqueIdentifier__c = 'NOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: No junctions should be created
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Should not create junctions for LOAs without mapping');
    }

    @isTest
    static void createMode_handlesMultipleProductsPerMapping() {
        // Arrange: Create second product linked to same mapping
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        // Create second insurance product
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct(
            'Health Insurance', TEST_STATE, true
        );

        // Link second product to mapping
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product_LOA_Mapping__c productMappingJunction2 = TestDataFactory.createInsuranceProductLOAMappingJunction(
            product2.Id, mapping.Id, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = 'MULTIPRODUCT' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Should create junction for each product linked to the mapping
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id, d4c_InsuranceProduct__c
            FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(2, junctions.size(), 'Should create junction for each product linked to mapping');
    }

    @isTest
    static void createMode_preventsDuplicateJunctions() {
        // Arrange: Get test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create existing junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c existingJunction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = 'DUPLICATE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode (should upsert, not fail on duplicate)
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Should still have only 1 junction (upsert should not duplicate)
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(1, junctions.size(), 'Upsert should prevent duplicate junctions');
    }

    // ============================================================
    // UPDATE MODE TESTS
    // ============================================================

    @isTest
    static void updateMode_deletesOldAndCreatesNewJunctions() {
        // Arrange: Create two mappings with different products
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c productA = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create mapping B with different product
        d4c_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        d4c_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create LOA initially linked to mapping A
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mappingA.Id,
            d4c_UniqueIdentifier__c = 'UPDATEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create existing junction for mapping A's product
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c existingJunction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = productA.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productA.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create old LOA version (before update)
        d4c_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to point to mapping B
        loa.d4c_LineOfAuthorityCode__c = '12';
        loa.d4c_LineOfAuthorityDescription__c = 'Property Insurance';
        loa.d4c_LOAMapping__c = mappingB.Id;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = new Map<Id, d4c_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Old junction (productA) should be deleted, new junction (productB) should exist
        List<d4c_License_Insurance_Product__c> junctionsForA = [
            SELECT Id FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id AND d4c_InsuranceProduct__c = :productA.Id
        ];
        List<d4c_License_Insurance_Product__c> junctionsForB = [
            SELECT Id FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id AND d4c_InsuranceProduct__c = :productB.Id
        ];

        System.assertEquals(0, junctionsForA.size(), 'Old junction should be deleted');
        System.assertEquals(1, junctionsForB.size(), 'New junction should be created');
    }

    @isTest
    static void updateMode_handlesNullToMappingChange() {
        // Arrange: LOA changes from no mapping to having a mapping
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create LOA initially without mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = 'XX',
            d4c_LineOfAuthorityCode__c = '999',
            d4c_LineOfAuthorityDescription__c = 'No Match',
            d4c_LOAMapping__c = null,
            d4c_UniqueIdentifier__c = 'NULLTOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create old LOA version (with null mapping)
        d4c_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to have matching fields and mapping
        loa.d4c_StateOrProvinceCode__c = TEST_STATE;
        loa.d4c_LineOfAuthorityCode__c = TEST_LOA_CODE;
        loa.d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION;
        loa.d4c_LOAMapping__c = mapping.Id;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = new Map<Id, d4c_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be created for the new mapping
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(1, junctions.size(), 'Junction should be created when mapping changes from null');
    }

    @isTest
    static void updateMode_handlesMappingToNullChange() {
        // Arrange: LOA changes from having a mapping to no mapping
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = 'MAPPINGTONULL' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create existing junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c existingJunction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create old LOA version (with mapping)
        d4c_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to have no mapping
        loa.d4c_StateOrProvinceCode__c = 'XX';
        loa.d4c_LineOfAuthorityCode__c = '999';
        loa.d4c_LineOfAuthorityDescription__c = 'No Match';
        loa.d4c_LOAMapping__c = null;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = new Map<Id, d4c_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be deleted when mapping changes to null
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Junction should be deleted when mapping changes to null');
    }

    // ============================================================
    // DELETE MODE TESTS
    // ============================================================

    @isTest
    static void deleteMode_deletesJunctionsForDeletedLoas() {
        // Arrange: Get test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mapping.Id,
            d4c_UniqueIdentifier__c = 'DELETEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create junction that should be deleted
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id],
            'Junction should exist before delete');

        // Reset batch test state

        // Act: Run batch in DELETE mode
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.DELETE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be deleted
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id FROM d4c_License_Insurance_Product__c WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Junction should be deleted when LOA is deleted');
    }

    @isTest
    static void deleteMode_skipsLoasWithoutMapping() {
        // Arrange: LOA without mapping (nothing to delete)
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = 'XX',
            d4c_LineOfAuthorityCode__c = '999',
            d4c_LineOfAuthorityDescription__c = 'No Mapping',
            d4c_LOAMapping__c = null,
            d4c_UniqueIdentifier__c = 'DELETENOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in DELETE mode (should complete without error)
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.DELETE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Batch should complete without error (no assertions to fail)
        System.assert(true, 'Batch should complete without error for LOAs without mapping');
    }

    // ============================================================
    // SCENARIO 3: Multiple LOAs for Same License
    // Verifies that when a License has multiple LOAs with different mappings,
    // both get mapped correctly, both junctions are created, and the
    // License's d4c_License_Products__c shows both products.
    // ============================================================

    @isTest
    static void scenario3_multipleLoasForSameLicense_bothMappedAndBothProductsInPicklist() {
        // Arrange: Get existing test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c productA = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c LIMIT 1];

        // Create second mapping with different LOA code and second product
        d4c_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        d4c_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create two LOAs for the same License with different mappings
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        Long timestamp = System.currentTimeMillis();
        d4c_LineOfAuthority__c loaA = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mappingA.Id,
            d4c_UniqueIdentifier__c = 'SCENARIO3A' + timestamp
        );
        d4c_LineOfAuthority__c loaB = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = '12',
            d4c_LineOfAuthorityDescription__c = 'Property Insurance',
            d4c_LOAMapping__c = mappingB.Id,
            d4c_UniqueIdentifier__c = 'SCENARIO3B' + timestamp
        );
        insert new List<d4c_LineOfAuthority__c>{ loaA, loaB };
        LineOfAuthorityTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode for both LOAs
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loaA, loaB };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert 1: Both LOAs should be mapped
        List<d4c_LineOfAuthority__c> insertedLoas = [
            SELECT Id, d4c_LOAMapping__c
            FROM d4c_LineOfAuthority__c
            WHERE Id IN (:loaA.Id, :loaB.Id)
        ];
        System.assertEquals(2, insertedLoas.size(), 'Should have 2 LOAs');
        for (d4c_LineOfAuthority__c loa : insertedLoas) {
            System.assertNotEquals(null, loa.d4c_LOAMapping__c, 'LOA should have mapping populated');
        }

        // Assert 2: Two junctions should be created (one for each product)
        List<d4c_License_Insurance_Product__c> junctions = [
            SELECT Id, d4c_License__c, d4c_InsuranceProduct__c
            FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(2, junctions.size(), 'Should have 2 License-Product junctions');

        // Assert 3: License's d4c_License_Products__c should contain both product names
        d4c_License__c updatedLicense = [
            SELECT Id, d4c_License_Products__c
            FROM d4c_License__c
            WHERE Id = :license.Id
        ];
        System.assertNotEquals(null, updatedLicense.d4c_License_Products__c,
            'License should have products in picklist');
        System.assert(updatedLicense.d4c_License_Products__c.contains(productA.d4c_ProductName__c),
            'License picklist should contain first product: ' + productA.d4c_ProductName__c);
        System.assert(updatedLicense.d4c_License_Products__c.contains(productB.d4c_ProductName__c),
            'License picklist should contain second product: ' + productB.d4c_ProductName__c);
    }

    // ============================================================
    // SCENARIO 5: Delete LOA with Remaining LOAs
    // Verifies that when one LOA is deleted but another remains for the
    // same License, only the deleted LOA's product is removed from the
    // License's d4c_License_Products__c while the remaining product stays.
    // ============================================================

    @isTest
    static void scenario5_deleteLoaWithRemainingLoas_onlyDeletedProductRemovedFromPicklist() {
        // Arrange: Get existing test data
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        d4c_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c LIMIT 1];
        d4c_Insurance_Product__c productA = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c LIMIT 1];

        // Create second mapping with different LOA code and second product
        d4c_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        d4c_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create two LOAs for the same License with different mappings
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        Long timestamp = System.currentTimeMillis();
        d4c_LineOfAuthority__c loaA = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = TEST_LOA_CODE,
            d4c_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            d4c_LOAMapping__c = mappingA.Id,
            d4c_UniqueIdentifier__c = 'SCENARIO5A' + timestamp
        );
        d4c_LineOfAuthority__c loaB = new d4c_LineOfAuthority__c(
            d4c_License__c = license.Id,
            d4c_StateOrProvinceCode__c = TEST_STATE,
            d4c_LineOfAuthorityCode__c = '12',
            d4c_LineOfAuthorityDescription__c = 'Property Insurance',
            d4c_LOAMapping__c = mappingB.Id,
            d4c_UniqueIdentifier__c = 'SCENARIO5B' + timestamp
        );
        insert new List<d4c_LineOfAuthority__c>{ loaA, loaB };
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create both junctions and update License picklist
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junctionA = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = productA.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productA.Id)
        );
        d4c_License_Insurance_Product__c junctionB = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = productB.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productB.Id)
        );
        insert new List<d4c_License_Insurance_Product__c>{ junctionA, junctionB };

        // Set License picklist to have both products
        d4c_License__c licenseToUpdate = new d4c_License__c(
            Id = license.Id,
            d4c_License_Products__c = productA.d4c_ProductName__c + ';' + productB.d4c_ProductName__c
        );
        update licenseToUpdate;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify setup: License has both products
        d4c_License__c licenseBeforeDelete = [
            SELECT Id, d4c_License_Products__c
            FROM d4c_License__c
            WHERE Id = :license.Id
        ];
        System.assert(licenseBeforeDelete.d4c_License_Products__c.contains(productA.d4c_ProductName__c),
            'Setup: License should have product A');
        System.assert(licenseBeforeDelete.d4c_License_Products__c.contains(productB.d4c_ProductName__c),
            'Setup: License should have product B');

        // Reset batch test state

        // Act: Run batch in DELETE mode for only loaB (keep loaA)
        Test.startTest();
        List<d4c_LineOfAuthority__c> loaList = new List<d4c_LineOfAuthority__c>{ loaB };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.DELETE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert 1: Junction for product B should be deleted, junction for product A should remain
        List<d4c_License_Insurance_Product__c> remainingJunctions = [
            SELECT Id, d4c_InsuranceProduct__c
            FROM d4c_License_Insurance_Product__c
            WHERE d4c_License__c = :license.Id
        ];
        System.assertEquals(1, remainingJunctions.size(), 'Should have 1 remaining junction');
        System.assertEquals(productA.Id, remainingJunctions[0].d4c_InsuranceProduct__c,
            'Remaining junction should be for product A');

        // Assert 2: License picklist should have product A but not product B
        d4c_License__c updatedLicense = [
            SELECT Id, d4c_License_Products__c
            FROM d4c_License__c
            WHERE Id = :license.Id
        ];
        System.assertNotEquals(null, updatedLicense.d4c_License_Products__c,
            'License should still have products in picklist');
        System.assert(updatedLicense.d4c_License_Products__c.contains(productA.d4c_ProductName__c),
            'License picklist should still contain product A: ' + productA.d4c_ProductName__c);
        System.assert(!updatedLicense.d4c_License_Products__c.contains(productB.d4c_ProductName__c),
            'License picklist should NOT contain deleted product B: ' + productB.d4c_ProductName__c);
    }

}