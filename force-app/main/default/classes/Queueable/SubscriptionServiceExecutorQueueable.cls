/**
 *********************************************************
 * Apex Class Name    : SubscriptionServiceExecutorQueueable
 * Created Date       : 2025-12-25
 * @description       : Unified queueable class for all subscription operations.
 *                      Extends SubscriptionService to have direct access to service methods.
 *                      Handles both synchronous (single operation) and chained (bulk) execution.
 *
 *                      Operations:
 *                      - REMOVE_NPN_AFTER_UPDATE: Sync - removes NPNs from NIPR + clears SF lookup
 *                      - REMOVE_NPN_AFTER_DELETE: Sync - removes NPNs from NIPR only (producers already deleted)
 *                      - RESUBSCRIBE_TO_DIFFERENT_POOL: Sync - moves producer between subscription pools
 *                      - ADD_NPNS_BULK: Chained - processes allocations one per transaction
 *
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   2025-12-25   Dev4Clouds          Initial Version - Merged orchestrator + executor
 *********************************************************
 **/
public class SubscriptionServiceExecutorQueueable extends SubscriptionService implements Queueable, Database.AllowsCallouts {

    private static final String CLASS_NAME = 'SubscriptionServiceExecutorQueueable';
    private static final Integer MAX_CHAIN_DEPTH = 100;

    // Operation type determines which method to execute
    private NIPREnums.SubscriptionOperation operationType;

    // Properties for different operation types
    private String npn;                                          // For RESUBSCRIBE_TO_DIFFERENT_POOL (single)
    private Set<String> npns;                                    // For REMOVE operations (bulk)
    private Map<String, Id> npnToSubscriptionMap;                // For REMOVE_NPN_AFTER_DELETE
    private List<SubscriptionAllocation> allocations;            // For ADD_NPNS_BULK (chained)
    private List<NPNWithExcludeFlag> npnsWithFlags;              // For ADD_NPNS_BULK (initial call)

    // Selectors
    private final EntitySelector entitySelector = new EntitySelector();

    // ==================== INNER CLASS ====================

    /**
     * Inner class to hold NPN with its exclude carrier appointments flag
     * Used when batch passes NPNs to this executor
     */
    public class NPNWithExcludeFlag {
        public String npn;
        public Boolean excludeCarrierAppointments;

        public NPNWithExcludeFlag(String npn, Boolean excludeCarrierAppointments) {
            this.npn = npn;
            this.excludeCarrierAppointments = excludeCarrierAppointments;
        }
    }

    // ==================== CONSTRUCTORS ====================

    /**
     * Constructor for RESUBSCRIBE_TO_DIFFERENT_POOL (single NPN operation)
     */
    public SubscriptionServiceExecutorQueueable(String npn, NIPREnums.SubscriptionOperation operationType) {
        this.npn = npn;
        this.operationType = operationType;
    }

    /**
     * Constructor for REMOVE_NPN_AFTER_UPDATE (bulk - queries fresh producers)
     */
    public SubscriptionServiceExecutorQueueable(Set<String> npns, NIPREnums.SubscriptionOperation operationType) {
        this.npns = npns;
        this.operationType = operationType;
    }

    /**
     * Constructor for REMOVE_NPN_AFTER_DELETE (bulk - uses deleted producer data, no query)
     */
    public SubscriptionServiceExecutorQueueable(Map<String, Id> npnToSubscriptionMap, NIPREnums.SubscriptionOperation operationType) {
        this.npnToSubscriptionMap = npnToSubscriptionMap;
        this.npns = npnToSubscriptionMap.keySet();
        this.operationType = operationType;
    }

    /**
     * Constructor for ADD_NPNS_BULK - Initial call from batch with NPNs + exclude flags
     * This constructor calculates allocations and then chains itself
     */
    public SubscriptionServiceExecutorQueueable(List<NPNWithExcludeFlag> npnsWithFlags) {
        this.npnsWithFlags = npnsWithFlags;
        this.operationType = NIPREnums.SubscriptionOperation.ADD_NPNS_BULK;
    }

    /**
     * Constructor for ADD_NPNS_BULK - Chained call with pre-calculated allocations
     * Used internally when chaining to process remaining allocations
     */
    public SubscriptionServiceExecutorQueueable(List<SubscriptionAllocation> allocations, NIPREnums.SubscriptionOperation operationType) {
        this.allocations = allocations;
        this.operationType = operationType;
    }

    // ==================== EXECUTE ====================

    public void execute(QueueableContext context) {
        String methodName = 'execute';

        try {
            Logger.info(CLASS_NAME, methodName,
                'Starting subscription operation',
                'Operation: ' + operationType.name(), null);

            switch on operationType {
                when REMOVE_NPN_AFTER_UPDATE {
                    executeRemoveNPNAfterUpdate();
                }
                when REMOVE_NPN_AFTER_DELETE {
                    executeRemoveNPNAfterDelete();
                }
                when RESUBSCRIBE_TO_DIFFERENT_POOL {
                    executeResubscribeToDifferentPool();
                }
                when ADD_NPNS_BULK {
                    executeAddNPNsBulk();
                }
                when ADD_TO_SUBSCRIPTION {
                    // Legacy single add - redirect to bulk with single NPN
                    executeLegacySingleAdd();
                }
            }

            Logger.info(CLASS_NAME, methodName,
                'Completed subscription operation',
                'Operation: ' + operationType.name(), null);

        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName,
                'Error during subscription operation',
                'Operation: ' + operationType.name() + ', Error: ' + e.getMessage(),
                e.getStackTraceString(), null);
        }

        Logger.commitAsync();
    }

    // ==================== OPERATION EXECUTORS ====================

    /**
     * Removes NPNs from NIPR and clears SF subscription lookups
     * Synchronous - completes in single transaction
     */
    private void executeRemoveNPNAfterUpdate() {
        String methodName = 'executeRemoveNPNAfterUpdate';

        if (npns == null || npns.isEmpty()) {
            Logger.warning(CLASS_NAME, methodName, 'No NPNs to remove', '', null);
            return;
        }

        Logger.info(CLASS_NAME, methodName, 'Removing NPNs from NIPR and SF', 'NPNs: ' + npns, null);

        // Call inherited service method
        removeNPNFromNIPRAndSF(npns);
    }

    /**
     * Removes NPNs from NIPR only (producers already deleted in SF)
     * Synchronous - completes in single transaction
     */
    private void executeRemoveNPNAfterDelete() {
        String methodName = 'executeRemoveNPNAfterDelete';

        if (npnToSubscriptionMap == null || npnToSubscriptionMap.isEmpty()) {
            Logger.warning(CLASS_NAME, methodName, 'No NPNs to remove', '', null);
            return;
        }

        Logger.info(CLASS_NAME, methodName, 'Removing NPNs from NIPR (after delete)',
            'NPNs: ' + npnToSubscriptionMap.keySet(), null);

        // Call inherited service method
        removeNPNFromNIPR(npnToSubscriptionMap);
    }

    /**
     * Moves producer from one subscription pool to another (exclude flag changed)
     * Synchronous - completes in single transaction
     */
    private void executeResubscribeToDifferentPool() {
        String methodName = 'executeResubscribeToDifferentPool';

        if (String.isBlank(npn)) {
            Logger.warning(CLASS_NAME, methodName, 'No NPN provided', '', null);
            return;
        }

        List<d4c_Entity__c> producers = producerSelector.getProducersByNPNs(new Set<String>{ npn });
        if (producers.isEmpty()) {
            Logger.error(CLASS_NAME, methodName, 'Producer not found', 'NPN: ' + npn, null, null);
            return;
        }

        Logger.info(CLASS_NAME, methodName, 'Resubscribing producer to different pool', 'NPN: ' + npn, null);

        // Set producer and call inherited service method
        setProducer(producers[0]);
        resubscribeToDifferentPool();
    }

    /**
     * Handles bulk NPN additions using allocations
     * If npnsWithFlags is set, calculates allocations first
     * If allocations is set, processes first allocation and chains rest
     */
    private void executeAddNPNsBulk() {
        String methodName = 'executeAddNPNsBulk';

        // If we have NPNs with flags, calculate allocations first
        if (npnsWithFlags != null && !npnsWithFlags.isEmpty()) {
            calculateAndChainAllocations();
            return;
        }

        // If we have allocations, process them
        if (allocations != null && !allocations.isEmpty()) {
            processAllocationAndChain();
            return;
        }

        Logger.info(CLASS_NAME, methodName, 'No NPNs or allocations to process', '', null);
    }

    /**
     * Legacy single add - convert to bulk approach
     */
    private void executeLegacySingleAdd() {
        String methodName = 'executeLegacySingleAdd';

        if (String.isBlank(npn)) {
            Logger.warning(CLASS_NAME, methodName, 'No NPN provided', '', null);
            return;
        }

        List<d4c_Entity__c> producers = producerSelector.getProducersByNPNs(new Set<String>{ npn });
        if (producers.isEmpty()) {
            Logger.error(CLASS_NAME, methodName, 'Producer not found', 'NPN: ' + npn, null, null);
            return;
        }

        Logger.info(CLASS_NAME, methodName, 'Adding single NPN to subscription', 'NPN: ' + npn, null);

        // Set producer and call inherited service method
        setProducer(producers[0]);
        addNPNToSubscription();
    }

    // ==================== BULK ALLOCATION HELPERS ====================

    /**
     * Calculates allocations from NPNs with flags and chains to process them
     */
    private void calculateAndChainAllocations() {
        String methodName = 'calculateAndChainAllocations';

        // Separate NPNs by exclude flag
        List<String> regularNPNs = new List<String>();
        List<String> excludeNPNs = new List<String>();

        for (NPNWithExcludeFlag item : npnsWithFlags) {
            if (item.excludeCarrierAppointments) {
                excludeNPNs.add(item.npn);
            } else {
                regularNPNs.add(item.npn);
            }
        }

        Logger.info(CLASS_NAME, methodName, 'Calculating allocations',
            'Regular NPNs: ' + regularNPNs.size() + ', Exclude NPNs: ' + excludeNPNs.size(), null);

        // Calculate allocations for both pools
        List<SubscriptionAllocation> allAllocations = new List<SubscriptionAllocation>();

        if (!regularNPNs.isEmpty()) {
            List<SubscriptionAllocation> regularAllocations = allocateNPNsToSubscriptions(regularNPNs, false);
            allAllocations.addAll(regularAllocations);
            Logger.info(CLASS_NAME, methodName, 'Calculated regular allocations',
                'Allocations: ' + regularAllocations.size(), null);
        }

        if (!excludeNPNs.isEmpty()) {
            List<SubscriptionAllocation> excludeAllocations = allocateNPNsToSubscriptions(excludeNPNs, true);
            allAllocations.addAll(excludeAllocations);
            Logger.info(CLASS_NAME, methodName, 'Calculated exclude allocations',
                'Allocations: ' + excludeAllocations.size(), null);
        }

        // Chain to process allocations
        if (!allAllocations.isEmpty()) {
            Logger.info(CLASS_NAME, methodName, 'Chaining to process allocations',
                'Total allocations: ' + allAllocations.size(), null);
            Logger.commitSync();

            if (!Test.isRunningTest()) {
                // Note: MaximumQueueableStackDepth was already set by the initial enqueueJob call
                // from ProducerTriggerHandler/RunEntityInfoReportBatchable - we just chain normally here
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(allAllocations, NIPREnums.SubscriptionOperation.ADD_NPNS_BULK));
            }
        } else {
            Logger.info(CLASS_NAME, methodName, 'No allocations needed', '', null);
        }
    }

    /**
     * Processes first allocation and chains to process remaining
     */
    private void processAllocationAndChain() {
        String methodName = 'processAllocationAndChain';

        // Take first allocation
        SubscriptionAllocation currentAllocation = allocations.remove(0);

        try {
            Logger.info(CLASS_NAME, methodName, 'Processing allocation',
                'Subscription: ' + currentAllocation.subscriptionName +
                ', Requires Creation: ' + currentAllocation.requiresCreation +
                ', NPN Count: ' + currentAllocation.npnsToAdd.size(), null);

            // Process this allocation using inherited service method
            processAllocation(currentAllocation);

            Logger.info(CLASS_NAME, methodName, 'Successfully processed allocation',
                'Subscription: ' + currentAllocation.subscriptionName, null);

        } catch (Exception e) {
            // Log critical error but DON'T stop the chain
            Logger.errorWithCritical(CLASS_NAME, methodName,
                'Failed to process allocation - continuing with next',
                'Subscription: ' + currentAllocation.subscriptionName +
                ', NPNs: ' + JSON.serialize(currentAllocation.npnsToAdd) +
                ', Error: ' + e.getMessage(),
                e.getStackTraceString(), true);
        }

        // Chain to next allocation if any remain
        if (!allocations.isEmpty()) {
            Logger.info(CLASS_NAME, methodName, 'Chaining to next allocation',
                'Remaining allocations: ' + allocations.size(), null);
            Logger.commitSync();

            if (!Test.isRunningTest()) {
                // Note: MaximumQueueableStackDepth was already set by the initial enqueueJob call
                // We just chain normally - the depth limit carries through the chain
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(allocations, NIPREnums.SubscriptionOperation.ADD_NPNS_BULK));
            }
        } else {
            Logger.info(CLASS_NAME, methodName, 'All allocations processed', 'Executor chain completed', null);
        }
    }
}