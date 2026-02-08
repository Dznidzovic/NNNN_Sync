/*
*********************************************************
Apex Class Name    : LineOfAuthorityTrigger
Created Date       : 2025-12-13
@description       : Handles trigger events for the Line of Authority object.
                     Manages LOA to Insurance Product mapping lookups.
@author            : Stefan
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan         Initial Version
*********************************************************
*/
trigger LineOfAuthorityTrigger on ht_LineOfAuthority__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete
) {
    TriggerDispatcher.run(new LineOfAuthorityTriggerHandler(), Trigger.operationType);
}