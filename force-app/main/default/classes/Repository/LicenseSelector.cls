/**
 *********************************************************
 * Apex Class Name    : LicenseSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for ht_License__c object
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class LicenseSelector {
    /**
     ********************************************************
     * @Method Name    : getCarrierAppointmentsByProducerNpn
     * @description    : Returns list of ht_License__c by ht_NPN__c of ht_Producer__C object field
     * @param          : npns - Set of unique NPN values
     * @return         : List<ht_License__c> - list of Producer records
     *******************************************************
     **/
    public List<ht_License__c> getLicensesByProducerNpn(Set<String> npns) {
        return [
            SELECT
                Id,
                ht_uniqueIdentifier__c,
                ht_LicenseNumber__c,
                ht_Producer__r.ht_NPN__c
            FROM
                ht_License__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getLicensesByProducerNpnAndStates
     * @description    : Returns list of ht_License__c by ht_NPN__c and ht_StateOrProvinceCode__c
     *                   Used for deletion logic to only query licenses for producer+state combinations
     *                   that have data in the NIPR payload
     * @param          : npns - Set of unique NPN values
     * @param          : states - Set of state/province codes
     * @return         : List<ht_License__c> - list of License records
     *******************************************************
     **/
    public List<ht_License__c> getLicensesByProducerNpnAndStates(Set<String> npns, Set<String> states) {
        return [
            SELECT
                Id,
                ht_uniqueIdentifier__c,
                ht_LicenseNumber__c,
                ht_Producer__r.ht_NPN__c,
                ht_StateOrProvinceCode__c
            FROM
                ht_License__c
            WHERE
                ht_Producer__r.ht_NPN__c IN :npns
                AND ht_StateOrProvinceCode__c IN :states
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getLicensesWithProductsFieldByIds
     * @description    : Returns list of Licenses with ht_License_Products__c field by IDs
     *                   Used for updating the multi-select picklist of product names
     * @param          : licenseIds - Set of License IDs
     * @return         : List<ht_License__c> - list of License records
     *******************************************************
     **/
    public List<ht_License__c> getLicensesWithProductsFieldByIds(Set<Id> licenseIds) {
        return [
            SELECT
                Id,
                ht_License_Products__c
            FROM
                ht_License__c
            WHERE
                Id IN :licenseIds
        ];
    }
}