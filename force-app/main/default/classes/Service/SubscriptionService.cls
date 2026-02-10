/**
 *********************************************************
 * Apex Class Name    : SubscriptionService
 * Created Date       : 2025-04-16
 * @description       : Service class for managing NIPR subscription operations
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   2025-04-16   Uros Markovic           Initial Version
 * 1.1   2025-04-25   Stefan Nidzovic         Added removeNPNsFromSubscription method
 * 1.2   2025-10-22   Stefan Nidzovic         Fixed getSubscriptionCounts to exclude large agency subscriptions
 * 1.3   2025-10-24   Stefan Nidzovic         Added support for Exclude Carrier Appointments subscription pools
 * 2.0   10-24-2025   Stefan Nidzovic         Complete refactor - clean architecture with DRY principles
 *********************************************************
 **/
public virtual with sharing class SubscriptionService {

    @TestVisible
    private static Integer MAX_PRODUCERS_PER_SUBSCRIPTION = 500;
    private final Integer MAX_RETRY_ATTEMPTS = 10;

    private final String CLASS_NAME = 'SubscriptionService';

    // PUBLIC PROPERTY - Set by orchestrator, used throughout service
    public d4c_Entity__c producer { get; private set; }

    // Selectors and Callouts
    private final MetadataTypeSelector mtdSelector = new MetadataTypeSelector();
    private final SubscriptionSelector subscriptionSelector = new SubscriptionSelector();
    private final ProducerSelector producerSelector = new ProducerSelector();
    private final CreateSubscription createSubscriptionAPI = new CreateSubscription();
    private final AddNPNToSubscription addNPNToSubscriptionAPI = new AddNPNToSubscription();
    private final RemoveNPNFromSubscription removeNPNFromSubscriptionAPI = new RemoveNPNFromSubscription();

    // ==================== SETTER ====================

    /**
     *********************************************************
     * @Method Name    : setProducer
     * @description    : Sets the producer for this service instance (called by orchestrator)
     * @param producer : Fresh producer record from orchestrator (or deleted producer for afterDelete)
     * @return         : void
     *********************************************************
     **/
    public void setProducer(d4c_Entity__c producer) {
        this.producer = producer;
    }

    // ==================== PUBLIC METHODS ====================

    /**
     *********************************************************
     * @Method Name    : addNPNToSubscription
     * @description    : Adds an NPN to a subscription (finds existing with capacity or creates new)
     *                   ALL DML operations happen AFTER all API callouts complete
     * @return         : void
     *********************************************************
     **/
    public void addNPNToSubscription() {
        String methodName = 'addNPNToSubscription';

        if (producer == null) {
            throw new SubscriptionServiceException('Producer not set in service. Call setProducer() first.');
        }

        String npn = producer.d4c_NPN__c;
        Boolean excludeFlag = producer.d4c_ExcludeCarrierAppointments__c;

        loadMaxProducersPerSubscription();

        // Find or create subscription and add NPN
        Id subscriptionId = findOrCreateAndAddNPN(excludeFlag);

        // Update producer with subscription lookup
        updateProducerSubscription(subscriptionId);

        Logger.commitAsync();
    }

    /**
     *********************************************************
     * @Method Name    : removeNPNFromNIPRAndSF (BULK)
     * @description    : Removes multiple NPNs from NIPR and clears Salesforce subscription lookups
     *                   Bulkified version - groups NPNs by subscription for efficient API calls
     * @param npns     : Set of NPNs to remove
     * @return         : void
     *********************************************************
     **/
    public void removeNPNFromNIPRAndSF(Set<String> npns) {
        String methodName = 'removeNPNFromNIPRAndSF';

        if (npns == null || npns.isEmpty()) {
            return;
        }

        // Query all producers with these NPNs
        List<d4c_Entity__c> producers = producerSelector.getProducersByNPNs(npns);

        if (producers.isEmpty()) {
            Logger.warning(CLASS_NAME, methodName, 'No producers found for NPNs', 'NPNs: ' + npns, null);
            return;
        }

        // Group NPNs by subscription for efficient API calls
        Map<Id, List<String>> subscriptionToNPNsMap = new Map<Id, List<String>>();
        List<d4c_Entity__c> producersToUpdate = new List<d4c_Entity__c>();

        for (d4c_Entity__c prod : producers) {
            if (prod.d4c_Subscription__c == null) {
                continue; // Skip producers without subscription
            }

            if (!subscriptionToNPNsMap.containsKey(prod.d4c_Subscription__c)) {
                subscriptionToNPNsMap.put(prod.d4c_Subscription__c, new List<String>());
            }
            subscriptionToNPNsMap.get(prod.d4c_Subscription__c).add(prod.d4c_NPN__c);

            producersToUpdate.add(prod);
        }

        // Step 1: Remove from NIPR (callouts) - grouped by subscription
        List<d4c_Subscription__c> subscriptions = subscriptionSelector.getSubscriptionsByIds(subscriptionToNPNsMap.keySet());

        for (d4c_Subscription__c sub : subscriptions) {
            String apiSubName = sub.d4c_Subscription_Name__c + '-' + UserInfo.getOrganizationId();
            List<String> npnsToRemove = subscriptionToNPNsMap.get(sub.Id);

            Boolean removeSuccess = executeRemoveNPNCallout(npnsToRemove, apiSubName);

            if (!removeSuccess) {
                throw new SubscriptionServiceException('Failed to remove NPNs: ' + npnsToRemove + ' from subscription: ' + sub.d4c_Subscription_Name__c);
            }
        }

        // Step 2: Clear producer subscription lookups in Salesforce (DML after callouts)
        for (d4c_Entity__c prod : producersToUpdate) {
            prod.d4c_Subscription__c = null;
        }

        update producersToUpdate;

        Logger.commitAsync();
    }

    /**
     *********************************************************
     * @Method Name    : removeNPNFromNIPR (BULK)
     * @description    : Removes multiple NPNs from NIPR subscription (callout only, no DML)
     *                   Used for afterDelete (producers already deleted, can't update SF)
     *                   Bulkified version - groups NPNs by subscription for efficient API calls
     * @param npnToSubscriptionMap : Map of NPN -> Subscription ID (from deleted producers)
     * @return         : void
     *********************************************************
     **/
    public void removeNPNFromNIPR(Map<String, Id> npnToSubscriptionMap) {
        String methodName = 'removeNPNFromNIPR';

        if (npnToSubscriptionMap == null || npnToSubscriptionMap.isEmpty()) {
            return;
        }

        // Group NPNs by subscription for efficient API calls
        Map<Id, List<String>> subscriptionToNPNsMap = new Map<Id, List<String>>();

        for (String npn : npnToSubscriptionMap.keySet()) {
            Id subscriptionId = npnToSubscriptionMap.get(npn);

            if (!subscriptionToNPNsMap.containsKey(subscriptionId)) {
                subscriptionToNPNsMap.put(subscriptionId, new List<String>());
            }
            subscriptionToNPNsMap.get(subscriptionId).add(npn);
        }

        // Query subscriptions
        List<d4c_Subscription__c> subscriptions = subscriptionSelector.getSubscriptionsByIds(subscriptionToNPNsMap.keySet());

        // Execute remove callouts (no DML - producers already deleted)
        for (d4c_Subscription__c sub : subscriptions) {
            String apiSubName = sub.d4c_Subscription_Name__c + '-' + UserInfo.getOrganizationId();
            List<String> npnsToRemove = subscriptionToNPNsMap.get(sub.Id);

            Boolean removeSuccess = executeRemoveNPNCallout(npnsToRemove, apiSubName);

            if (!removeSuccess) {
                throw new SubscriptionServiceException('Failed to remove NPNs: ' + npnsToRemove + ' from subscription: ' + sub.d4c_Subscription_Name__c);
            }
        }

        Logger.commitAsync();
    }

    /**
     *********************************************************
     * @Method Name    : resubscribeToDifferentPool
     * @description    : Resubscribes an NPN to a different subscription pool
     *                   (e.g., exclude carrier appointments flag changed)
     *                   ALL callouts happen first, then all DML
     * @return         : void
     *********************************************************
     **/
    public void resubscribeToDifferentPool() {
        String methodName = 'resubscribeToDifferentPool';

        if (producer == null) {
            throw new SubscriptionServiceException('Producer not set in service. Call setProducer() first.');
        }

        String npn = producer.d4c_NPN__c;
        Boolean newExcludeFlag = producer.d4c_ExcludeCarrierAppointments__c;

        Logger.info(CLASS_NAME, methodName,
            'Starting resubscription to different pool',
            'NPN: ' + npn, null);

        loadMaxProducersPerSubscription();

        // CALLOUT 1: Remove from current subscription in NIPR
        d4c_Subscription__c oldSubscription = subscriptionSelector.getSubscriptionById(producer.d4c_Subscription__c);
        String oldApiSubName = oldSubscription.d4c_Subscription_Name__c + '-' + UserInfo.getOrganizationId();
        Boolean removeSuccess = executeRemoveNPNCallout(new List<String>{npn}, oldApiSubName);

        if (!removeSuccess) {
            throw new SubscriptionServiceException('Failed to remove NPN: ' + npn + ' from old subscription: ' + oldSubscription.d4c_Subscription_Name__c + ' during resubscription');
        }

        // Find or create new subscription and add NPN
        Id newSubscriptionId = findOrCreateAndAddNPN(newExcludeFlag);

        // Update producer with new subscription lookup
        updateProducerSubscription(newSubscriptionId);

        Logger.info(CLASS_NAME, methodName,
            'Completed resubscription to different pool',
            'NPN: ' + npn, null);
    }

    // ==================== PRIVATE METHODS ====================

    /**
     *********************************************************
     * @Method Name    : loadMaxProducersPerSubscription
     * @description    : Loads max producers per subscription from metadata
     * @return         : void
     *********************************************************
     **/
    private void loadMaxProducersPerSubscription() {
        Decimal maxCount = mtdSelector.getNIPRSyncSettings()?.d4c_MaxNPNCountPerSubscription__c;
        if (!Test.isRunningTest()) {
            MAX_PRODUCERS_PER_SUBSCRIPTION = maxCount != null ? Integer.valueOf(maxCount) : MAX_PRODUCERS_PER_SUBSCRIPTION;
        }
    }

    /**
     *********************************************************
     * @Method Name    : findOrCreateAndAddNPN
     * @description    : Finds existing subscription with capacity or creates new one,
     *                   adds NPN via API, then creates/returns subscription ID for DML
     * @param excludeCarrierAppointments : Filter flag for subscription pool
     * @return         : Id - Subscription ID for producer lookup update
     *********************************************************
     **/
    private Id findOrCreateAndAddNPN(Boolean excludeCarrierAppointments) {
        String methodName = 'findOrCreateAndAddNPN';
        String npn = producer.d4c_NPN__c;

        // Step 1: Find existing subscription with capacity
        SubscriptionResult subResult = findSubscriptionWithCapacity(excludeCarrierAppointments);

        String subscriptionName;
        Boolean isNewSubscription = false;

        if (subResult != null) {
            // Found existing subscription with capacity
            subscriptionName = subResult.subscriptionName;
        } else {
            // No subscription with capacity, create new one in NIPR
            subscriptionName = createNewSubscriptionInNIPR(excludeCarrierAppointments);
            isNewSubscription = true;
        }

        // Step 2: Call Add NPN API with retry mechanism
        String apiSubName = subscriptionName + '-' + UserInfo.getOrganizationId();
        Boolean apiSuccess = callAddNPNAPIWithRetry(new List<String>{npn}, apiSubName);

        if (!apiSuccess) {
            throw new SubscriptionServiceException('Failed to add NPN: ' + npn + ' to subscription: ' + subscriptionName + ' after ' + MAX_RETRY_ATTEMPTS + ' attempts');
        }

        // Step 3: ALL DML operations AFTER callouts succeed
        Id subscriptionId;

        if (isNewSubscription) {
            // Create subscription record in Salesforce with d4c_Subscription_Name__c matching NIPR
            // The SubscriptionTriggerHandler will update the custom settings counter on afterInsert
            d4c_Subscription__c newSubscription = new d4c_Subscription__c(
                d4c_Subscription_Name__c = subscriptionName,
                d4c_ExcludeCarrierAppointments__c = excludeCarrierAppointments
            );
            insert newSubscription;

            subscriptionId = newSubscription.Id;

            Logger.info(CLASS_NAME, methodName,
                'Created new subscription in Salesforce',
                'Subscription ID: ' + subscriptionId + ', Subscription Name: ' + subscriptionName + ', Exclude Flag: ' + excludeCarrierAppointments,
                subscriptionId);
        } else {
            subscriptionId = subResult.subscriptionId;
        }

        return subscriptionId;
    }

    /**
     *********************************************************
     * @Method Name    : findSubscriptionWithCapacity
     * @description    : Finds an existing subscription with available capacity
     * @param excludeCarrierAppointments : Filter flag for subscription pool
     * @return         : SubscriptionResult wrapper with name and ID, or null if none found
     *********************************************************
     **/
    private SubscriptionResult findSubscriptionWithCapacity(Boolean excludeCarrierAppointments) {
        List<d4c_Subscription__c> subscriptions = subscriptionSelector.getSubscriptionsWithProducersByExcludeFlag(excludeCarrierAppointments);

        for (d4c_Subscription__c sub : subscriptions) {
            Integer producerCount = sub.Producers__r != null ? sub.Producers__r.size() : 0;
            if (producerCount < MAX_PRODUCERS_PER_SUBSCRIPTION) {
                return new SubscriptionResult(sub.Id, sub.d4c_Subscription_Name__c);
            }
        }

        return null;
    }

    /**
     *********************************************************
     * @Method Name    : createNewSubscriptionInNIPR
     * @description    : Creates a new subscription in NIPR API
     *                   DOES NOT create Salesforce record yet (DML after callouts)
     * @param excludeCarrierAppointments : Flag for subscription mode
     * @return         : String - The subscription name created in NIPR
     *********************************************************
     **/
    private String createNewSubscriptionInNIPR(Boolean excludeCarrierAppointments) {
        String methodName = 'createNewSubscriptionInNIPR';

        // Get current counter value (NO DML before HTTP request!)
        d4c_NIPRSubscriptionDetails__c settings = d4c_NIPRSubscriptionDetails__c.getOrgDefaults();

        Decimal currentNumber = 0;
        if (settings != null && settings.d4c_Latest_Number__c != null) {
            currentNumber = settings.d4c_Latest_Number__c;
        }

        // Calculate next number (but don't update yet!)
        Decimal nextNumber = currentNumber + 1;

        // Format subscription name: S-0000, S-0001, etc.
        String nextSubName = 'S-' + String.valueOf(nextNumber.intValue()).leftPad(4, '0');
        String niprSubName = nextSubName + '-' + UserInfo.getOrganizationId();

        Logger.info(CLASS_NAME, methodName,
            'Generated new subscription name using custom counter',
            'Counter: ' + nextNumber + ', Subscription Name: ' + nextSubName, null);

        // Call NIPR API to create subscription (NO DML before this!)
        createSubscriptionAPI.setExcludeCarrierAppointmentsMode(excludeCarrierAppointments);
        String apiResponse = createSubscriptionAPI.createSubscription(niprSubName);

        Boolean apiSuccess = String.isNotBlank(apiResponse) && !apiResponse.contains('<faultstring>');

        if (!apiSuccess) {
            Logger.error(CLASS_NAME, methodName,
                'Failed to create subscription in NIPR',
                'Subscription Name: ' + niprSubName + ', Response: ' + apiResponse, null, null);
            throw new SubscriptionServiceException('Failed to create subscription: ' + niprSubName + ' in NIPR API. Response: ' + apiResponse);
        }

        Logger.info(CLASS_NAME, methodName,
            'Successfully created subscription in NIPR (Salesforce record will be created after Add NPN succeeds)',
            'Subscription Name: ' + nextSubName, null);

        // Return the subscription name (NOT the Salesforce ID - DML happens later)
        return nextSubName;
    }

    /**
     *********************************************************
     * @Method Name    : callAddNPNAPIWithRetry
     * @description    : Calls Add NPN API with retry mechanism (keeps existing 10 retry loop for NIPR timing issues)
     * @param npnList  : List of NPNs to add
     * @param subscriptionName : Subscription name
     * @return         : Boolean - success flag
     *********************************************************
     **/
    private Boolean callAddNPNAPIWithRetry(List<String> npnList, String subscriptionName) {
        String methodName = 'callAddNPNAPIWithRetry';
        Integer attemptCount = 0;
        Boolean success = false;

        while (attemptCount < MAX_RETRY_ATTEMPTS && !success) {
            try {
                AddNPNToSubscriptionDTO response = addNPNToSubscriptionAPI.addNPN(npnList, subscriptionName);

                if (response.isSuccess) {
                    success = true;
                    Logger.info(CLASS_NAME, methodName,
                        'Successfully added NPNs to subscription',
                        'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList), null);
                } else {
                    attemptCount++;
                    Logger.warning(CLASS_NAME, methodName,
                        'Attempt ' + attemptCount + ' failed to add NPNs',
                        'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList) + ', Error: ' + response.errorMessage, null);
                }
            } catch (Exception e) {
                attemptCount++;
                Logger.warning(CLASS_NAME, methodName,
                    'Attempt ' + attemptCount + ' failed with exception',
                    'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList) + ', Error: ' + e.getMessage(), null);
            }
        }

        return success;
    }

    /**
     *********************************************************
     * @Method Name    : executeRemoveNPNCallout
     * @description    : Executes remove NPN callout
     * @param npnList  : List of NPNs to remove
     * @param subscriptionName : Subscription name
     * @return         : Boolean - success flag
     *********************************************************
     **/
    private Boolean executeRemoveNPNCallout(List<String> npnList, String subscriptionName) {
        String methodName = 'executeRemoveNPNCallout';

        try {
            RemoveNPNFromSubscriptionDTO response = removeNPNFromSubscriptionAPI.removeNPN(npnList, subscriptionName);

            if (response.isSuccess) {
                Logger.info(CLASS_NAME, methodName,
                    'Successfully removed NPNs from subscription',
                    'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList), null);
                return true;
            } else {
                Logger.error(CLASS_NAME, methodName,
                    'Failed to remove NPNs from subscription',
                    'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList) + ', Error: ' + response.errorMessage, null, null);
                return false;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName,
                'Exception during NPN removal',
                'Subscription: ' + subscriptionName + ', NPNs: ' + JSON.serialize(npnList) + ', Error: ' + e.getMessage(), e.getStackTraceString(), null);
            return false;
        }
    }

    /**
     *********************************************************
     * @Method Name    : updateProducerSubscription
     * @description    : Updates or clears producer subscription lookup using external ID upsert
     * @param subscriptionId : Subscription ID (or null to clear)
     * @return         : void
     *********************************************************
     **/
    private void updateProducerSubscription(Id subscriptionId) {
        d4c_Entity__c producerToUpdate = new d4c_Entity__c(
            d4c_NPN__c = producer.d4c_NPN__c,
            d4c_Subscription__c = subscriptionId
        );

        upsert producerToUpdate d4c_NPN__c;
    }

    // ==================== BULK SUBSCRIPTION METHODS ====================

    /**
     *********************************************************
     * @Method Name    : allocateNPNsToSubscriptions
     * @description    : Calculates how to distribute NPNs across subscriptions.
     *                   First fills existing subs with capacity, then calculates new subs needed.
     *                   Returns a list of allocations for SubscriptionExecutor to process.
     * @param npns     : List of NPNs to allocate
     * @param excludeCarrierAppointments : Filter flag for subscription pool
     * @return         : List<SubscriptionAllocation> - Allocations for each subscription
     *********************************************************
     **/
    public List<SubscriptionAllocation> allocateNPNsToSubscriptions(List<String> npns, Boolean excludeCarrierAppointments) {
        String methodName = 'allocateNPNsToSubscriptions';

        if (npns == null || npns.isEmpty()) {
            return new List<SubscriptionAllocation>();
        }

        loadMaxProducersPerSubscription();

        List<SubscriptionAllocation> allocations = new List<SubscriptionAllocation>();
        List<String> remainingNPNs = new List<String>(npns);

        Logger.info(CLASS_NAME, methodName,
            'Starting NPN allocation',
            'Total NPNs: ' + npns.size() + ', Exclude Flag: ' + excludeCarrierAppointments, null);

        // Step 1: Get existing subscriptions with capacity
        List<d4c_Subscription__c> existingSubscriptions = subscriptionSelector.getSubscriptionsWithProducersByExcludeFlag(excludeCarrierAppointments);

        for (d4c_Subscription__c sub : existingSubscriptions) {
            if (remainingNPNs.isEmpty()) {
                break;
            }

            Integer currentCount = sub.Producers__r != null ? sub.Producers__r.size() : 0;
            Integer availableSlots = MAX_PRODUCERS_PER_SUBSCRIPTION - currentCount;

            if (availableSlots > 0) {
                // Allocate NPNs to this subscription
                Integer npnsToAllocate = Math.min(availableSlots, remainingNPNs.size());
                List<String> allocatedNPNs = new List<String>();

                for (Integer i = 0; i < npnsToAllocate; i++) {
                    allocatedNPNs.add(remainingNPNs.remove(0));
                }

                SubscriptionAllocation allocation = new SubscriptionAllocation();
                allocation.subscriptionName = sub.d4c_Subscription_Name__c;
                allocation.subscriptionId = sub.Id;
                allocation.requiresCreation = false;
                allocation.excludeCarrierAppointments = excludeCarrierAppointments;
                allocation.npnsToAdd = allocatedNPNs;

                allocations.add(allocation);

                Logger.info(CLASS_NAME, methodName,
                    'Allocated NPNs to existing subscription',
                    'Subscription: ' + sub.d4c_Subscription_Name__c + ', NPNs: ' + npnsToAllocate, null);
            }
        }

        // Step 2: Calculate new subscriptions needed for remaining NPNs
        if (!remainingNPNs.isEmpty()) {
            // Get current counter value
            d4c_NIPRSubscriptionDetails__c settings = d4c_NIPRSubscriptionDetails__c.getOrgDefaults();
            Decimal currentNumber = (settings != null && settings.d4c_Latest_Number__c != null)
                ? settings.d4c_Latest_Number__c
                : 0;

            while (!remainingNPNs.isEmpty()) {
                currentNumber++;
                String newSubName = 'S-' + String.valueOf(currentNumber.intValue()).leftPad(4, '0');

                // Allocate up to MAX_PRODUCERS_PER_SUBSCRIPTION NPNs to this new subscription
                Integer npnsToAllocate = Math.min(MAX_PRODUCERS_PER_SUBSCRIPTION, remainingNPNs.size());
                List<String> allocatedNPNs = new List<String>();

                for (Integer i = 0; i < npnsToAllocate; i++) {
                    allocatedNPNs.add(remainingNPNs.remove(0));
                }

                SubscriptionAllocation allocation = new SubscriptionAllocation();
                allocation.subscriptionName = newSubName;
                allocation.subscriptionId = null; // Will be set after creation
                allocation.requiresCreation = true;
                allocation.excludeCarrierAppointments = excludeCarrierAppointments;
                allocation.npnsToAdd = allocatedNPNs;

                allocations.add(allocation);

                Logger.info(CLASS_NAME, methodName,
                    'Allocated NPNs to new subscription',
                    'Subscription: ' + newSubName + ', NPNs: ' + npnsToAllocate, null);
            }
        }

        Logger.info(CLASS_NAME, methodName,
            'Completed NPN allocation',
            'Total Allocations: ' + allocations.size() + ', Existing Subs: ' +
            (allocations.size() - countNewSubscriptions(allocations)) +
            ', New Subs: ' + countNewSubscriptions(allocations), null);

        return allocations;
    }

    /**
     *********************************************************
     * @Method Name    : processAllocation
     * @description    : Processes a single subscription allocation.
     *                   Creates subscription in NIPR if needed, adds NPNs, creates SF records.
     * @param allocation : The allocation to process
     * @return         : void
     *********************************************************
     **/
    public void processAllocation(SubscriptionAllocation allocation) {
        String methodName = 'processAllocation';

        if (allocation == null || allocation.npnsToAdd == null || allocation.npnsToAdd.isEmpty()) {
            return;
        }

        String apiSubName = allocation.subscriptionName + '-' + UserInfo.getOrganizationId();
        Id subscriptionId = allocation.subscriptionId;

        // Step 1: Create subscription in NIPR if needed
        if (allocation.requiresCreation) {
            Boolean createSuccess = callCreateSubscriptionAPIWithRetry(apiSubName, allocation.excludeCarrierAppointments);

            if (!createSuccess) {
                throw new SubscriptionServiceException('Failed to create subscription: ' + allocation.subscriptionName + ' in NIPR API after ' + MAX_RETRY_ATTEMPTS + ' attempts');
            }
        }

        // Step 2: Add NPNs to subscription with retry
        Boolean addSuccess = callAddNPNAPIWithRetry(allocation.npnsToAdd, apiSubName);

        if (!addSuccess) {
            throw new SubscriptionServiceException('Failed to add NPNs to subscription: ' + allocation.subscriptionName + ' after ' + MAX_RETRY_ATTEMPTS + ' attempts');
        }

        // Step 3: DML after all callouts succeed
        if (allocation.requiresCreation) {
            // Create subscription record in Salesforce
            d4c_Subscription__c newSubscription = new d4c_Subscription__c(
                d4c_Subscription_Name__c = allocation.subscriptionName,
                d4c_ExcludeCarrierAppointments__c = allocation.excludeCarrierAppointments
            );
            insert newSubscription;
            subscriptionId = newSubscription.Id;

            Logger.info(CLASS_NAME, methodName,
                'Created subscription in Salesforce',
                'Subscription: ' + allocation.subscriptionName + ', ID: ' + subscriptionId, subscriptionId);
        }

        // Step 4: Update producers with subscription lookup
        List<d4c_Entity__c> producersToUpdate = new List<d4c_Entity__c>();
        for (String npn : allocation.npnsToAdd) {
            producersToUpdate.add(new d4c_Entity__c(
                d4c_NPN__c = npn,
                d4c_Subscription__c = subscriptionId
            ));
        }

        upsert producersToUpdate d4c_NPN__c;

        Logger.info(CLASS_NAME, methodName,
            'Updated producers with subscription',
            'Subscription: ' + allocation.subscriptionName + ', Producers: ' + producersToUpdate.size(), subscriptionId);
    }

    /**
     *********************************************************
     * @Method Name    : callCreateSubscriptionAPIWithRetry
     * @description    : Calls Create Subscription API with retry mechanism
     * @param subscriptionName : Full subscription name (with org ID)
     * @param excludeCarrierAppointments : Flag for subscription mode
     * @return         : Boolean - success flag
     *********************************************************
     **/
    private Boolean callCreateSubscriptionAPIWithRetry(String subscriptionName, Boolean excludeCarrierAppointments) {
        String methodName = 'callCreateSubscriptionAPIWithRetry';
        Integer attemptCount = 0;
        Boolean success = false;

        while (attemptCount < MAX_RETRY_ATTEMPTS && !success) {
            try {
                createSubscriptionAPI.setExcludeCarrierAppointmentsMode(excludeCarrierAppointments);
                String apiResponse = createSubscriptionAPI.createSubscription(subscriptionName);

                if (String.isNotBlank(apiResponse) && !apiResponse.contains('<faultstring>')) {
                    success = true;
                    Logger.info(CLASS_NAME, methodName,
                        'Successfully created subscription in NIPR',
                        'Subscription: ' + subscriptionName, null);
                } else {
                    attemptCount++;
                    Logger.warning(CLASS_NAME, methodName,
                        'Attempt ' + attemptCount + ' failed to create subscription',
                        'Subscription: ' + subscriptionName + ', Response: ' + apiResponse, null);
                }
            } catch (Exception e) {
                attemptCount++;
                Logger.warning(CLASS_NAME, methodName,
                    'Attempt ' + attemptCount + ' failed with exception',
                    'Subscription: ' + subscriptionName + ', Error: ' + e.getMessage(), null);
            }
        }

        return success;
    }

    /**
     *********************************************************
     * @Method Name    : countNewSubscriptions
     * @description    : Helper to count allocations that require new subscription creation
     * @param allocations : List of allocations
     * @return         : Integer - count of new subscriptions
     *********************************************************
     **/
    private Integer countNewSubscriptions(List<SubscriptionAllocation> allocations) {
        Integer count = 0;
        for (SubscriptionAllocation alloc : allocations) {
            if (alloc.requiresCreation) {
                count++;
            }
        }
        return count;
    }

    // ==================== INNER CLASSES ====================

    /**
     * Allocation DTO for bulk subscription processing.
     * Represents one subscription (existing or new) and the NPNs to add to it.
     */
    public class SubscriptionAllocation {
        public String subscriptionName;
        public Id subscriptionId;
        public Boolean requiresCreation;
        public Boolean excludeCarrierAppointments;
        public List<String> npnsToAdd;
    }

    /**
     * Wrapper class to return subscription ID and Name together
     */
    private class SubscriptionResult {
        public Id subscriptionId;
        public String subscriptionName;

        public SubscriptionResult(Id subscriptionId, String subscriptionName) {
            this.subscriptionId = subscriptionId;
            this.subscriptionName = subscriptionName;
        }
    }

    public class SubscriptionServiceException extends Exception {}
}