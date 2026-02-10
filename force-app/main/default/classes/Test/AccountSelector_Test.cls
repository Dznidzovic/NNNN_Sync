/*
*********************************************************
Apex Class Name    : AccountSelector_Test
Created Date       : 2025-10-23
@description       : Test class for AccountSelector
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-10-23   Dev4Clouds Initial Version
*********************************************************
*/
@isTest
private class AccountSelector_Test {

    @isTest
    static void testGetAccountsByNPNs_EmptyResult() {
        // Test with no data - should return empty list
        AccountSelector selector = new AccountSelector();

        Test.startTest();
        List<Account> results = selector.getAccountsByNPNs(new Set<String>{'99999999'});
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no accounts exist');
    }

    @isTest
    static void testGetAccountsByNPNs_EmptyInput() {
        // Test with empty input set
        AccountSelector selector = new AccountSelector();

        Test.startTest();
        List<Account> results = selector.getAccountsByNPNs(new Set<String>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for empty input');
    }

    @isTest
    static void testGetAccountsByNPNs_NullInput() {
        // Test with null input
        AccountSelector selector = new AccountSelector();

        Test.startTest();
        List<Account> results = selector.getAccountsByNPNs(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }
}