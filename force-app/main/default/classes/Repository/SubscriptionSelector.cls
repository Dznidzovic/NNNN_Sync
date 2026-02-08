/**
 *********************************************************
 * Apex Class Name    : SubscriptionSelector
 * Created Date       : 04-23-2025
 * @description       : Selector class holding all the queries used for ht_Subscription__c and related objects
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-23-2025   Stefan Nidzovic          Initial Version
 * 1.1   10-24-2025   Stefan Nidzovic          Added methods for subscription refactoring
 *********************************************************
 **/
public with sharing class SubscriptionSelector {     

    /**
     ********************************************************
     * @Method Name    : getSubscriptionById
     * @description    : Returns a subscription record by its Id
     * @param          : subscriptionId - Id of the subscription record
     * @return         : ht_Subscription__c - Subscription record
     *******************************************************
     **/
    public ht_Subscription__c getSubscriptionById(Id subscriptionId) {
        return [
            SELECT
                Id,
                Name,
                ht_Subscription_Name__c
            FROM
                ht_Subscription__c
            WHERE
                Id = :subscriptionId
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getSubscriptionsByIds
     * @description    : Returns subscription records by their ids
     * @param          : subscriptionIds - Ids of the subscription records
     * @return         : List<ht_Subscription__c> - Subscription records
     *******************************************************
     **/
    public List<ht_Subscription__c> getSubscriptionsByIds(Set<Id> subscriptionIds) {
        return [
            SELECT
                Id,
                Name,
                ht_Subscription_Name__c
            FROM
                ht_Subscription__c
            WHERE
                Id IN :subscriptionIds
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getSubscriptionsWithProducersByExcludeFlag
     * @description    : Returns subscriptions filtered by exclude carrier appointments flag with producer count
     * @param          : excludeCarrierAppointments - Boolean flag to filter subscriptions
     * @return         : List<ht_Subscription__c> - List of subscription records with related producers
     *******************************************************
     **/
    public List<ht_Subscription__c> getSubscriptionsWithProducersByExcludeFlag(Boolean excludeCarrierAppointments) {
        return [
            SELECT Id, Name, ht_Subscription_Name__c, ht_ExcludeCarrierAppointments__c,
                (SELECT Id FROM Producers__r)
            FROM ht_Subscription__c
            WHERE ht_ExcludeCarrierAppointments__c = :excludeCarrierAppointments
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     ********************************************************
     * @Method Name    : getLatestSubscriptionByName
     * @description    : Returns the latest subscription ordered by Name (autonumber) descending
     * @return         : ht_Subscription__c - Latest subscription record, or null if none exist
     *******************************************************
     **/
    public ht_Subscription__c getLatestSubscriptionByName() {
        List<ht_Subscription__c> latestSubs = [
            SELECT Id, Name, ht_Subscription_Name__c
            FROM ht_Subscription__c
            ORDER BY ht_Subscription_Name__c DESC
            LIMIT 1
        ];

        return latestSubs.isEmpty() ? null : latestSubs[0];
    }
}