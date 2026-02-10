/**
 *********************************************************
 * Apex Class Name    : RunEntityInfoReportSchedulable
 * Created Date       : 2025-12-17
 * @description       : Schedulable class that executes RunEntityInfoReportBatchable
 *                      after a delay. Queries producers with 'Processing' status
 *                      to collect all pending NPNs before batch execution.
 *                      Only processes producers created/modified after the schedule
 *                      was first created (minus 5 second buffer).
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author         Modification
 * 1.0   2025-12-17   Stefan Nidzovic         Initial Version
 * 1.1   2025-12-17   Stefan Nidzovic         Added scheduledSince filter for producer query
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
     * @description     : Queries all producers awaiting processing that were
     *                    created/modified after the schedule time and executes batch
     * @param ctx       : SchedulableContext
     *********************************************************
     **/
    public void execute(SchedulableContext ctx) {
        // Query all producers awaiting processing created/modified since scheduling
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