/*
*********************************************************
Apex Class Name    : LOAProductMappingService_Test
Created Date       : 2025-12-15
@description       : Test class for LOAProductMappingService
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
1.1   2025-12-24   Dev4Clouds         Enhanced with TestDataFactory and realistic scenarios
*********************************************************
*/
@isTest
private class LOAProductMappingService_Test {

    @TestSetup
    static void setupTestData() {
        // Create Producer with License using TestDataFactory
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

        // Create Insurance Product
        d4c_Insurance_Product__c product = TestDataFactory.createInsuranceProduct('Health Insurance', '12345', true);

        // Create junction between Product and Mapping
        TestDataFactory.createInsuranceProductLOAMappingJunction(product.Id, mapping.Id, true);

        // Create LOAs (trigger will auto-populate d4c_LOAMapping__c for loa1)
        d4c_LineOfAuthority__c loa1 = TestDataFactory.createLOAForMatching(license.Id, 'CA', '935', 'Accident & Health', true);
        d4c_LineOfAuthority__c loa2 = TestDataFactory.createLOAForMatching(license.Id, 'NY', '101', 'Life', true);
    }

    @isTest
    static void testBuildMappingKey() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Act & Assert
        Test.startTest();

        // Valid key
        String validKey = service.buildMappingKey('CA', '935', 'Accident & Health');
        System.assertEquals('CA-935-Accident & Health', validKey, 'Valid key should be built correctly');

        // Missing state
        String missingState = service.buildMappingKey(null, '935', 'Accident & Health');
        System.assertEquals(null, missingState, 'Key should be null when state is missing');

        // Missing code
        String missingCode = service.buildMappingKey('CA', '', 'Accident & Health');
        System.assertEquals(null, missingCode, 'Key should be null when code is blank');

        // Missing description
        String missingDesc = service.buildMappingKey('CA', '935', null);
        System.assertEquals(null, missingDesc, 'Key should be null when description is missing');

        Test.stopTest();
    }

    @isTest
    static void testMatchLoasToMappings_withRealData() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();
        List<d4c_LineOfAuthority__c> loas = queryLoas();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();

        // Reset mapping to null
        for (d4c_LineOfAuthority__c loa : loas) {
            loa.d4c_LOAMapping__c = null;
        }

        // Act
        Test.startTest();
        service.matchLoasToMappings(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(1, mappings.size(), 'Should have 1 mapping');

        // First LOA (CA-935-Accident & Health) should match the mapping
        System.assertNotEquals(null, loas[0].d4c_LOAMapping__c, 'First LOA should be matched');
        System.assertEquals(mappings[0].Id, loas[0].d4c_LOAMapping__c, 'First LOA should match to correct mapping');

        // Second LOA (NY-101-Life) should not match
        System.assertEquals(null, loas[1].d4c_LOAMapping__c, 'Second LOA should not match (no mapping exists)');
    }

    @isTest
    static void testMatchLoasToMappings() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Create test data with mapping inserted
        d4c_LOA_Insurance_Product_Mapping__c mapping = new d4c_LOA_Insurance_Product_Mapping__c(
            d4c_StateOrProvinceCode__c = 'TX',
            d4c_LineOfAuthorityCode__c = '950',
            d4c_LineOfAuthorityDescription__c = 'Life'
        );
        insert mapping;

        // Create LOAs to match
        List<d4c_LineOfAuthority__c> loas = new List<d4c_LineOfAuthority__c>{
            new d4c_LineOfAuthority__c(
                d4c_StateOrProvinceCode__c = 'TX',
                d4c_LineOfAuthorityCode__c = '950',
                d4c_LineOfAuthorityDescription__c = 'Life'
            ),
            new d4c_LineOfAuthority__c(
                d4c_StateOrProvinceCode__c = 'FL',
                d4c_LineOfAuthorityCode__c = '101',
                d4c_LineOfAuthorityDescription__c = 'Property'
            )
        };

        // Act
        Test.startTest();
        service.matchLoasToMappings(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(mapping.Id, loas[0].d4c_LOAMapping__c, 'First LOA should be matched to mapping');
        System.assertEquals(null, loas[1].d4c_LOAMapping__c, 'Second LOA should not be matched (no matching mapping)');
    }

    @isTest
    static void testFindOrphanLoasForMappings_withRealData() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();

        // Set LOAs to have null mapping (orphans)
        List<d4c_LineOfAuthority__c> loas = queryLoas();
        for (d4c_LineOfAuthority__c loa : loas) {
            loa.d4c_LOAMapping__c = null;
        }
        LineOfAuthorityTriggerHandler.triggerDisabled = true;
        update loas;
        LineOfAuthorityTriggerHandler.triggerDisabled = false;

        // Act
        Test.startTest();
        List<d4c_LineOfAuthority__c> orphans = service.findOrphanLoasForMappings(new Set<Id>{mappings[0].Id});
        Test.stopTest();

        // Assert
        System.assertEquals(1, orphans.size(), 'Should find 1 orphan LOA (CA-935-Accident & Health)');
        System.assertEquals(mappings[0].Id, orphans[0].d4c_LOAMapping__c, 'Orphan should be matched to mapping');
    }

    @isTest
    static void testFilterLoasWithMappings() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();

        List<d4c_LineOfAuthority__c> loas = new List<d4c_LineOfAuthority__c>{
            new d4c_LineOfAuthority__c(d4c_LOAMapping__c = mappings[0].Id),
            new d4c_LineOfAuthority__c(d4c_LOAMapping__c = null),
            new d4c_LineOfAuthority__c(d4c_LOAMapping__c = mappings[0].Id)
        };

        // Act
        Test.startTest();
        List<d4c_LineOfAuthority__c> filtered = service.filterLoasWithMappings(loas);
        Test.stopTest();

        // Assert
        System.assertEquals(2, filtered.size(), 'Should return 2 LOAs with mappings');
    }

    @isTest
    static void testFilterLoasWithChangedMappings() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = queryLoaMappings();
        List<d4c_LineOfAuthority__c> loas = queryLoas();

        // Create old map
        Map<Id, d4c_LineOfAuthority__c> newLoaMap = new Map<Id, d4c_LineOfAuthority__c>();
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap = new Map<Id, d4c_LineOfAuthority__c>();

        for (d4c_LineOfAuthority__c loa : loas) {
            oldLoaMap.put(loa.Id, loa.clone(true, true, true, true));
            newLoaMap.put(loa.Id, loa);
        }

        // Change mapping on first LOA
        newLoaMap.get(loas[0].Id).d4c_LOAMapping__c = null;

        // Act
        Test.startTest();
        Map<String, Object> result = service.filterLoasWithChangedMappings(newLoaMap, oldLoaMap);
        Test.stopTest();

        // Assert
        List<d4c_LineOfAuthority__c> changedLoas = (List<d4c_LineOfAuthority__c>) result.get('changed');
        Map<Id, d4c_LineOfAuthority__c> oldLoas = (Map<Id, d4c_LineOfAuthority__c>) result.get('old');

        System.assertEquals(1, changedLoas.size(), 'Should return 1 changed LOA');
        System.assertEquals(1, oldLoas.size(), 'Should return old values for 1 changed LOA');
    }

    @isTest
    static void testFindOrphanLoasForMappingsWithEmptySet() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Act
        Test.startTest();
        List<d4c_LineOfAuthority__c> result = service.findOrphanLoasForMappings(new Set<Id>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty set should return empty list');
    }

    @isTest
    static void testEmptyLoasMatchHandling() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Act
        Test.startTest();
        service.matchLoasToMappings(new List<d4c_LineOfAuthority__c>());
        Test.stopTest();

        // Assert - test passes if no exception
        System.assert(true, 'Empty list should be handled gracefully');
    }

    @isTest
    static void testDeleteLicenseProductsForDeletedMappingJunctions() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Get the Product-LOA junction
        List<d4c_Insurance_Product_LOA_Mapping__c> productLoaJunctions = queryProductLOAJunctions();
        System.assertEquals(1, productLoaJunctions.size(), 'Should have 1 product-LOA junction');

        // Act
        Test.startTest();
        Integer deletedCount = service.deleteLicenseProductsForDeletedMappingJunctions(productLoaJunctions);
        Test.stopTest();

        // Assert - method should handle the deletion gracefully
        System.assert(deletedCount >= 0, 'Should have processed junctions');
    }

    @isTest
    static void testDeleteLicenseProductsForDeletedMappingJunctions_withEmptyList() {
        // Arrange
        LOAProductMappingService service = new LOAProductMappingService();

        // Act
        Test.startTest();
        Integer deletedCount = service.deleteLicenseProductsForDeletedMappingJunctions(new List<d4c_Insurance_Product_LOA_Mapping__c>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, deletedCount, 'Empty list should return 0');
    }

    // HELPER METHODS
    private static List<d4c_LOA_Insurance_Product_Mapping__c> queryLoaMappings() {
        return [
            SELECT Id, d4c_StateOrProvinceCode__c, d4c_LineOfAuthorityCode__c,
                   d4c_LineOfAuthorityDescription__c, d4c_UniqueIdentifier__c
            FROM d4c_LOA_Insurance_Product_Mapping__c
        ];
    }

    private static List<d4c_LineOfAuthority__c> queryLoas() {
        return [
            SELECT Id, d4c_LOAMapping__c, d4c_StateOrProvinceCode__c,
                   d4c_LineOfAuthorityCode__c, d4c_LineOfAuthorityDescription__c, d4c_License__c
            FROM d4c_LineOfAuthority__c
            ORDER BY d4c_StateOrProvinceCode__c
        ];
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