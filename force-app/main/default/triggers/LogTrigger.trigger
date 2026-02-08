/*
*********************************************************
Trigger Name       : ht_LogTrigger  
Created Date       : 06-08-2025
@description       : Handles logic for ht_Log__e platform event trigger
@author            : HipTen Admin
Modification Log:
Ver   Date         Author         Modification
1.0   06-08-2025   HipTen Admin   Initial Version
*********************************************************
*/

trigger LogTrigger on ht_Log__e (after insert) {
    TriggerDispatcher.run(new LogTriggerHandler(), Trigger.operationType);
}