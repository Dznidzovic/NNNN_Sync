/**
 * @description       : 
 * @author            : Dev4Clouds
 * @group             : 
 * @last modified on  : 02-10-2026
 * @last modified by  : Stefan Nidzovic
**/
trigger SubscriptionTrigger on d4c_Subscription__c (
    after insert
) {
    TriggerDispatcher.run(new SubscriptionTriggerHandler(), Trigger.operationType);
}