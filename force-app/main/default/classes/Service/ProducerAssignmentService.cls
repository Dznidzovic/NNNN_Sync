/*
*********************************************************
Apex Class Name    : ProducerAssignmentService
Created Date       : 2025-04-08
@description       : Service class for assigning Producer__c based on ht_NPN__c for any SObject
@author            : Uros Markovic
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-08   Uros Markovic   Initial Version
1.1   2025-04-10   Uros Markovic   Replaced manual insert logic with upsert on ht_NPN__c
1.2   2025-04-25   Stefan Nidzovic   Added handling for orphaned producers when NPN is changed
*********************************************************
*/
public with sharing class ProducerAssignmentService {

    private static final String CLASS_NAME = 'ProducerAssignmentService';

    // Test-visible mock properties for unit testing without DML
    @TestVisible private static Map<String, ht_Producer__c> mockProducersByNPN;
    @TestVisible private static List<Account> mockAccountsByNPN;
    @TestVisible private static List<Contact> mockContactsByNPN;
    @TestVisible private static List<Lead> mockLeadsByNPN;
    @TestVisible private static Boolean useMocks = false;

    private final ProducerSelector producerSelector = new ProducerSelector();
    private final AccountSelector accountSelector = new AccountSelector();
    private final ContactSelector contactSelector = new ContactSelector();
    private final LeadSelector leadSelector = new LeadSelector();


    /*
    *********************************************************
    @Method Name    : assignProducers
    @author         : Uros Markovic
    @description    : Main entry method to assign Producer__c based on ht_NPN__c field
    @param          : records - List of incoming SObject records
    @param          : oldRecords - Map of old SObject records (for update comparison)
    @return         : void
    ********************************************************
    */
    public void assignProducers(List<SObject> records, Map<Id, SObject> oldRecords) {
        List<SObject> recordsToProcess = filterChangedAndValidRecords(records, oldRecords);

        if (recordsToProcess.isEmpty()) return;

        // Handle new NPNs - assign or create producers for these NPNs
        Set<String> newNpns = extractUniqueNPNs(recordsToProcess);
        List<ht_Producer__c> existingProducers = useMocks && mockProducersByNPN != null
            ? mockProducersByNPN.values()
            : producerSelector.getProducersByNPNs(newNpns);
        Map<String, ht_Producer__c> producerMap = buildProducerMapByNPN(existingProducers);

        Boolean upsertFailed = upsertMissingProducers(newNpns, producerMap, recordsToProcess);

        if (upsertFailed) return;

        assignProducersToRecords(recordsToProcess, producerMap);
    }

    /*
    *********************************************************
    @Method Name    : handleOrphanedProducers
    @author         : Stefan Nidzovic
    @description    : Handles producers that may need to be deleted when NPNs are changed
    @param          : newRecords - List of new SObject records
    @param          : oldRecords - Map of old SObject records
    @return         : void
    ********************************************************
    */
    public void handleOrphanedProducers(List<SObject> newRecords, Map<Id, SObject> oldRecords) {
        // Collect old NPNs that are different from new NPNs (potential orphans)
        Set<String> potentialOrphanedNpns = new Set<String>();
        
        for (SObject newRecord : newRecords) {
            Id recordId = newRecord.Id;
            if (oldRecords.containsKey(recordId)) {
                SObject oldRecord = oldRecords.get(recordId);
                
                String oldNpn = (String) oldRecord.get('ht_NPN__c');
                String newNpn = (String) newRecord.get('ht_NPN__c');
                
                if (String.isNotBlank(oldNpn) && oldNpn != newNpn) {
                    potentialOrphanedNpns.add(oldNpn);
                }
            }
        }
        
        if (potentialOrphanedNpns.isEmpty()) return;

        // Get producers with these NPNs
        List<ht_Producer__c> potentialOrphanedProducers = useMocks && mockProducersByNPN != null
            ? getProducersFromMockByNPNs(potentialOrphanedNpns)
            : producerSelector.getProducersByNPNs(potentialOrphanedNpns);
        
        if (potentialOrphanedProducers.isEmpty()) return;
        
        // Find which NPNs are still in use by any Account, Contact, or Lead
        Set<String> npnsStillInUse = checkForRelatedRecords(potentialOrphanedNpns);
        
        // Collect producers whose NPNs are no longer in use
        List<ht_Producer__c> producersToDelete = new List<ht_Producer__c>();
        for (ht_Producer__c producer : potentialOrphanedProducers) {
            if (!npnsStillInUse.contains(producer.ht_NPN__c)) {
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
                Logger.error(CLASS_NAME, 'handleOrphanedProducers',
                    'Failed to delete orphaned producers',
                    e.getMessage(),
                    e.getStackTraceString());

                Logger.commitAsync();
            }
        }
    }
    
    /*
    *********************************************************
    @Method Name    : getProducersFromMockByNPNs
    @author         : Stefan Nidzovic
    @description    : Helper method to get producers from mock map by NPNs
    @param          : npns - Set of NPNs to search for
    @return         : List<ht_Producer__c> - List of producers matching the NPNs
    ********************************************************
    */
    private List<ht_Producer__c> getProducersFromMockByNPNs(Set<String> npns) {
        List<ht_Producer__c> result = new List<ht_Producer__c>();
        for (String npn : npns) {
            if (mockProducersByNPN.containsKey(npn)) {
                result.add(mockProducersByNPN.get(npn));
            }
        }
        return result;
    }

    /*
    *********************************************************
    @Method Name    : checkForRelatedRecords
    @author         : Stefan Nidzovic
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
            if (String.isNotBlank(acc.ht_NPN__c)) {
                npnsStillInUse.add(acc.ht_NPN__c);
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
            if (String.isNotBlank(con.ht_NPN__c)) {
                npnsStillInUse.add(con.ht_NPN__c);
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
            if (String.isNotBlank(lead.ht_NPN__c)) {
                npnsStillInUse.add(lead.ht_NPN__c);
            }
        }
        
        return npnsStillInUse;
    }

    /*
    *********************************************************
    @Method Name    : filterChangedAndValidRecords
    @author         : Uros Markovic
    @description    : Filters records where ht_NPN__c is changed and valid
    @param          : records - New list of SObject records
    @param          : oldRecords - Map of old SObject records
    @return         : List<SObject> - filtered valid records
    ********************************************************
    */
    private List<SObject> filterChangedAndValidRecords(List<SObject> records, Map<Id, SObject> oldRecords) {
        List<SObject> result = new List<SObject>();

        for (SObject record : records) {
            String newNpn = (String) record.get('ht_NPN__c');
            Boolean npnChanged = true;

            if (oldRecords != null && oldRecords.containsKey(record.Id)) {
                String oldNpn = (String) oldRecords.get(record.Id).get('ht_NPN__c');
                npnChanged = oldNpn != newNpn;
            }

            if (String.isNotBlank(newNpn)) {
                if (!RegexUtils.isValidNPN(newNpn)) {
                    if (record instanceof Contact) {
                        ((Contact) record).ht_NPN__c.addError('NPN must contain only numeric characters.');
                    } else if (record instanceof Lead) {
                        ((Lead) record).ht_NPN__c.addError('NPN must contain only numeric characters.');
                    } else if (record instanceof Account) {
                        ((Account) record).ht_NPN__c.addError('NPN must contain only numeric characters.');
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
    @description    : Extracts unique ht_NPN__c values from SObject records
    @author         : Uros Markovic
    @param          : records - List of filtered SObject records
    @return         : Set<String> - set of unique NPNs
    ********************************************************
    */
    private Set<String> extractUniqueNPNs(List<SObject> records) {
        Set<String> npns = new Set<String>();
        for (SObject record : records) {
            npns.add((String) record.get('ht_NPN__c'));
        }
        return npns;
    }

    /*
    *********************************************************
    @Method Name    : buildProducerMapByNPN
    @description    : Builds map of ht_Producer__c records by ht_NPN__c
    @author         : Uros Markovic
    @param          : producerList - List of Producer records
    @return         : Map<String, ht_Producer__c>
    ********************************************************
    */
    private Map<String, ht_Producer__c> buildProducerMapByNPN(List<ht_Producer__c> producerList) {
        Map<String, ht_Producer__c> producerMap = new Map<String, ht_Producer__c>();
        for (ht_Producer__c p : producerList) {
            producerMap.put(p.ht_NPN__c, p);
        }
        return producerMap;
    }

    /*
    *********************************************************
    @Method Name    : upsertMissingProducers
    @description    : Performs upsert on new Producers and updates the map
    @param          : npns - Set of unique NPNs
    @param          : producerMap - Existing producer map (will be updated)
    @param          : recordsToProcess - Records needing producer assignment
    @return         : Boolean - true if error occurred, false otherwise
    ********************************************************
    */
    private Boolean upsertMissingProducers(Set<String> npns, Map<String, ht_Producer__c> producerMap, List<SObject> recordsToProcess) {
        List<ht_Producer__c> producersToUpsert = new List<ht_Producer__c>();
        for (String npn : npns) {
            if (!producerMap.containsKey(npn)) {
                producersToUpsert.add(new ht_Producer__c(ht_NPN__c = npn));
            }
        }

        if (producersToUpsert.isEmpty()) return false;

        // Skip DML in test mode with mocks
        if (useMocks) {
            // In mock mode, create producers with proper mock IDs using dynamic key prefix
            String keyPrefix = ht_Producer__c.SObjectType.getDescribe().getKeyPrefix();
            Integer counter = mockProducersByNPN != null ? mockProducersByNPN.size() : 0;
            for (ht_Producer__c p : producersToUpsert) {
                if (mockProducersByNPN == null) {
                    mockProducersByNPN = new Map<String, ht_Producer__c>();
                }
                // Create a new producer with proper ID using dynamic key prefix
                counter++;
                String fakeId = keyPrefix + '0'.repeat(12 - String.valueOf(counter).length()) + counter;
                ht_Producer__c mockProducer = new ht_Producer__c();
                mockProducer.Id = Id.valueOf(fakeId);
                mockProducer.ht_NPN__c = p.ht_NPN__c;
                mockProducersByNPN.put(mockProducer.ht_NPN__c, mockProducer);
                producerMap.put(mockProducer.ht_NPN__c, mockProducer);
            }
            return false;
        }

        try {
            upsert producersToUpsert ht_NPN__c;
        } catch (DmlException e) {
            for (SObject record : recordsToProcess) {
                record.addError('Failed to assign producer. Contact your administrator.');
            }

            Logger.error(CLASS_NAME, 'upsertMissingProducers',
                'Failed to upsert producer records',
                e.getMessage(),
                e.getStackTraceString());
                
            Logger.commitAsync();

            return true;
        }

        // Refresh map after successful upsert
        List<ht_Producer__c> updatedProducers = producerSelector.getProducersByNPNs(npns);
        producerMap.clear();
        producerMap.putAll(buildProducerMapByNPN(updatedProducers));

        return false;
    }

    /*
    *********************************************************
    @Method Name    : assignProducersToRecords
    @description    : Assigns Producer__c lookup to record based on ht_NPN__c match
    @author         : Uros Markovic
    @param          : records - List of filtered SObject records
    @param          : producerMap - Map of NPN to ht_Producer__c records
    @return         : void
    ********************************************************
    */
    private void assignProducersToRecords(List<SObject> records, Map<String, ht_Producer__c> producerMap) {
        for (SObject record : records) {
            String npn = (String) record.get('ht_NPN__c');
            if (producerMap.containsKey(npn)) {
                record.put('ht_Producer__c', producerMap.get(npn).Id);
            }
        }
    }
}