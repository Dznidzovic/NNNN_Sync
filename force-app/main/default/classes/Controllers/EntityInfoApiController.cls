/*
 *********************************************************************
 Apex Class Name    : EntityInfoApiController
 Created Date       : 04-21-2025
 @description       : Controller class used to process entity information via API callout based on NPN provided.
                      Now runs asynchronously via batch job instead of synchronously.
 @author            : Dev4Clouds
 Modification Log:
 Ver   Date         Author                           Modification
 1.0   04-21-2025   Dev4Clouds                  Initial Version
 2.0   12-25-2025   Dev4Clouds                  Changed to async batch processing
 ********************************************************************
 **/
public with sharing class EntityInfoApiController {

    private static final String CLASS_NAME = 'EntityInfoApiController';

    // Test flag to force exception for coverage
    @TestVisible
    private static Boolean forceException = false;

    /*********************************************************
     @Method Name    : processNPN
     @author         : Dev4Clouds
     @description    : Enqueues the Entity Info batch job to process the NPN asynchronously.
                       Returns immediately - user will see results after refresh.
     @param          : npn - NPN of the producer to process data for
     @return         : void
     *******************************************************
     **/
    @AuraEnabled(cacheable=false)
    public static void processNPN(String npn) {
        if (String.isBlank(npn)) {
            throw new AuraHandledException('Producer NPN is required.');
        }

        try {
            // Test coverage: Force exception if flag is set
            if (forceException) {
                throw new DmlException('Forced exception for test coverage');
            }

            // Execute batch asynchronously - single NPN executes immediately
            RunEntityInfoReportBatchable batch = new RunEntityInfoReportBatchable(new Set<String>{ npn });
            Database.executeBatch(batch, 1);

            Logger.info(CLASS_NAME, 'processNPN',
                'Enqueued Entity Info batch for NPN',
                'NPN: ' + npn, null);
            Logger.commitAsync();

        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'processNPN', e, null);
            Logger.commitAsync();
            throw new AuraHandledException('Failed to start sync process: ' + e.getMessage());
        }
    }
}