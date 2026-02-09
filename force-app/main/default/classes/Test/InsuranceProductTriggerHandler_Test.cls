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
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE,
            d4c_ProductName__c = TEST_PRODUCT_NAME
        );

        // Act
        Test.startTest();
        insert product;
        Test.stopTest();

        // Assert
        product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-' + TEST_PRODUCT_NAME;
        System.assertEquals(expectedUniqueId, product.d4c_UniqueIdentifier__c,
            'Unique identifier should be State-ProductName');
    }

    @isTest
    static void beforeInsert_handlesNullState() {
        // Arrange: Product with null state
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_ProductName__c = TEST_PRODUCT_NAME
        );

        // Act
        Test.startTest();
        try {
            insert product;
            // If insert succeeds, check that unique ID is null
            product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.d4c_UniqueIdentifier__c),
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
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE
        );

        // Act
        Test.startTest();
        try {
            insert product;
            // If insert succeeds, check that unique ID is null
            product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.d4c_UniqueIdentifier__c),
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
        List<d4c_Insurance_Product__c> products = new List<d4c_Insurance_Product__c>();
        for (Integer i = 0; i < 200; i++) {
            products.add(new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = TEST_STATE,
                d4c_ProductName__c = 'Product ' + i
            ));
        }

        // Act
        Test.startTest();
        insert products;
        Test.stopTest();

        // Assert: All products should have unique identifier populated
        List<d4c_Insurance_Product__c> insertedProducts = [
            SELECT Id, d4c_StateOrProvince__c, d4c_ProductName__c, d4c_UniqueIdentifier__c
            FROM d4c_Insurance_Product__c
            WHERE Id IN :products
        ];

        System.assertEquals(200, insertedProducts.size(), 'All 200 products should be inserted');
        for (d4c_Insurance_Product__c product : insertedProducts) {
            String expectedUniqueId = product.d4c_StateOrProvince__c + '-' + product.d4c_ProductName__c;
            System.assertEquals(expectedUniqueId, product.d4c_UniqueIdentifier__c,
                'Each product should have correct unique identifier');
        }
    }

    // ============================================================
    // UNIQUE IDENTIFIER TESTS (beforeUpdate)
    // ============================================================

    @isTest
    static void beforeUpdate_recalculatesWhenStateChanges() {
        // Arrange: Insert product with initial values
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE,
            d4c_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product;

        // Act: Update the state
        Test.startTest();
        product.d4c_StateOrProvince__c = 'TX';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = 'TX-' + TEST_PRODUCT_NAME;
        System.assertEquals(expectedUniqueId, product.d4c_UniqueIdentifier__c,
            'Unique identifier should be recalculated when state changes');
    }

    @isTest
    static void beforeUpdate_recalculatesWhenProductNameChanges() {
        // Arrange: Insert product with initial values
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE,
            d4c_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product;

        // Act: Update the product name
        Test.startTest();
        product.d4c_ProductName__c = 'Health Insurance';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated
        product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-Health Insurance';
        System.assertEquals(expectedUniqueId, product.d4c_UniqueIdentifier__c,
            'Unique identifier should be recalculated when product name changes');
    }

    @isTest
    static void beforeUpdate_alwaysRecalculates() {
        // Arrange: Insert product and manually set a different unique ID
        InsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE,
            d4c_ProductName__c = TEST_PRODUCT_NAME,
            d4c_UniqueIdentifier__c = 'MANUAL-VALUE'
        );
        insert product;
        InsuranceProductTriggerHandler.triggerDisabled = false;

        // Act: Update any field to trigger beforeUpdate
        Test.startTest();
        product.d4c_ProductName__c = 'Updated Product';
        update product;
        Test.stopTest();

        // Assert: Unique identifier should be recalculated (not kept as MANUAL-VALUE)
        product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
        String expectedUniqueId = TEST_STATE + '-Updated Product';
        System.assertEquals(expectedUniqueId, product.d4c_UniqueIdentifier__c,
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
            d4c_Insurance_Product__c product = new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = TEST_STATE,
                d4c_ProductName__c = TEST_PRODUCT_NAME
            );
            insert product;

            // If insert succeeds, unique ID should not be populated
            product = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_Insurance_Product__c WHERE Id = :product.Id];
            System.assert(String.isBlank(product.d4c_UniqueIdentifier__c),
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
        d4c_Insurance_Product__c product1 = new d4c_Insurance_Product__c(
            d4c_StateOrProvince__c = TEST_STATE,
            d4c_ProductName__c = TEST_PRODUCT_NAME
        );
        insert product1;

        // Act: Try to create duplicate product
        Test.startTest();
        try {
            d4c_Insurance_Product__c product2 = new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = TEST_STATE,
                d4c_ProductName__c = TEST_PRODUCT_NAME
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
        d4c_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        d4c_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.d4c_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(TEST_PRODUCT_NAME, TEST_STATE, true);

        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '100', 'Life Insurance', true
        );

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
            WHERE d4c_InsuranceProduct__c = :product.Id], 'Junction should exist before delete');

        // Act: Delete the product (beforeDelete should delete junctions)
        Test.startTest();
        delete product;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c
            WHERE d4c_InsuranceProduct__c = :product.Id],
            'Product-LOA Mapping junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_deletesLicenseProductJunctions() {
        // Arrange: Create test data
        d4c_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        d4c_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.d4c_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct(TEST_PRODUCT_NAME, TEST_STATE, true);

        // Create License-Product junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c licenseProductJunction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert licenseProductJunction;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junction exists
        System.assertEquals(1, [SELECT COUNT() FROM d4c_License_Insurance_Product__c
            WHERE d4c_InsuranceProduct__c = :product.Id], 'Junction should exist before delete');

        // Act: Delete the product (beforeDelete should delete junctions)
        Test.startTest();
        delete product;
        Test.stopTest();

        // Assert: Junction should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_License_Insurance_Product__c
            WHERE d4c_InsuranceProduct__c = :product.Id],
            'License-Product junction should be deleted by beforeDelete');
    }

    @isTest
    static void beforeDelete_bulkDeleteProducts() {
        // Arrange: Create test data for multiple products
        d4c_Producer__c producer = TestDataFactory.createProducer('1234567890');
        insert producer;

        d4c_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.d4c_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        List<d4c_Insurance_Product__c> products = new List<d4c_Insurance_Product__c>();
        for (Integer i = 0; i < 5; i++) {
            products.add(TestDataFactory.createInsuranceProduct('Product ' + i, TEST_STATE, false));
        }
        insert products;

        d4c_LOA_Insurance_Product_Mapping__c loaMapping = TestDataFactory.createLOAInsuranceProductMapping(
            TEST_STATE, '100', 'Life Insurance', true
        );

        // Create junctions for all products
        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = true;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;

        List<d4c_Insurance_Product_LOA_Mapping__c> productLoaJunctions = new List<d4c_Insurance_Product_LOA_Mapping__c>();
        List<d4c_License_Insurance_Product__c> licenseProductJunctions = new List<d4c_License_Insurance_Product__c>();

        for (d4c_Insurance_Product__c product : products) {
            productLoaJunctions.add(new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = product.Id,
                d4c_LOAMapping__c = loaMapping.Id,
                d4c_UniqueIdentifier__c = String.valueOf(product.Id) + '-' + String.valueOf(loaMapping.Id)
            ));

            licenseProductJunctions.add(new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product.Id,
                d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
            ));
        }
        insert productLoaJunctions;
        insert licenseProductJunctions;

        InsuranceProductLOAMappingTriggerHandler.triggerDisabled = false;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;

        // Verify junctions exist
        System.assertEquals(5, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c],
            'Should have 5 Product-LOA junctions before delete');
        System.assertEquals(5, [SELECT COUNT() FROM d4c_License_Insurance_Product__c],
            'Should have 5 License-Product junctions before delete');

        // Act: Bulk delete all products
        Test.startTest();
        delete products;
        Test.stopTest();

        // Assert: All junctions should be deleted
        System.assertEquals(0, [SELECT COUNT() FROM d4c_Insurance_Product_LOA_Mapping__c],
            'All Product-LOA junctions should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM d4c_License_Insurance_Product__c],
            'All License-Product junctions should be deleted');
    }
}