/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReportBatchable
 * Created Date       : 04-13-2025
 * @description       : Batchable class that triggers the NIPR Entity Info API integration
 *                      for each provided NPN. Replaces queueable chaining to avoid the
 *                      "Too many queueable jobs" issue. Handles errors and updates
 *                      Producer status fields as needed.
 *                      Uses Database.Stateful to collect successful NPNs and process
 *                      subscription additions in finish() via SubscriptionServiceExecutorQueueable.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author              Modification
 * 1.0   04-13-2025   Dev4Clouds     Initial Version
 * 2.0   12-25-2025   Dev4Clouds     Added Stateful interface for bulk subscription processing
 * 2.1   12-25-2025   Dev4Clouds     Refactored to use unified SubscriptionServiceExecutorQueueable
 *********************************************************
**/
public with sharing class RunEntityInfoReportBatchable implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    private final EntitySelector entitySelector = new EntitySelector();
    private List<String> npnList;
    private final String CLASS_NAME = 'RunEntityInfoReportBatchable';

    // Stateful properties to collect successful NPNs by exclude flag
    private List<String> successfulRegularNPNs = new List<String>();
    private List<String> successfulExcludeNPNs = new List<String>();

    public RunEntityInfoReportBatchable(Set<String> npns) {
        this.npnList = new List<String>(npns);
    }

    public Iterable<String> start(Database.BatchableContext context) {
        String methodName = 'start';

        Logger.info(CLASS_NAME, methodName, 'Starting Entity Info report batch',
                  'NPNs count: ' + npnList.size(), null);

        return npnList;
    }

    public void execute(Database.BatchableContext context, List<String> scope) {
        String methodName = 'execute';

        Logger.info(CLASS_NAME, methodName, 'Processing batch of NPNs',
                  'Batch size: ' + scope.size(), null);

        for (String npn : scope) {
            Logger.debug(CLASS_NAME, methodName, 'Processing NPN', 'NPN: ' + npn, null);

            try {
                // Invoke integration service for this NPN
                ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
                service.processData(npn);

                Logger.info(CLASS_NAME, methodName, 'Successfully processed NPN',
                          'NPN: ' + npn, null);

                // Track successful NPN for subscription processing in finish()
                // Query the producer to check its exclude flag
                List<d4c_Entity__c> producers = producerSelector.getProducersByNPNs(new Set<String>{ npn });
                if (!producers.isEmpty()) {
                    d4c_Entity__c producer = producers[0];
                    // Only add NPNs that are Active and don't already have a subscription
                    if (producer.d4c_NPNStatus__c == 'Active' && producer.d4c_Subscription__c == null) {
                        if (producer.d4c_ExcludeCarrierAppointments__c) {
                            successfulExcludeNPNs.add(npn);
                        } else {
                            successfulRegularNPNs.add(npn);
                        }
                    }
                }

            } catch (Exception e) {
                Logger.error(CLASS_NAME, methodName, e, null);

                String exceptionMessage = e.getMessage();

                List<d4c_Entity__c> producers = producerSelector.getProducersByNPNs(new Set<String>{ npn });

                if (producers == null || producers.isEmpty()) {
                    Logger.warning(CLASS_NAME, methodName, 'Producer with this NPN not yet created',
                                 'NPN: ' + npn, null);
                } else {
                    d4c_Entity__c producer = producers[0];

                    if (exceptionMessage.contains(NIPREnums.EntityInfoError.NO_PRODUCER_DATA.toString())) {
                        producer.d4c_NPNStatus__c = 'Invalid NPN';
                        producer.d4c_NPNSyncError__c = exceptionMessage.split(':')[0];
                        producer.d4c_IntegrationError__c = '';

                        Logger.warning(CLASS_NAME, methodName, 'Invalid NPN detected',
                                     'NPN: ' + npn + ', Error: ' + producer.d4c_NPNSyncError__c,
                                     producer.Id);
                    } else {
                        producer.d4c_NPNStatus__c = 'Error';
                        producer.d4c_NPNSyncError__c = 'Integration Error';
                        producer.d4c_IntegrationError__c = exceptionMessage;

                        Logger.error(CLASS_NAME, methodName,
                                   'Integration error for NPN',
                                   'NPN: ' + npn + ', Error: ' + exceptionMessage,
                                   producer.Id);
                    }

                    Logger.commitAsync();

                    try {
                        update producer;
                    } catch (Exception updateEx) {
                        Logger.error(CLASS_NAME, methodName,
                                   'Failed to update producer status',
                                   'NPN: ' + npn + ', Error: ' + updateEx.getMessage(),
                                   producer.Id);

                        Logger.commitAsync();

                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        String methodName = 'finish';

        Logger.info(CLASS_NAME, methodName, 'Finished processing all NPNs through batch job',
                  'Total NPNs processed: ' + npnList.size() +
                  ', Successful Regular: ' + successfulRegularNPNs.size() +
                  ', Successful Exclude: ' + successfulExcludeNPNs.size(), null);

        // Build list of NPNs with their exclude flags for subscription processing
        List<SubscriptionServiceExecutorQueueable.NPNWithExcludeFlag> npnsWithFlags =
            new List<SubscriptionServiceExecutorQueueable.NPNWithExcludeFlag>();

        for (String npn : successfulRegularNPNs) {
            npnsWithFlags.add(new SubscriptionServiceExecutorQueueable.NPNWithExcludeFlag(npn, false));
        }

        for (String npn : successfulExcludeNPNs) {
            npnsWithFlags.add(new SubscriptionServiceExecutorQueueable.NPNWithExcludeFlag(npn, true));
        }

        // Enqueue executor to handle allocation calculation and processing
        if (!npnsWithFlags.isEmpty()) {
            if (!Test.isRunningTest()) {
                // Set max chain depth on INITIAL enqueue - subsequent chains inherit this limit
                AsyncOptions asyncOptions = new AsyncOptions();
                asyncOptions.MaximumQueueableStackDepth = 100;
                System.enqueueJob(new SubscriptionServiceExecutorQueueable(npnsWithFlags), asyncOptions);
            }

            Logger.info(CLASS_NAME, methodName, 'Enqueued SubscriptionServiceExecutorQueueable',
                'Total NPNs: ' + npnsWithFlags.size(), null);
        } else {
            Logger.info(CLASS_NAME, methodName, 'No subscription processing needed',
                'All NPNs either failed or already have subscriptions', null);
        }

        Logger.commitSync();
    }
}