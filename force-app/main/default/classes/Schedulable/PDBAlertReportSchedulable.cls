/**
 *********************************************************
 * Apex Class Name    : PDBAlertReportSchedulable
 * Created Date       : 04-29-2025
 * @description       : Schedulable class that runs the RunPDBAlertReportBatchable daily
 *                      at 11 AM CT. Also handles scheduling retry attempts when
 *                      reports are not available.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-29-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
global class PDBAlertReportSchedulable implements Schedulable {
    
    @TestVisible
    private String reportDate;

    @TestVisible
    private Integer retryAttemptsRemaining;

    @TestVisible
    private Boolean isRetry;
    
    /**
     *********************************************************
     * @methodName      : Constructor
     * @description     : Default constructor for daily scheduled execution.
     *                    For the daily scheduled job, we don't need to store the date
     *                    since we'll use the current date when execute() is called.
     *********************************************************
     **/
    global PDBAlertReportSchedulable() {
        // The daily scheduled job will use Date.today() when execute() is called
        this.isRetry = false;
        this.retryAttemptsRemaining = 1;
    }
    
    /**
     *********************************************************
     * @methodName      : Constructor with parameters
     * @description     : Constructor used for retry attempts
     * @param reportDate : The date in string format to retrieve NIPR data for
     * @param retryCount : Number of retry attempts remaining
     *********************************************************
     **/
    global PDBAlertReportSchedulable(String reportDate, Integer retryCount) {
        this.reportDate = reportDate;
        this.retryAttemptsRemaining = retryCount;
        this.isRetry = true;
    }
    
    /**
     *********************************************************
     * @methodName      : execute
     * @description     : Executes the NIPR PDB Alerts batch job
     * @param ctx       : SchedulableContext
     *********************************************************
     **/
    global void execute(SchedulableContext ctx) {
        // For the daily scheduled job (not a retry), use today's date
        String dateToUse = isRetry ? reportDate : String.valueOf(Date.today());
        
        // Execute the batch with batch size = 1 to process one subscription at a time
        RunPDBAlertReportBatchable batch = new RunPDBAlertReportBatchable(dateToUse, retryAttemptsRemaining);
        Database.executeBatch(batch, 1);
    }
    
    /**
     *********************************************************
     * @methodName      : scheduleDaily
     * @description     : Static method to schedule the job to run daily at 11 AM CT
     * @return          : Id of the scheduled job
     *********************************************************
     **/
    global static Id scheduleDaily() {
        // Schedule for 11 AM Central Time (CT)
        // During daylight savings, this would be 12:00 PM CT, which is acceptable
        String cronExp = '0 0 9 * * ?';
        return System.schedule('NIPR PDB Alerts Daily Report - 11 AM CT', cronExp, new PDBAlertReportSchedulable());
    }
}