/**
 *********************************************************************
 * Apex Class Name    : NIPREnums
 * Created Date       : 04-13-2025
 * @description       : Enum container class for NIPR API-related constants.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                           Modification
 * 1.0   04-13-2025   Stefan Nidzovic                  Initial Version
 * 1.1   10-24-2025   Stefan Nidzovic                  Added SubscriptionOperation enum
 *********************************************************************
 **/
public with sharing class NIPREnums {
    public enum PDBAlertError {
        REPORT_NOT_AVAILABLE,
        UNKOWN_ISSUE
    }

    public enum EntityInfoError {
        NO_PRODUCER_DATA,
        UNKOWN_ISSUE
    }

    public enum SubscriptionOperation {
        ADD_TO_SUBSCRIPTION,
        REMOVE_NPN_AFTER_UPDATE,
        REMOVE_NPN_AFTER_DELETE,
        RESUBSCRIBE_TO_DIFFERENT_POOL,
        ADD_NPNS_BULK
    }

    /**
     * Operation modes for LOA Product Categorization batch processing
     */
    public enum OperationMode {
        CREATE_MODE,   // Create new License-Product junctions
        UPDATE_MODE,   // Update existing junctions (delete old, create new)
        DELETE_MODE    // Delete junctions for removed LOAs
    }
}