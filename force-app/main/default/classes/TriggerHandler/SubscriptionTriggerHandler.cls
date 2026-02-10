/*********************************************************
 * Apex Class Name    : SubscriptionTriggerHandler
 * Created Date       : 2025-12-24
 * @description       : Trigger handler for d4c_Subscription__c that increments the
 *                      custom settings counter (d4c_NIPRSubscriptionDetails__c.d4c_Latest_Number__c)
 *                      whenever a new subscription is created
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   2025-12-24   Dev4Clouds                   Initial Version
 *********************************************************
 **/
public with sharing class SubscriptionTriggerHandler extends BaseTriggerHandler {
    @TestVisible
    private static Boolean triggerDisabled = false;

    public override Boolean isDisabled() {
        return triggerDisabled || super.isDisabled();
    }

    /**
     *********************************************************
     * @Method Name    : afterInsert
     * @description    : Increments the custom settings counter when subscriptions are created
     *                   The counter tracks the latest subscription number used
     * @param          : newItems - Map of new subscription records
     * @return         : void
     *********************************************************
     **/
    public override void afterInsert(Map<Id, SObject> newItems) {
        // Find the highest subscription number from the newly inserted subscriptions
        Decimal maxNumber = 0;

        for (SObject obj : newItems.values()) {
            d4c_Subscription__c subscription = (d4c_Subscription__c) obj;

            // Extract number from d4c_Subscription_Name__c (format: S-XXXX)
            if (String.isNotBlank(subscription.d4c_Subscription_Name__c)) {
                String subscriptionName = subscription.d4c_Subscription_Name__c;

                // Parse the number from S-XXXX format
                if (subscriptionName.startsWith('S-') && subscriptionName.length() >= 6) {
                    String numberPart = subscriptionName.substring(2); // Remove 'S-'
                    try {
                        Decimal subscriptionNumber = Decimal.valueOf(numberPart);
                        if (subscriptionNumber > maxNumber) {
                            maxNumber = subscriptionNumber;
                        }
                    } catch (Exception e) {
                        // Skip invalid format - continue processing other subscriptions
                    }
                }
            }
        }

        // Only update counter if we found valid subscription numbers
        if (maxNumber > 0) {
            updateCustomSettingsCounter(maxNumber);
        }
    }

    /**
     *********************************************************
     * @Method Name    : updateCustomSettingsCounter
     * @description    : Updates the custom settings counter if the new value is higher
     * @param          : newNumber - The new subscription number to set
     * @return         : void
     *********************************************************
     **/
    private void updateCustomSettingsCounter(Decimal newNumber) {
        d4c_NIPRSubscriptionDetails__c settings = d4c_NIPRSubscriptionDetails__c.getOrgDefaults();

        // getOrgDefaults() returns an object with null Id if no settings exist
        if (settings == null || settings.Id == null) {
            settings = new d4c_NIPRSubscriptionDetails__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                d4c_Latest_Number__c = newNumber
            );
            insert settings;
        } else {
            // Only update if the new number is higher than current
            if (settings.d4c_Latest_Number__c == null || newNumber > settings.d4c_Latest_Number__c) {
                settings.d4c_Latest_Number__c = newNumber;
                update settings;
            }
        }
    }
}