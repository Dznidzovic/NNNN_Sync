/**
 *********************************************************
 * Apex Class Name    : DMLExecutor
 * Created Date       : 03-30-2025
 * @description       : Handles batched execution of Delete and Upsert DML operations. 
 *                      Automatically slices input records into batches and enqueues 
 *                      chained jobs when needed. Uses ListUtils to emulate subList behavior.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author              Modification
 * 1.0   03-30-2025   Stefan Nidzovic     Initial Version
 *********************************************************
**/
public class DMLExecutor implements Queueable {
    // Enum to represent which DML operation we're executing: DELETE or UPSERT
    public enum DMLType { DEL, UPS }
    // Records to upsert (used only for UPS operation)
    private List<SObject> upsertRecords;
    // Ids to delete (used only for DEL operation)
    private List<Id> deleteIds;
    // Operation type: UPS or DEL
    private DMLType operation;
    // External ID field for UPSERT operations
    private Schema.SObjectField externalIdField;
    // Next queueable job to run after this one (for chaining)
    private Queueable nextJob;
    // Maximum number of records to process per job (safe under platform limits)
    private static final Integer BATCH_SIZE = Test.isRunningTest() ? 9000 : 2000;

    // Used for exceptional behaviour when this class is called from "ProcessPDBAlertReportService" because we want to create specific logs when exceptions happen in there
    private String callerClassName;
    // Correlation ID to track the entire transaction chain
    private String correlationId;

    // Test flag to force exception for coverage
    @TestVisible
    private static Boolean forceException = false;

    // Constructor for UPSERT: pass records, external ID field, and optionally the next job
    public DMLExecutor(List<SObject> upsertRecords, Schema.SObjectField externalIdField, Queueable nextJob) {
        this.upsertRecords = upsertRecords;
        this.externalIdField = externalIdField;
        this.operation = DMLType.UPS;
        this.nextJob = nextJob;
    }

    public DMLExecutor(List<SObject> upsertRecords, Schema.SObjectField externalIdField,
                  Queueable nextJob, String callerClassName) {
        this.upsertRecords = upsertRecords;
        this.externalIdField = externalIdField;
        this.operation = DMLType.UPS;
        this.nextJob = nextJob;
        this.callerClassName = callerClassName;
        // Preserve correlation ID if it exists
        this.correlationId = CorrelationIdUtils.getCurrentCorrelationId();
    }

    // Constructor for DELETE: pass record IDs and optionally the next job
    public DMLExecutor(List<Id> deleteIds, Queueable nextJob) {
        this.deleteIds = deleteIds;
        this.operation = DMLType.DEL;
        this.nextJob = nextJob;
    }

    public DMLExecutor(List<Id> deleteIds, Queueable nextJob, String callerClassName) {
        this.deleteIds = deleteIds;
        this.operation = DMLType.DEL;
        this.nextJob = nextJob;
        this.callerClassName = callerClassName;
        // Preserve correlation ID if it exists
        this.correlationId = CorrelationIdUtils.getCurrentCorrelationId();
    }

    // Main method that runs when this queueable is enqueued
    public void execute(QueueableContext context) {
        // Restore correlation ID for this transaction
        if (String.isNotBlank(correlationId)) {
            CorrelationIdUtils.setCorrelationId(correlationId);
        }

        Logger.debug('DMLExecutor', 'execute',
           CorrelationIdUtils.formatLogMessage('Starting DML operation'),
           'CorrelationId: ' + correlationId + ' | Operation Type: ' + operation,
           null);

        if (operation == DMLType.DEL) {
            Logger.info('DMLExecutor', 'handleDeleteQueue',
                CorrelationIdUtils.formatLogMessage('Deleting records'),
                'CorrelationId: ' + correlationId + ' | Records count: ' + (deleteIds != null ? deleteIds.size() : 0) +
                ' | Batch size: ' + BATCH_SIZE,
                null);

            handleDeleteQueue();
        } else if (operation == DMLType.UPS) {
            Logger.info('DMLExecutor', 'handleUpsertQueue',
                CorrelationIdUtils.formatLogMessage('Upserting records'),
                'CorrelationId: ' + correlationId + ' | Records count: ' + (upsertRecords != null ? upsertRecords.size() : 0) +
                ' | Batch size: ' + BATCH_SIZE,
                null);
            handleUpsertQueue();
        }
    }

    /**
     *********************************************************
     * @methodName      : handleDeleteQueue
     * @description     : Deletes records by their Ids, safely processes moe than 10k DML limit and also chains the original next chainable job
     * @return          : void
     *********************************************************
     **/
    private void handleDeleteQueue() {
        if (deleteIds == null || deleteIds.isEmpty()) {
            // Nothing to delete, move to next job
            chainNext();
            return;
        }

        // Filter out already-deleted records to avoid ENTITY_IS_DELETED errors
        deleteIds = filterExistingIds(deleteIds);

        if (deleteIds.isEmpty()) {
            chainNext();
            return;
        }

        if (deleteIds.size() <= BATCH_SIZE) {
            try {
                // Small enough to delete in one go
                Database.delete(deleteIds, true);
                Logger.debug('DMLExecutor', 'handleUpsertQueue', 'Upsert operation successful', null, null);

                Logger.commitAsync();
                chainNext();
            } catch (Exception e) {
                Logger.error('DMLExecutor', 'handleUpsertQueue', e, null);

                // Add special handling for ProcessPDBAlertReportService
                if (callerClassName == 'ProcessPDBAlertReportService') {
                    logNIPRServiceError(e);
                }

                Logger.commitSync();
            }

        } else {
            // Too many records: split into batches and enqueue them as separate jobs
            List<Queueable> chainedDeletes = new List<Queueable>();
            Integer total = deleteIds.size();

            for (Integer i = 0; i < total; i += BATCH_SIZE) {
                // Slice into chunks of size <= 9000
                List<Id> chunk = ListUtils.slice(deleteIds, i, Math.min(i + BATCH_SIZE, total));
                DMLExecutor executor = new DMLExecutor(chunk, null);
                executor.correlationId = this.correlationId; // Pass correlation ID to chunk
                chainedDeletes.add(executor);
            }

            // Reverse-chain the jobs so they execute in the intended order
            Queueable chain = nextJob;

            for (Integer i = chainedDeletes.size() - 1; i >= 0; i--) {
                DMLExecutor current = (DMLExecutor) chainedDeletes[i];
                current.nextJob = chain;
                chain = current;
            }

            // Start the first job in the chain (will call others recursively)
            System.enqueueJob(chain);
        }
    }

    /**
     *********************************************************
     * @methodName      : handleUpsertQueue
     * @description     : Upserts records by their defined upsert key for this object, safely processes more than 10k DML limit and also chains the original next chainable job
     * @return          : void
     *********************************************************
     **/
    private void handleUpsertQueue() {
        if (upsertRecords == null || upsertRecords.isEmpty()) {
            // Nothing to upsert, move to next job
            chainNext();
            return;
        }

        if (upsertRecords.size() <= BATCH_SIZE) {
            try {
                // Test coverage: Force exception if flag is set
                if (forceException) {
                    throw new DmlException('Forced exception for test coverage');
                }

                Database.upsert(upsertRecords, externalIdField, true);
                Logger.debug('DMLExecutor', 'handleUpsertQueue', 'Upsert operation successful', null, null);
                Logger.commitAsync();

                chainNext();
            } catch (Exception e) {
                Logger.error('DMLExecutor', 'handleUpsertQueue', e, null);

                // Add special handling for ProcessPDBAlertReportService
                if (callerClassName == 'ProcessPDBAlertReportService') {
                    logNIPRServiceError(e);
                }

                Logger.commitSync();
            }
        } else {
            // Too many records: split into batches and enqueue as separate jobs
            List<Queueable> chainedUpserts = new List<Queueable>();
            Integer total = upsertRecords.size();

            for (Integer i = 0; i < total; i += BATCH_SIZE) {
                // Slice into chunks of size <= 9000
                List<SObject> chunk = ListUtils.slice(upsertRecords, i, Math.min(i + BATCH_SIZE, total));
                DMLExecutor executor = new DMLExecutor(chunk, externalIdField, null);
                executor.correlationId = this.correlationId; // Pass correlation ID to chunk
                chainedUpserts.add(executor);
            }

            // Reverse-chain the jobs so they execute in the intended order
            Queueable chain = nextJob;

            for (Integer i = chainedUpserts.size() - 1; i >= 0; i--) {
                DMLExecutor current = (DMLExecutor) chainedUpserts[i];
                current.nextJob = chain;
                chain = current;
            }

            // Start the first job in the chain (will call others recursively)
            System.enqueueJob(chain);
        }
    }

    /**
     *********************************************************
     * @methodName      : chainNext
     * @description     : Chains the next qieieable job which was defined for this object
     * @return          : void
     *********************************************************
     **/
    private void chainNext() {
        if (nextJob != null && !Test.isRunningTest()) {
            // Pass correlation ID to next job if it's a DMLExecutor
            if (nextJob instanceof DMLExecutor) {
                DMLExecutor nextDML = (DMLExecutor) nextJob;
                nextDML.correlationId = this.correlationId;
            }
            System.enqueueJob(nextJob);
        }
    }

    private void logNIPRServiceError(Exception e) {
        String objType = '';
        String npnContext = '';

        if (this.operation == DMLExecutor.DMLType.UPS && !upsertRecords.isEmpty()) {
            objType = upsertRecords[0].getSObjectType().getDescribe().getName();

            // Extract NPN context for better debugging
            if (objType == 'd4c_Producer__c') {
                Set<String> npns = new Set<String>();
                for(SObject rec : upsertRecords) {
                    d4c_Producer__c prod = (d4c_Producer__c)rec;
                    if(prod.d4c_NPN__c != null) npns.add(prod.d4c_NPN__c);
                }
                if(!npns.isEmpty()) npnContext = ' | NPNs: ' + String.join(new List<String>(npns), ', ');
            } else if (objType == 'd4c_License__c' || objType == 'd4c_CarrierAppointment__c') {
                Set<String> npns = new Set<String>();
                for(SObject rec : upsertRecords) {
                    SObject producer = rec.getSObject('d4c_Producer__r');
                    if(producer != null && producer.get('d4c_NPN__c') != null) {
                        npns.add((String)producer.get('d4c_NPN__c'));
                    }
                }
                if(!npns.isEmpty()) npnContext = ' | NPNs: ' + String.join(new List<String>(npns), ', ');
            }
        }

        Logger.errorWithCritical(callerClassName, 'DML Operation Failed',
            CorrelationIdUtils.formatLogMessage('PDB Alert DML Error - ' + objType + npnContext),
            'CorrelationId: ' + correlationId + ' | Object: ' + objType + npnContext + ' | Error: ' + e.getMessage() +
            ' | Record Count: ' + (upsertRecords != null ? upsertRecords.size() : deleteIds.size()),
            e.getStackTraceString(),
            true);
    }

    /**
     *********************************************************
     * @methodName      : filterExistingIds
     * @description     : Filters out IDs of records that no longer exist to prevent ENTITY_IS_DELETED errors
     * @param           : ids - List of record IDs to filter
     * @return          : List<Id> - Only IDs of records that still exist
     *********************************************************
     **/
    private List<Id> filterExistingIds(List<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return new List<Id>();
        }

        // Get the SObject type from the first ID
        String sObjectType = ids[0].getSObjectType().getDescribe().getName();

        // Query to find which records still exist
        String query = 'SELECT Id FROM ' + sObjectType + ' WHERE Id IN :ids';
        List<SObject> existingRecords = Database.query(query);

        // Build set of existing IDs
        Set<Id> existingIds = new Set<Id>();
        for (SObject rec : existingRecords) {
            existingIds.add(rec.Id);
        }

        // Return only IDs that still exist
        List<Id> filteredIds = new List<Id>();
        for (Id recordId : ids) {
            if (existingIds.contains(recordId)) {
                filteredIds.add(recordId);
            }
        }

        return filteredIds;
    }
}