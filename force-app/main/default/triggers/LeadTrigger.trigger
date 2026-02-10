/*
*********************************************************
Apex Class Name    : LeadTrigger
Created Date       : 2025-04-02
@description       : Handles logic for Lead trigger events.
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-04-02   Dev4Clouds      Initial Version
*********************************************************
*/

trigger LeadTrigger on Lead (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new LeadTriggerHandler(), Trigger.operationType);
}