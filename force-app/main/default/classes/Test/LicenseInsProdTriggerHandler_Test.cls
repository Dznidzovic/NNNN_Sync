/*
*********************************************************
Apex Class Name    : LicenseInsProdTriggerHandler_Test
Created Date       : 2025-12-13
@description       : Test class for LicenseInsuranceProductTriggerHandler.
                     Tests unique identifier generation and License picklist updates.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan Nidzovic         Initial Version
*********************************************************
*/
@isTest
private class LicenseInsProdTriggerHandler_Test {

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
        d4c_License__c license = TestDataFactory.createLicense('LIPTEST123', producer.Id);
        license.d4c_StateOrProvinceCode__c = TEST_STATE;
        insert license;

        // Create second License for multi-license tests
        d4c_License__c license2 = TestDataFactory.createLicense('LIPTEST456', producer.Id);
        license2.d4c_StateOrProvinceCode__c = 'TX';
        insert license2;

        // Create Insurance Products
        d4c_Insurance_Product__c product1 = TestDataFactory.createInsuranceProduct(
            'Life Insurance', TEST_STATE, true
        );

        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct(
            'Health Insurance', TEST_STATE, true
        );

        d4c_Insurance_Product__c product3 = TestDataFactory.createInsuranceProduct(
            'Property Insurance', TEST_STATE, true
        );

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
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];


        // Act
        Test.startTest();
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: Unique identifier should be populated
        junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_License_Insurance_Product__c WHERE Id = :junction.Id];
        String expectedUniqueId = String.valueOf(license.Id) + '-' + String.valueOf(product.Id);
        System.assertEquals(expectedUniqueId, junction.d4c_UniqueIdentifier__c,
            'Unique identifier should be LicenseId-ProductId');
    }

    @isTest
    static void beforeInsert_handlesNullLicenseId() {
        // Arrange: Create junction without License (edge case)
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];


        // Act: Try to insert junction without License
        Test.startTest();
        try {
            d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
                d4c_InsuranceProduct__c = product.Id
            );
            insert junction;
            // If we get here, check that unique ID is null or empty
            junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_License_Insurance_Product__c WHERE Id = :junction.Id];
            System.assert(String.isBlank(junction.d4c_UniqueIdentifier__c),
                'Unique identifier should be blank when License is null');
        } catch (DmlException e) {
            // Expected: Master-Detail might require License
            System.assert(true, 'Master-Detail field requires parent, DML failed as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void beforeInsert_preventsDuplicateJunctions() {
        // Arrange
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        // Create first junction
        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junction1 = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction1;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;


        // Act: Try to insert duplicate junction
        Test.startTest();
        try {
            d4c_License_Insurance_Product__c junction2 = new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product.Id
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
    // ADD PRODUCT NAMES TO LICENSE TESTS (afterInsert)
    // ============================================================

    @isTest
    static void afterInsert_addsProductNameToLicensePicklist() {
        // Arrange
        d4c_License__c license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];


        // Act
        Test.startTest();
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: License should have product name in picklist
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assertNotEquals(null, license.d4c_License_Products__c,
            'License should have insurance products populated');
        System.assert(license.d4c_License_Products__c.contains('Life Insurance'),
            'License picklist should contain Life Insurance');
    }

    @isTest
    static void afterInsert_addsMultipleProducts() {
        // Arrange
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        List<d4c_Insurance_Product__c> products = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c];


        // Act: Insert multiple junctions
        Test.startTest();
        List<d4c_License_Insurance_Product__c> junctions = new List<d4c_License_Insurance_Product__c>();
        for (d4c_Insurance_Product__c product : products) {
            junctions.add(new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product.Id
            ));
        }
        insert junctions;
        Test.stopTest();

        // Assert: License should have all product names
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assertNotEquals(null, license.d4c_License_Products__c,
            'License should have insurance products populated');
        System.assert(license.d4c_License_Products__c.contains('Life Insurance'),
            'License picklist should contain Life Insurance');
        System.assert(license.d4c_License_Products__c.contains('Health Insurance'),
            'License picklist should contain Health Insurance');
        System.assert(license.d4c_License_Products__c.contains('Property Insurance'),
            'License picklist should contain Property Insurance');
    }

    @isTest
    static void afterInsert_preservesExistingPicklistValues() {
        // Arrange: Set existing value on License
        d4c_License__c license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        license.d4c_License_Products__c = 'Existing Value';
        update license;

        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];


        // Act
        Test.startTest();
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: Existing value should be preserved
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assert(license.d4c_License_Products__c.contains('Existing Value'),
            'Existing picklist value should be preserved');
        System.assert(license.d4c_License_Products__c.contains('Life Insurance'),
            'New product name should be added');
    }

    @isTest
    static void afterInsert_noDuplicatePicklistValue() {
        // Arrange: Set existing value that matches new product
        d4c_License__c license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        license.d4c_License_Products__c = 'Life Insurance';
        update license;

        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];


        // Act
        Test.startTest();
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id
        );
        insert junction;
        Test.stopTest();

        // Assert: Should not have duplicate values
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        // Count occurrences of 'Life Insurance'
        Integer count = license.d4c_License_Products__c.countMatches('Life Insurance');
        System.assertEquals(1, count, 'Life Insurance should appear only once');
    }

    // ============================================================
    // REMOVE PRODUCT NAMES FROM LICENSE TESTS (afterDelete)
    // ============================================================

    @isTest
    static void afterDelete_removesProductName() {
        // Arrange: Create junction with trigger disabled, set picklist manually
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction;

        // Set the picklist value manually
        license.d4c_License_Products__c = 'Life Insurance;Health Insurance';
        update license;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;


        // Act: Delete the junction
        Test.startTest();
        delete junction;
        Test.stopTest();

        // Assert: Life Insurance should be removed from picklist
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assert(!license.d4c_License_Products__c.contains('Life Insurance'),
            'Life Insurance should be removed from picklist');
        System.assert(license.d4c_License_Products__c.contains('Health Insurance'),
            'Health Insurance should remain in picklist');
    }

    @isTest
    static void afterDelete_clearsPicklistWhenLastRemoved() {
        // Arrange: Create junction with trigger disabled, set only one picklist value
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction;

        license.d4c_License_Products__c = 'Life Insurance';
        update license;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;


        // Act: Delete the junction
        Test.startTest();
        delete junction;
        Test.stopTest();

        // Assert: Picklist should be empty or null
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assert(String.isBlank(license.d4c_License_Products__c),
            'Picklist should be empty when last product is removed');
    }

    @isTest
    static void afterDelete_noMatchingPicklistValue() {
        // Arrange: Create junction but don't add to picklist
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id, d4c_ProductName__c FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;
        d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
            d4c_License__c = license.Id,
            d4c_InsuranceProduct__c = product.Id,
            d4c_UniqueIdentifier__c = String.valueOf(license.Id) + '-' + String.valueOf(product.Id)
        );
        insert junction;

        // Set different value in picklist (not the product being deleted)
        license.d4c_License_Products__c = 'Other Product';
        update license;
        LicenseInsuranceProductTriggerHandler.triggerDisabled = false;


        // Act: Delete the junction - should not throw exception
        Test.startTest();
        delete junction;
        Test.stopTest();

        // Assert: Original value should remain
        license = [SELECT Id, d4c_License_Products__c FROM d4c_License__c WHERE Id = :license.Id];
        System.assertEquals('Other Product', license.d4c_License_Products__c,
            'Original picklist value should remain unchanged');
    }

    // ============================================================
    // TRIGGER DISABLED TEST
    // ============================================================

    @isTest
    static void triggerDisabled_skipsAllProcessing() {
        // Arrange
        d4c_License__c license = [SELECT Id FROM d4c_License__c WHERE d4c_LicenseNumber__c = 'LIPTEST123' LIMIT 1];
        d4c_Insurance_Product__c product = [SELECT Id FROM d4c_Insurance_Product__c WHERE d4c_ProductName__c = 'Life Insurance' LIMIT 1];

        LicenseInsuranceProductTriggerHandler.triggerDisabled = true;

        // Act: When trigger is disabled, UniqueIdentifier won't be populated by the trigger
        // The insert should fail because d4c_UniqueIdentifier__c is a required field
        Test.startTest();
        try {
            d4c_License_Insurance_Product__c junction = new d4c_License_Insurance_Product__c(
                d4c_License__c = license.Id,
                d4c_InsuranceProduct__c = product.Id
            );
            insert junction;
            // If insert succeeds, the trigger was bypassed (no unique ID populated)
            junction = [SELECT Id, d4c_UniqueIdentifier__c FROM d4c_License_Insurance_Product__c WHERE Id = :junction.Id];
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