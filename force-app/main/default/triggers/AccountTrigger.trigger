/*
*********************************************************
Apex Class Name    : AccountTrigger
Created Date       : 2025-03-31
@description       : Handles logic for Account trigger events.
@author            : Uros Markovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-03-28   Uros Markovic  Initial Version
*********************************************************
*/

trigger AccountTrigger on Account (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new AccountTriggerHandler(), Trigger.operationType);
}