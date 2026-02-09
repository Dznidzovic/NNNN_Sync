/**
*********************************************************
* Apex Class Name    : Logger
* Created Date       : 04-30-2025
* @description       : Logger utility class for tracking events, errors, and debug information
*                      Supports different log levels and both synchronous and asynchronous logging
*                      Updated to use platform events for async logging
* @author            : HipTen Admin
* Modification Log:
* Ver   Date         Author                   Modification
* 1.0   04-30-2025   HipTen Admin             Initial Version
* 1.1   04-30-2025   HipTen Admin             Added metadata-driven system debug configuration
* 1.2   05-02-2025   HipTen Admin             Added critical error flag support
* 1.3   06-08-2025   HipTen Admin             Updated async logging to use platform events
*********************************************************
**/
public without sharing class Logger {
   
    // Log levels in order of severity
    public enum LogLevel {
        DEBUG, INFO, WARNING, ERROR
    }
    
    // Static collection to store logs before committing
    private static List<d4c_Log__c> pendingLogs = new List<d4c_Log__c>();
    
    // Transaction ID for grouping logs
    private static String transactionId;
    
    // Selector for metadata type records
    private static final MetadataTypeSelector metadataSelector = new MetadataTypeSelector();
    
    // Flag to control system debug output - controlled by Custom Metadata
    private static Boolean enableSystemDebug {
        get {
            if (enableSystemDebug == null) {
                try {
                    d4c_NIPR_Sync_Settings__mdt settings = metadataSelector.getNIPRSyncSettings();
                    enableSystemDebug = settings.d4c_EnableDebugging__c;
                } catch (Exception ex) {
                    // If metadata query fails, default to true for safety
                    enableSystemDebug = true;
                    System.debug(LoggingLevel.ERROR, 'LOGGER CONFIG ERROR: Failed to retrieve logger configuration: ' + ex.getMessage());
                }
            }
            return enableSystemDebug;
        }
        private set;
    }
    
    public static String generateUUID() {
       return String.valueOf(UUID.randomUUID());
    }

    /**
     *********************************************************
     * @methodName      : getTransactionId
     * @description     : Gets the current transaction ID or creates a new one
     * @return          : String - Unique transaction ID
     *********************************************************
     **/
    public static String getTransactionId() {
        if (transactionId == null) {
            transactionId = Logger.generateUUID();
        }
        return transactionId;
    }

    /**
     *********************************************************
     * @methodName      : setTransactionId
     * @description     : Sets a custom transaction ID for correlation across processes
     * @param customTransactionId : The transaction ID to use
     *********************************************************
     **/
    public static void setTransactionId(String customTransactionId) {
        if (String.isNotBlank(customTransactionId)) {
            transactionId = customTransactionId;
        }
    }
    
    /**
     *********************************************************
     * @methodName      : debug
     * @description     : Creates a debug level log with related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Debug message
     * @param details       : Additional details (optional)
     * @param relatedRecord : Related record ID
     *********************************************************
     **/
    public static void debug(String sourceName, String sourceMethod, String message, String details, String relatedRecord) {
        createLog(LogLevel.DEBUG, sourceName, sourceMethod, message, details, null, relatedRecord, false);
    }
    
    /**
     *********************************************************
     * @methodName      : debug
     * @description     : Creates a debug level log without related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Debug message
     * @param details       : Additional details (optional)
     *********************************************************
     **/
    public static void debug(String sourceName, String sourceMethod, String message, String details) {
        debug(sourceName, sourceMethod, message, details, null);
    }
    
    /**
     *********************************************************
     * @methodName      : debug
     * @description     : Creates a simple debug level log
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Debug message
     *********************************************************
     **/
    public static void debug(String sourceName, String sourceMethod, String message) {
        debug(sourceName, sourceMethod, message, null, null);
    }
    
    /**
     *********************************************************
     * @methodName      : info
     * @description     : Creates an info level log with related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Info message
     * @param details       : Additional details (optional)
     * @param relatedRecord : Related record ID
     *********************************************************
     **/
    public static void info(String sourceName, String sourceMethod, String message, String details, String relatedRecord) {
        createLog(LogLevel.INFO, sourceName, sourceMethod, message, details, null, relatedRecord, false);
    }
    
    /**
     *********************************************************
     * @methodName      : info
     * @description     : Creates an info level log without related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Info message
     * @param details       : Additional details (optional)
     *********************************************************
     **/
    public static void info(String sourceName, String sourceMethod, String message, String details) {
        info(sourceName, sourceMethod, message, details, null);
    }
    
    /**
     *********************************************************
     * @methodName      : info
     * @description     : Creates a simple info level log
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Info message
     *********************************************************
     **/
    public static void info(String sourceName, String sourceMethod, String message) {
        info(sourceName, sourceMethod, message, null, null);
    }
    
    /**
     *********************************************************
     * @methodName      : warning
     * @description     : Creates a warning level log with related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Warning message
     * @param details       : Additional details (optional)
     * @param relatedRecord : Related record ID
     *********************************************************
     **/
    public static void warning(String sourceName, String sourceMethod, String message, String details, String relatedRecord) {
        createLog(LogLevel.WARNING, sourceName, sourceMethod, message, details, null, relatedRecord, false);
    }
    
    /**
     *********************************************************
     * @methodName      : warning
     * @description     : Creates a warning level log without related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Warning message
     * @param details       : Additional details (optional)
     *********************************************************
     **/
    public static void warning(String sourceName, String sourceMethod, String message, String details) {
        warning(sourceName, sourceMethod, message, details, null);
    }
    
    /**
     *********************************************************
     * @methodName      : warning
     * @description     : Creates a simple warning level log
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Warning message
     *********************************************************
     **/
    public static void warning(String sourceName, String sourceMethod, String message) {
        warning(sourceName, sourceMethod, message, null, null);
    }
    
    /**
     *********************************************************
     * @methodName      : error
     * @description     : Creates an error level log with all details
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Error message
     * @param details       : Detailed error information
     * @param stackTrace    : Exception stack trace
     * @param relatedRecord : Related record ID
     *********************************************************
     **/
    public static void error(String sourceName, String sourceMethod, String message, String details, String stackTrace, String relatedRecord) {
        createLog(LogLevel.ERROR, sourceName, sourceMethod, message, details, stackTrace, relatedRecord, false);
    }
    
    /**
     *********************************************************
     * @methodName      : error
     * @description     : Creates an error level log without related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Error message
     * @param details       : Detailed error information
     * @param stackTrace    : Exception stack trace
     *********************************************************
     **/
    public static void error(String sourceName, String sourceMethod, String message, String details, String stackTrace) {
        error(sourceName, sourceMethod, message, details, stackTrace, null);
    }

    /**
     *********************************************************
     * @methodName      : errorWithCritical
     * @description     : Creates an error level log with critical flag
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Error message
     * @param details       : Detailed error information
     * @param stackTrace    : Exception stack trace
     * @param critical      : Indicates if error is critical
     *********************************************************
     **/
    public static void errorWithCritical(String sourceName, String sourceMethod, String message, String details, String stackTrace, Boolean critical) {
        createLog(LogLevel.ERROR, sourceName, sourceMethod, message, details, stackTrace, null, critical);
    }
    
    /**
     *********************************************************
     * @methodName      : error
     * @description     : Creates a simple error level log
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Error message
     *********************************************************
     **/
    public static void error(String sourceName, String sourceMethod, String message) {
        error(sourceName, sourceMethod, message, null, null);
    }
    
    /**
     *********************************************************
     * @methodName      : error
     * @description     : Creates an error level log from an exception with related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param ex            : Exception object
     * @param relatedRecord : Related record ID
     *********************************************************
     **/
    public static void error(String sourceName, String sourceMethod, Exception ex, String relatedRecord) {
        String message = ex.getMessage();
        String details = 'Type: ' + ex.getTypeName() + '\nLine: ' + ex.getLineNumber();
        String stackTrace = ex.getStackTraceString();
        
        error(sourceName, sourceMethod, message, details, stackTrace, relatedRecord);
    }
    
    /**
     *********************************************************
     * @methodName      : error
     * @description     : Creates an error level log from an exception without related record
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param ex            : Exception object
     *********************************************************
     **/
    public static void error(String sourceName, String sourceMethod, Exception ex) {
        error(sourceName, sourceMethod, ex, null);
    }
    
    /**
     *********************************************************
     * @methodName      : errorWithCritical
     * @description     : Creates a critical error log from an exception
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param ex            : Exception object
     * @param critical      : Indicates if error is critical
     *********************************************************
     **/
    public static void errorWithCritical(String sourceName, String sourceMethod, Exception ex, Boolean critical) {
        String message = ex.getMessage();
        String details = 'Type: ' + ex.getTypeName() + '\nLine: ' + ex.getLineNumber();
        String stackTrace = ex.getStackTraceString();
        
        createLog(LogLevel.ERROR, sourceName, sourceMethod, message, details, stackTrace, null, critical);
    }
    
    /**
     *********************************************************
     * @methodName      : createLog
     * @description     : Core method for creating a log entry
     * @param level         : Log level (DEBUG, INFO, WARNING, ERROR)
     * @param sourceName    : Class or Flow name
     * @param sourceMethod  : Method or Flow element name
     * @param message       : Log message
     * @param details       : Additional details
     * @param stackTrace    : Stack trace for errors
     * @param relatedRecord : Related record ID
     * @param critical      : Indicates if log is critical
     *********************************************************
     **/
    private static void createLog(LogLevel level, String sourceName, String sourceMethod, 
                               String message, String details, String stackTrace, String relatedRecord, Boolean critical) {
        // Create log object
        d4c_Log__c log = new d4c_Log__c(
            d4c_LogLevel__c = level.name(),
            d4c_SourceName__c = sourceName,
            d4c_SourceMethod__c = sourceMethod,
            d4c_Message__c = truncateField(message, 255),
            d4c_Details__c = truncateField(details, 131071),
            d4c_StackTrace__c = stackTrace,
            d4c_Source__c = 'Apex', // Default to Apex, could be parameterized
            d4c_OccurredDateTime__c = Datetime.now(),
            d4c_RelatedRecord__c = relatedRecord,
            d4c_TransactionId__c = getTransactionId(),
            d4c_Critical__c = critical
        );
        
        // Add to pending logs
        pendingLogs.add(log);
                
        // Output to debug logs if enabled by metadata configuration
        if (enableSystemDebug) {
            // Start with basic information
            String debugMessage = 'LOGGER [' + level + ']' + (critical ? ' [CRITICAL]' : '') + ' ' + sourceName + '.' + sourceMethod + ': ' + message;
            
            // Include all available additional information
            if (details != null && details != '') {
                debugMessage += '\nDetails: ' + details;
            }
            
            if (stackTrace != null && stackTrace != '') {
                debugMessage += '\nStack Trace: ' + stackTrace;
            }
            
            if (relatedRecord != null && relatedRecord != '') {
                debugMessage += '\nRelated Record: ' + relatedRecord;
            }
            
            // Include transaction ID for correlation
            debugMessage += '\nTransaction ID: ' + getTransactionId();
            
            // Log with appropriate level
            System.debug(
                level == LogLevel.ERROR ? LoggingLevel.ERROR : 
                level == LogLevel.WARNING ? LoggingLevel.WARN : 
                level == LogLevel.INFO ? LoggingLevel.INFO : 
                LoggingLevel.DEBUG, 
                debugMessage
            );
        }
    }
    
    /**
     *********************************************************
     * @methodName      : commitSync
     * @description     : Commits all pending logs synchronously in the current transaction
     * @return          : List<d4c_Log__c> - The committed log records with their IDs
     *********************************************************
     **/
    public static List<d4c_Log__c> commitSync() {
        if (pendingLogs.isEmpty()) {
            return new List<d4c_Log__c>();
        }
        
        List<d4c_Log__c> logsToCommit = pendingLogs.clone();
        pendingLogs.clear();
        
        try {
            insert logsToCommit;
            return logsToCommit;
        } catch (Exception ex) {
            // If logging itself fails, output to debug logs
            if (enableSystemDebug) {
                System.debug(LoggingLevel.ERROR, 'LOGGER FAILURE: Failed to insert logs: ' + ex.getMessage());
            }
            throw ex;
        }
    }

    /**
     *********************************************************
     * @methodName      : commitAsync
     * @description     : Commits all pending logs asynchronously via platform events
     * @return          : Id - Returns null (maintained for backward compatibility)
     *********************************************************
     **/
    public static Id commitAsync() {        
        if (pendingLogs.isEmpty()) {
            return null;
        }
        
        List<d4c_Log__c> logsToCommit = pendingLogs.clone();
        pendingLogs.clear();
        
        try {
            // Serialize logs to JSON
            String jsonContent = JSON.serialize(logsToCommit);
            
            // Trim if content exceeds Long Text Area limit
            if (jsonContent.length() > 131070) {
                jsonContent = jsonContent.substring(0, 131070);
                
                if (enableSystemDebug) {
                    System.debug(LoggingLevel.WARN, 'LOGGER WARNING: JSON content was truncated from ' + JSON.serialize(logsToCommit).length() + ' to 131070 characters due to field limit');
                }
            }
            
            // Create platform event
            d4c_Log__e logEvent = new d4c_Log__e(
                d4c_Content__c = jsonContent
            );
            
            // Publish the event
            EventBus.publish(logEvent);
            
            if (enableSystemDebug) {
                System.debug(LoggingLevel.INFO, 'LOGGER: Published ' + logsToCommit.size() + ' logs via platform event');
            }
            
            return null; // Return null for backward compatibility (no batch ID)
        } catch (Exception ex) {
            // If platform event publishing fails, fallback to sync commit
            if (enableSystemDebug) {
                System.debug(LoggingLevel.ERROR, 'LOGGER FAILURE: Failed to publish platform event, falling back to sync: ' + ex.getMessage());
            }
            
            // Restore the logs to pending and commit synchronously as fallback
            pendingLogs.addAll(logsToCommit);
            commitSync();
            
            return null;
        }
    }
    
    /**
     *********************************************************
     * @methodName      : processLogEvent
     * @description     : Static method to process log events from platform event trigger
     *                    This method is called by the trigger handler
     * @param logContent : JSON string containing serialized log records
     *********************************************************
     **/
    public static void processLogEvent(String logContent) {
        try {
            // Deserialize the JSON content back to log records
            List<d4c_Log__c> logsToInsert = (List<d4c_Log__c>) JSON.deserialize(logContent, List<d4c_Log__c>.class);
            
            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
                
                if (enableSystemDebug) {
                    System.debug(LoggingLevel.INFO, 'LOGGER: Successfully inserted ' + logsToInsert.size() + ' logs from platform event');
                }
            }
        } catch (Exception ex) {
            // Log the error but don't throw - we don't want to cause the platform event to retry
            if (enableSystemDebug) {
                System.debug(LoggingLevel.ERROR, 'LOGGER FAILURE: Failed to process log event: ' + ex.getMessage() + '\nContent: ' + logContent);
            }
        }
    }
    
    /**
     *********************************************************
     * @methodName      : truncateField
     * @description     : Utility method to truncate string fields to fit SF limits
     * @param value     : The string to truncate
     * @param maxLength : Maximum length allowed
     * @return          : String - Truncated string
     *********************************************************
     **/
    private static String truncateField(String value, Integer maxLength) {
        if (value == null) {
            return null;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}