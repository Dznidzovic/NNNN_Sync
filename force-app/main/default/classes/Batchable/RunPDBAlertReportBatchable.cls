/**
 * @description       : 
 * @author            : Stefan Nidzovic
 * @group             : 
 * @last modified on  : 02-09-2026
 * @last modified by  : Stefan Nidzovic
**/
public class RunPDBAlertReportBatchable implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private String reportDate;
    private Integer retryAttemptsRemaining;
    
    @TestVisible
    private Boolean reportNotAvailable = false;
    
    @TestVisible
    private Boolean noAlertsToday = false;
    
    @TestVisible
    private Id testScheduledJobId;
    
    @TestVisible
    private Integer testRetryAttemptsRemaining;
    
    @TestVisible
    private Boolean testRetryScheduled = false;
    
    private SubscriptionSelector subscriptionSelector = new SubscriptionSelector();
    
    public RunPDBAlertReportBatchable(String reportDate, Integer retryCount) {
        this.reportDate = reportDate;
        this.retryAttemptsRemaining = retryCount;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT
                Id,
                Name,
                d4c_Subscription_Name__c,
                (SELECT Id FROM Producers__r LIMIT 1)
            FROM d4c_Subscription__c
            ORDER BY Id
        ]);
    }

    public void execute(Database.BatchableContext bc, List<d4c_Subscription__c> subscriptions) {
        if (reportNotAvailable || noAlertsToday) {
            return;
        }
        
        if (subscriptions == null || subscriptions.isEmpty()) {
            return;
        }
        
        d4c_Subscription__c subscription = subscriptions[0];
        
        if (subscription.Producers__r == null || subscription.Producers__r.isEmpty()) {
            return;
        }
        
        try {
            String niprSubscriptionName = subscription.d4c_Subscription_Name__c + '-' + UserInfo.getOrganizationId();

            if (!Test.isRunningTest()) {

                Logger.info('RunPDBAlertReportBatchable', 'execute', 'Processing subscription',
            'Subscription: ' + subscription.d4c_Subscription_Name__c + ', Report Date: ' + reportDate, subscription.Id);

                ProcessPDBAlertReportService niprService = new ProcessPDBAlertReportService();
                niprService.importData(reportDate, niprSubscriptionName);

                // Update subscription's last sync timestamp after successful processing
                subscription.d4c_LastNIPRSync__c = Datetime.now();
                update subscription;
            } else {
                throw new ProcessPDBAlertReportService.PDBAlertReportException('REPORT_NOT_AVAILABLE: The requested report is not available or complete');
            }

            Logger.info('RunPDBAlertReportBatchable', 'execute', 'Successfully processed subscription',
            'Subscription: ' + subscription.d4c_Subscription_Name__c, subscription.Id);

        } catch (Exception ex) {
            Logger.error('RunPDBAlertReportBatchable', 'execute', ex, subscription.Id);
            
            if (ex instanceof ProcessPDBAlertReportService.PDBAlertReportException &&
                ex.getMessage().contains('REPORT_NOT_AVAILABLE')) {
                
                if (ex.getMessage().contains('There are no alerts scheduled for the day')) {
                    Logger.warning('RunPDBAlertReportBatchable', 'execute', 'No alerts run today - no retry needed',
                                 'Subscription: ' + subscription.d4c_Subscription_Name__c, subscription.Id);

                    noAlertsToday = true;
                } else if (ex.getMessage().contains('The requested report is not available or complete')) {
                    Logger.warning('RunPDBAlertReportBatchable', 'execute', 'Report not finished yet - will retry',
                                 'Subscription: ' + subscription.d4c_Subscription_Name__c + ', Retries Remaining: ' + retryAttemptsRemaining,
                                 subscription.Id);

                    reportNotAvailable = true;
                }
            }
        }

        Logger.commitSync();
    }

    public void finish(Database.BatchableContext bc) {
        if (reportNotAvailable && retryAttemptsRemaining > 0) {
            Integer remainingAttempts = retryAttemptsRemaining - 1;
            testRetryAttemptsRemaining = remainingAttempts;

            Datetime nextRunTime = Datetime.now().addHours(5);
            String cronExp = '' + nextRunTime.second() + ' ' + nextRunTime.minute() + ' ' 
                           + nextRunTime.hour() + ' ' + nextRunTime.day() + ' ' 
                           + nextRunTime.month() + ' ? ' + nextRunTime.year();
            
             Logger.info('RunPDBAlertReportBatchable', 'finish', 'Scheduling retry attempt', 
               'Attempt #: ' + retryAttemptsRemaining + 
               ', Next Run: ' + nextRunTime.format() + 
               ', Remaining Attempts: ' + remainingAttempts, null);
            
            String jobName = 'NIPR PDB Alerts Retry #' + retryAttemptsRemaining + ' - ' + 
                             String.valueOf(Datetime.now().getTime());
            
            PDBAlertReportSchedulable scheduler = new PDBAlertReportSchedulable(reportDate, remainingAttempts);
            testScheduledJobId = System.schedule(jobName, cronExp, scheduler);
            testRetryScheduled = true;
        } else {
            Logger.debug('RunPDBAlertReportBatchable', 'finish', 'No retry needed or max attempts reached', null, null);            testRetryScheduled = false;
        }

        Logger.debug('RunPDBAlertReportBatchable', 'finish', 'Job Finished', null, null); 
        
        Logger.commitSync();
    }
}