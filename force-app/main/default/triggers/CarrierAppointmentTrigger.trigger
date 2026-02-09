/*
*********************************************************
Apex Class Name    : CarrierAppointmentTrigger
Created Date       : 2025-04-09
@description       : Handles trigger events for the Carrier Appointment object.
@author            : Uros Markovic
Modification Log:
Ver   Date         Author         Modification
1.0   2025-04-09   Uros Markovic  Initial Version
*********************************************************
*/
trigger CarrierAppointmentTrigger on d4c_CarrierAppointment__c (
    before insert, 
    before update, 
    before delete, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    TriggerDispatcher.run(new CarrierAppointmentTriggerHandler(), Trigger.operationType);
}