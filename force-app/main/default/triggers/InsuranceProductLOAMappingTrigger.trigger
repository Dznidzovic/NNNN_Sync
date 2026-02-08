/*
*********************************************************
Apex Class Name    : InsuranceProductLOAMappingTrigger
Created Date       : 2025-12-13
@description       : Handles trigger events for the Insurance Product LOA Mapping junction object.
                     Manages unique identifier generation and reverse LOA matching.
@author            : Stefan
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan         Initial Version
*********************************************************
*/
trigger InsuranceProductLOAMappingTrigger on ht_Insurance_Product_LOA_Mapping__c (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    TriggerDispatcher.run(new InsuranceProductLOAMappingTriggerHandler(), Trigger.operationType);
}