/*
*********************************************************
Apex Class Name    : ContactTriggerHandler
Created Date       : 2025-03-28
@description       : Handles logic for Contact trigger events.
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author         Modification
1.0   2025-03-28   Dev4Clouds      Initial Version
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