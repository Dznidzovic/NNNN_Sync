/*
*********************************************************
Apex Class Name    : ContactSelector_Test
Created Date       : 2025-10-23
@description       : Test class for ContactSelector
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-10-23   Dev4Clouds Initial Version
*********************************************************
*/
@isTest
private class ContactSelector_Test {

    @isTest
    static void testGetContactsByNPNs_EmptyResult() {
        // Test with no data - should return empty list
        ContactSelector selector = new ContactSelector();

        Test.startTest();
        List<Contact> results = selector.getContactsByNPNs(new Set<String>{'99999999'});
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no contacts exist');
    }

    @isTest
    static void testGetContactsByNPNs_EmptyInput() {
        // Test with empty input set
        ContactSelector selector = new ContactSelector();

        Test.startTest();
        List<Contact> results = selector.getContactsByNPNs(new Set<String>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for empty input');
    }

    @isTest
    static void testGetContactsByNPNs_NullInput() {
        // Test with null input
        ContactSelector selector = new ContactSelector();

        Test.startTest();
        List<Contact> results = selector.getContactsByNPNs(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }
}