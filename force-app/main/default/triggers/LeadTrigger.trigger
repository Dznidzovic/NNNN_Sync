/*
*********************************************************
Apex Class Name    : LeadTrigger
Created Date       : 2025-04-02
@description       : Handles logic for Lead trigger events.
@author            : Uros Markovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-04-02   Uros Markovic      Initial Version
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