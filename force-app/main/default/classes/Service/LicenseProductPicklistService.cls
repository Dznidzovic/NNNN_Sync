/*
*********************************************************
Apex Class Name    : LicenseProductPicklistService
Created Date       : 2025-12-15
@description       : Service class for managing License Insurance Products picklist field.
                     Centralizes business logic for:
                     - Adding product names to License ht_License_Products__c field
                     - Removing product names from License ht_License_Products__c field
                     - Maintaining semicolon-separated list of product names
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
public with sharing class LicenseProductPicklistService {

    private static final String CLASS_NAME = 'LicenseProductPicklistService';

    @TestVisible
    private static LicenseSelector mockLicenseSelector;
    @TestVisible
    private static InsuranceProductSelector mockProductSelector;

    private LicenseSelector licenseSelector {
        get {
            if (mockLicenseSelector != null) {
                return mockLicenseSelector;
            }
            if (licenseSelector == null) {
                licenseSelector = new LicenseSelector();
            }
            return licenseSelector;
        }
        set;
    }

    private InsuranceProductSelector productSelector {
        get {
            if (mockProductSelector != null) {
                return mockProductSelector;
            }
            if (productSelector == null) {
                productSelector = new InsuranceProductSelector();
            }
            return productSelector;
        }
        set;
    }

    /**
     *********************************************************
     * @Method Name    : parsePicklistValues
     * @description    : Parses semicolon-separated picklist string into a Set.
     * @param          : picklistValue - Semicolon-separated string value
     * @return         : Set of individual values (trimmed)
     *********************************************************
     */
    public Set<String> parsePicklistValues(String picklistValue) {
        Set<String> values = new Set<String>();
        if (String.isNotBlank(picklistValue)) {
            for (String value : picklistValue.split(';')) {
                values.add(value.trim());
            }
        }
        return values;
    }

    /**
     *********************************************************
     * @Method Name    : buildPicklistString
     * @description    : Builds semicolon-separated string from Set of values.
     *                   Values are sorted alphabetically.
     * @param          : values - Set of values to combine
     * @return         : Semicolon-separated string, or null if empty
     *********************************************************
     */
    public String buildPicklistString(Set<String> values) {
        if (values == null || values.isEmpty()) {
            return null;
        }
        List<String> sortedValues = new List<String>(values);
        sortedValues.sort();
        return String.join(sortedValues, ';');
    }

    /**
     *********************************************************
     * @Method Name    : addProductNamesToLicenses
     * @description    : Adds Insurance Product names to License picklist fields.
     *                   Returns list of Licenses that need to be updated.
     * @param          : junctions - List of License-Product junction records
     * @return         : List of License records to update (with new picklist values)
     *********************************************************
     */
    public List<ht_License__c> addProductNamesToLicenses(List<ht_License_Insurance_Product__c> junctions) {
        String methodName = 'addProductNamesToLicenses';
        List<ht_License__c> licensesToUpdate = new List<ht_License__c>();

        try {
            // 1. Collect License IDs and Product IDs from junctions
            Set<Id> licenseIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();
            Map<Id, Set<Id>> licenseToProductIds = new Map<Id, Set<Id>>();

            for (ht_License_Insurance_Product__c junction : junctions) {
                if (junction.ht_License__c != null) {
                    licenseIds.add(junction.ht_License__c);
                }
                if (junction.ht_InsuranceProduct__c != null) {
                    productIds.add(junction.ht_InsuranceProduct__c);
                }

                // Map License to its Products
                if (!licenseToProductIds.containsKey(junction.ht_License__c)) {
                    licenseToProductIds.put(junction.ht_License__c, new Set<Id>());
                }
                licenseToProductIds.get(junction.ht_License__c).add(junction.ht_InsuranceProduct__c);
            }

            if (licenseIds.isEmpty() || productIds.isEmpty()) {
                return licensesToUpdate;
            }

            // 2. Query current License values using selector
            Map<Id, ht_License__c> licenses = new Map<Id, ht_License__c>(
                licenseSelector.getLicensesWithProductsFieldByIds(licenseIds)
            );

            // 3. Query Product names using selector
            Map<Id, ht_Insurance_Product__c> products = new Map<Id, ht_Insurance_Product__c>(
                productSelector.getProductsByIds(productIds)
            );

            // 4. For each License, add product names
            for (Id licenseId : licenseToProductIds.keySet()) {
                ht_License__c license = licenses.get(licenseId);
                if (license == null) {
                    continue;
                }

                // Parse existing values into Set
                Set<String> existingProducts = parsePicklistValues(license.ht_License_Products__c);

                // Add new product names
                Boolean hasChanges = false;
                for (Id productId : licenseToProductIds.get(licenseId)) {
                    ht_Insurance_Product__c product = products.get(productId);
                    if (product != null && String.isNotBlank(product.ht_ProductName__c)) {
                        if (!existingProducts.contains(product.ht_ProductName__c)) {
                            existingProducts.add(product.ht_ProductName__c);
                            hasChanges = true;
                        }
                    }
                }

                // Rebuild picklist string if changed
                if (hasChanges) {
                    license.ht_License_Products__c = buildPicklistString(existingProducts);
                    licensesToUpdate.add(license);
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return licensesToUpdate;
    }

    /**
     *********************************************************
     * @Method Name    : removeProductNamesFromLicenses
     * @description    : Removes Insurance Product names from License picklist fields.
     *                   Returns list of Licenses that need to be updated.
     * @param          : deletedJunctions - List of deleted License-Product junction records
     * @return         : List of License records to update (with updated picklist values)
     *********************************************************
     */
    public List<ht_License__c> removeProductNamesFromLicenses(List<ht_License_Insurance_Product__c> deletedJunctions) {
        String methodName = 'removeProductNamesFromLicenses';
        List<ht_License__c> licensesToUpdate = new List<ht_License__c>();

        try {
            // 1. Collect License IDs and Product IDs from deleted junctions
            Set<Id> licenseIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();
            Map<Id, Set<Id>> licenseToDeletedProductIds = new Map<Id, Set<Id>>();

            for (ht_License_Insurance_Product__c junction : deletedJunctions) {
                if (junction.ht_License__c != null) {
                    licenseIds.add(junction.ht_License__c);
                }
                if (junction.ht_InsuranceProduct__c != null) {
                    productIds.add(junction.ht_InsuranceProduct__c);
                }

                // Map License to its deleted Products
                if (!licenseToDeletedProductIds.containsKey(junction.ht_License__c)) {
                    licenseToDeletedProductIds.put(junction.ht_License__c, new Set<Id>());
                }
                licenseToDeletedProductIds.get(junction.ht_License__c).add(junction.ht_InsuranceProduct__c);
            }

            if (licenseIds.isEmpty() || productIds.isEmpty()) {
                return licensesToUpdate;
            }

            // 2. Query current License values using selector
            Map<Id, ht_License__c> licenses = new Map<Id, ht_License__c>(
                licenseSelector.getLicensesWithProductsFieldByIds(licenseIds)
            );

            // 3. Query Product names using selector
            Map<Id, ht_Insurance_Product__c> products = new Map<Id, ht_Insurance_Product__c>(
                productSelector.getProductsByIds(productIds)
            );

            // 4. For each License, remove deleted product names
            for (Id licenseId : licenseToDeletedProductIds.keySet()) {
                ht_License__c license = licenses.get(licenseId);
                if (license == null || String.isBlank(license.ht_License_Products__c)) {
                    continue;
                }

                // Parse existing values into Set
                Set<String> existingProducts = parsePicklistValues(license.ht_License_Products__c);

                // Remove deleted product names
                Boolean hasChanges = false;
                for (Id productId : licenseToDeletedProductIds.get(licenseId)) {
                    ht_Insurance_Product__c product = products.get(productId);
                    if (product != null && String.isNotBlank(product.ht_ProductName__c)) {
                        if (existingProducts.contains(product.ht_ProductName__c)) {
                            existingProducts.remove(product.ht_ProductName__c);
                            hasChanges = true;
                        }
                    }
                }

                // Rebuild picklist string if changed
                if (hasChanges) {
                    license.ht_License_Products__c = buildPicklistString(existingProducts);
                    licensesToUpdate.add(license);
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return licensesToUpdate;
    }
}