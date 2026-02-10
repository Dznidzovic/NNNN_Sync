/*
*********************************************************
Trigger Name       : d4c_LogTrigger  
Created Date       : 06-08-2025
@description       : Handles logic for d4c_Logger__e platform event trigger
@author            : HipTen Admin
Modification Log:
Ver   Date         Author         Modification
1.0   06-08-2025   HipTen Admin   Initial Version
*********************************************************
*/

trigger LogTrigger on d4c_Logger__e (after insert) {
    TriggerDispatcher.run(new LogTriggerHandler(), Trigger.operationType);
}