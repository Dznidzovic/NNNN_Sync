/*
*********************************************************
Apex Class Name    : EntityAssignmentService
Created Date       : 2025-04-08
@description       : Service class for assigning Entity__c based on d4c_NPN__c for any SObject
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-08   Dev4Clouds   Initial Version
1.1   2025-04-10   Dev4Clouds   Replaced manual insert logic with upsert on d4c_NPN__c
1.2   2025-04-25   Dev4Clouds   Added handling for orphaned producers when NPN is changed
*********************************************************
*/
public with sharing class EntityAssignmentService {

    private static final String CLASS_NAME = 'EntityAssignmentService';

    // Test-visible mock properties for unit testing without DML
    @TestVisible private static Map<String, d4c_Entity__c> mockEntitysByNPN;
    @TestVisible private static List<Account> mockAccountsByNPN;
    @TestVisible private static List<Contact> mockContactsByNPN;
    @TestVisible private static List<Lead> mockLeadsByNPN;
    @TestVisible private static Boolean useMocks = false;

    private final EntitySelector entitySelector = new EntitySelector();
    private final AccountSelector accountSelector = new AccountSelector();
    private final ContactSelector contactSelector = new ContactSelector();
    private final LeadSelector leadSelector = new LeadSelector();


    /*
    *********************************************************
    @Method Name    : assignEntitys
    @author         : Dev4Clouds
    @description    : Main entry method to assign Entity__c based on d4c_NPN__c field
    @param          : records - List of incoming SObject records
    @param          : oldRecords - Map of old SObject records (for update comparison)
    @return         : void
    ********************************************************
    */
    public void assignEntitys(List<SObject> records, Map<Id, SObject> oldRecords) {
        List<SObject> recordsToProcess = filterChangedAndValidRecords(records, oldRecords);

        if (recordsToProcess.isEmpty()) return;

        // Handle new NPNs - assign or create producers for these NPNs
        Set<String> newNpns = extractUniqueNPNs(recordsToProcess);
        List<d4c_Entity__c> existingEntitys = useMocks && mockEntitysByNPN != null
            ? mockEntitysByNPN.values()
            : entitySelector.getEntitysByNPNs(newNpns);
        Map<String, d4c_Entity__c> producerMap = buildEntityMapByNPN(existingEntitys);

        Boolean upsertFailed = upsertMissingEntitys(newNpns, producerMap, recordsToProcess);

        if (upsertFailed) return;

        assignEntitysToRecords(recordsToProcess, producerMap);
    }

    /*
    *********************************************************
    @Method Name    : handleOrphanedEntitys
    @author         : Dev4Clouds
    @description    : Handles producers that may need to be deleted when NPNs are changed
    @param          : newRecords - List of new SObject records
    @param          : oldRecords - Map of old SObject records
    @return         : void
    ********************************************************
    */
    public void handleOrphanedEntitys(List<SObject> newRecords, Map<Id, SObject> oldRecords) {
        // Collect old NPNs that are different from new NPNs (potential orphans)
        Set<String> potentialOrphanedNpns = new Set<String>();
        
        for (SObject newRecord : newRecords) {
            Id recordId = newRecord.Id;
            if (oldRecords.containsKey(recordId)) {
                SObject oldRecord = oldRecords.get(recordId);
                
                String oldNpn = (String) oldRecord.get('d4c_NPN__c');
                String newNpn = (String) newRecord.get('d4c_NPN__c');
                
                if (String.isNotBlank(oldNpn) && oldNpn != newNpn) {
                    potentialOrphanedNpns.add(oldNpn);
                }
            }
        }
        
        if (potentialOrphanedNpns.isEmpty()) return;

        // Get producers with these NPNs
        List<d4c_Entity__c> potentialOrphanedEntitys = useMocks && mockEntitysByNPN != null
            ? getEntitysFromMockByNPNs(potentialOrphanedNpns)
            : entitySelector.getEntitysByNPNs(potentialOrphanedNpns);
        
        if (potentialOrphanedEntitys.isEmpty()) return;
        
        // Find which NPNs are still in use by any Account, Contact, or Lead
        Set<String> npnsStillInUse = checkForRelatedRecords(potentialOrphanedNpns);
        
        // Collect producers whose NPNs are no longer in use
        List<d4c_Entity__c> producersToDelete = new List<d4c_Entity__c>();
        for (d4c_Entity__c producer : potentialOrphanedEntitys) {
            if (!npnsStillInUse.contains(producer.d4c_NPN__c)) {
                producersToDelete.add(producer);
            }
        }
        
        // Delete orphaned producers
        if (!producersToDelete.isEmpty()) {
            // Skip DML in test mode with mocks
            if (useMocks) {
                return; // In mock mode, skip the delete operation
            }

            try {
                delete producersToDelete;
            } catch (Exception e) {
                Logger.error(CLASS_NAME, 'handleOrphanedEntitys',
                    'Failed to delete orphaned producers',
                    e.getMessage(),
                    e.getStackTraceString());

                Logger.commitAsync();
            }
        }
    }
    
    /*
    *********************************************************
    @Method Name    : getEntitysFromMockByNPNs
    @author         : Dev4Clouds
    @description    : Helper method to get producers from mock map by NPNs
    @param          : npns - Set of NPNs to search for
    @return         : List<d4c_Entity__c> - List of producers matching the NPNs
    ********************************************************
    */
    private List<d4c_Entity__c> getEntitysFromMockByNPNs(Set<String> npns) {
        List<d4c_Entity__c> result = new List<d4c_Entity__c>();
        for (String npn : npns) {
            if (mockEntitysByNPN.containsKey(npn)) {
                result.add(mockEntitysByNPN.get(npn));
            }
        }
        return result;
    }

    /*
    *********************************************************
    @Method Name    : checkForRelatedRecords
    @author         : Dev4Clouds
    @description    : Checks if any NPNs are still in use by any records
    @param          : npnsToCheck - Set of NPNs to check for usage
    @return         : Set<String> - Set of NPNs that are still in use
    ********************************************************
    */
    private Set<String> checkForRelatedRecords(Set<String> npnsToCheck) {
        // Create a set to hold NPNs that are still in use
        Set<String> npnsStillInUse = new Set<String>();
        
        // Query for any Accounts, Contacts, or Leads that use these NPNs
        // Use a single optimized SOQL query for each object type

        List<Account> accounts = useMocks && mockAccountsByNPN != null
            ? mockAccountsByNPN
            : accountSelector.getAccountsByNPNs(npnsToCheck);

        for (Account acc : accounts) {
            if (String.isNotBlank(acc.d4c_NPN__c)) {
                npnsStillInUse.add(acc.d4c_NPN__c);
            }
        }

        // If all NPNs are already found in use, no need to check other objects
        if (npnsStillInUse.size() == npnsToCheck.size()) {
            return npnsStillInUse;
        }
        
        List<Contact> contacts = useMocks && mockContactsByNPN != null
            ? mockContactsByNPN
            : contactSelector.getContactsByNPNs(npnsToCheck);

        for (Contact con : contacts) {
            if (String.isNotBlank(con.d4c_NPN__c)) {
                npnsStillInUse.add(con.d4c_NPN__c);
            }
        }
        
        // If all NPNs are already found in use, no need to check other objects
        if (npnsStillInUse.size() == npnsToCheck.size()) {
            return npnsStillInUse;
        }
        
        List<Lead> leads = useMocks && mockLeadsByNPN != null
            ? mockLeadsByNPN
            : leadSelector.getLeadsByNPNs(npnsToCheck);
        
        for (Lead lead : leads) {
            if (String.isNotBlank(lead.d4c_NPN__c)) {
                npnsStillInUse.add(lead.d4c_NPN__c);
            }
        }
        
        return npnsStillInUse;
    }

    /*
    *********************************************************
    @Method Name    : filterChangedAndValidRecords
    @author         : Dev4Clouds
    @description    : Filters records where d4c_NPN__c is changed and valid
    @param          : records - New list of SObject records
    @param          : oldRecords - Map of old SObject records
    @return         : List<SObject> - filtered valid records
    ********************************************************
    */
    private List<SObject> filterChangedAndValidRecords(List<SObject> records, Map<Id, SObject> oldRecords) {
        List<SObject> result = new List<SObject>();

        for (SObject record : records) {
            String newNpn = (String) record.get('d4c_NPN__c');
            Boolean npnChanged = true;

            if (oldRecords != null && oldRecords.containsKey(record.Id)) {
                String oldNpn = (String) oldRecords.get(record.Id).get('d4c_NPN__c');
                npnChanged = oldNpn != newNpn;
            }

            if (String.isNotBlank(newNpn)) {
                if (!RegexUtils.isValidNPN(newNpn)) {
                    if (record instanceof Contact) {
                        ((Contact) record).d4c_NPN__c.addError('NPN must contain only numeric characters.');
                    } else if (record instanceof Lead) {
                        ((Lead) record).d4c_NPN__c.addError('NPN must contain only numeric characters.');
                    } else if (record instanceof Account) {
                        ((Account) record).d4c_NPN__c.addError('NPN must contain only numeric characters.');
                    } else {
                        record.addError('Invalid record type for NPN validation.');
                    }
                    continue;
                }
            }

            if (!npnChanged || String.isBlank(newNpn)) continue;

            result.add(record);
        }

        return result;
    }

    /*
    *********************************************************
    @Method Name    : extractUniqueNPNs
    @description    : Extracts unique d4c_NPN__c values from SObject records
    @author         : Dev4Clouds
    @param          : records - List of filtered SObject records
    @return         : Set<String> - set of unique NPNs
    ********************************************************
    */
    private Set<String> extractUniqueNPNs(List<SObject> records) {
        Set<String> npns = new Set<String>();
        for (SObject record : records) {
            npns.add((String) record.get('d4c_NPN__c'));
        }
        return npns;
    }

    /*
    *********************************************************
    @Method Name    : buildEntityMapByNPN
    @description    : Builds map of d4c_Entity__c records by d4c_NPN__c
    @author         : Dev4Clouds
    @param          : producerList - List of Entity records
    @return         : Map<String, d4c_Entity__c>
    ********************************************************
    */
    private Map<String, d4c_Entity__c> buildEntityMapByNPN(List<d4c_Entity__c> producerList) {
        Map<String, d4c_Entity__c> producerMap = new Map<String, d4c_Entity__c>();
        for (d4c_Entity__c p : producerList) {
            producerMap.put(p.d4c_NPN__c, p);
        }
        return producerMap;
    }

    /*
    *********************************************************
    @Method Name    : upsertMissingEntitys
    @description    : Performs upsert on new Entitys and updates the map
    @param          : npns - Set of unique NPNs
    @param          : producerMap - Existing producer map (will be updated)
    @param          : recordsToProcess - Records needing producer assignment
    @return         : Boolean - true if error occurred, false otherwise
    ********************************************************
    */
    private Boolean upsertMissingEntitys(Set<String> npns, Map<String, d4c_Entity__c> producerMap, List<SObject> recordsToProcess) {
        List<d4c_Entity__c> producersToUpsert = new List<d4c_Entity__c>();
        for (String npn : npns) {
            if (!producerMap.containsKey(npn)) {
                producersToUpsert.add(new d4c_Entity__c(d4c_NPN__c = npn));
            }
        }

        if (producersToUpsert.isEmpty()) return false;

        // Skip DML in test mode with mocks
        if (useMocks) {
            // In mock mode, create producers with proper mock IDs using dynamic key prefix
            String keyPrefix = d4c_Entity__c.SObjectType.getDescribe().getKeyPrefix();
            Integer counter = mockEntitysByNPN != null ? mockEntitysByNPN.size() : 0;
            for (d4c_Entity__c p : producersToUpsert) {
                if (mockEntitysByNPN == null) {
                    mockEntitysByNPN = new Map<String, d4c_Entity__c>();
                }
                // Create a new producer with proper ID using dynamic key prefix
                counter++;
                String fakeId = keyPrefix + '0'.repeat(12 - String.valueOf(counter).length()) + counter;
                d4c_Entity__c mockEntity = new d4c_Entity__c();
                mockEntity.Id = Id.valueOf(fakeId);
                mockEntity.d4c_NPN__c = p.d4c_NPN__c;
                mockEntitysByNPN.put(mockEntity.d4c_NPN__c, mockEntity);
                producerMap.put(mockEntity.d4c_NPN__c, mockEntity);
            }
            return false;
        }

        try {
            upsert producersToUpsert d4c_NPN__c;
        } catch (DmlException e) {
            for (SObject record : recordsToProcess) {
                record.addError('Failed to assign producer. Contact your administrator.');
            }

            Logger.error(CLASS_NAME, 'upsertMissingEntitys',
                'Failed to upsert producer records',
                e.getMessage(),
                e.getStackTraceString());
                
            Logger.commitAsync();

            return true;
        }

        // Refresh map after successful upsert
        List<d4c_Entity__c> updatedEntitys = entitySelector.getEntitysByNPNs(npns);
        producerMap.clear();
        producerMap.putAll(buildEntityMapByNPN(updatedEntitys));

        return false;
    }

    /*
    *********************************************************
    @Method Name    : assignEntitysToRecords
    @description    : Assigns Entity__c lookup to record based on d4c_NPN__c match
    @author         : Dev4Clouds
    @param          : records - List of filtered SObject records
    @param          : producerMap - Map of NPN to d4c_Entity__c records
    @return         : void
    ********************************************************
    */
    private void assignEntitysToRecords(List<SObject> records, Map<String, d4c_Entity__c> producerMap) {
        for (SObject record : records) {
            String npn = (String) record.get('d4c_NPN__c');
            if (producerMap.containsKey(npn)) {
                record.put('d4c_Entity__c', producerMap.get(npn).Id);
            }
        }
    }
}