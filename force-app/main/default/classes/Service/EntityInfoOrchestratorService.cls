/**
 *********************************************************
 * Apex Class Name    : EntityInfoOrchestratorService
 * Created Date       : 2025-12-23
 * @description       : Orchestrates Entity Info batch processing
 *                      Decides whether to execute immediately (single NPN)
 *                      or use smart scheduling (multiple NPNs)
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-23   Dev4Clouds         Initial Version
 *********************************************************
 **/
public class EntityInfoOrchestratorService {

    // PROPERTIES
    private static final String CLASS_NAME = 'EntityInfoOrchestratorService';

    // Smart scheduling constants
    private static final String ENTITY_INFO_JOB_NAME = 'NIPR_EntityInfo_Process';
    private static final Integer INITIAL_DELAY_MINUTES = 2;
    private static final Integer RESCHEDULE_THRESHOLD_MINUTES = 1;

    // Test flag to allow scheduling in tests for coverage
    @TestVisible
    private static Boolean allowSchedulingInTests = false;

    /**
     *********************************************************
     * @Method Name    : execute
     * @description    : Main entry point that decides whether to execute immediately or schedule
     * @param          : npns - Set of NPNs to process
     * @return         : void
     *********************************************************
     **/
    public static void execute(Set<String> npns) {
        if (npns == null || npns.isEmpty()) {
            return;
        }

        if (npns.size() == 1) {
            // Single entity update - execute immediately
            executeImmediately(npns);
        } else {
            // Bulk data load - use smart scheduling
            scheduleEntityInfoBatchIfNeeded();
        }
    }

    /**
     *********************************************************
     * @Method Name    : executeImmediately
     * @description    : Executes the batch immediately for single NPN
     * @param          : npns - Set containing single NPN
     * @return         : void
     *********************************************************
     **/
    private static void executeImmediately(Set<String> npns) {
        String methodName = 'executeImmediately';

        try {
            RunEntityInfoReportBatchable batch = new RunEntityInfoReportBatchable(npns);

            if (Test.isRunningTest()) {
                // In test context, execute synchronously to avoid batch execution limits
                // Call execute directly with a mock batch context
                Database.BatchableContext mockContext = null;
                List<String> npnList = new List<String>(npns);
                batch.execute(mockContext, npnList);
            } else {
                // In production, execute as normal batch
                Database.executeBatch(batch, 1);
            }

            Logger.info(CLASS_NAME, methodName,
                'Executed Entity Info batch immediately',
                'NPN: ' + new List<String>(npns)[0], null);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /**
     *********************************************************
     * @Method Name    : scheduleEntityInfoBatchIfNeeded
     * @description    : Smart scheduling for Entity Info batch processing.
     *                   Schedules batch 2 minutes in the future to allow bulk imports to accumulate.
     *                   If existing job is < 1 min away, reschedules to 2 min from now.
     * @return         : void
     *********************************************************
     **/
    private static void scheduleEntityInfoBatchIfNeeded() {
        String methodName = 'scheduleEntityInfoBatchIfNeeded';

        // In test context, don't actually schedule jobs unless flag is set
        if (Test.isRunningTest() && !allowSchedulingInTests) {
            Logger.info(CLASS_NAME, methodName,
                'Skipping scheduling in test context',
                'Smart scheduling would occur in production', null);
            return;
        }

        try {
            // Check for existing scheduled job
            List<CronTrigger> existingJobs = [
                SELECT Id, NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE :ENTITY_INFO_JOB_NAME + '%'
                AND State IN ('WAITING', 'ACQUIRED')
                LIMIT 1
            ];

            if (!existingJobs.isEmpty()) {
                Long minutesUntilRun = (existingJobs[0].NextFireTime.getTime() - DateTime.now().getTime()) / 60000;

                if (minutesUntilRun < RESCHEDULE_THRESHOLD_MINUTES) {
                    // Extract original schedule timestamp from job name
                    DateTime originalScheduleTime = extractScheduleTimeFromJobName(existingJobs[0].Id);
                    // Reschedule - abort old job and create new one with same original timestamp
                    System.abortJob(existingJobs[0].Id);
                    scheduleNewEntityInfoJob(originalScheduleTime);

                    Logger.info(CLASS_NAME, methodName,
                        'Rescheduled existing Entity Info job',
                        'Original time: ' + originalScheduleTime, null);
                }
                // Else: existing schedule is fine, NPNs will be picked up by query in scheduler
            } else {
                // No existing schedule - create new one with current timestamp (minus 5 seconds buffer)
                DateTime scheduledSince = DateTime.now().addSeconds(-5);
                scheduleNewEntityInfoJob(scheduledSince);

                Logger.info(CLASS_NAME, methodName,
                    'Created new Entity Info scheduled job',
                    'Scheduled since: ' + scheduledSince, null);
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }

    /**
     *********************************************************
     * @Method Name    : extractScheduleTimeFromJobName
     * @description    : Extracts the original schedule timestamp from the job name
     * @param cronTriggerId : Id of the CronTrigger
     * @return         : DateTime - the original schedule time
     *********************************************************
     **/
    private static DateTime extractScheduleTimeFromJobName(Id cronTriggerId) {
        CronTrigger ct = [
            SELECT CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :cronTriggerId
            LIMIT 1
        ];

        String jobName = ct.CronJobDetail.Name;
        // Job name format: NIPR_EntityInfo_Process_<timestamp>
        String timestampStr = jobName.substringAfter(ENTITY_INFO_JOB_NAME + '_');
        if (String.isNotBlank(timestampStr)) {
            return DateTime.valueOf(timestampStr.replace('T', ' '));
        }
        // Fallback to now minus 5 seconds if parsing fails
        return DateTime.now().addSeconds(-5);
    }

    /**
     *********************************************************
     * @Method Name    : scheduleNewEntityInfoJob
     * @description    : Creates a new scheduled job to run Entity Info batch
     *                   2 minutes in the future. Encodes scheduledSince in job name.
     * @param scheduledSince : DateTime when scheduling was first triggered
     * @return         : void
     *********************************************************
     **/
    private static void scheduleNewEntityInfoJob(DateTime scheduledSince) {
        String methodName = 'scheduleNewEntityInfoJob';

        // In test context, don't actually schedule jobs unless flag is set
        if (Test.isRunningTest() && !allowSchedulingInTests) {
            Logger.info(CLASS_NAME, methodName,
                'Skipping job creation in test context',
                'Job would be scheduled for: ' + scheduledSince, null);
            return;
        }

        try {
            DateTime runTime = DateTime.now().addMinutes(INITIAL_DELAY_MINUTES);
            String cronExpression = runTime.format('s m H d M \'?\' yyyy');
            // Encode scheduledSince in job name for retrieval during rescheduling
            String jobName = ENTITY_INFO_JOB_NAME + '_' + scheduledSince.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss');
            System.schedule(jobName, cronExpression, new RunEntityInfoReportSchedulable(scheduledSince));

            Logger.info(CLASS_NAME, methodName,
                'Scheduled Entity Info job',
                'Job name: ' + jobName + ', Run time: ' + runTime, null);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, methodName, e, null);
            Logger.commitAsync();
        }
    }
}