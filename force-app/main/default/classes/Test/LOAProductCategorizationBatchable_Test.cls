/**
 *********************************************************
 * Apex Class Name    : LOAProductCategorizationBatchable_Test
 * Created Date       : 2025-12-13
 * @description       : Test class for LOAProductCategorizationBatchable
 *                      Tests CREATE, UPDATE, and DELETE mode processing
 *                      of License-Insurance Product junctions based on LOA mappings.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-13   Stefan Nidzovic         Initial Version
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

        // Create Producer
        ht_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        // Create License
        ht_License__c license = new ht_License__c(
            ht_LicenseNumber__c = 'BATCHLIC123',
            ht_Producer__c = producer.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LicenseClassCode__c = '3',
            ht_UniqueIdentifier__c = 'BATCHLIC123CA3'
        );
        insert license;

        // Create LOA Insurance Product Mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, TEST_LOA_CODE, TEST_LOA_DESCRIPTION, true
        );

        // Create Insurance Product
        ht_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(
            'Life Insurance', TEST_STATE, true
        );

        // Create Junction between Mapping and Product
        ht_Insurance_Product_LOA_Mapping__c productMappingJunction = TestDataFactory.createInsuranceProductLOAMappingJunction(
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
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c product = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping populated (simulating post-trigger state)
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mapping.Id,
            ht_UniqueIdentifier__c = 'CREATEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: License-Insurance Product junction should be created
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id, ht_License__c, ht_InsuranceProduct__c, ht_UniqueIdentifier__c
            FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id
        ];

        System.assertEquals(1, junctions.size(), 'Should create 1 License-Product junction');
        System.assertEquals(license.Id, junctions[0].ht_License__c, 'Junction should link to correct License');
        System.assertEquals(product.Id, junctions[0].ht_InsuranceProduct__c, 'Junction should link to correct Product');
    }

    @isTest
    static void createMode_skipsLoasWithoutMapping() {
        // Arrange: Get test data
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        // Create LOA without mapping (null ht_LOAMapping__c)
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = 'XX',
            ht_LineOfAuthorityCode__c = '999',
            ht_LineOfAuthorityDescription__c = 'No Mapping Type',
            ht_LOAMapping__c = null,
            ht_UniqueIdentifier__c = 'NOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: No junctions should be created
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Should not create junctions for LOAs without mapping');
    }

    @isTest
    static void createMode_handlesMultipleProductsPerMapping() {
        // Arrange: Create second product linked to same mapping
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        // Create second insurance product
        ht_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct(
            'Health Insurance', TEST_STATE, true
        );

        // Link second product to mapping
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        ht_Insurance_Product_LOA_Mapping__c productMappingJunction2 = TestDataFactory.createInsuranceProductLOAMappingJunction(
            product2.Id, mapping.Id, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mapping.Id,
            ht_UniqueIdentifier__c = 'MULTIPRODUCT' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Should create junction for each product linked to the mapping
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id, ht_InsuranceProduct__c
            FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(2, junctions.size(), 'Should create junction for each product linked to mapping');
    }

    @isTest
    static void createMode_preventsDuplicateJunctions() {
        // Arrange: Get test data
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c product = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create existing junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c existingJunction = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = product.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mapping.Id,
            ht_UniqueIdentifier__c = 'DUPLICATE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode (should upsert, not fail on duplicate)
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Should still have only 1 junction (upsert should not duplicate)
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(1, junctions.size(), 'Upsert should prevent duplicate junctions');
    }

    // ============================================================
    // UPDATE MODE TESTS
    // ============================================================

    @isTest
    static void updateMode_deletesOldAndCreatesNewJunctions() {
        // Arrange: Create two mappings with different products
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c productA = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create mapping B with different product
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        ht_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create LOA initially linked to mapping A
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mappingA.Id,
            ht_UniqueIdentifier__c = 'UPDATEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create existing junction for mapping A's product
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c existingJunction = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = productA.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productA.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create old LOA version (before update)
        ht_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to point to mapping B
        loa.ht_LineOfAuthorityCode__c = '12';
        loa.ht_LineOfAuthorityDescription__c = 'Property Insurance';
        loa.ht_LOAMapping__c = mappingB.Id;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        Map<Id, ht_LineOfAuthority__c> oldLoaMap = new Map<Id, ht_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Old junction (productA) should be deleted, new junction (productB) should exist
        List<ht_License_Insurance_Product__c> junctionsForA = [
            SELECT Id FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id AND ht_InsuranceProduct__c = :productA.Id
        ];
        List<ht_License_Insurance_Product__c> junctionsForB = [
            SELECT Id FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id AND ht_InsuranceProduct__c = :productB.Id
        ];

        System.assertEquals(0, junctionsForA.size(), 'Old junction should be deleted');
        System.assertEquals(1, junctionsForB.size(), 'New junction should be created');
    }

    @isTest
    static void updateMode_handlesNullToMappingChange() {
        // Arrange: LOA changes from no mapping to having a mapping
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c product = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create LOA initially without mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = 'XX',
            ht_LineOfAuthorityCode__c = '999',
            ht_LineOfAuthorityDescription__c = 'No Match',
            ht_LOAMapping__c = null,
            ht_UniqueIdentifier__c = 'NULLTOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create old LOA version (with null mapping)
        ht_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to have matching fields and mapping
        loa.ht_StateOrProvinceCode__c = TEST_STATE;
        loa.ht_LineOfAuthorityCode__c = TEST_LOA_CODE;
        loa.ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION;
        loa.ht_LOAMapping__c = mapping.Id;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        Map<Id, ht_LineOfAuthority__c> oldLoaMap = new Map<Id, ht_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be created for the new mapping
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(1, junctions.size(), 'Junction should be created when mapping changes from null');
    }

    @isTest
    static void updateMode_handlesMappingToNullChange() {
        // Arrange: LOA changes from having a mapping to no mapping
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c product = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mapping.Id,
            ht_UniqueIdentifier__c = 'MAPPINGTONULL' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create existing junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c existingJunction = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = product.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert existingJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Create old LOA version (with mapping)
        ht_LineOfAuthority__c oldLoa = loa.clone(true, true, true, true);

        // Update LOA to have no mapping
        loa.ht_StateOrProvinceCode__c = 'XX';
        loa.ht_LineOfAuthorityCode__c = '999';
        loa.ht_LineOfAuthorityDescription__c = 'No Match';
        loa.ht_LOAMapping__c = null;

        // Reset batch test state

        // Act: Run batch in UPDATE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        Map<Id, ht_LineOfAuthority__c> oldLoaMap = new Map<Id, ht_LineOfAuthority__c>{ loa.Id => oldLoa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(loaList, oldLoaMap);
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be deleted when mapping changes to null
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Junction should be deleted when mapping changes to null');
    }

    // ============================================================
    // DELETE MODE TESTS
    // ============================================================

    @isTest
    static void deleteMode_deletesJunctionsForDeletedLoas() {
        // Arrange: Get test data
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mapping = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c product = [SELECT Id FROM ht_Insurance_Product__c LIMIT 1];

        // Create LOA with mapping
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mapping.Id,
            ht_UniqueIdentifier__c = 'DELETEMODE' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create junction that should be deleted
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c junction = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = product.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id],
            'Junction should exist before delete');

        // Reset batch test state

        // Act: Run batch in DELETE mode
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.DELETE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert: Junction should be deleted
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id FROM ht_License_Insurance_Product__c WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(0, junctions.size(), 'Junction should be deleted when LOA is deleted');
    }

    @isTest
    static void deleteMode_skipsLoasWithoutMapping() {
        // Arrange: LOA without mapping (nothing to delete)
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];

        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = 'XX',
            ht_LineOfAuthorityCode__c = '999',
            ht_LineOfAuthorityDescription__c = 'No Mapping',
            ht_LOAMapping__c = null,
            ht_UniqueIdentifier__c = 'DELETENOMAPPING' + System.currentTimeMillis()
        );
        insert loa;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in DELETE mode (should complete without error)
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loa };
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
    // License's ht_License_Products__c shows both products.
    // ============================================================

    @isTest
    static void scenario3_multipleLoasForSameLicense_bothMappedAndBothProductsInPicklist() {
        // Arrange: Get existing test data
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c productA = [SELECT Id, ht_ProductName__c FROM ht_Insurance_Product__c LIMIT 1];

        // Create second mapping with different LOA code and second product
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        ht_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create two LOAs for the same License with different mappings
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        Long timestamp = System.currentTimeMillis();
        ht_LineOfAuthority__c loaA = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mappingA.Id,
            ht_UniqueIdentifier__c = 'SCENARIO3A' + timestamp
        );
        ht_LineOfAuthority__c loaB = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = '12',
            ht_LineOfAuthorityDescription__c = 'Property Insurance',
            ht_LOAMapping__c = mappingB.Id,
            ht_UniqueIdentifier__c = 'SCENARIO3B' + timestamp
        );
        insert new List<ht_LineOfAuthority__c>{ loaA, loaB };
        LineOfAuthorityTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Reset batch test state

        // Act: Run batch in CREATE mode for both LOAs
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loaA, loaB };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.CREATE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert 1: Both LOAs should be mapped
        List<ht_LineOfAuthority__c> insertedLoas = [
            SELECT Id, ht_LOAMapping__c
            FROM ht_LineOfAuthority__c
            WHERE Id IN (:loaA.Id, :loaB.Id)
        ];
        System.assertEquals(2, insertedLoas.size(), 'Should have 2 LOAs');
        for (ht_LineOfAuthority__c loa : insertedLoas) {
            System.assertNotEquals(null, loa.ht_LOAMapping__c, 'LOA should have mapping populated');
        }

        // Assert 2: Two junctions should be created (one for each product)
        List<ht_License_Insurance_Product__c> junctions = [
            SELECT Id, ht_License__c, ht_InsuranceProduct__c
            FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(2, junctions.size(), 'Should have 2 License-Product junctions');

        // Assert 3: License's ht_License_Products__c should contain both product names
        ht_License__c updatedLicense = [
            SELECT Id, ht_License_Products__c
            FROM ht_License__c
            WHERE Id = :license.Id
        ];
        System.assertNotEquals(null, updatedLicense.ht_License_Products__c,
            'License should have products in picklist');
        System.assert(updatedLicense.ht_License_Products__c.contains(productA.ht_ProductName__c),
            'License picklist should contain first product: ' + productA.ht_ProductName__c);
        System.assert(updatedLicense.ht_License_Products__c.contains(productB.ht_ProductName__c),
            'License picklist should contain second product: ' + productB.ht_ProductName__c);
    }

    // ============================================================
    // SCENARIO 5: Delete LOA with Remaining LOAs
    // Verifies that when one LOA is deleted but another remains for the
    // same License, only the deleted LOA's product is removed from the
    // License's ht_License_Products__c while the remaining product stays.
    // ============================================================

    @isTest
    static void scenario5_deleteLoaWithRemainingLoas_onlyDeletedProductRemovedFromPicklist() {
        // Arrange: Get existing test data
        ht_License__c license = [SELECT Id FROM ht_License__c WHERE ht_LicenseNumber__c = 'BATCHLIC123' LIMIT 1];
        ht_LOA_Insurance_Product_Mapping__c mappingA = [SELECT Id FROM ht_LOA_Insurance_Product_Mapping__c LIMIT 1];
        ht_Insurance_Product__c productA = [SELECT Id, ht_ProductName__c FROM ht_Insurance_Product__c LIMIT 1];

        // Create second mapping with different LOA code and second product
        ht_LOA_Insurance_Product_Mapping__c mappingB = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '12', 'Property Insurance', true
        );
        ht_Insurance_Product__c productB = TestDataFactory.createInsuranceProduct(
            'Property Product', TEST_STATE, true
        );
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        TestDataFactory.createInsuranceProductLOAMappingJunction(productB.Id, mappingB.Id, true);
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;

        // Create two LOAs for the same License with different mappings
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        Long timestamp = System.currentTimeMillis();
        ht_LineOfAuthority__c loaA = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = TEST_LOA_CODE,
            ht_LineOfAuthorityDescription__c = TEST_LOA_DESCRIPTION,
            ht_LOAMapping__c = mappingA.Id,
            ht_UniqueIdentifier__c = 'SCENARIO5A' + timestamp
        );
        ht_LineOfAuthority__c loaB = new ht_LineOfAuthority__c(
            ht_License__c = license.Id,
            ht_StateOrProvinceCode__c = TEST_STATE,
            ht_LineOfAuthorityCode__c = '12',
            ht_LineOfAuthorityDescription__c = 'Property Insurance',
            ht_LOAMapping__c = mappingB.Id,
            ht_UniqueIdentifier__c = 'SCENARIO5B' + timestamp
        );
        insert new List<ht_LineOfAuthority__c>{ loaA, loaB };
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Create both junctions and update License picklist
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c junctionA = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = productA.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productA.Id)
        );
        ht_License_Insurance_Product__c junctionB = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = productB.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(productB.Id)
        );
        insert new List<ht_License_Insurance_Product__c>{ junctionA, junctionB };

        // Set License picklist to have both products
        ht_License__c licenseToUpdate = new ht_License__c(
            Id = license.Id,
            ht_License_Products__c = productA.ht_ProductName__c + ';' + productB.ht_ProductName__c
        );
        update licenseToUpdate;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify setup: License has both products
        ht_License__c licenseBeforeDelete = [
            SELECT Id, ht_License_Products__c
            FROM ht_License__c
            WHERE Id = :license.Id
        ];
        System.assert(licenseBeforeDelete.ht_License_Products__c.contains(productA.ht_ProductName__c),
            'Setup: License should have product A');
        System.assert(licenseBeforeDelete.ht_License_Products__c.contains(productB.ht_ProductName__c),
            'Setup: License should have product B');

        // Reset batch test state

        // Act: Run batch in DELETE mode for only loaB (keep loaA)
        Test.startTest();
        List<ht_LineOfAuthority__c> loaList = new List<ht_LineOfAuthority__c>{ loaB };
        LOAProductCategorizationBatchable batchJob = new LOAProductCategorizationBatchable(
            loaList,
            NIPREnums.OperationMode.DELETE_MODE
        );
        Database.executeBatch(batchJob, 100);
        Test.stopTest();

        // Assert 1: Junction for product B should be deleted, junction for product A should remain
        List<ht_License_Insurance_Product__c> remainingJunctions = [
            SELECT Id, ht_InsuranceProduct__c
            FROM ht_License_Insurance_Product__c
            WHERE ht_License__c = :license.Id
        ];
        System.assertEquals(1, remainingJunctions.size(), 'Should have 1 remaining junction');
        System.assertEquals(productA.Id, remainingJunctions[0].ht_InsuranceProduct__c,
            'Remaining junction should be for product A');

        // Assert 2: License picklist should have product A but not product B
        ht_License__c updatedLicense = [
            SELECT Id, ht_License_Products__c
            FROM ht_License__c
            WHERE Id = :license.Id
        ];
        System.assertNotEquals(null, updatedLicense.ht_License_Products__c,
            'License should still have products in picklist');
        System.assert(updatedLicense.ht_License_Products__c.contains(productA.ht_ProductName__c),
            'License picklist should still contain product A: ' + productA.ht_ProductName__c);
        System.assert(!updatedLicense.ht_License_Products__c.contains(productB.ht_ProductName__c),
            'License picklist should NOT contain deleted product B: ' + productB.ht_ProductName__c);
    }

}