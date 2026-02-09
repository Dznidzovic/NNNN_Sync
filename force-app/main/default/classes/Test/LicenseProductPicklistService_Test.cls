/*
*********************************************************
Apex Class Name    : LicenseProductPicklistService_Test
Created Date       : 2025-12-15
@description       : Test class for LicenseProductPicklistService
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
@isTest
private class LicenseProductPicklistService_Test {

    @isTest
    static void testParsePicklistValues() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();

        // Act
        Test.startTest();
        Set<String> values = service.parsePicklistValues('Health Insurance;Life Insurance;Auto Insurance');
        Set<String> emptyValues = service.parsePicklistValues(null);
        Set<String> blankValues = service.parsePicklistValues('');
        Test.stopTest();

        // Assert
        System.assertEquals(3, values.size(), 'Should parse 3 values');
        System.assert(values.contains('Health Insurance'), 'Should contain Health Insurance');
        System.assert(values.contains('Life Insurance'), 'Should contain Life Insurance');
        System.assert(values.contains('Auto Insurance'), 'Should contain Auto Insurance');
        System.assertEquals(0, emptyValues.size(), 'Null should return empty set');
        System.assertEquals(0, blankValues.size(), 'Blank should return empty set');
    }

    @isTest
    static void testBuildPicklistString() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();
        Set<String> values = new Set<String>{'Zebra', 'Apple', 'Banana'};

        // Act
        Test.startTest();
        String result = service.buildPicklistString(values);
        String nullResult = service.buildPicklistString(null);
        String emptyResult = service.buildPicklistString(new Set<String>());
        Test.stopTest();

        // Assert
        System.assertEquals('Apple;Banana;Zebra', result, 'Values should be sorted and joined');
        System.assertEquals(null, nullResult, 'Null set should return null');
        System.assertEquals(null, emptyResult, 'Empty set should return null');
    }

    @isTest
    static void testAddProductNamesToLicensesWithEmptyList() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();

        // Act
        Test.startTest();
        List<d4c_License__c> result = service.addProductNamesToLicenses(new List<d4c_License_Insurance_Product__c>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty list should return empty list');
    }

    @isTest
    static void testRemoveProductNamesFromLicensesWithEmptyList() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();

        // Act
        Test.startTest();
        List<d4c_License__c> result = service.removeProductNamesFromLicenses(new List<d4c_License_Insurance_Product__c>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, result.size(), 'Empty list should return empty list');
    }

    @isTest
    static void testParseAndBuildRoundTrip() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();
        String original = 'Alpha;Beta;Gamma';

        // Act
        Test.startTest();
        Set<String> parsed = service.parsePicklistValues(original);
        String rebuilt = service.buildPicklistString(parsed);
        Test.stopTest();

        // Assert
        System.assertEquals(original, rebuilt, 'Round trip should preserve values');
    }

    @isTest
    static void testParsePicklistValuesWithSpaces() {
        // Arrange
        LicenseProductPicklistService service = new LicenseProductPicklistService();

        // Act
        Test.startTest();
        Set<String> values = service.parsePicklistValues('  Health Insurance  ;  Life Insurance  ');
        Test.stopTest();

        // Assert
        System.assertEquals(2, values.size(), 'Should parse 2 values');
        System.assert(values.contains('Health Insurance'), 'Should contain trimmed Health Insurance');
        System.assert(values.contains('Life Insurance'), 'Should contain trimmed Life Insurance');
    }
}