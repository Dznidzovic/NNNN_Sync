/*
*********************************************************
Apex Class Name    : InsuranceProductTrigger
Created Date       : 2025-12-15
@description       : Handles trigger events for the Insurance Product object.
                     Manages unique identifier auto-generation.
@author            : Stefan
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan         Initial Version
*********************************************************
*/
trigger InsuranceProductTrigger on d4c_Insurance_Product__c (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    TriggerDispatcher.run(new InsuranceProductTriggerHandler(), Trigger.operationType);
}