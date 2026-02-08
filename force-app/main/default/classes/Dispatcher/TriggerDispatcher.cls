/*
*********************************************************
Apex Class Name    : TriggerDispatcher
Created Date       : 03-16-2025
@description       : Handles the execution of Apex Triggers by dispatching 
                     them to the appropriate methods in the provided TriggerHandler.
                     Implements the Trigger Dispatcher pattern for modular trigger management.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author                               Modification
1.0   03-16-2025   Stefan Nidzovic                     Initial Version
*********************************************************
*/
public without sharing class TriggerDispatcher {

    // Test-visible properties to force execution of specific operation types in tests
    @TestVisible private static Boolean forceBeforeInsert = false;
    @TestVisible private static Boolean forceBeforeUpdate = false;
    @TestVisible private static Boolean forceBeforeDelete = false;
    @TestVisible private static Boolean forceAfterInsert = false;
    @TestVisible private static Boolean forceAfterUpdate = false;
    @TestVisible private static Boolean forceAfterDelete = false;
    @TestVisible private static Boolean forceAfterUndelete = false;

    /*********************************************************
    @Method Name    : run
    @description    : Dispatches the trigger execution to the appropriate
                      method in the provided TriggerHandler based on the
                      trigger operation context.
    @param          : handler - The instance of a TriggerHandler implementation.
    @param          : operation - The current trigger operation being executed.
    *********************************************************/
    public static void run(BaseTriggerHandler handler, TriggerOperation operation) {

        // Disabling Trigger logic based on custom settings or test flag
        if (handler.isDisabled()) {
            return;
        }

        // Detect the current trigger context and fire the relevant methods on the trigger handler:
        switch on operation {
            when BEFORE_INSERT {
                if (Trigger.isExecuting || forceBeforeInsert) {
                    handler.beforeInsert(Trigger.new);
                }
            }
            when BEFORE_UPDATE {
                if (Trigger.isExecuting || forceBeforeUpdate) {
                    handler.beforeUpdate(Trigger.newMap, Trigger.oldMap);
                }
            }
            when BEFORE_DELETE {
                if (Trigger.isExecuting || forceBeforeDelete) {
                    handler.beforeDelete(Trigger.oldMap);
                }
            }
            when AFTER_INSERT {
                if (Trigger.isExecuting || forceAfterInsert) {
                    handler.afterInsert(Trigger.newMap);
                }
            }
            when AFTER_UPDATE {
                if (Trigger.isExecuting || forceAfterUpdate) {
                    handler.afterUpdate(Trigger.newMap, Trigger.oldMap);
                }
            }
            when AFTER_DELETE {
                if (Trigger.isExecuting || forceAfterDelete) {
                    handler.afterDelete(Trigger.oldMap);
                }
            }
            when AFTER_UNDELETE {
                if (Trigger.isExecuting || forceAfterUndelete) {
                    handler.afterUndelete(Trigger.oldMap);
                }
            }
        }
    }
}