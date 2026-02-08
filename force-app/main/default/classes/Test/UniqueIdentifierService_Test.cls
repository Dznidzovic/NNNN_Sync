/*
*********************************************************
Apex Class Name    : UniqueIdentifierService_Test
Created Date       : 2025-12-15
@description       : Test class for UniqueIdentifierService
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
@isTest
private class UniqueIdentifierService_Test {

    @isTest
    static void testPopulateInsuranceProductUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();
        List<ht_Insurance_Product__c> products = new List<ht_Insurance_Product__c>{
            new ht_Insurance_Product__c(
                ht_StateOrProvince__c = 'CA',
                ht_ProductName__c = 'Health Insurance'
            ),
            new ht_Insurance_Product__c(
                ht_StateOrProvince__c = 'NY',
                ht_ProductName__c = 'Life Insurance'
            ),
            new ht_Insurance_Product__c(
                ht_StateOrProvince__c = null,
                ht_ProductName__c = 'Auto Insurance'
            )
        };

        // Act
        Test.startTest();
        service.populateInsuranceProductUniqueId(products);
        Test.stopTest();

        // Assert
        System.assertEquals('CA-Health Insurance', products[0].ht_UniqueIdentifier__c, 'First product unique ID should be set');
        System.assertEquals('NY-Life Insurance', products[1].ht_UniqueIdentifier__c, 'Second product unique ID should be set');
        System.assertEquals(null, products[2].ht_UniqueIdentifier__c, 'Third product unique ID should be null (missing state)');
    }

    @isTest
    static void testPopulateLOAMappingUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();
        List<ht_LOA_Insurance_Product_Mapping__c> mappings = new List<ht_LOA_Insurance_Product_Mapping__c>{
            new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = 'CA',
                ht_LineOfAuthorityCode__c = '935',
                ht_LineOfAuthorityDescription__c = 'Accident & Health'
            ),
            new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = 'NY',
                ht_LineOfAuthorityCode__c = '101',
                ht_LineOfAuthorityDescription__c = 'Life'
            ),
            new ht_LOA_Insurance_Product_Mapping__c(
                ht_StateOrProvinceCode__c = 'TX',
                ht_LineOfAuthorityCode__c = null,
                ht_LineOfAuthorityDescription__c = 'Property'
            )
        };

        // Act
        Test.startTest();
        service.populateLOAMappingUniqueId(mappings);
        Test.stopTest();

        // Assert
        System.assertEquals('CA-935-Accident & Health', mappings[0].ht_UniqueIdentifier__c, 'First mapping unique ID should be set');
        System.assertEquals('NY-101-Life', mappings[1].ht_UniqueIdentifier__c, 'Second mapping unique ID should be set');
        System.assertEquals(null, mappings[2].ht_UniqueIdentifier__c, 'Third mapping unique ID should be null (missing code)');
    }

    @isTest
    static void testPopulateInsProdLOAMappingUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Create fake IDs for testing
        Id fakeProductId1 = MockHelper.generateId(ht_Insurance_Product__c.SObjectType);
        Id fakeProductId2 = MockHelper.generateId(ht_Insurance_Product__c.SObjectType);
        Id fakeMappingId1 = MockHelper.generateId(ht_LOA_Insurance_Product_Mapping__c.SObjectType);
        Id fakeMappingId2 = MockHelper.generateId(ht_LOA_Insurance_Product_Mapping__c.SObjectType);

        List<ht_Insurance_Product_LOA_Mapping__c> junctions = new List<ht_Insurance_Product_LOA_Mapping__c>{
            new ht_Insurance_Product_LOA_Mapping__c(
                ht_InsuranceProduct__c = fakeProductId1,
                ht_LOAMapping__c = fakeMappingId1
            ),
            new ht_Insurance_Product_LOA_Mapping__c(
                ht_InsuranceProduct__c = fakeProductId2,
                ht_LOAMapping__c = fakeMappingId2
            ),
            new ht_Insurance_Product_LOA_Mapping__c(
                ht_InsuranceProduct__c = null,
                ht_LOAMapping__c = fakeMappingId1
            )
        };

        // Act
        Test.startTest();
        service.populateInsProdLOAMappingUniqueId(junctions);
        Test.stopTest();

        // Assert
        System.assertEquals(fakeProductId1 + '-' + fakeMappingId1, junctions[0].ht_UniqueIdentifier__c, 'First junction unique ID should be set');
        System.assertEquals(fakeProductId2 + '-' + fakeMappingId2, junctions[1].ht_UniqueIdentifier__c, 'Second junction unique ID should be set');
        System.assertEquals(null, junctions[2].ht_UniqueIdentifier__c, 'Third junction unique ID should be null (missing product)');
    }

    @isTest
    static void testPopulateLicenseInsProdUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Create fake IDs for testing
        Id fakeLicenseId1 = MockHelper.generateId(ht_License__c.SObjectType);
        Id fakeLicenseId2 = MockHelper.generateId(ht_License__c.SObjectType);
        Id fakeProductId1 = MockHelper.generateId(ht_Insurance_Product__c.SObjectType);
        Id fakeProductId2 = MockHelper.generateId(ht_Insurance_Product__c.SObjectType);

        List<ht_License_Insurance_Product__c> junctions = new List<ht_License_Insurance_Product__c>{
            new ht_License_Insurance_Product__c(
                ht_License__c = fakeLicenseId1,
                ht_InsuranceProduct__c = fakeProductId1
            ),
            new ht_License_Insurance_Product__c(
                ht_License__c = fakeLicenseId2,
                ht_InsuranceProduct__c = fakeProductId2
            ),
            new ht_License_Insurance_Product__c(
                ht_License__c = fakeLicenseId1,
                ht_InsuranceProduct__c = null
            )
        };

        // Act
        Test.startTest();
        service.populateLicenseInsProdUniqueId(junctions);
        Test.stopTest();

        // Assert
        System.assertEquals(fakeLicenseId1 + '-' + fakeProductId1, junctions[0].ht_UniqueIdentifier__c, 'First junction unique ID should be set');
        System.assertEquals(fakeLicenseId2 + '-' + fakeProductId2, junctions[1].ht_UniqueIdentifier__c, 'Second junction unique ID should be set');
        System.assertEquals(null, junctions[2].ht_UniqueIdentifier__c, 'Third junction unique ID should be null (missing product)');
    }

    @isTest
    static void testEmptyLists() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Act & Assert - should not throw
        Test.startTest();
        service.populateInsuranceProductUniqueId(new List<ht_Insurance_Product__c>());
        service.populateLOAMappingUniqueId(new List<ht_LOA_Insurance_Product_Mapping__c>());
        service.populateInsProdLOAMappingUniqueId(new List<ht_Insurance_Product_LOA_Mapping__c>());
        service.populateLicenseInsProdUniqueId(new List<ht_License_Insurance_Product__c>());
        Test.stopTest();

        // If we get here, test passed (no exceptions)
        System.assert(true, 'Empty lists should be handled gracefully');
    }
}