/*
*********************************************************
Apex Class Name    : LOAProductMappingService
Created Date       : 2025-12-15
@description       : Service class for LOA to Insurance Product Mapping operations.
                     Centralizes business logic for:
                     - Matching LOAs to Insurance Product Mappings by state/code/description
                     - Finding and updating orphan LOAs when new mappings are created
                     - Handling cascade delete cleanup when mappings are removed
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Dev4Clouds         Initial Version
*********************************************************
*/
public with sharing class LOAProductMappingService {

    private static final String CLASS_NAME = 'LOAProductMappingService';

    private LOAInsuranceProductMappingSelector mappingSelector = new LOAInsuranceProductMappingSelector();
    private LineOfAuthoritySelector loaSelector = new LineOfAuthoritySelector();
    private LicenseInsuranceProductSelector licenseProductSelector = new LicenseInsuranceProductSelector();
    private LicenseProductCategorizationService categorizationService = new LicenseProductCategorizationService();

    /**
     *********************************************************
     * @Method Name    : buildMappingKey
     * @description    : Builds the unique key for matching LOA to mapping.
     *                   Format: StateOrProvinceCode-LineOfAuthorityCode-LineOfAuthorityDescription
     * @param          : stateCode - State or province code
     * @param          : loaCode - Line of Authority code
     * @param          : loaDescription - Line of Authority description
     * @return         : The unique key string, or null if any component is missing
     *********************************************************
     */
    public String buildMappingKey(String stateCode, String loaCode, String loaDescription) {
        if (String.isBlank(stateCode) || String.isBlank(loaCode) || String.isBlank(loaDescription)) {
            return null;
        }
        return stateCode + '-' + loaCode + '-' + loaDescription;
    }

    /**
     *********************************************************
     * @Method Name    : matchLoasToMappings
     * @description    : Matches LOA records to their Insurance Product mappings.
     *                   Uses state/code/description composite key to find matching mappings.
     *                   Sets d4c_LOAMapping__c lookup field on each LOA.
     * @param          : loas - List of LOA records to match
     *********************************************************
     */
    public void matchLoasToMappings(List<d4c_LineOfAuthority__c> loas) {
        String methodName = 'matchLoasToMappings';

        try {
            // 1. Build Set<String> of unique keys for all LOAs
            Set<String> keys = new Set<String>();
            for (d4c_LineOfAuthority__c loa : loas) {
                String key = buildMappingKey(
                    loa.d4c_StateOrProvinceCode__c,
                    loa.d4c_LineOfAuthorityCode__c,
                    loa.d4c_LineOfAuthorityDescription__c
                );
                if (key != null) {
                    keys.add(key);
                }
            }

            // Early exit if no valid keys
            if (keys.isEmpty()) {
                return;
            }

            // 2. Query mappings by UniqueIdentifier using selector
            Map<String, Id> keyToMappingId = new Map<String, Id>();
            List<d4c_LOA_Insurance_Product_Mapping__c> mappings = mappingSelector.getMappingsByUniqueIdentifiers(keys);
            for (d4c_LOA_Insurance_Product_Mapping__c mapping : mappings) {
                keyToMappingId.put(mapping.d4c_UniqueIdentifier__c, mapping.Id);
            }

            // 3. For each LOA, set the mapping lookup
            for (d4c_LineOfAuthority__c loa : loas) {
                String key = buildMappingKey(
                    loa.d4c_StateOrProvinceCode__c,
                    loa.d4c_LineOfAuthorityCode__c,
                    loa.d4c_LineOfAuthorityDescription__c
                );
                if (key != null && keyToMappingId.containsKey(key)) {
                    loa.d4c_LOAMapping__c = keyToMappingId.get(key);
                    loa.d4c_IsProductMatched__c = true;
                } else {
                    loa.d4c_LOAMapping__c = null;
                    loa.d4c_IsProductMatched__c = false;
                }
            }

        } catch (Exception e) {
            // Log error but don't throw - LOA should save even if matching fails
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /**
     *********************************************************
     * @Method Name    : findOrphanLoasForMappings
     * @description    : Finds LOA records that should be linked to given mappings.
     *                   "Orphan" LOAs are those with matching state/code/description
     *                   but null d4c_LOAMapping__c.
     * @param          : loaMappingIds - Set of d4c_LOA_Insurance_Product_Mapping__c IDs
     * @return         : List of orphan LOA records with d4c_LOAMapping__c populated
     *********************************************************
     */
    public List<d4c_LineOfAuthority__c> findOrphanLoasForMappings(Set<Id> loaMappingIds) {
        String methodName = 'findOrphanLoasForMappings';
        List<d4c_LineOfAuthority__c> loasToUpdate = new List<d4c_LineOfAuthority__c>();

        try {
            if (loaMappingIds == null || loaMappingIds.isEmpty()) {
                return loasToUpdate;
            }

            // 1. Query mappings with state/code/description fields
            List<d4c_LOA_Insurance_Product_Mapping__c> mappings = mappingSelector.getMappingsByIds(loaMappingIds);

            // 2. Build unique keys and collect filter values
            Map<String, Id> keyToMappingId = new Map<String, Id>();
            Set<String> states = new Set<String>();
            Set<String> codes = new Set<String>();
            Set<String> descriptions = new Set<String>();

            for (d4c_LOA_Insurance_Product_Mapping__c mapping : mappings) {
                String key = buildMappingKey(
                    mapping.d4c_StateOrProvinceCode__c,
                    mapping.d4c_LineOfAuthorityCode__c,
                    mapping.d4c_LineOfAuthorityDescription__c
                );
                if (key != null) {
                    keyToMappingId.put(key, mapping.Id);
                    states.add(mapping.d4c_StateOrProvinceCode__c);
                    codes.add(mapping.d4c_LineOfAuthorityCode__c);
                    descriptions.add(mapping.d4c_LineOfAuthorityDescription__c);
                }
            }

            if (keyToMappingId.isEmpty()) {
                return loasToUpdate;
            }

            // 3. Query orphan LOAs using selector
            List<d4c_LineOfAuthority__c> potentialOrphans = loaSelector.getOrphanLoasByStateCodeDesc(
                states, codes, descriptions
            );

            // 4. Match orphan LOAs with mappings using composite key
            for (d4c_LineOfAuthority__c loa : potentialOrphans) {
                String loaKey = buildMappingKey(
                    loa.d4c_StateOrProvinceCode__c,
                    loa.d4c_LineOfAuthorityCode__c,
                    loa.d4c_LineOfAuthorityDescription__c
                );
                if (keyToMappingId.containsKey(loaKey)) {
                    loa.d4c_LOAMapping__c = keyToMappingId.get(loaKey);
                    loasToUpdate.add(loa);
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return loasToUpdate;
    }

    /**
     *********************************************************
     * @Method Name    : deleteLicenseProductsForDeletedMappingJunctions
     * @description    : When d4c_Insurance_Product_LOA_Mapping__c junctions are deleted,
     *                   finds and deletes the License-Product junctions that were granted
     *                   by those specific mapping-product relationships.
     * @param          : deletedJunctions - List of deleted d4c_Insurance_Product_LOA_Mapping__c records
     * @return         : Number of License-Product junctions deleted
     *********************************************************
     */
    public Integer deleteLicenseProductsForDeletedMappingJunctions(List<d4c_Insurance_Product_LOA_Mapping__c> deletedJunctions) {
        String methodName = 'deleteLicenseProductsForDeletedMappingJunctions';
        Integer deletedCount = 0;
        
        try {
            if (deletedJunctions == null || deletedJunctions.isEmpty()) {
                return deletedCount;
            }

            // 1. Extract unique LOA Mapping IDs and Product IDs from deleted junctions
            Set<Id> loaMappingIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();
            Map<Id, Set<Id>> mappingToProductIds = new Map<Id, Set<Id>>();

            for (d4c_Insurance_Product_LOA_Mapping__c junction : deletedJunctions) {
                if (junction.d4c_LOAMapping__c != null && junction.d4c_InsuranceProduct__c != null) {
                    loaMappingIds.add(junction.d4c_LOAMapping__c);
                    productIds.add(junction.d4c_InsuranceProduct__c);

                    // Build map of mapping to products
                    if (!mappingToProductIds.containsKey(junction.d4c_LOAMapping__c)) {
                        mappingToProductIds.put(junction.d4c_LOAMapping__c, new Set<Id>());
                    }
                    mappingToProductIds.get(junction.d4c_LOAMapping__c).add(junction.d4c_InsuranceProduct__c);
                }
            }

            if (loaMappingIds.isEmpty() || productIds.isEmpty()) {
                return deletedCount;
            }

            // 2. Get all LOAs affected by these mappings
            List<d4c_LineOfAuthority__c> affectedLoas = loaSelector.getLoasByMappingIds(loaMappingIds);

            if (affectedLoas.isEmpty()) {
                return deletedCount;
            }

            // 3. Build unique identifiers for junctions to delete
            Set<String> junctionKeysToDelete = new Set<String>();

            for (d4c_LineOfAuthority__c loa : affectedLoas) {
                if (loa.d4c_License__c == null || loa.d4c_LOAMapping__c == null) {
                    continue;
                }

                Set<Id> productsForThisMapping = mappingToProductIds.get(loa.d4c_LOAMapping__c);
                if (productsForThisMapping != null) {
                    for (Id productId : productsForThisMapping) {
                        // Build unique identifier for License-Product junction
                        String junctionKey = categorizationService.buildLicenseProductUniqueId(loa.d4c_License__c, productId);
                        if (junctionKey != null) {
                            junctionKeysToDelete.add(junctionKey);
                        }
                    }
                }
            }

            // 4. Query and delete the specific License-Product junctions
            if (!junctionKeysToDelete.isEmpty()) {
                List<d4c_License_Insurance_Product__c> junctionsToDelete =
                    licenseProductSelector.getJunctionsByUniqueIdentifiers(junctionKeysToDelete);

                if (!junctionsToDelete.isEmpty()) {
                    delete junctionsToDelete;
                    deletedCount = junctionsToDelete.size();
                }
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }

        return deletedCount;
    }


    /**
     *********************************************************
     * @Method Name    : filterLoasWithMappings
     * @description    : Filters LOA records to only include those with d4c_LOAMapping__c populated.
     * @param          : loas - List of LOA records to filter
     * @return         : List of LOA records where d4c_LOAMapping__c is not null
     *********************************************************
     */
    public List<d4c_LineOfAuthority__c> filterLoasWithMappings(List<d4c_LineOfAuthority__c> loas) {
        List<d4c_LineOfAuthority__c> result = new List<d4c_LineOfAuthority__c>();
        for (d4c_LineOfAuthority__c loa : loas) {
            if (loa.d4c_LOAMapping__c != null) {
                result.add(loa);
            }
        }
        return result;
    }

    /**
     *********************************************************
     * @Method Name    : filterLoasWithChangedMappings
     * @description    : Filters LOA records to only include those where d4c_LOAMapping__c changed.
     * @param          : newLoaMap - Map of new LOA values
     * @param          : oldLoaMap - Map of old LOA values
     * @return         : Map with 'changed' key containing filtered new LOAs and 'old' containing their old values
     *********************************************************
     */
    public Map<String, Object> filterLoasWithChangedMappings(
        Map<Id, d4c_LineOfAuthority__c> newLoaMap,
        Map<Id, d4c_LineOfAuthority__c> oldLoaMap
    ) {
        List<d4c_LineOfAuthority__c> changedLoas = new List<d4c_LineOfAuthority__c>();
        Map<Id, d4c_LineOfAuthority__c> oldLoasForChanged = new Map<Id, d4c_LineOfAuthority__c>();

        for (Id loaId : newLoaMap.keySet()) {
            d4c_LineOfAuthority__c newLoa = newLoaMap.get(loaId);
            d4c_LineOfAuthority__c oldLoa = oldLoaMap.get(loaId);

            // Check if mapping changed (including null to value, value to null, value to different value)
            if (newLoa.d4c_LOAMapping__c != oldLoa.d4c_LOAMapping__c) {
                changedLoas.add(newLoa);
                oldLoasForChanged.put(loaId, oldLoa);
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('changed', changedLoas);
        result.put('old', oldLoasForChanged);
        return result;
    }
}