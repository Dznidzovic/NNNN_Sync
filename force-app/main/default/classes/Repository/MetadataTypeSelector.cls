/**
 *********************************************************
 * Apex Class Name    : MetadataTypeSelector
 * Created Date       : 04-23-2025
 * @description       : Selector class holding all the queries used for custom metadata type objects
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-23-2025   Stefan Nidzovic          Initial Version
 * 1.1   04-30-2025   HipTen Admin             Added Logger configuration selector
 *********************************************************
 **/
public with sharing class MetadataTypeSelector {
    /**
     ********************************************************
     * @Method Name    : getNIPRSyncSettings
     * @description    : Returns the consolidated NIPR Sync Settings custom metadata record
     * @param          : None
     * @return         : d4c_NIPR_Sync_Settings__mdt - Custom metadata record with all NIPR sync configuration
     *******************************************************
     **/
    public d4c_NIPR_Sync_Settings__mdt getNIPRSyncSettings() {
        return [
            SELECT
                Id,
                d4c_EnableDebugging__c,
                d4c_MaxNPNCountPerSubscription__c,
                d4c_SubscriptionEmail__c,
                d4c_TestXMLActive__c,
                d4c_TestXMLData__c
            FROM
                d4c_NIPR_Sync_Settings__mdt
            WHERE
                DeveloperName = 'NIPR_Global_Settings'
            LIMIT 1
        ];
    }
}