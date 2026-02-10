/**
 *********************************************************
 * Apex Class Name    : LicenseSelector
 * Created Date       : 03-30-2025
 * @description       : Selector class holding all the queries used for d4c_License__c object
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
     * @description    : Returns list of d4c_License__c by d4c_NPN__c of d4c_Entity__c object field
     * @param          : npns - Set of unique NPN values
     * @return         : List<d4c_License__c> - list of Producer records
     *******************************************************
     **/
    public List<d4c_License__c> getLicensesByProducerNpn(Set<String> npns) {
        return [
            SELECT
                Id,
                d4c_uniqueIdentifier__c,
                d4c_LicenseNumber__c,
                d4c_Entity__r.d4c_NPN__c
            FROM
                d4c_License__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getLicensesByProducerNpnAndStates
     * @description    : Returns list of d4c_License__c by d4c_NPN__c and d4c_StateOrProvinceCode__c
     *                   Used for deletion logic to only query licenses for producer+state combinations
     *                   that have data in the NIPR payload
     * @param          : npns - Set of unique NPN values
     * @param          : states - Set of state/province codes
     * @return         : List<d4c_License__c> - list of License records
     *******************************************************
     **/
    public List<d4c_License__c> getLicensesByProducerNpnAndStates(Set<String> npns, Set<String> states) {
        return [
            SELECT
                Id,
                d4c_uniqueIdentifier__c,
                d4c_LicenseNumber__c,
                d4c_Entity__r.d4c_NPN__c,
                d4c_StateOrProvinceCode__c
            FROM
                d4c_License__c
            WHERE
                d4c_Entity__r.d4c_NPN__c IN :npns
                AND d4c_StateOrProvinceCode__c IN :states
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getLicensesWithProductsFieldByIds
     * @description    : Returns list of Licenses with d4c_License_Products__c field by IDs
     *                   Used for updating the multi-select picklist of product names
     * @param          : licenseIds - Set of License IDs
     * @return         : List<d4c_License__c> - list of License records
     *******************************************************
     **/
    public List<d4c_License__c> getLicensesWithProductsFieldByIds(Set<Id> licenseIds) {
        return [
            SELECT
                Id,
                d4c_License_Products__c
            FROM
                d4c_License__c
            WHERE
                Id IN :licenseIds
        ];
    }
}