/*
*********************************************************
Apex Class Name    : UniqueIdentifierService
Created Date       : 2025-12-15
@description       : Service class for generating unique identifiers on LOA Product Categorization objects.
                     Centralizes unique identifier generation logic for:
                     - d4c_Insurance_Product__c
                     - d4c_LOA_Insurance_Product_Mapping__c
                     - d4c_Insurance_Product_LOA_Mapping__c (junction)
                     - d4c_License_Insurance_Product__c (junction)
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan Nidzovic         Initial Version
*********************************************************
*/
public with sharing class UniqueIdentifierService {

    /**
     *********************************************************
     * @Method Name    : populateInsuranceProductUniqueId
     * @description    : Populates UniqueIdentifier for Insurance Product records.
     *                   Format: {StateOrProvince}-{ProductName}
     *                   Example: CA-Health Insurance
     * @param          : products - List of Insurance Product records to process
     *********************************************************
     */
    public void populateInsuranceProductUniqueId(List<d4c_Insurance_Product__c> products) {
        for (d4c_Insurance_Product__c product : products) {
            if (String.isNotBlank(product.d4c_StateOrProvince__c) &&
                String.isNotBlank(product.d4c_ProductName__c)) {
                product.d4c_UniqueIdentifier__c = product.d4c_StateOrProvince__c + '-' +
                    product.d4c_ProductName__c;
            }
        }
    }

    /**
     *********************************************************
     * @Method Name    : populateLOAMappingUniqueId
     * @description    : Populates UniqueIdentifier for LOA Insurance Product Mapping records.
     *                   Format: {StateOrProvinceCode}-{LineOfAuthorityCode}-{LineOfAuthorityDescription}
     *                   Example: CA-935-Accident & Health
     * @param          : mappings - List of LOA Mapping records to process
     *********************************************************
     */
    public void populateLOAMappingUniqueId(List<d4c_LOA_Insurance_Product_Mapping__c> mappings) {
        for (d4c_LOA_Insurance_Product_Mapping__c mapping : mappings) {
            if (String.isNotBlank(mapping.d4c_StateOrProvinceCode__c) &&
                String.isNotBlank(mapping.d4c_LineOfAuthorityCode__c) &&
                String.isNotBlank(mapping.d4c_LineOfAuthorityDescription__c)) {
                mapping.d4c_UniqueIdentifier__c = mapping.d4c_StateOrProvinceCode__c + '-' +
                    mapping.d4c_LineOfAuthorityCode__c + '-' +
                    mapping.d4c_LineOfAuthorityDescription__c;
            }
        }
    }

    /**
     *********************************************************
     * @Method Name    : populateInsProdLOAMappingUniqueId
     * @description    : Populates UniqueIdentifier for Insurance Product LOA Mapping junction records.
     *                   Format: {InsuranceProductId}-{LOAMappingId}
     * @param          : junctions - List of junction records to process
     *********************************************************
     */
    public void populateInsProdLOAMappingUniqueId(List<d4c_Insurance_Product_LOA_Mapping__c> junctions) {
        for (d4c_Insurance_Product_LOA_Mapping__c junction : junctions) {
            if (junction.d4c_InsuranceProduct__c != null && junction.d4c_LOAMapping__c != null) {
                junction.d4c_UniqueIdentifier__c = String.valueOf(junction.d4c_InsuranceProduct__c) +
                    '-' + String.valueOf(junction.d4c_LOAMapping__c);
            }
        }
    }

    /**
     *********************************************************
     * @Method Name    : populateLicenseInsProdUniqueId
     * @description    : Populates UniqueIdentifier for License Insurance Product junction records.
     *                   Format: {LicenseId}-{InsuranceProductId}
     * @param          : junctions - List of junction records to process
     *********************************************************
     */
    public void populateLicenseInsProdUniqueId(List<d4c_License_Insurance_Product__c> junctions) {
        for (d4c_License_Insurance_Product__c junction : junctions) {
            if (junction.d4c_License__c != null && junction.d4c_InsuranceProduct__c != null) {
                junction.d4c_UniqueIdentifier__c = String.valueOf(junction.d4c_License__c) +
                    '-' + String.valueOf(junction.d4c_InsuranceProduct__c);
            }
        }
    }
}