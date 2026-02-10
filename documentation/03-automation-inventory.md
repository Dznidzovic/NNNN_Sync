# NIPR Integration - Automation Inventory

```
+==============================================================================+
|                         AUTOMATION INVENTORY                                 |
|                   Triggers, Handlers, Services & Jobs                        |
+==============================================================================+


==============================================================================
                              TRIGGERS & HANDLERS
==============================================================================

+-----------------------------------------------------------------------------+
|  TRIGGER                      | HANDLER CLASS                    | CONTEXTS |
+-------------------------------+----------------------------------+----------+
| AccountTrigger                | AccountTriggerHandler            | AI,AU    |
| ContactTrigger                | ContactTriggerHandler            | AI,AU    |
| LeadTrigger                   | LeadTriggerHandler               | AI,AU    |
| ProducerTrigger               | ProducerTriggerHandler           | AI,AU    |
| SubscriptionTrigger           | SubscriptionTriggerHandler       | AI,AU    |
| CarrierAppointmentTrigger     | CarrierAppointmentTriggerHandler | BI,BU    |
| LineOfAuthorityTrigger        | LineOfAuthorityTriggerHandler    | BI,BU,   |
|                               |                                  | AI,AU,AD |
| LOAInsuranceProductMapping    | LOAInsuranceProductMapping       | BI,BU,   |
|   Trigger                     |   TriggerHandler                 | BD,AD    |
| InsuranceProductTrigger       | InsuranceProductTriggerHandler   | AI,AU,AD |
| InsuranceProductLOAMapping    | InsuranceProductLOAMapping       | BI,BU,   |
|   Trigger                     |   TriggerHandler                 | BD,AD    |
| LicenseInsuranceProductTrigger| LicenseInsuranceProductTrigger   | BI,BD    |
|                               |   Handler                        |          |
| LogTrigger                    | LogTriggerHandler                | AI       |
+-------------------------------+----------------------------------+----------+

Legend: BI=beforeInsert, AI=afterInsert, BU=beforeUpdate, AU=afterUpdate,
        BD=beforeDelete, AD=afterDelete


==============================================================================
                         TRIGGER HANDLER DETAILS
==============================================================================

+-----------------------------------------------------------------------------+
| ProducerTriggerHandler                                                      |
|-----------------------------------------------------------------------------|
| Location: classes/TriggerHandler/ProducerTriggerHandler.cls                 |
|                                                                             |
| afterInsert:                                                                |
|   - Check d4c_SyncRecordToNIPR__c = 'On' AND d4c_NPNStatus__c != 'Active'     |
|   - Collect NPNs for Entity Info API sync                                   |
|   - Enqueue RunEntityInfoReportBatchable                                    |
|                                                                             |
| afterUpdate:                                                                |
|   - Check if d4c_SyncRecordToNIPR__c changed to 'On'                         |
|   - Trigger Entity Info API sync for newly enabled producers                |
+-----------------------------------------------------------------------------+

+-----------------------------------------------------------------------------+
| LineOfAuthorityTriggerHandler                                               |
|-----------------------------------------------------------------------------|
| Location: classes/TriggerHandler/LineOfAuthorityTriggerHandler.cls          |
|                                                                             |
| beforeInsert / beforeUpdate:                                                |
|   - Call LOAProductMappingService.matchLoasToMappings()                     |
|   - Set d4c_LOAMapping__c lookup based on State/Code/Description match       |
|   - Set d4c_IsProductMatched__c = true/false                                 |
|                                                                             |
| afterInsert:                                                                |
|   - Enqueue LOAProductCategorizationBatchable for LOAs with mappings        |
|                                                                             |
| afterUpdate:                                                                |
|   - If mapping changed, enqueue batch to update License_Insurance_Product   |
|                                                                             |
| afterDelete:                                                                |
|   - Enqueue batch to clean up License_Insurance_Product records             |
+-----------------------------------------------------------------------------+

+-----------------------------------------------------------------------------+
| LOAInsuranceProductMappingTriggerHandler                                    |
|-----------------------------------------------------------------------------|
| Location: classes/TriggerHandler/LOAInsuranceProductMappingTriggerHandler.cls|
|                                                                             |
| beforeInsert / beforeUpdate:                                                |
|   - Call UniqueIdentifierService.populateLOAMappingUniqueId()               |
|   - Generate d4c_UniqueIdentifier__c = State-Code-Description                |
|                                                                             |
| beforeDelete:                                                               |
|   - Store related LOA IDs in static variable (for afterDelete)              |
|   - Delete child d4c_Insurance_Product_LOA_Mapping__c junctions              |
|                                                                             |
| afterDelete:                                                                |
|   - Query stored LOA IDs, set d4c_LOAMapping__c = null                       |
|   - LOA trigger will set d4c_IsProductMatched__c = false                     |
+-----------------------------------------------------------------------------+

+-----------------------------------------------------------------------------+
| InsuranceProductLOAMappingTriggerHandler                                    |
|-----------------------------------------------------------------------------|
| Location: classes/TriggerHandler/InsuranceProductLOAMappingTriggerHandler.cls|
|                                                                             |
| beforeInsert:                                                               |
|   - Generate unique identifier                                              |
|                                                                             |
| afterInsert / afterUpdate:                                                  |
|   - Enqueue LOAProductCategorizationBatchable                               |
|                                                                             |
| afterDelete:                                                                |
|   - Delete related d4c_License_Insurance_Product__c records                  |
+-----------------------------------------------------------------------------+


==============================================================================
                              SERVICES
==============================================================================

+-----------------------------------------------------------------------------+
| SERVICE CLASS                        | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| ProcessEntityInfoApiService          | Process Entity Info API response,    |
|   classes/Service/                   | create/update Producer, Licenses,    |
|                                      | LOAs, Appointments, Addresses        |
+--------------------------------------+--------------------------------------+
| ProcessPDBAlertReportService         | Process PDB Alert response,          |
|   classes/Service/                   | handle alert types (NEW_AGENT,       |
|                                      | LICENSE_CHANGE, etc.)                |
+--------------------------------------+--------------------------------------+
| SubscriptionService                  | Manage NIPR subscriptions,           |
|   classes/Service/                   | add/remove NPNs, capacity mgmt       |
+--------------------------------------+--------------------------------------+
| ProducerAssignmentService            | Auto-link Account/Contact/Lead       |
|   classes/Service/                   | to Producer by NPN match             |
+--------------------------------------+--------------------------------------+
| LOAProductMappingService             | Match LOAs to Insurance Product      |
|   classes/Service/                   | Mappings by State/Code/Description   |
+--------------------------------------+--------------------------------------+
| UniqueIdentifierService              | Generate unique identifiers for      |
|   classes/Service/                   | LOA Mappings and other objects       |
+--------------------------------------+--------------------------------------+
| LicenseProductCategorizationService  | Categorize licenses by matching      |
|   classes/Service/                   | LOAs to insurance products           |
+--------------------------------------+--------------------------------------+
| LicenseProductPicklistService        | Provide picklist values for          |
|   classes/Service/                   | License Insurance Products           |
+--------------------------------------+--------------------------------------+
| EntityInfoOrchestratorService        | Orchestrate Entity Info API calls    |
|   classes/Service/                   | and processing                       |
+--------------------------------------+--------------------------------------+


==============================================================================
                          CALLOUT CLASSES (SOAP API)
==============================================================================

+-----------------------------------------------------------------------------+
| CALLOUT CLASS                        | NIPR API ENDPOINT                    |
+--------------------------------------+--------------------------------------+
| RetrieveEntityInfoApiData            | Get full producer data by NPN        |
|   classes/Callout/                   | (licenses, LOAs, appointments)       |
+--------------------------------------+--------------------------------------+
| RetrievePDBSpecificReportData        | Get PDB Alert updates for a          |
|   classes/Callout/                   | subscription (daily changes)         |
+--------------------------------------+--------------------------------------+
| AddNPNToSubscription                 | Add NPN to NIPR subscription         |
|   classes/Callout/                   |                                      |
+--------------------------------------+--------------------------------------+
| RemoveNPNFromSubscription            | Remove NPN from NIPR subscription    |
|   classes/Callout/                   |                                      |
+--------------------------------------+--------------------------------------+
| CreateSubscription                   | Create new NIPR subscription         |
|   classes/Callout/                   |                                      |
+--------------------------------------+--------------------------------------+
| BaseApiInvoker                       | Base class for all SOAP callouts     |
|   classes/Callout/                   | (authentication, error handling)     |
+--------------------------------------+--------------------------------------+


==============================================================================
                       BATCHABLE & QUEUEABLE CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| CLASS                                | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| RunEntityInfoReportBatchable         | Batch process producers for Entity   |
|   classes/Batchable/                 | Info API sync (batch size=1)         |
|                                      | Enqueues SubscriptionServiceExecutor |
+--------------------------------------+--------------------------------------+
| RunPDBAlertReportBatchable           | Batch process subscriptions for      |
|   classes/Batchable/                 | PDB Alert sync (batch size=1)        |
|                                      | Updates d4c_LastNIPRSync__c           |
+--------------------------------------+--------------------------------------+
| LOAProductCategorizationBatchable    | Batch create/update License_         |
|   classes/Batchable/                 | Insurance_Product records            |
+--------------------------------------+--------------------------------------+
| DeleteLogsBatchable                  | Batch delete old log records         |
|   classes/Batchable/                 |                                      |
+--------------------------------------+--------------------------------------+
| SubscriptionServiceExecutorQueueable | Chain queueable for subscription     |
|   classes/Queueable/                 | operations (add NPN, get entity info)|
|                                      | Uses AsyncOptions.MaxStackDepth=100  |
+--------------------------------------+--------------------------------------+
| RunPDBAlert                          | Queueable to run PDB Alert process   |
|   classes/Queueable/                 |                                      |
+--------------------------------------+--------------------------------------+
| DMLExecutor                          | Queueable for async DML operations   |
|   classes/Queueable/                 |                                      |
+--------------------------------------+--------------------------------------+


==============================================================================
                          SCHEDULABLE CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| CLASS                                | SCHEDULE                             |
+--------------------------------------+--------------------------------------+
| PDBAlertReportSchedulable            | Daily @ 2 AM                         |
|   classes/Schedulable/               | Triggers RunPDBAlertReportBatchable  |
+--------------------------------------+--------------------------------------+
| RunEntityInfoReportSchedulable       | On-demand / Scheduled                |
|   classes/Schedulable/               | Triggers RunEntityInfoReportBatchable|
+--------------------------------------+--------------------------------------+
| DeleteLogsScheduleable               | Periodic cleanup                     |
|   classes/Schedulable/               | Triggers DeleteLogsBatchable         |
+--------------------------------------+--------------------------------------+


==============================================================================
                            SELECTORS (REPOSITORY)
==============================================================================

+-----------------------------------------------------------------------------+
| SELECTOR CLASS                       | OBJECT(S)                            |
+--------------------------------------+--------------------------------------+
| ProducerSelector                     | d4c_Entity__c                       |
| LicenseSelector                      | d4c_License__c                        |
| LineOfAuthoritySelector              | d4c_LineOfAuthority__c                |
| CarrierAppointmentSelector           | d4c_CarrierAppointment__c             |
| SubscriptionSelector                 | d4c_Subscription__c                   |
| ProducerAddressSelector              | d4c_ProducerAddress__c                |
| ProducerCommunicationSelector        | d4c_ProducerCommunication__c          |
| AccountSelector                      | Account                              |
| ContactSelector                      | Contact                              |
| LeadSelector                         | Lead                                 |
| LOAInsuranceProductMappingSelector   | d4c_LOA_Insurance_Product_Mapping__c  |
| InsuranceProductLOAMappingSelector   | d4c_Insurance_Product_LOA_Mapping__c  |
| LicenseInsuranceProductSelector      | d4c_License_Insurance_Product__c      |
| RecordTypeSelector                   | RecordType                           |
| MetadataTypeSelector                 | Custom Metadata Types                |
+--------------------------------------+--------------------------------------+


==============================================================================
                              CONTROLLERS
==============================================================================

+-----------------------------------------------------------------------------+
| CONTROLLER CLASS                     | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| EntityInfoApiController              | REST endpoint for manual Entity      |
|   classes/Controllers/               | Info API trigger from UI             |
|   @RestResource(urlMapping='/nipr/*')|                                      |
+--------------------------------------+--------------------------------------+


==============================================================================
                           UTILITY CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| UTILITY CLASS                        | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| Logger                               | Logging utility (async via Platform  |
|   classes/Utils/                     | Events to avoid mixed DML)           |
+--------------------------------------+--------------------------------------+
| XMLUtils                             | Parse SOAP XML responses             |
|   classes/Utils/                     |                                      |
+--------------------------------------+--------------------------------------+
| DateUtils                            | Date parsing and formatting          |
|   classes/Utils/                     |                                      |
+--------------------------------------+--------------------------------------+
| StringUtils                          | String manipulation utilities        |
|   classes/Utils/                     |                                      |
+--------------------------------------+--------------------------------------+
| ListUtils                            | List/Collection utilities            |
|   classes/Utils/                     |                                      |
+--------------------------------------+--------------------------------------+
| RegexUtils                           | Regular expression utilities         |
|   classes/Utils/                     |                                      |
+--------------------------------------+--------------------------------------+
| CorrelationIdUtils                   | Generate correlation IDs for         |
|   classes/Utils/                     | request tracing                      |
+--------------------------------------+--------------------------------------+


==============================================================================
                           FRAMEWORK CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| CLASS                                | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| TriggerDispatcher                    | Central trigger dispatcher           |
|   classes/Dispatcher/                | Routes to appropriate handler        |
+--------------------------------------+--------------------------------------+
| BaseTriggerHandler                   | Base class for all trigger handlers  |
|   classes/TriggerHandler/            | Provides context methods, isDisabled |
+--------------------------------------+--------------------------------------+


==============================================================================
                            DTO CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| DTO CLASS                            | PURPOSE                              |
+--------------------------------------+--------------------------------------+
| EntityInfoDTO                        | Entity Info API response mapping     |
|   classes/DTO/                       |                                      |
+--------------------------------------+--------------------------------------+
| LicensingReportDTO                   | Licensing report data structures     |
|   classes/DTO/                       |                                      |
+--------------------------------------+--------------------------------------+
| AddNPNToSubscriptionDTO              | Add NPN request/response             |
|   classes/DTO/                       |                                      |
+--------------------------------------+--------------------------------------+
| RemoveNPNFromSubscriptionDTO         | Remove NPN request/response          |
|   classes/DTO/                       |                                      |
+--------------------------------------+--------------------------------------+


==============================================================================
                           TEST CLASSES
==============================================================================

+-----------------------------------------------------------------------------+
| TEST CLASS                           | TESTS                                |
+--------------------------------------+--------------------------------------+
| ProcessEntityInfoApiService_Test     | Entity Info processing               |
| ProcessPDBAlertReportService_Test    | PDB Alert processing                 |
| SubscriptionService_Test             | Subscription management              |
| ProducerTriggerHandler_Test          | Producer trigger logic               |
| LineOfAuthorityTriggerHandler_Test   | LOA trigger logic                    |
| LOAInsProdMappingTriggerHandler_Test | LOA Mapping trigger logic            |
| InsuranceProductTriggerHandler_Test  | Insurance Product trigger            |
| InsProdLOAMappingHandler_Test        | Product-LOA junction trigger         |
| LicenseInsProdTriggerHandler_Test    | License-Product trigger              |
| LOAProductMappingService_Test        | LOA matching service                 |
| LOAProductCategorizationBatchable_Test| Categorization batch                |
| UniqueIdentifierService_Test         | Unique ID generation                 |
| RunEntityInfoReportBatchable_Test    | Entity Info batch                    |
| RunPDBAlertReportBatchable_Test      | PDB Alert batch                      |
| RunEntityInfoReportSchedulable_Test  | Entity Info schedulable              |
| PDBAlertReportSchedulable_Test       | PDB Alert schedulable                |
| EntityInfoApiController_Test         | REST controller                      |
| DMLExecutor_Test                     | Async DML                            |
| BaseApiInvoker_Test                  | SOAP callout base                    |
| Logger_Test                          | Logging utility                      |
| TriggerDispatcherTest                | Trigger framework                    |
| HttpMockFactory                      | HTTP mock utility                    |
| HttpSoapMultiMockFactory             | Multi-response SOAP mocks            |
| TestDataFactory                      | Test data builders                   |
| MockHelper                           | Mock data utilities                  |
+--------------------------------------+--------------------------------------+

```
