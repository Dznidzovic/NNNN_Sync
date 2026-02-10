/*********************************************************************
Apex Class Name    : DeleteLogsBatchScheduler
Created Date       : 25-12-2024
@description       : Scheduler class to invoke the DeleteLogsBatch batch class to delete Logger__c records.

@author            : Dev4Clouds
Modification Log:
Ver   Date         Author                           Modification
1.0   25-12-2024   Dev4Clouds                  Initial Version
*********************************************************************/
global with sharing class DeleteLogsScheduleable implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Schedule executes the batch process
        Database.executeBatch(new DeleteLogsBatchable(), 2000);
    }

    /**
     *********************************************************
     * @methodName      : scheduleTwiceMonthly
     * @description     : Schedules this job to run on the 1st and 15th of each month at 2:00 AM
     * @return          : Id - ID of the scheduled job
     *********************************************************
     **/
    global static Id scheduleTwiceMonthly() {
        String cronExp = '0 0 2 1,15 * ?'; // At 02:00 AM on the 1st and 15th of every month
        String jobName = 'DeleteLogsScheduleable_1stAnd15th';

        if (!Test.isRunningTest()) {
            return System.schedule(jobName, cronExp, new DeleteLogsScheduleable());
        } else {
            return null;
        }
    }
}