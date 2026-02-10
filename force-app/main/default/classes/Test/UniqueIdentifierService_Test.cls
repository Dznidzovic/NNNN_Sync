/*
*********************************************************
Apex Class Name    : UniqueIdentifierService_Test
Created Date       : 2025-12-15
@description       : Test class for UniqueIdentifierService
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
@isTest
private class UniqueIdentifierService_Test {

    @isTest
    static void testPopulateInsuranceProductUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();
        List<d4c_Insurance_Product__c> products = new List<d4c_Insurance_Product__c>{
            new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = 'CA',
                d4c_ProductName__c = 'Health Insurance'
            ),
            new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = 'NY',
                d4c_ProductName__c = 'Life Insurance'
            ),
            new d4c_Insurance_Product__c(
                d4c_StateOrProvince__c = null,
                d4c_ProductName__c = 'Auto Insurance'
            )
        };

        // Act
        Test.startTest();
        service.populateInsuranceProductUniqueId(products);
        Test.stopTest();

        // Assert
        System.assertEquals('CA-Health Insurance', products[0].d4c_UniqueIdentifier__c, 'First product unique ID should be set');
        System.assertEquals('NY-Life Insurance', products[1].d4c_UniqueIdentifier__c, 'Second product unique ID should be set');
        System.assertEquals(null, products[2].d4c_UniqueIdentifier__c, 'Third product unique ID should be null (missing state)');
    }

    @isTest
    static void testPopulateLOAMappingUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();
        List<d4c_LOA_Insurance_Product_Mapping__c> mappings = new List<d4c_LOA_Insurance_Product_Mapping__c>{
            new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = 'CA',
                d4c_LineOfAuthorityCode__c = '935',
                d4c_LineOfAuthorityDescription__c = 'Accident & Health'
            ),
            new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = 'NY',
                d4c_LineOfAuthorityCode__c = '101',
                d4c_LineOfAuthorityDescription__c = 'Life'
            ),
            new d4c_LOA_Insurance_Product_Mapping__c(
                d4c_StateOrProvinceCode__c = 'TX',
                d4c_LineOfAuthorityCode__c = null,
                d4c_LineOfAuthorityDescription__c = 'Property'
            )
        };

        // Act
        Test.startTest();
        service.populateLOAMappingUniqueId(mappings);
        Test.stopTest();

        // Assert
        System.assertEquals('CA-935-Accident & Health', mappings[0].d4c_UniqueIdentifier__c, 'First mapping unique ID should be set');
        System.assertEquals('NY-101-Life', mappings[1].d4c_UniqueIdentifier__c, 'Second mapping unique ID should be set');
        System.assertEquals(null, mappings[2].d4c_UniqueIdentifier__c, 'Third mapping unique ID should be null (missing code)');
    }

    @isTest
    static void testPopulateInsProdLOAMappingUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Create fake IDs for testing
        Id fakeProductId1 = MockHelper.generateId(d4c_Insurance_Product__c.SObjectType);
        Id fakeProductId2 = MockHelper.generateId(d4c_Insurance_Product__c.SObjectType);
        Id fakeMappingId1 = MockHelper.generateId(d4c_LOA_Insurance_Product_Mapping__c.SObjectType);
        Id fakeMappingId2 = MockHelper.generateId(d4c_LOA_Insurance_Product_Mapping__c.SObjectType);

        List<d4c_Insurance_Product_LOA_Mapping__c> junctions = new List<d4c_Insurance_Product_LOA_Mapping__c>{
            new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = fakeProductId1,
                d4c_LOAMapping__c = fakeMappingId1
            ),
            new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = fakeProductId2,
                d4c_LOAMapping__c = fakeMappingId2
            ),
            new d4c_Insurance_Product_LOA_Mapping__c(
                d4c_InsuranceProduct__c = null,
                d4c_LOAMapping__c = fakeMappingId1
            )
        };

        // Act
        Test.startTest();
        service.populateInsProdLOAMappingUniqueId(junctions);
        Test.stopTest();

        // Assert
        System.assertEquals(fakeProductId1 + '-' + fakeMappingId1, junctions[0].d4c_UniqueIdentifier__c, 'First junction unique ID should be set');
        System.assertEquals(fakeProductId2 + '-' + fakeMappingId2, junctions[1].d4c_UniqueIdentifier__c, 'Second junction unique ID should be set');
        System.assertEquals(null, junctions[2].d4c_UniqueIdentifier__c, 'Third junction unique ID should be null (missing product)');
    }

    @isTest
    static void testPopulateLicenseInsProdUniqueId() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Create fake IDs for testing
        Id fakeLicenseId1 = MockHelper.generateId(d4c_License__c.SObjectType);
        Id fakeLicenseId2 = MockHelper.generateId(d4c_License__c.SObjectType);
        Id fakeProductId1 = MockHelper.generateId(d4c_Insurance_Product__c.SObjectType);
        Id fakeProductId2 = MockHelper.generateId(d4c_Insurance_Product__c.SObjectType);

        List<d4c_License_Insurance_Product__c> junctions = new List<d4c_License_Insurance_Product__c>{
            new d4c_License_Insurance_Product__c(
                d4c_License__c = fakeLicenseId1,
                d4c_InsuranceProduct__c = fakeProductId1
            ),
            new d4c_License_Insurance_Product__c(
                d4c_License__c = fakeLicenseId2,
                d4c_InsuranceProduct__c = fakeProductId2
            ),
            new d4c_License_Insurance_Product__c(
                d4c_License__c = fakeLicenseId1,
                d4c_InsuranceProduct__c = null
            )
        };

        // Act
        Test.startTest();
        service.populateLicenseInsProdUniqueId(junctions);
        Test.stopTest();

        // Assert
        System.assertEquals(fakeLicenseId1 + '-' + fakeProductId1, junctions[0].d4c_UniqueIdentifier__c, 'First junction unique ID should be set');
        System.assertEquals(fakeLicenseId2 + '-' + fakeProductId2, junctions[1].d4c_UniqueIdentifier__c, 'Second junction unique ID should be set');
        System.assertEquals(null, junctions[2].d4c_UniqueIdentifier__c, 'Third junction unique ID should be null (missing product)');
    }

    @isTest
    static void testEmptyLists() {
        // Arrange
        UniqueIdentifierService service = new UniqueIdentifierService();

        // Act & Assert - should not throw
        Test.startTest();
        service.populateInsuranceProductUniqueId(new List<d4c_Insurance_Product__c>());
        service.populateLOAMappingUniqueId(new List<d4c_LOA_Insurance_Product_Mapping__c>());
        service.populateInsProdLOAMappingUniqueId(new List<d4c_Insurance_Product_LOA_Mapping__c>());
        service.populateLicenseInsProdUniqueId(new List<d4c_License_Insurance_Product__c>());
        Test.stopTest();

        // If we get here, test passed (no exceptions)
        System.assert(true, 'Empty lists should be handled gracefully');
    }
}