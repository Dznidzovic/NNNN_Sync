trigger ProducerTrigger on ht_Producer__c (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new ProducerTriggerHandler(), Trigger.operationType);
}