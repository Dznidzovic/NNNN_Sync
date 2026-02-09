/*
*********************************************************
Apex Class Name    : d4c_LogTriggerHandler
Created Date       : 06-08-2025
@description       : Handles trigger logic for d4c_Log__e platform event
@author            : HipTen Admin
Modification Log:
Ver   Date         Author          Modification
1.0   06-08-2025   HipTen Admin    Initial Version
*********************************************************
*/
public with sharing class LogTriggerHandler extends BaseTriggerHandler {
    
    @TestVisible
    private static Boolean triggerDisabled = false;

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    /**
     *********************************************************
     * @methodName      : afterInsert
     * @description     : Handles after insert events for platform event
     * @param newItems  : List of new platform event records
     *********************************************************
     **/
    public override void afterInsert(Map<Id, SObject> newItems) {
        List<d4c_Log__e> logEvents = (List<d4c_Log__e>) newItems.values();
        
        for (d4c_Log__e logEvent : logEvents) {
            if (String.isNotBlank(logEvent.d4c_Content__c)) {
                // Use the Logger class's static method to process the event
                Logger.processLogEvent(logEvent.d4c_Content__c);
            }
        }
    }
}