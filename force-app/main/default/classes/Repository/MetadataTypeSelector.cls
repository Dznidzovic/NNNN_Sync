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
     * @Method Name    : getNIPRNPNSubMaxCount
     * @description    : Returns the custom metadata type record containing the maximum NPN count configuration for NIPR subscriptions
     * @param          : None
     * @return         : ht_NIPR_Subsciption_NPN_Count__mdt - Custom metadata record with maximum NPN count
     *******************************************************
     **/
    public ht_NIPR_Subsciption_NPN_Count__mdt getNIPRNPNSubMaxCount() {
        return [
            SELECT
                Id,
                ht_MAX_NPN_Count__c
            FROM
                ht_NIPR_Subsciption_NPN_Count__mdt
            WHERE
                DeveloperName LIKE '%MAX_NPN_Count'
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getNIPRNPNSubMaxCount
     * @description    : Returns the custom metadata type record containing the maximum NPN count configuration for NIPR subscriptions
     * @param          : None
     * @return         : ht_NIPR_Subsciption_NPN_Count__mdt - Custom metadata record with maximum NPN count
     *******************************************************
     **/
    public ht_NIPR_Subscription_Email__mdt getNIPRSubscriptionEmail() {
        return [
            SELECT
                Id,
                ht_Email__c
            FROM
                ht_NIPR_Subscription_Email__mdt
            WHERE
                DeveloperName LIKE '%NIPR_Subscription_Email'
        ];
    }
    
    /**
     ********************************************************
     * @Method Name    : getLoggerConfig
     * @description    : Returns the custom metadata type record containing the Logger configuration
     * @param          : None
     * @return         : ht_NIPRLogger__mdt - Custom metadata record with logger configuration
     *******************************************************
     **/
    public ht_NIPRLogger__mdt getLoggerConfig() {
        return [
            SELECT
                Id,
                ht_EnableDebugging__c
            FROM
                ht_NIPRLogger__mdt
            WHERE
                DeveloperName LIKE '%Logger_Config'
        ];
    }
}