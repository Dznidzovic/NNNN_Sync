/*
*********************************************************
Apex Class Name    : LOAInsuranceProductMappingTrigger
Created Date       : 2025-12-15
@description       : Handles trigger events for the LOA Insurance Product Mapping object.
                     Manages unique identifier auto-generation.
@author            : Stefan
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-15   Stefan         Initial Version
*********************************************************
*/
trigger LOAInsuranceProductMappingTrigger on ht_LOA_Insurance_Product_Mapping__c (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    TriggerDispatcher.run(new LOAInsuranceProductMappingTriggerHandler(), Trigger.operationType);
}