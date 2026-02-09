/*********************************************************************
Apex Class Name    : DeleteLogsBatch
Created Date       : 25-12-2024
@description       : Deletes all records of the d4c_Log__c object in Salesforce. 

@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author                           Modification
1.0   25-12-2024   Stefan Nidzovic                  Initial Version
*********************************************************************/
public with sharing class DeleteLogsBatchable implements Database.Batchable<SObject>, Database.Stateful {

    // Start method to query the records to be deleted
    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime twoWeeksAgo = Datetime.now().addDays(-14);

        return Database.getQueryLocator('SELECT Id FROM d4c_Log__c WHERE CreatedDate <= :twoWeeksAgo');
    }

    // Execute method to process each batch of records
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        try {
            delete scope;
        } catch (Exception e) {
            System.debug('Error while deleting records: ' + e.getMessage());
        }
    }

    // Finish method for post-processing
    public void finish(Database.BatchableContext BC) {
        System.debug('Batch deletion process completed.');
    }
}