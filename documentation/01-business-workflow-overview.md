# NIPR Integration - Business Workflow Overview

```
+==============================================================================+
|                      NIPR INTEGRATION SYSTEM OVERVIEW                        |
+==============================================================================+

                              EXTERNAL SYSTEMS
+-----------------------------------------------------------------------------+
|                                                                             |
|    +-------------------+                      +------------------------+    |
|    |       NIPR        |                      |     Salesforce Org     |    |
|    |  (National Ins.   |<------ SOAP -------->|                        |    |
|    |  Entity Reg.)   |       API            |   [This Application]   |    |
|    +-------------------+                      +------------------------+    |
|                                                                             |
+-----------------------------------------------------------------------------+


==============================================================================
                         1. PRODUCER ONBOARDING FLOW
==============================================================================

 User Action                     System Processing                    Result
+----------+    +------------------------------------------------+   +--------+
|          |    |                                                |   |        |
| Create   |--->| EntityTrigger                                |-->| Entity|
| Entity |    |      |                                         |   | Created |
| Record   |    |      v                                         |   |        |
| (NPN)    |    | EntityTriggerHandler.afterInsert()           |   +--------+
|          |    |      |                                         |
+----------+    |      | Check: d4c_SyncRecordToNIPR__c = 'On'    |
                |      | Check: d4c_NPNStatus__c != 'Active'      |
                |      |                                         |
                |      v                                         |
                | RunEntityInfoReportBatchable                   |
                |      |                                         |
                |      v                                         |
                | SubscriptionServiceExecutorQueueable           |
                |      |                                         |
                |      +---> AddNPNToSubscription (SOAP)         |
                |      |          |                              |
                |      |          v                              |
                |      |     NIPR adds NPN to subscription       |
                |      |                                         |
                |      +---> RetrieveEntityInfoApiData (SOAP)    |
                |                 |                              |
                |                 v                              |
                |      ProcessEntityInfoApiService               |
                |           |                                    |
                |           +---> Create/Update Entity         |
                |           +---> Create/Update Licenses         |
                |           +---> Create/Update LOAs             |
                |           +---> Create/Update Appointments     |
                |           +---> Create/Update Addresses        |
                |           +---> Set d4c_LastNIPRSync__c         |
                +------------------------------------------------+


==============================================================================
                      2. DAILY PDB ALERT PROCESSING FLOW
==============================================================================

                        Scheduled @ 2 AM Daily
                               |
                               v
+-----------------------------------------------------------------------------+
|                     PDBAlertReportSchedulable                               |
|                              |                                              |
|                              v                                              |
|                    RunPDBAlertReportBatchable                               |
|                              |                                              |
|     +------------------------+------------------------+                     |
|     |                        |                        |                     |
|     v                        v                        v                     |
| Subscription 1          Subscription 2           Subscription N             |
|     |                        |                        |                     |
|     v                        v                        v                     |
| RetrievePDBSpecificReportData (SOAP) - Get alerts for each subscription     |
|                              |                                              |
|                              v                                              |
|                 ProcessPDBAlertReportService                                |
|                              |                                              |
|     +------------------------+------------------------+                     |
|     |                        |                        |                     |
|     v                        v                        v                     |
| NEW_AGENT              LICENSE_CHANGE          APPOINTMENT_CHANGE           |
| NEW_AGENCY             LOA_CHANGE              ADDRESS_CHANGE               |
|     |                        |                        |                     |
|     v                        v                        v                     |
| Create New              Update Existing         Update Carrier              |
| Entity Records        License/LOA Data        Appointments                |
|                              |                                              |
|                              v                                              |
|                 Set d4c_LastNIPRSync__c on Subscription                      |
+-----------------------------------------------------------------------------+


==============================================================================
                    3. LOA TO INSURANCE PRODUCT MAPPING FLOW
==============================================================================

+-----------------------------------------------------------------------------+
|                                                                             |
|  MASTER DATA SETUP                    AUTOMATIC MATCHING                    |
|  ==================                   ==================                    |
|                                                                             |
|  +--------------------------+                                               |
|  | Insurance Products       |                                               |
|  | (e.g., Auto, Home, Life) |                                               |
|  +--------------------------+                                               |
|            |                                                                |
|            v                                                                |
|  +--------------------------+         +---------------------------+         |
|  | LOA Mapping Records      |         | Line of Authority (LOA)   |         |
|  | (State + Code + Desc)    |<------->| Records from NIPR         |         |
|  | d4c_UniqueIdentifier__c   |  Match  | (State + Code + Desc)     |         |
|  +--------------------------+   by    +---------------------------+         |
|            |                  Key              |                            |
|            v                                   v                            |
|  +--------------------------+         +---------------------------+         |
|  | Product-LOA Junction     |         | d4c_LOAMapping__c (lookup) |         |
|  | (many-to-many)           |         | d4c_IsProductMatched__c    |         |
|  +--------------------------+         +---------------------------+         |
|                                                |                            |
|                                                v                            |
|                                       +---------------------------+         |
|                                       | License Insurance Product |         |
|                                       | (Entity can sell this)  |         |
|                                       +---------------------------+         |
|                                                                             |
+-----------------------------------------------------------------------------+

          LOA Matching Logic (LineOfAuthorityTriggerHandler)
          ==================================================

   +------------------+     +----------------------+     +------------------+
   | LOA Insert/      |---->| matchLoasToMappings()|---->| Set lookup &     |
   | Update           |     | in LOAProduct        |     | IsProductMatched |
   |                  |     | MappingService       |     | = true/false     |
   +------------------+     +----------------------+     +------------------+

          LOA Mapping Delete (LOAInsuranceProductMappingTriggerHandler)
          =============================================================

   +------------------+     +----------------------+     +------------------+
   | Delete LOA       |---->| beforeDelete: Store  |---->| afterDelete:     |
   | Mapping Record   |     | related LOA IDs      |     | Clear lookup,    |
   |                  |     | (static variable)    |     | trigger re-match |
   +------------------+     +----------------------+     +------------------+


==============================================================================
                       4. SUBSCRIPTION MANAGEMENT FLOW
==============================================================================

                     +----------------------------------+
                     |    NIPR SUBSCRIPTION LIMITS      |
                     |    Max 500 NPNs per subscription |
                     +----------------------------------+
                                    |
          +-------------------------+-------------------------+
          |                         |                         |
          v                         v                         v
   +-------------+           +-------------+           +-------------+
   | Subscription|           | Subscription|           | Subscription|
   |      A      |           |      B      |           |      C      |
   | (450 NPNs)  |           | (500 NPNs)  |           | (200 NPNs)  |
   +-------------+           +-------------+           +-------------+
          |                         |                         |
          v                         v                         v
   +-------------+           +-------------+           +-------------+
   | Add new NPN |           | FULL - Need |           | Add new NPN |
   | if capacity |           | new subscr. |           | if capacity |
   +-------------+           +-------------+           +-------------+

   SubscriptionService.addEntityToSubscription()
   ================================================
   1. Find subscription with capacity (< 500 NPNs)
   2. If none found, create new subscription
   3. Call AddNPNToSubscription SOAP API
   4. Update d4c_Subscription__c lookup on Entity


==============================================================================
                      5. DATA SYNCHRONIZATION STRATEGY
==============================================================================

+-----------------------------------------------------------------------------+
|                         EXTERNAL ID UPSERT PATTERN                          |
|                                                                             |
|   All NIPR objects use external IDs for idempotent upserts:                 |
|                                                                             |
|   +------------------------+------------------------------------------+     |
|   | Object                 | External ID Field                        |     |
|   +------------------------+------------------------------------------+     |
|   | d4c_Entity__c         | d4c_NPN__c                                |     |
|   | d4c_License__c          | d4c_UniqueIdentifier__c (LicNum+State+Cls)|     |
|   | d4c_LineOfAuthority__c  | d4c_UniqueIdentifier__c (License+Code+Dsc)|     |
|   | d4c_CarrierAppointment__c| d4c_UniqueIdentifier__c                  |     |
|   | d4c_LOA_Insurance_Product_Mapping__c | d4c_UniqueIdentifier__c      |     |
|   +------------------------+------------------------------------------+     |
|                                                                             |
|   Benefits:                                                                 |
|   - Idempotent operations (re-running won't create duplicates)              |
|   - Simplified sync logic (upsert vs insert/update decision)                |
|   - Natural key matching with NIPR data                                     |
|                                                                             |
+-----------------------------------------------------------------------------+


==============================================================================
                         6. ERROR HANDLING & RETRY
==============================================================================

                        +------------------------+
                        |    API Call Fails      |
                        +------------------------+
                                   |
                                   v
                        +------------------------+
                        | Log Error to           |
                        | d4c_Logger__c           |
                        +------------------------+
                                   |
                                   v
                        +------------------------+
                        | Set Error Fields:      |
                        | - d4c_NPNSyncError__c   |
                        | - d4c_IntegrationError__c|
                        +------------------------+
                                   |
                                   v
                        +------------------------+
                        | Retry Logic:           |
                        | - Up to 3 attempts     |
                        | - Exponential backoff  |
                        +------------------------+
                                   |
                                   v
                        +------------------------+
                        | If success:            |
                        | - Clear error fields   |
                        | - Set LastNIPRSync     |
                        +------------------------+


==============================================================================
                              LEGEND
==============================================================================

    +--------+
    |        |   Process/Service
    +--------+

    ------->     Data Flow

    <------->    Bidirectional/Matching

    - - - ->     Async/Scheduled

```
