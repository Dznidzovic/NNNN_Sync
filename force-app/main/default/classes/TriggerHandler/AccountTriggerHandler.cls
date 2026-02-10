/*
*********************************************************
Apex Class Name    : AccountTriggerHandler
Created Date       : 2025-04-02
@description       : Handles trigger logic for Account
@author            : Dev4Clouds
Modification Log:
Ver   Date         Author          Modification
1.0   2025-04-02   Dev4Clouds   Initial Version
1.1   2025-04-25   Dev4Clouds   Added afterUpdate for orphaned producer handling
*********************************************************
*/
public with sharing class AccountTriggerHandler extends BaseTriggerHandler{
    private final ProducerAssignmentService assignmentService = new ProducerAssignmentService();

    @TestVisible
    private static Boolean triggerDisabled = false;

    public override Boolean isDisabled() {
        // Check both: test flag OR custom metadata type setting
        return triggerDisabled || super.isDisabled();
    }

    public override void beforeInsert(List<SObject> newItems) {
        assignmentService.assignProducers(newItems, null);
    }

    public override void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        assignmentService.assignProducers(newItems.values(), oldItems);
    }
    
    public override void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        // Handle orphaned producer cleanup after the update is complete
        assignmentService.handleOrphanedProducers(newItems.values(), oldItems);
    }
}