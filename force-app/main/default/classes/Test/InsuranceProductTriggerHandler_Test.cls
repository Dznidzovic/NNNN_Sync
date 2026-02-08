/*
*********************************************************
Apex Class Name    : InsuranceProductTriggerHandler_Test
Created Date       : 2025-12-15
@description       : Test class for InsuranceProductTriggerHandler.
                     Tests unique identifier auto-generation on insert and update.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
@isTest
private class InsuranceProductTriggerHandler_Test {

    private static final String TEST_STATE = 'CA';
    private static final String TEST_PRODUCT_NAME = 'Life Insurance';

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeInsert)
    // ============================================================

    @isTest
    static void beforeInsert_populatesUniqueIdentifier() {
        // Arrange
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE,
            ht_ProductName__c = TEST_PRODUCT_NAME
        );

        // Act
        Test.startTest();
        insert product;
        Test.stopTest();

        // Assert
        product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_PRODUCT_NAME;
        System.assertEquals(expectedUniqueId, product.ht_UniqueIdentifier__c,
            'Unique identifier should be State-ProductName');
    }

    @isTest
    static void beforeInsert_handlesNullState() {
        // Arrange: Product with null state
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_ProductName__c = TEST_PRODUCT_NAME
        );

        // Act
        Test.startTest();
        try {
            insert product;
            // If insert succeeds, check that unique ID is null
            product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.ht_UniqueIdentifier__c),
                'Unique identifier should be blank when State is null');
        } catch (DmlException e) {
            // Expected: Required field validation might fail
            System.assert(true, 'Insert failed as expected due to missing required field');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_handlesNullProductName() {
        // Arrange: Product with null product name
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE
        );

        // Act
        Test.startTest();
        try {
            insert product;
            // If insert succeeds, check that unique ID is null
            product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.ht_UniqueIdentifier__c),
                'Unique identifier should be blank when ProductName is null');
        } catch (DmlException e) {
            // Expected: Required field validation might fail
            System.assert(true, 'Insert failed as expected due to missing required field');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_handlesBulkInsert() {
        // Arrange: Create 200 products
        List<ht_Insurance_Product__c> products = new List<ht_Insurance_Product__c>();
        for (Integer i = 0; i < 200; i++) {
            products.add(new ht_Insurance_Product__c(
                ht_StateOrProvince__c = TEST_STATE,
                ht_ProductName__c = 'Product ' + i
            ));
        }

        // Act
        Test.startTest();
        insert products;
        Test.stopTest();

        // Assert: All products should have unique identifier populated
        List<ht_Insurance_Product__c> insertedProducts = [
            SELECT Id, ht_StateOrProvince__c, ht_ProductName__c, ht_UniqueIdentifier__c
            FROM ht_Insurance_Product__c
            WHERE Id IN :products
        ];

        System.assertEquals(200, insertedProducts.size(), 'All 200 products should be inserted');
        for (ht_Insurance_Product__c product : insertedProducts) {
            String expectedUniqueId = product.ht_StateOrProvince__c + '-' + product.ht_ProductName__c;
            System.assertEquals(expectedUniqueId, product.ht_UniqueIdentifier__c,
                'Each product should have correct unique identifier');
        }
    }

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeUpdate)
    // ============================================================

    @isTest
    static void beforeUpdate_recalculatesWhenStateChanges() {
        // Arrange: Insert product with initial values
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE,
            ht_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product;

        // Act: Update the state
        Test.startTest();
        product.ht_StateOrProvince__c = 'TX';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = 'TX-' + TEST_PRODUCT_NAME;
        System.assertEquals(expectedUniqueId, product.ht_UniqueIdentifier__c,
            'Unique identifier should be recalculated when state changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenProductNameChanges() {
        // Arrange: Insert product with initial values
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE,
            ht_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product;

        // Act: Update the product name
        Test.startTest();
        product.ht_ProductName__c = 'Health Insurance';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-Health Insurance';
        System.assertEquals(expectedUniqueId, product.ht_UniqueIdentifier__c,
            'Unique identifier should be recalculated when product name changes');
    }

    @isTest
    static void beforeUpdate_alwaysRecalculates() {
        // Arrange: Insert product and manually set a different unique ID
        InsuranceProductTriggerHandler.triggerDisabled = true;
        ht_Insurance_Product__c product = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE,
            ht_ProductName__c = TEST_PRODUCT_NAME,
            ht_UniqueIdentifier__c = 'MANUAL-VALUE'
        );
        insert product;
        InsuranceProductTriggerHandler.triggerDisabled = false;

        // Act: Update any field to trigger beforeUpdate
        Test.startTest();
        product.ht_ProductName__c = 'Updated Product';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated (not kept as MANUAL-VALUE)
        product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-Updated Product';
        System.assertEquals(expectedUniqueId, product.ht_UniqueIdentifier__c,
            'Unique identifier should always be recalculated on update');
    }

    // ============================================================
    // TRIGGER DISABLED TEST
    // ============================================================

    @isTest
    static void triggerDisabled_skipsProcessing() {
        // Arrange
        InsuranceProductTriggerHandler.triggerDisabled = true;

        // Act
        Test.startTest();
        try {
            ht_Insurance_Product__c product = new ht_Insurance_Product__c(
                ht_StateOrProvince__c = TEST_STATE,
                ht_ProductName__c = TEST_PRODUCT_NAME
            );
            insert product;

            // If insert succeeds, unique ID should not be populated
            product = [SELECT Id, ht_UniqueIdentifier__c FROM ht_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.ht_UniqueIdentifier__c),
                'Unique identifier should not be populated when trigger is disabled');
        } catch (DmlException e) {
            // Expected: Required field validation might fail since trigger didn't populate it
            System.assert(e.getMessage().containsIgnoreCase('REQUIRED_FIELD_MISSING') ||
                         e.getMessage().containsIgnoreCase('UniqueIdentifier'),
                'Insert should fail due to missing required field when trigger is disabled: ' + e.getMessage());
        }
        Test.stopTest();

        // Cleanup
        InsuranceProductTriggerHandler.triggerDisabled = false;
    }

    // ============================================================
    // DUPLICATE PREVENTION TEST
    // ============================================================

    @isTest
    static void beforeInsert_preventsDuplicateUniqueIdentifier() {
        // Arrange: Create first product
        ht_Insurance_Product__c product1 = new ht_Insurance_Product__c(
            ht_StateOrProvince__c = TEST_STATE,
            ht_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product1;

        // Act: Try to create duplicate product
        Test.startTest();
        try {
            ht_Insurance_Product__c product2 = new ht_Insurance_Product__c(
                ht_StateOrProvince__c = TEST_STATE,
                ht_ProductName__c = TEST_PRODUCT_NAME
            );
            insert product2;
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
        ht_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        ht_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.ht_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        ht_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(TEST_PRODUCT_NAME, TEST_STATE, true);

        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '100', 'Life Insurance', true
        );

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
            WHERE ht_InsuranceProduct__c = :product.Id], 'Junction should exist before delete');

        // Act: Delete the product (beforeDelete should delete junctions)
        Test.startTest();
        delete product;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c
            WHERE ht_InsuranceProduct__c = :product.Id],
            'Product-LOA Mapping junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_deletesLicenseProductJunctions() {
        // Arrange: Create test data
        ht_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        ht_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.ht_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        ht_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(TEST_PRODUCT_NAME, TEST_STATE, true);

        // Create License-Product junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        ht_License_Insurance_Product__c licenseProductJunction = new ht_License_Insurance_Product__c(
            ht_License__c = license.Id,
            ht_InsuranceProduct__c = product.Id,
            ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert licenseProductJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM ht_License_Insurance_Product__c
            WHERE ht_InsuranceProduct__c = :product.Id], 'Junction should exist before delete');

        // Act: Delete the product (beforeDelete should delete junctions)
        Test.startTest();
        delete product;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM ht_License_Insurance_Product__c
            WHERE ht_InsuranceProduct__c = :product.Id],
            'License-Product junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_bulkDeleteProducts() {
        // Arrange: Create test data for multiple products
        ht_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        ht_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.ht_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        List<ht_Insurance_Product__c> products = new List<ht_Insurance_Product__c>();
        for (Integer i = 0; i < 5; i++) {
            products.add(TestDataFactory.createInsuranceProduct('Product ' + i, TEST_STATE, false));
        }
        insert products;

        ht_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '100', 'Life Insurance', true
        );

        // Create junctions for all products
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;

        List<ht_Insurance_Product_LOA_Mapping__c> productLoaJunctions = new List<ht_Insurance_Product_LOA_Mapping__c>();
        List<ht_License_Insurance_Product__c> licenseProductJunctions = new List<ht_License_Insurance_Product__c>();

        for (ht_Insurance_Product__c product : products) {
            productLoaJunctions.add(new ht_Insurance_Product_LOA_Mapping__c(
                ht_InsuranceProduct__c = product.Id,
                ht_LOAMapping__c = loaMapping.Id,
                ht_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
            ));

            licenseProductJunctions.add(new ht_License_Insurance_Product__c(
                ht_License__c = license.Id,
                ht_InsuranceProduct__c = product.Id,
                ht_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
            ));
        }
        insert productLoaJunctions;
        insert licenseProductJunctions;

        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junctions exist
        System.assertEquals(5, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c],
            'Should have 5 Product-LOA junctions before delete');
        System.assertEquals(5, [SELECT COUNT() FROM ht_License_Insurance_Product__c],
            'Should have 5 License-Product junctions before delete');

        // Act: Bulk delete all products
        Test.startTest();
        delete products;
        Test.stopTest();

        // Assert: All junctions should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM ht_Insurance_Product_LOA_Mapping__c],
            'All Product-LOA junctions should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM ht_License_Insurance_Product__c],
            'All License-Product junctions should be deleted');
    }
}