/*
*********************************************************
Apex Class Name    : ContactTriggerHandler
Created Date       : 2025-03-28
@description       : Handles logic for Contact trigger events.
@author            : Uros Markovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-03-28   Uros Markovic      Initial Version
*********************************************************
*/

trigger ContactTrigger on Contact (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new ContactTriggerHandler(), Trigger.operationType);
}