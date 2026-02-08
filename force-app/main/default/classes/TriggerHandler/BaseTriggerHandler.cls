/*
*********************************************************
Apex Class Name    : BaseTriggerHandler
Created Date       : 03-16-2025
@description       : Base class for handling Apex Triggers using the Trigger Dispatcher pattern.
                     Provides virtual methods for handling different trigger events.
@author            : Stefan Nidzovic
Modification Log:
Ver   Date         Author                               Modification
1.0   03-16-2025   Stefan Nidzovic                     Initial Version
*********************************************************
*/
public virtual class BaseTriggerHandler {

    /*********************************************************
    @Method Name    : isDisabled
    @description    : Determines if trigger execution should be disabled.
                      Checks BOTH in-code static boolean flag (for tests) AND
                      ht_Trigger_Dispatcher_Settings__mdt Custom Metadata Type.
                      If a metadata record exists with ht_Disabled__c = true, the trigger is disabled.
    @return         : Boolean - True if the trigger should be disabled, otherwise False.
    *********************************************************/
    public virtual Boolean isDisabled() {
        // Check in-code static boolean flag first (overridden in child classes for tests)
        // Child classes should override this method to check their own static boolean

        // Get the handler class name
        String handlerName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));

        // Get custom metadata type record using cached getInstance() method (no SOQL query)
        ht_Trigger_Dispatcher_Settings__mdt setting = ht_Trigger_Dispatcher_Settings__mdt.getInstance(handlerName);

        // If a record exists and ht_Disabled__c is true, the trigger is disabled
        return setting != null && setting.ht_Disabled__c == true;
    }

    /*********************************************************
    @Method Name    : beforeInsert
    @description    : Virtual method executed before inserting new records.
    @param          : newItems - List of new SObjects being inserted.
    *********************************************************/
    public virtual void beforeInsert(List<SObject> newItems) {
    }

    /*********************************************************
    @Method Name    : beforeUpdate
    @description    : Virtual method executed before updating existing records.
    @param          : newItems - Map of updated records with their new values.
    @param          : oldItems - Map of existing records with their old values.
    *********************************************************/
    public virtual void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    /*********************************************************
    @Method Name    : beforeDelete
    @description    : Virtual method executed before deleting records.
    @param          : oldItems - Map of records that are about to be deleted.
    *********************************************************/
    public virtual void beforeDelete(Map<Id, SObject> oldItems) {
    }

    /*********************************************************
    @Method Name    : afterInsert
    @description    : Virtual method executed after inserting new records.
    @param          : newItems - Map of new records that have been inserted.
    *********************************************************/
    public virtual void afterInsert(Map<Id, SObject> newItems) {
    }

    /*********************************************************
    @Method Name    : afterUpdate
    @description    : Virtual method executed after updating existing records.
    @param          : newItems - Map of updated records with their new values.
    @param          : oldItems - Map of existing records with their old values.
    *********************************************************/
    public virtual void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    /*********************************************************
    @Method Name    : afterDelete
    @description    : Virtual method executed after deleting records.
    @param          : oldItems - Map of records that were deleted.
    *********************************************************/
    public virtual void afterDelete(Map<Id, SObject> oldItems) {
    }

    /*********************************************************
    @Method Name    : afterUndelete
    @description    : Virtual method executed after undeleting records from the Recycle Bin.
    @param          : oldItems - Map of records that were undeleted.
    *********************************************************/
    public virtual void afterUndelete(Map<Id, SObject> oldItems) {
    }
}