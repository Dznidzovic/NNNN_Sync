# NIPR Integration - Object Model

```
+==============================================================================+
|                         COMPLETE OBJECT MODEL                                |
+==============================================================================+


                              CORE NIPR OBJECTS
==============================================================================

                         +-------------------------+
                         |     d4c_Producer__c      |
                         |-------------------------|
                         | d4c_NPN__c (External ID) |<------ Primary Entity
                         | d4c_FirstName__c         |        (Insurance Agent)
                         | d4c_LastName__c          |
                         | d4c_NPNStatus__c         |
                         | d4c_EntityType__c        |
                         | d4c_SyncRecordToNIPR__c  |
                         | d4c_NPNSyncError__c      |
                         | d4c_IntegrationError__c  |
                         | d4c_LastNIPRSync__c      |
                         | d4c_Subscription__c (FK) |-----+
                         +-------------------------+     |
                                    |                    |
        +---------------------------+--------+           |
        |                          |         |           |
        v                          v         v           v
+----------------+    +------------------+   |   +-------------------+
|d4c_ProducerAddr |    |d4c_ProducerComm   |   |   | d4c_Subscription__c|
|   ess__c       |    |   unication__c   |   |   |-------------------|
|----------------|    |------------------|   |   | d4c_SubscriptionId |
| d4c_Producer__c |    | d4c_Producer__c   |   |   | d4c_Status__c      |
| d4c_AddressLine |    | d4c_Type__c       |   |   | d4c_LastNIPRSync__c|
| d4c_City__c     |    | d4c_Value__c      |   |   | d4c_NPNCount__c    |
| d4c_State__c    |    +------------------+   |   +-------------------+
| d4c_PostalCode__c|                          |
+----------------+                           |
                                             |
                                             v
                         +-------------------------+
                         |     d4c_License__c       |
                         |-------------------------|
                         | d4c_UniqueIdentifier__c  |<------ External ID
                         | d4c_Producer__c (MD)     |        (LicNum+State+Class)
                         | d4c_LicenseNumber__c     |
                         | d4c_StateOrProvinceCode__c|
                         | d4c_LicenseClassCode__c  |
                         | d4c_LicenseStatus__c     |
                         | d4c_IssueDate__c         |
                         | d4c_ExpirationDate__c    |
                         +-------------------------+
                                    |
                                    | (Master-Detail)
                                    v
                    +-----------------------------+
                    |   d4c_LineOfAuthority__c     |
                    |-----------------------------|
                    | d4c_UniqueIdentifier__c      |<------ External ID
                    | d4c_License__c (MD)          |
                    | d4c_StateOrProvinceCode__c   |
                    | d4c_LineOfAuthorityCode__c   |
                    | d4c_LineOfAuthorityDesc__c   |
                    | d4c_LOAStatus__c             |
                    | d4c_LOAMapping__c (Lookup)   |----+
                    | d4c_IsProductMatched__c      |    |
                    +-----------------------------+    |
                                                       |
                                                       |
                              CARRIER APPOINTMENTS     |
==============================================================================  |
                                                       |
                         +-------------------------+   |
                         |d4c_CarrierAppointment__c |   |
                         |-------------------------|   |
                         | d4c_UniqueIdentifier__c  |   |
                         | d4c_Producer__c (Lookup) |   |
                         | d4c_Carrier__c (Lookup)  |---+---> d4c_Carrier__c
                         | d4c_Status__c            |   |     (Carrier Master)
                         | d4c_StateCode__c         |   |
                         | d4c_EffectiveDate__c     |   |
                         | d4c_TerminationDate__c   |   |
                         +-------------------------+   |
                                                       |
                                                       |
                    INSURANCE PRODUCT MAPPING          |
==============================================================================  |
                                                       |
+---------------------------+                          |
| d4c_Insurance_Product__c   |                          |
|---------------------------|                          |
| Name                      |                          |
| d4c_State__c               |                          |
| d4c_IsActive__c            |                          |
+---------------------------+                          |
            |                                          |
            | (Junction)                               |
            v                                          v
+-----------------------------------+    +--------------------------------+
|d4c_Insurance_Product_LOA_Mapping__c|    |d4c_LOA_Insurance_Product_       |
|-----------------------------------|    |        Mapping__c              |
| d4c_InsuranceProduct__c (MD)       |    |--------------------------------|
| d4c_LOAMapping__c (Lookup)         |--->| d4c_UniqueIdentifier__c         |
| d4c_UniqueIdentifier__c            |    | d4c_StateOrProvinceCode__c      |
+-----------------------------------+    | d4c_LineOfAuthorityCode__c      |
                                         | d4c_LineOfAuthorityDescription__c|
                                         +--------------------------------+
                                                       ^
                                                       |
                    +----------------------------------+
                    | (Lookup from LOA)


                    LICENSE TO INSURANCE PRODUCT
==============================================================================

     d4c_License__c                      d4c_Insurance_Product__c
          |                                      |
          |                                      |
          +-------------+    +-------------------+
                        |    |
                        v    v
               +------------------------------+
               |d4c_License_Insurance_Product__c|
               |------------------------------|
               | d4c_License__c (MD)           |
               | d4c_InsuranceProduct__c (Lkup)|
               | d4c_UniqueIdentifier__c       |
               | d4c_IsActive__c               |
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
| d4c_NPN__c   |     | d4c_NPN__c   |     | d4c_NPN__c   |
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
| d4c_NIPRLogger__mdt        |     | d4c_NIPR_Subscription_     |
| (Custom Metadata)         |     |    NPN_Count__mdt         |
|---------------------------|     |---------------------------|
| Enable/Disable logging    |     | Max NPNs per subscription |
| Log level settings        |     | (Default: 500)            |
+---------------------------+     +---------------------------+

+---------------------------+     +---------------------------+
| d4c_Logger__c              |     | d4c_Log__e                 |
| (Custom Object)           |     | (Platform Event)          |
|---------------------------|     |---------------------------|
| d4c_ClassName__c           |     | Async log publishing      |
| d4c_MethodName__c          |     |                           |
| d4c_Message__c             |     |                           |
| d4c_CorrelationId__c       |     |                           |
+---------------------------+     +---------------------------+

+---------------------------+
| d4c_NIPRTestXMLResponse__mdt|
|---------------------------|
| Mock XML responses for    |
| unit testing              |
+---------------------------+



                         RELATIONSHIP SUMMARY
==============================================================================

                    MASTER-DETAIL RELATIONSHIPS (MD)
                    ================================

    d4c_Producer__c ----(MD)----> d4c_License__c
    d4c_License__c  ----(MD)----> d4c_LineOfAuthority__c
    d4c_License__c  ----(MD)----> d4c_License_Insurance_Product__c
    d4c_Insurance_Product__c --(MD)--> d4c_Insurance_Product_LOA_Mapping__c


                    LOOKUP RELATIONSHIPS
                    ====================

    d4c_Producer__c -----> d4c_Subscription__c
    d4c_Producer__c <----- d4c_CarrierAppointment__c
    d4c_Producer__c <----- d4c_ProducerAddress__c
    d4c_Producer__c <----- d4c_ProducerCommunication__c
    d4c_CarrierAppointment__c ----> d4c_Carrier__c
    d4c_LineOfAuthority__c ----> d4c_LOA_Insurance_Product_Mapping__c
    d4c_Insurance_Product_LOA_Mapping__c ----> d4c_LOA_Insurance_Product_Mapping__c
    d4c_License_Insurance_Product__c ----> d4c_Insurance_Product__c
    Account/Contact/Lead ----> d4c_Producer__c (by NPN)


                    EXTERNAL IDS (For Upsert Operations)
                    ====================================

    +--------------------------------+--------------------------------------+
    | Object                         | External ID Field                    |
    +--------------------------------+--------------------------------------+
    | d4c_Producer__c                 | d4c_NPN__c                            |
    | d4c_License__c                  | d4c_UniqueIdentifier__c               |
    | d4c_LineOfAuthority__c          | d4c_UniqueIdentifier__c               |
    | d4c_CarrierAppointment__c       | d4c_UniqueIdentifier__c               |
    | d4c_LOA_Insurance_Product_Mapping__c | d4c_UniqueIdentifier__c          |
    | d4c_Insurance_Product_LOA_Mapping__c | d4c_UniqueIdentifier__c          |
    | d4c_License_Insurance_Product__c| d4c_UniqueIdentifier__c               |
    +--------------------------------+--------------------------------------+

```
