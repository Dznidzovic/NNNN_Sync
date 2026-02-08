/**
 *********************************************************
 * Apex Class Name    : RunPDBAlert
 * Created Date       : 03-30-2025
 * @description       : Queueable class that triggers the NIPR PDB Alert data import process
 *                      by invoking ProcessPDBAlertReportService. It passes the report
 *                      date and subscription name to retrieve and process licensing data.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-30-2025   Stefan Nidzovic          Initial Version
 * 1.1   12-25-2025   Stefan Nidzovic          Updated to use ProcessPDBAlertReportService
 *********************************************************
 **/
public class RunPDBAlert implements Queueable, Database.AllowsCallouts {
    private String reportDate;
    private String subscriptionName;

    public RunPDBAlert(String reportDate, String subscriptionName) {
        this.reportDate = reportDate;
        this.subscriptionName = subscriptionName;
    }

    public void execute(QueueableContext context) {
        ProcessPDBAlertReportService service = new ProcessPDBAlertReportService();
        service.importData(reportDate, subscriptionName);
    }
}