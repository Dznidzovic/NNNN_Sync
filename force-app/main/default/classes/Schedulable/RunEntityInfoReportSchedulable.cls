/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReportSchedulable
 * Created Date       : 2025-12-17
 * @description       : Schedulable class that executes RunEntityInfoReportBatchable
 *                      after a delay. Queries entitys with 'Processing' status
 *                      to collect all pending NPNs before batch execution.
 *                      Only processes entitys created/modified after the schedule
 *                      was first created (minus 5 second buffer).
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-17   Dev4Clouds         Initial Version
 * 1.1   2025-12-17   Dev4Clouds         Added scheduledSince filter for entity query
 *********************************************************
 **/
public class RunEntityInfoReportSchedulable implements Schedulable {

    // Timestamp from when scheduling was first triggered (minus 5 second buffer)
    private DateTime scheduledSince;

    /**
     *********************************************************
     * @methodName      : RunEntityInfoReportSchedulable
     * @description     : Constructor that captures the schedule timestamp
     * @param scheduledSince : DateTime when the job was first scheduled (minus 5s buffer)
     *********************************************************
     **/
    public RunEntityInfoReportSchedulable(DateTime scheduledSince) {
        this.scheduledSince = scheduledSince;
    }

    /**
     *********************************************************
     * @methodName      : execute
     * @description     : Queries all entitys awaiting processing that were
     *                    created/modified after the schedule time and executes batch
     * @param ctx       : SchedulableContext
     *********************************************************
     **/
    public void execute(SchedulableContext ctx) {
        // Query all entitys awaiting processing created/modified since scheduling
        Set<String> npns = new Set<String>();
        for (d4c_Entity__c p : [
            SELECT d4c_NPN__c
            FROM d4c_Entity__c
            WHERE d4c_NPNStatus__c = 'Processing'
            AND d4c_SyncRecordToNIPR__c = 'On'
            AND d4c_NPN__c != null
            AND LastModifiedDate >= :scheduledSince
        ]) {
            npns.add(p.d4c_NPN__c);
        }

        if (!npns.isEmpty()) {
            Database.executeBatch(new RunEntityInfoReportBatchable(npns), 1);
        }
    }
}