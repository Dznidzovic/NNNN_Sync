trigger SubscriptionTrigger on ht_Subscription__c (
    after insert
) {
    TriggerDispatcher.run(new SubscriptionTriggerHandler(), Trigger.operationType);
}