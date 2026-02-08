# NIPR Integration - Object Model

```
+==============================================================================+
|                         COMPLETE OBJECT MODEL                                |
+==============================================================================+


                              CORE NIPR OBJECTS
==============================================================================

                         +-------------------------+
                         |     ht_Producer__c      |
                         |-------------------------|
                         | ht_NPN__c (External ID) |<------ Primary Entity
                         | ht_FirstName__c         |        (Insurance Agent)
                         | ht_LastName__c          |
                         | ht_NPNStatus__c         |
                         | ht_EntityType__c        |
                         | ht_SyncRecordToNIPR__c  |
                         | ht_NPNSyncError__c      |
                         | ht_IntegrationError__c  |
                         | ht_LastNIPRSync__c      |
                         | ht_Subscription__c (FK) |-----+
                         +-------------------------+     |
                                    |                    |
        +---------------------------+--------+           |
        |                          |         |           |
        v                          v         v           v
+----------------+    +------------------+   |   +-------------------+
|ht_ProducerAddr |    |ht_ProducerComm   |   |   | ht_Subscription__c|
|   ess__c       |    |   unication__c   |   |   |-------------------|
|----------------|    |------------------|   |   | ht_SubscriptionId |
| ht_Producer__c |    | ht_Producer__c   |   |   | ht_Status__c      |
| ht_AddressLine |    | ht_Type__c       |   |   | ht_LastNIPRSync__c|
| ht_City__c     |    | ht_Value__c      |   |   | ht_NPNCount__c    |
| ht_State__c    |    +------------------+   |   +-------------------+
| ht_PostalCode__c|                          |
+----------------+                           |
                                             |
                                             v
                         +-------------------------+
                         |     ht_License__c       |
                         |-------------------------|
                         | ht_UniqueIdentifier__c  |<------ External ID
                         | ht_Producer__c (MD)     |        (LicNum+State+Class)
                         | ht_LicenseNumber__c     |
                         | ht_StateOrProvinceCode__c|
                         | ht_LicenseClassCode__c  |
                         | ht_LicenseStatus__c     |
                         | ht_IssueDate__c         |
                         | ht_ExpirationDate__c    |
                         +-------------------------+
                                    |
                                    | (Master-Detail)
                                    v
                    +-----------------------------+
                    |   ht_LineOfAuthority__c     |
                    |-----------------------------|
                    | ht_UniqueIdentifier__c      |<------ External ID
                    | ht_License__c (MD)          |
                    | ht_StateOrProvinceCode__c   |
                    | ht_LineOfAuthorityCode__c   |
                    | ht_LineOfAuthorityDesc__c   |
                    | ht_LOAStatus__c             |
                    | ht_LOAMapping__c (Lookup)   |----+
                    | ht_IsProductMatched__c      |    |
                    +-----------------------------+    |
                                                       |
                                                       |
                              CARRIER APPOINTMENTS     |
==============================================================================  |
                                                       |
                         +-------------------------+   |
                         |ht_CarrierAppointment__c |   |
                         |-------------------------|   |
                         | ht_UniqueIdentifier__c  |   |
                         | ht_Producer__c (Lookup) |   |
                         | ht_Carrier__c (Lookup)  |---+---> ht_Carrier__c
                         | ht_Status__c            |   |     (Carrier Master)
                         | ht_StateCode__c         |   |
                         | ht_EffectiveDate__c     |   |
                         | ht_TerminationDate__c   |   |
                         +-------------------------+   |
                                                       |
                                                       |
                    INSURANCE PRODUCT MAPPING          |
==============================================================================  |
                                                       |
+---------------------------+                          |
| ht_Insurance_Product__c   |                          |
|---------------------------|                          |
| Name                      |                          |
| ht_State__c               |                          |
| ht_IsActive__c            |                          |
+---------------------------+                          |
            |                                          |
            | (Junction)                               |
            v                                          v
+-----------------------------------+    +--------------------------------+
|ht_Insurance_Product_LOA_Mapping__c|    |ht_LOA_Insurance_Product_       |
|-----------------------------------|    |        Mapping__c              |
| ht_InsuranceProduct__c (MD)       |    |--------------------------------|
| ht_LOAMapping__c (Lookup)         |--->| ht_UniqueIdentifier__c         |
| ht_UniqueIdentifier__c            |    | ht_StateOrProvinceCode__c      |
+-----------------------------------+    | ht_LineOfAuthorityCode__c      |
                                         | ht_LineOfAuthorityDescription__c|
                                         +--------------------------------+
                                                       ^
                                                       |
                    +----------------------------------+
                    | (Lookup from LOA)


                    LICENSE TO INSURANCE PRODUCT
==============================================================================

     ht_License__c                      ht_Insurance_Product__c
          |                                      |
          |                                      |
          +-------------+    +-------------------+
                        |    |
                        v    v
               +------------------------------+
               |ht_License_Insurance_Product__c|
               |------------------------------|
               | ht_License__c (MD)           |
               | ht_InsuranceProduct__c (Lkup)|
               | ht_UniqueIdentifier__c       |
               | ht_IsActive__c               |
               +------------------------------+
                            ^
                            |
                Created by LOAProductCategorizationBatchable
                when LOA matches mapping with products



                         STANDARD OBJECTS INTEGRATION
==============================================================================

+-------------+     +-------------+     +-------------+
|   Account   |     |   Contact   |     |    Lead     |
|-------------|     |-------------|     |-------------|
| ht_NPN__c   |     | ht_NPN__c   |     | ht_NPN__c   |
| (Lookup to  |     | (Lookup to  |     | (Lookup to  |
|  Producer)  |     |  Producer)  |     |  Producer)  |
+-------------+     +-------------+     +-------------+
      |                   |                   |
      +-------------------+-------------------+
                          |
                          v
              ProducerAssignmentService
              (Auto-link by NPN match)



                         METADATA & LOGGING
==============================================================================

+---------------------------+     +---------------------------+
| ht_NIPRLogger__mdt        |     | ht_NIPR_Subscription_     |
| (Custom Metadata)         |     |    NPN_Count__mdt         |
|---------------------------|     |---------------------------|
| Enable/Disable logging    |     | Max NPNs per subscription |
| Log level settings        |     | (Default: 500)            |
+---------------------------+     +---------------------------+

+---------------------------+     +---------------------------+
| ht_Logger__c              |     | ht_Log__e                 |
| (Custom Object)           |     | (Platform Event)          |
|---------------------------|     |---------------------------|
| ht_ClassName__c           |     | Async log publishing      |
| ht_MethodName__c          |     |                           |
| ht_Message__c             |     |                           |
| ht_CorrelationId__c       |     |                           |
+---------------------------+     +---------------------------+

+---------------------------+
| ht_NIPRTestXMLResponse__mdt|
|---------------------------|
| Mock XML responses for    |
| unit testing              |
+---------------------------+



                         RELATIONSHIP SUMMARY
==============================================================================

                    MASTER-DETAIL RELATIONSHIPS (MD)
                    ================================

    ht_Producer__c ----(MD)----> ht_License__c
    ht_License__c  ----(MD)----> ht_LineOfAuthority__c
    ht_License__c  ----(MD)----> ht_License_Insurance_Product__c
    ht_Insurance_Product__c --(MD)--> ht_Insurance_Product_LOA_Mapping__c


                    LOOKUP RELATIONSHIPS
                    ====================

    ht_Producer__c -----> ht_Subscription__c
    ht_Producer__c <----- ht_CarrierAppointment__c
    ht_Producer__c <----- ht_ProducerAddress__c
    ht_Producer__c <----- ht_ProducerCommunication__c
    ht_CarrierAppointment__c ----> ht_Carrier__c
    ht_LineOfAuthority__c ----> ht_LOA_Insurance_Product_Mapping__c
    ht_Insurance_Product_LOA_Mapping__c ----> ht_LOA_Insurance_Product_Mapping__c
    ht_License_Insurance_Product__c ----> ht_Insurance_Product__c
    Account/Contact/Lead ----> ht_Producer__c (by NPN)


                    EXTERNAL IDS (For Upsert Operations)
                    ====================================

    +--------------------------------+--------------------------------------+
    | Object                         | External ID Field                    |
    +--------------------------------+--------------------------------------+
    | ht_Producer__c                 | ht_NPN__c                            |
    | ht_License__c                  | ht_UniqueIdentifier__c               |
    | ht_LineOfAuthority__c          | ht_UniqueIdentifier__c               |
    | ht_CarrierAppointment__c       | ht_UniqueIdentifier__c               |
    | ht_LOA_Insurance_Product_Mapping__c | ht_UniqueIdentifier__c          |
    | ht_Insurance_Product_LOA_Mapping__c | ht_UniqueIdentifier__c          |
    | ht_License_Insurance_Product__c| ht_UniqueIdentifier__c               |
    +--------------------------------+--------------------------------------+

```
