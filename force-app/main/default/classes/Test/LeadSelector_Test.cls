/*
*********************************************************
Apex Class Name    : LeadSelector_Test
Created Date       : 2025-10-23
@description       : Test class for LeadSelector
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-10-23   Stefan Nidzovic Initial Version
*********************************************************
*/
@isTest
private class LeadSelector_Test {

    @isTest
    static void testGetLeadsByNPNs_EmptyResult() {
        // Test with no data - should return empty list
        LeadSelector selector = new LeadSelector();

        Test.startTest();
        List<Lead> results = selector.getLeadsByNPNs(new Set<String>{'99999999'});
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no leads exist');
    }

    @isTest
    static void testGetLeadsByNPNs_EmptyInput() {
        // Test with empty input set
        LeadSelector selector = new LeadSelector();

        Test.startTest();
        List<Lead> results = selector.getLeadsByNPNs(new Set<String>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for empty input');
    }

    @isTest
    static void testGetLeadsByNPNs_NullInput() {
        // Test with null input
        LeadSelector selector = new LeadSelector();

        Test.startTest();
        List<Lead> results = selector.getLeadsByNPNs(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }
}