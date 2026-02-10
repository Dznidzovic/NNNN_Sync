/*
*********************************************************
Apex Class Name    : LicenseProductCategorizationService
Created Date       : 2025-12-15
@description       : Service class for License-Insurance Product categorization operations.
                     Centralizes business logic for:
                     - Creating License-Product junctions when LOAs have mappings
                     - Updating junctions when LOA mappings change
                     - Deleting junctions when LOAs are removed
                     - Getting products associated with LOA mappings
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
public with sharing class LicenseProductCategorizationService {

    private static final String CLASS_NAME = 'LicenseProductCategorizationService';

    private InsuranceProductLOAMappingSelector junctionSelector = new InsuranceProductLOAMappingSelector();
    private LicenseInsuranceProductSelector licenseProductSelector = new LicenseInsuranceProductSelector();

    /**
     *********************************************************
     * @Method Name    : getProductIdsForMappings
     * @description    : Gets Insurance Product IDs linked to LOA Mapping IDs.
     * @param          : loaMappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : Map of LOA Mapping ID to List of Insurance Product IDs
     *********************************************************
     */
    public Map<Id, List<Id>> getProductIdsForMappings(Set<Id> loaMappingIds) {
        Map<Id, List<Id>> mappingToProductIds = new Map<Id, List<Id>>();

        if (loaMappingIds == null || loaMappingIds.isEmpty()) {
            return mappingToProductIds;
        }

        List<d4c_Insurance_Product_LOA_Mapping__c> junctions = junctionSelector.getJunctionsByLoaMappingIds(loaMappingIds);
        for (d4c_Insurance_Product_LOA_Mapping__c junction : junctions) {
            if (!mappingToProductIds.containsKey(junction.d4c_LOAMapping__c)) {
                mappingToProductIds.put(junction.d4c_LOAMapping__c, new List<Id>());
            }
            mappingToProductIds.get(junction.d4c_LOAMapping__c).add(junction.d4c_InsuranceProduct__c);
        }

        return mappingToProductIds;
    }

    /**
     *********************************************************
     * @Method Name    : getProductIdSetForMappings
     * @description    : Gets Insurance Product IDs linked to LOA Mapping IDs as Sets.
     * @param          : loaMappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : Map of LOA Mapping ID to Set of Insurance Product IDs
     *********************************************************
     */
    public Map<Id, Set<Id>> getProductIdSetForMappings(Set<Id> loaMappingIds) {
        Map<Id, Set<Id>> mappingToProductIds = new Map<Id, Set<Id>>();

        if (loaMappingIds == null || loaMappingIds.isEmpty()) {
            return mappingToProductIds;
        }

        List<d4c_Insurance_Product_LOA_Mapping__c> junctions = junctionSelector.getJunctionsByLoaMappingIds(loaMappingIds);
        for (d4c_Insurance_Product_LOA_Mapping__c junction : junctions) {
            if (!mappingToProductIds.containsKey(junction.d4c_LOAMapping__c)) {
                mappingToProductIds.put(junction.d4c_LOAMapping__c, new Set<Id>());
            }
            mappingToProductIds.get(junction.d4c_LOAMapping__c).add(junction.d4c_InsuranceProduct__c);
        }

        return mappingToProductIds;
    }

    /**
     *********************************************************
     * @Method Name    : buildLicenseProductUniqueId
     * @description    : Builds unique identifier for License-Product junction.
     * @param          : licenseId - License record ID
     * @param          : productId - Insurance Product record ID
     * @return         : Unique identifier string (LicenseId-ProductId)
     *********************************************************
     */
    public String buildLicenseProductUniqueId(Id licenseId, Id productId) {
        if (licenseId == null || productId == null) {
            return null;
        }
        return String.valueOf(licenseId) + '-' + String.valueOf(productId);
    }

    /**
     *********************************************************
     * @Method Name    : createJunctionsForLoas
     * @description    : Creates License-Insurance Product junctions for LOAs with mappings.
     *                   Uses upsert with External ID to prevent duplicates.
     * @param          : loas - List of LOA records with populated d4c_LOAMapping__c
     * @return         : List of junctions ready for upsert
     *********************************************************
     */
    public List<d4c_License_Insurance_Product__c> createJunctionsForLoas(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'createJunctionsForLoas';
        List<d4c_License_Insurance_Product__c> junctionsToCreate = new List<d4c_License_Insurance_Product__c>();

        try {
            // 1. Collect all LOA Mapping IDs from loas
            Set<Id> loaMappingIds = new Set<Id>();
            for (d4c_LineOfAuthority__c loa : loas) {
                if (loa.d4c_LOAMapping__c != null) {
                    loaMappingIds.add(loa.d4c_LOAMapping__c);
                }
            }

            if (loaMappingIds.isEmpty()) {
                return junctionsToCreate;
            }

            // 2. Get products for each mapping
            Map<Id, List<Id>> mappingToProductIds = getProductIdsForMappings(loaMappingIds);

            // 3. For each LOA, create junction records
            for (d4c_LineOfAuthority__c loa : loas) {
                if (loa.d4c_LOAMapping__c == null || loa.d4c_License__c == null) {
                    continue;
                }
                Id licenseId = loa.d4c_License__c;
                List<Id> productIds = mappingToProductIds.get(loa.d4c_LOAMapping__c);
                if (productIds != null) {
                    for (Id productId : productIds) {
                        junctionsToCreate.add(new d4c_License_Insurance_Product__c(
                            d4c_License__c = licenseId,
                            d4c_InsuranceProduct__c = productId,
                            d4c_UniqueIdentifier__c = buildLicenseProductUniqueId(licenseId, productId)
                        ));
                    }
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return junctionsToCreate;
    }

    /**
     *********************************************************
     * @Method Name    : calculateJunctionChangesForLoaUpdates
     * @description    : Calculates which junctions to add/remove when LOA mappings change.
     * @param          : loas - List of LOA records with new mapping values
     * @param          : oldLoaMap - Map of old LOA values
     * @return         : Map containing 'toCreate' (List) and 'keysToDelete' (Set<String>)
     *********************************************************
     */
    public Map<String, Object> calculateJunctionChangesForLoaUpdates(
        List<d4c_LineOfAuthority__c> loas,
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap
    ) {
        String methodName = 'calculateJunctionChangesForLoaUpdates';
        List<d4c_License_Insurance_Product__c> junctionsToCreate = new List<d4c_License_Insurance_Product__c>();
        Set<String> junctionKeysToDelete = new Set<String>();

        try {
            // 1. Collect all mapping IDs (both old and new)
            Set<Id> allMappingIds = new Set<Id>();
            for (d4c_LineOfAuthority__c loa : loas) {
                if (loa.d4c_LOAMapping__c != null) {
                    allMappingIds.add(loa.d4c_LOAMapping__c);
                }
                d4c_LineOfAuthority__c oldLoa = oldLoaMap != null ? oldLoaMap.get(loa.Id) : null;
                if (oldLoa != null && oldLoa.d4c_LOAMapping__c != null) {
                    allMappingIds.add(oldLoa.d4c_LOAMapping__c);
                }
            }

            // 2. Get products for all mappings
            Map<Id, Set<Id>> mappingToProductIds = getProductIdSetForMappings(allMappingIds);

            // 3. Calculate products to add and remove for each LOA
            for (d4c_LineOfAuthority__c loa : loas) {
                Id licenseId = loa.d4c_License__c;
                if (licenseId == null) {
                    continue;
                }

                d4c_LineOfAuthority__c oldLoa = oldLoaMap != null ? oldLoaMap.get(loa.Id) : null;

                // Get old and new product sets
                Set<Id> oldProducts = new Set<Id>();
                Set<Id> newProducts = new Set<Id>();

                if (oldLoa != null && oldLoa.d4c_LOAMapping__c != null && mappingToProductIds.containsKey(oldLoa.d4c_LOAMapping__c)) {
                    oldProducts = mappingToProductIds.get(oldLoa.d4c_LOAMapping__c);
                }
                if (loa.d4c_LOAMapping__c != null && mappingToProductIds.containsKey(loa.d4c_LOAMapping__c)) {
                    newProducts = mappingToProductIds.get(loa.d4c_LOAMapping__c);
                }

                // Products to remove: in old but not in new
                for (Id productId : oldProducts) {
                    if (!newProducts.contains(productId)) {
                        junctionKeysToDelete.add(buildLicenseProductUniqueId(licenseId, productId));
                    }
                }

                // Products to add: in new but not in old
                for (Id productId : newProducts) {
                    if (!oldProducts.contains(productId)) {
                        junctionsToCreate.add(new d4c_License_Insurance_Product__c(
                            d4c_License__c = licenseId,
                            d4c_InsuranceProduct__c = productId,
                            d4c_UniqueIdentifier__c = buildLicenseProductUniqueId(licenseId, productId)
                        ));
                    }
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('toCreate', junctionsToCreate);
        result.put('keysToDelete', junctionKeysToDelete);
        return result;
    }

    /**
     *********************************************************
     * @Method Name    : getJunctionKeysToDeleteForLoas
     * @description    : Gets junction keys to delete for deleted LOAs.
     * @param          : deletedLoas - List of deleted LOA records
     * @return         : Set of junction unique identifier keys to delete
     *********************************************************
     */
    public Set<String> getJunctionKeysToDeleteForLoas(List<d4c_LineOfAuthority__c> deletedLoas) {
        String methodName = 'getJunctionKeysToDeleteForLoas';
        Set<String> junctionKeysToDelete = new Set<String>();

        try {
            // 1. Collect all LOA Mapping IDs from deleted loas
            Set<Id> loaMappingIds = new Set<Id>();
            for (d4c_LineOfAuthority__c loa : deletedLoas) {
                if (loa.d4c_LOAMapping__c != null) {
                    loaMappingIds.add(loa.d4c_LOAMapping__c);
                }
            }

            if (loaMappingIds.isEmpty()) {
                return junctionKeysToDelete;
            }

            // 2. Get products for each mapping
            Map<Id, Set<Id>> mappingToProductIds = getProductIdSetForMappings(loaMappingIds);

            // 3. Build set of junction keys to delete
            for (d4c_LineOfAuthority__c loa : deletedLoas) {
                if (loa.d4c_LOAMapping__c == null || loa.d4c_License__c == null) {
                    continue;
                }
                Id licenseId = loa.d4c_License__c;
                Set<Id> productIds = mappingToProductIds.get(loa.d4c_LOAMapping__c);
                if (productIds != null) {
                    for (Id productId : productIds) {
                        junctionKeysToDelete.add(buildLicenseProductUniqueId(licenseId, productId));
                    }
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return junctionKeysToDelete;
    }

    /**
     *********************************************************
     * @Method Name    : getJunctionsToDeleteByKeys
     * @description    : Queries junction records by their unique identifier keys.
     * @param          : junctionKeys - Set of unique identifier keys
     * @return         : List of junction records to delete
     *********************************************************
     */
    public List<d4c_License_Insurance_Product__c> getJunctionsToDeleteByKeys(Set<String> junctionKeys) {
        if (junctionKeys == null || junctionKeys.isEmpty()) {
            return new List<d4c_License_Insurance_Product__c>();
        }
        return licenseProductSelector.getJunctionsByUniqueIdentifiers(junctionKeys);
    }
}