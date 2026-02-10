/**
 * @description       : Trigger for Entity Address Junction object
 * @author            : Dev4Clouds
 * @group             :
 * @last modified on  : 02-10-2026
 * @last modified by  : Stefan Nidzovic
**/
trigger EntityAddressJunctionTrigger on d4c_Entity_Address_Junction__c (
    before insert,
    before update
) {
    TriggerDispatcher.run(new EntityAddressJunctionTriggerHandler(), Trigger.operationType);
}
