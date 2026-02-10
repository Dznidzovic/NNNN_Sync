/**
 *********************************************************
 * Apex Class Name    : EntityCommunicationJunctionTriggerHandler
 * Created Date       : 02-10-2026
 * @description       : Trigger handler for d4c_Entity_Communication_Junction__c
 *                      Populates unique identifier as combination of Entity ID + Communication ID
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   02-10-2026   Dev4Clouds          Initial Version
 *********************************************************
 **/
public with sharing class EntityCommunicationJunctionTriggerHandler extends BaseTriggerHandler {
    /**
     ********************************************************
     * @Method Name    : beforeInsert
     * @description    : Populates unique identifier before insert
     * @param          : newRecords - List of new junction records
     *******************************************************
     **/
    public override void beforeInsert(List<SObject> newRecords) {
        populateUniqueIdentifier((List<d4c_Entity_Communication_Junction__c>) newRecords);
    }

    /**
     ********************************************************
     * @Method Name    : beforeUpdate
     * @description    : Populates unique identifier before update
     * @param          : newRecords - List of updated junction records
     * @param          : oldRecords - List of old junction records
     *******************************************************
     **/
    public override void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords) {
        populateUniqueIdentifier((List<d4c_Entity_Communication_Junction__c>) newRecords);
    }

    /**
     ********************************************************
     * @Method Name    : populateUniqueIdentifier
     * @description    : Creates unique identifier from Entity ID + Communication ID
     * @param          : junctions - List of junction records
     *******************************************************
     **/
    private void populateUniqueIdentifier(List<d4c_Entity_Communication_Junction__c> junctions) {
        for (d4c_Entity_Communication_Junction__c junction : junctions) {
            if (junction.d4c_Entity__c != null && junction.d4c_NIPR_Communication__c != null) {
                junction.d4c_UniqueIdentifier__c = String.valueOf(junction.d4c_Entity__c) + '-' + String.valueOf(junction.d4c_NIPR_Communication__c);
            }
        }
    }
}
