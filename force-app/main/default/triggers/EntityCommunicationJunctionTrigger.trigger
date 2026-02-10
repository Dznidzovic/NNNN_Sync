/**
 * @description       : Trigger for Entity Communication Junction object
 * @author            : Dev4Clouds
 * @group             :
 * @last modified on  : 02-10-2026
 * @last modified by  : Stefan Nidzovic
**/
trigger EntityCommunicationJunctionTrigger on d4c_Entity_Communication_Junction__c (
    before insert,
    before update
) {
    TriggerDispatcher.run(new EntityCommunicationJunctionTriggerHandler(), Trigger.operationType);
}
