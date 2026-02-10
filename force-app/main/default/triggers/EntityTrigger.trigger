/**
 * @description       : 
 * @author            : Stefan Nidzovic
 * @group             : 
 * @last modified on  : 02-09-2026
 * @last modified by  : Stefan Nidzovic
**/
trigger EntityTrigger on d4c_Entity__c (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new EntityTriggerHandler(), Trigger.operationType);
}