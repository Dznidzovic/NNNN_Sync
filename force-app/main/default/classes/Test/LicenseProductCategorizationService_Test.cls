/*
*********************************************************
Apex Class Name    : LicenseProductCategorizationService_Test
Created Date       : 2025-12-15
@description       : Test class for LicenseProductCategorizationService
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
1.1   2025-12-24   Stefan Nidzovic         Enhanced with TestDataFactory and realistic scenarios
*********************************************************
*/
@isTest
private class LicenseProductCategorizationService_Test {

    @TestSetup
    static void setupTestData() {
        // Create Producer with License
        d4c_Entity__c producer = TestDataFactory.createProducer('12345678');
        ProducerTriggerHandler.triggerDisabled = true;
        insert producer;
        ProducerTriggerHandler.triggerDisabled = false;

        // Create License
        d4c_License__c license = TestDataFactory.createLicense('LIC123', producer.Id);
        license.d4c_StateOrProvinceCode__c = 'CA';
        insert license;

        // Create LOA Insurance Product Mapping
        d4c_LOA_Insurance_Product_Mapping__c mapping = TestDataFactory.createLOAInsuranceProductMapping('CA', '935', 'Accident & Health', true);

        // Create Insurance Products
        d4c_Insurance_Product__c product1 = TestDataFactory.createInsuranceProduct('Health Insurance', '12345', true);
        d4c_Insurance_Product__c product2 = TestDataFactory.createInsuranceProduct('Life Insurance', '67890', true);

        // Create junctions between Products and Mapping
        TestDataFactory.createInsuranceProductLOAMappingJunction(product1.Id, mapping.Id, true);
        TestDataFactory.createInsuranceProductLOAMappingJunction(product2.Id, mapping.Id, true);

        // Create LOA with mapping (trigger will auto-populate d4c_LOAMapping__c)
        d4c_LineOfAuthority__c loa = TestDataFactory.createLOAForMatching(license.Id, 'CA', '935', 'Accident & Health', true);
    }

    @isTest
    static void testBuildLicenseProductUniqueId() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        List<d4c_License__c> licenses = queryLicenses();
        List<d4c_Insurance_Product__c> products = queryProducts();

        // Act
        Test.startTest();
        String uniqueId = service.buildLicenseProductUniqueId(licenses[0].Id, products[0].Id);
        String nullResult = service.buildLicenseProductUniqueId(null, products[0].Id);
        Test.stopTest();

        // Assert
        System.assertEquals(licenses[0].Id + '-' + products[0].Id, uniqueId, 'Unique ID should be built correctly');
        System.assertEquals(null, nullResult, 'Null license should return null');
    }

    @isTest
    static void testGetProductIdsForMappings_withRealData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();
        Set<Id> mappingIds = new Set<Id>{mappings[0].Id};

        // Act
        Test.startTest();
        Map<Id, List<Id>> result = service.getProductIdsForMappings(mappingIds);
        Test.stopTest();

        // Assert
        System.assertEquals(1, result.size(), 'Should have products for 1 mapping');
        System.assert(result.containsKey(mappings[0].Id), 'Should contain mapping ID');
        System.assertEquals(2, result.get(mappings[0].Id).size(), 'Should have 2 products for this mapping');
    }

    @isTest
    static void testGetProductIdsForMappingsWithEmptySet() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        Map<Id, List<Id>> result = service.getProductIdsForMappings(new Set<Id>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty set should return empty map');
    }

    @isTest
    static void testGetProductIdSetForMappings_withRealData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();
        Set<Id> mappingIds = new Set<Id>{mappings[0].Id};

        // Act
        Test.startTest();
        Map<Id, Set<Id>> result = service.getProductIdSetForMappings(mappingIds);
        Test.stopTest();

        // Assert
        System.assertEquals(1, result.size(), 'Should have products for 1 mapping');
        System.assert(result.containsKey(mappings[0].Id), 'Should contain mapping ID');
        System.assertEquals(2, result.get(mappings[0].Id).size(), 'Should have 2 products for this mapping');
    }

    @isTest
    static void testGetProductIdSetForMappingsWithEmptySet() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        Map<Id, Set<Id>> result = service.getProductIdSetForMappings(new Set<Id>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty set should return empty map');
    }

    @isTest
    static void testCreateJunctionsForLoas_withRealData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();
        List<d4c_LineOfAuthority__c> loas = queryLoas();

        // Act
        Test.startTest();
        List<d4c_License_Insurance_Product__c> junctions = service.createJunctionsForLoas(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(2, junctions.size(), 'Should create 2 junctions (LOA has mapping with 2 products)');

        // Verify unique identifiers are set
        for (d4c_License_Insurance_Product__c junction : junctions) {
            System.assertNotEquals(null, junction.d4c_UniqueIdentifier__c, 'Unique ID should be set');
            System.assertNotEquals(null, junction.d4c_License__c, 'License should be set');
            System.assertNotEquals(null, junction.d4c_InsuranceProduct__c, 'Product should be set');
        }
    }

    @isTest
    static void testCreateJunctionsForLoasWithEmptyList() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        List<d4c_License_Insurance_Product__c> result = service.createJunctionsForLoas(new List<d4c_LineOfAuthority__c>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty list should return empty list');
    }

    @isTest
    static void testCreateJunctionsForLoasWithNullMappings() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        List<d4c_LineOfAuthority__c> loas = new List<d4c_LineOfAuthority__c>{
            new d4c_LineOfAuthority__c(d4c_LOAMapping__c = null)
        };

        // Act
        Test.startTest();
        List<d4c_License_Insurance_Product__c> result = service.createJunctionsForLoas(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'LOAs without mappings should return empty list');
    }

    @isTest
    static void testCalculateJunctionChangesForLoaUpdates_withRealData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();
        List<d4c_LineOfAuthority__c> loas = queryLoas();

        // Create old map (LOA with old mapping)
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = new Map<Id, d4c_LineOfAuthority__c>();
        for (d4c_LineOfAuthority__c loa : loas) {
            oldLoaMap.put(loa.Id, loa.clone(true, true, true, true));
        }

        // Change mapping to null (simulating mapping change)
        loas[0].d4c_LOAMapping__c = null;

        // Act
        Test.startTest();
        Map<String, Object> result = service.calculateJunctionChangesForLoaUpdates(loas, oldLoaMap);
        Test.stopTest();

        // Assert
        List<d4c_License_Insurance_Product__c> toCreate = (List<d4c_License_Insurance_Product__c>) result.get('toCreate');
        Set<String> keysToDelete = (Set<String>) result.get('keysToDelete');

        System.assertEquals(0, toCreate.size(), 'Should not create new junctions (mapping set to null)');
        System.assertEquals(2, keysToDelete.size(), 'Should mark 2 junctions for deletion (2 products in old mapping)');
    }

    @isTest
    static void testCalculateJunctionChangesForLoaUpdatesWithEmptyData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        Map<String, Object> result = service.calculateJunctionChangesForLoaUpdates(
            new List<d4c_LineOfAuthority__c>(),
            new Map<Id, d4c_LineOfAuthority__c>()
        );
        Test.stopTest();

        // Assert
        List<d4c_License_Insurance_Product__c> toCreate = (List<d4c_License_Insurance_Product__c>) result.get('toCreate');
        Set<String> keysToDelete = (Set<String>) result.get('keysToDelete');

        System.assertEquals(0, toCreate.size(), 'Should return empty list for toCreate');
        System.assertEquals(0, keysToDelete.size(), 'Should return empty set for keysToDelete');
    }

    @isTest
    static void testGetJunctionKeysToDeleteForLoas_withRealData() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();
        List<d4c_LineOfAuthority__c> loas = queryLoas();

        // Act
        Test.startTest();
        Set<String> keys = service.getJunctionKeysToDeleteForLoas(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(2, keys.size(), 'Should return 2 junction keys (LOA has mapping with 2 products)');
    }

    @isTest
    static void testGetJunctionKeysToDeleteForLoasWithEmptyList() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        Set<String> result = service.getJunctionKeysToDeleteForLoas(new List<d4c_LineOfAuthority__c>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty list should return empty set');
    }

    @isTest
    static void testGetJunctionsToDeleteByKeysWithEmptySet() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        List<d4c_License_Insurance_Product__c> result = service.getJunctionsToDeleteByKeys(new Set<String>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty set should return empty list');
    }

    @isTest
    static void testGetJunctionsToDeleteByKeysWithNull() {
        // Arrange
        LicenseProductCategorizationService service = new LicenseProductCategorizationService();

        // Act
        Test.startTest();
        List<d4c_License_Insurance_Product__c> result = service.getJunctionsToDeleteByKeys(null);
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Null should return empty list');
    }

    // HELPER METHODS
    private static List<d4c_License__c> queryLicenses() {
        return [SELECT Id FROM d4c_License__c];
    }

    private static List<d4c_LOA_Insurance_Product_Mapping__c> queryLoaMappings() {
        return [SELECT Id FROM d4c_LOA_Insurance_Product_Mapping__c];
    }

    private static List<d4c_Insurance_Product__c> queryProducts() {
        return [SELECT Id FROM d4c_Insurance_Product__c];
    }

    private static List<d4c_LineOfAuthority__c> queryLoas() {
        return [SELECT Id, d4c_LOAMapping__c, d4c_License__c FROM d4c_LineOfAuthority__c];
    }

    private static List<d4c_License_Insurance_Product__c> queryLicenseProductJunctions() {
        return [
            SELECT Id, d4c_License__c, d4c_InsuranceProduct__c, d4c_UniqueIdentifier__c
            FROM d4c_License_Insurance_Product__c
        ];
    }

    private static List<d4c_Insurance_Product_LOA_Mapping__c> queryProductLOAJunctions() {
        return [
            SELECT Id, d4c_InsuranceProduct__c, d4c_LOAMapping__c, d4c_UniqueIdentifier__c
            FROM d4c_Insurance_Product_LOA_Mapping__c
        ];
    }
}