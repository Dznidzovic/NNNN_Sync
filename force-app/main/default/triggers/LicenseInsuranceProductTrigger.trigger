/*
*********************************************************
Apex Class Name    : LicenseInsuranceProductTrigger
Created Date       : 2025-12-13
@description       : Handles trigger events for the License Insurance Product junction object.
                     Manages unique identifier generation and License picklist updates.
@author            : Stefan
Modification Log:
Ver   Date         Author         Modification
1.0   2025-12-13   Stefan         Initial Version
*********************************************************
*/
trigger LicenseInsuranceProductTrigger on ht_License_Insurance_Product__c (
    before insert,
    after insert,
    after delete
) {
    TriggerDispatcher.run(new LicenseInsuranceProductTriggerHandler(), Trigger.operationType);
}