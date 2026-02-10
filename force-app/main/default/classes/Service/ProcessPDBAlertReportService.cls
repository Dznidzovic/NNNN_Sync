/**
 *********************************************************
 * Apex Class Name    : ProcessPDBAlertReportService
 * Created Date       : 03-19-2025
 * @description       : Handles importing NIPR Licensing Report data into Salesforce.
 *                      This class processes the NIPR PDB Alerts API Response which is deserialized into LicensingReportDTO class and maps that data into Salesforce objects
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Dev4Clouds          Initial Version
 * 1.1   12-25-2025   Dev4Clouds          Renamed from ImportNIPRDataToSalesforceService
 *********************************************************
 **/
public with sharing class ProcessPDBAlertReportService {
    // Apex Object containing all the data returned by NIPR API and deserialized to LicensingReportDTO class
    LicensingReportDTO.LicensingReport licensingReport;
    // Store values in a map that will be used to easily retreive specific address for corresponding producer
    private Map<String, LicensingReportDTO.Address> niprAddressesByKeys;
    // Store values in a a map that will be used if License records from NIPR have an existing NPN__c value in Salesforce database
    private Map<String, String> producerIdsByNpns = new Map<String, String>();
    // Store values in a map that will be used to easily retrieve existing Licenses by Entity NPN
    private Map<String, List<d4c_License__c>> existingLicensesByEntity = new Map<String, List<d4c_License__c>>();
    // Store values in a map that will be used to easily retrieve existing Carrier Appointments by Entity NPN
    private Map<String, List<d4c_CarrierAppointment__c>> existingCarrierAppointmentsByEntity = new Map<String, List<d4c_CarrierAppointment__c>>();
    // Store values in a map that will be used to easily retrieve existing LOA by a License Number
    private Map<String, List<d4c_LineOfAuthority__c>> existingLOAByLicense = new Map<String, List<d4c_LineOfAuthority__c>>();
    // Store main nipr entity Identifier (Agencies can have multiple identifiers but NPN is main one) by Refs (Keys) from PDB Alert
    private Map<String, String> identifiersByKeyReferences = new Map<String, String>();
    // Stores new or updated producer (agent) records before DML operation.
    private List<d4c_Entity__c> producers = new List<d4c_Entity__c>();
    // Stores new or updated producer communication records (Phone, Email).
    private List<d4c_EntityCommunication__c> producerCommunications = new List<d4c_EntityCommunication__c>();
    // Stores new or updated producer to be upserted to Salesforce
    private List<d4c_EntityAddress__c> producerAddresses = new List<d4c_EntityAddress__c>();
    // Stores new or updated carriers to be upserted to Salesforce
    private List<d4c_Carrier__c> carriers = new List<d4c_Carrier__c>();
    // Stores new or updated licenses to be upserted to Salesforce
    private List<d4c_License__c> licenses = new List<d4c_License__c>();
    // Stores new or updated Lines Of Authority to be upserted to Salesforce
    private List<d4c_LineOfAuthority__c> linesOfAuthority = new List<d4c_LineOfAuthority__c>();
    // Stores new or updated Carrier Appointments to be upserted to Salesforce
    private List<d4c_CarrierAppointment__c> carrierAppointments = new List<d4c_CarrierAppointment__c>();
    // Stores new or updated Lines Of Authority attached to Carrier Appointments to be upserted to SF
    // Stores IDs of producer communication records that need to be deleted.
    private Set<Id> producerCommunicationIdsForDeletion = new Set<Id>();
    // Stores IDs of producerAddress records that need to be deleted.
    private Set<Id> producerAddressIdsForDeletion = new Set<Id>();
    // Stores IDs of Entity License records that need to be deleted;
    private Set<Id> licenseIdsForDeletion = new Set<Id>();
    // Stores IDs of Lines Of Authority records that need to be deleted;
    private Set<Id> licenseLineOfAuthorityIdsForDeletion = new Set<Id>();
    // Stores IDs of Carrier Appointment records that need to be deleted;
    private Set<Id> carrierAppointmentIdsForDeletion = new Set<Id>();
    // Stores Ids of all objects to be deleted in one Set
    private Set<Id> allIdsToDelete = new Set<Id>();
    // Stores IDs of LineOfAuthority attached to Carrier Appointment records that need to be deleted;

    // private property used for logging purposes
    private String CLASS_NAME = 'ProcessPDBAlertReportService';

    /**
     *********************************************************
     * @methodName      : importData
     * @description     : Calls the external API to retrieve the NIPR licensing report,
     *                    processes producers and communication data, and updates data in Salesforce.
     * @param reportDate : The report date of the NIPR data being fetched(Represents data on that given day)
     * @param subscriptionName : The subscription used to retrieve the NIPR data(Subscription holds the npns which data is retreived for)
     *********************************************************
     **/
    public void importData(String reportDate, string subscriptionName) {
        // Used for Logging purposes
        String methodName = 'ImportData';

        // Generate correlation ID for this PDB Alert import transaction
        String correlationId = CorrelationIdUtils.generateCorrelationId('PDB-' + subscriptionName);

        // Log start of import process with searchable subscription name and correlation ID
        Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('PDB Alert Import - ' + subscriptionName),
        'CorrelationId: ' + correlationId + ' | Subscription: ' + subscriptionName + ' | Date: ' + reportDate, null);

        RetrievePDBSpecificReportData reportCallout = new RetrievePDBSpecificReportData();
        LicensingReportDTO reportData = reportCallout.retrieveData(reportDate, subscriptionName);

        if (!reportData.isSuccess) {
            if (reportData.errorType == NIPREnums.PDBAlertError.UNKOWN_ISSUE) {
                Logger.errorWithCritical(CLASS_NAME, methodName,
                    CorrelationIdUtils.formatLogMessage('PDB Alert API Error - ' + subscriptionName),
                    'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
                    ' | Subscription: ' + subscriptionName + ' | Error: ' + reportData.errorType + ' | ' + reportData.errorMessage,
                    null,
                    true);
            } else {
                Logger.error(CLASS_NAME, methodName,
                CorrelationIdUtils.formatLogMessage('PDB Alert Error - ' + subscriptionName + ' - ' + reportData.errorType),
                'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
                ' | Subscription: ' + subscriptionName + ' | Error: ' + reportData.errorMessage,
                null);
            }

            throw new PDBAlertReportException(reportData.errorType.toString() + ': ' + reportData.errorMessage);
        }

        try {
            licensingReport = reportData?.licensingReportProcessResult?.licensingReport;

            // Store values in a map where key is NIPR key identifier for Address details, we use this key to match producer to an address
            niprAddressesByKeys = getNiprAddressesByAddressKey(licensingReport?.addressList);

            // Process producers - agents and agencies
            if (!licensingReport?.producerList?.isEmpty()) {
                processEntitys(licensingReport.producerList);
            }

            // Process carriers
            if (!licensingReport?.carrierList?.isEmpty()) {
                processCarriers(licensingReport.carrierList);
            }

            // Process jurisdiction reports - maps data about Licenses, LOA and Carrier appointments
            if (!licensingReport?.jurisdictionReportList?.isEmpty()) {
                processJurisdictionReports(
                    licensingReport.jurisdictionReportList,
                    licensingReport.eligibleRecordsForDeletion
                );
            }

            // Delete/Upsert all the records
            syncNIPRDataWithSalesforce();

            // Log heap and CPU usage
            // Log completion with subscription context for searchability
            Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('PDB Alert Complete - ' + subscriptionName),
                'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
                ' | Subscription: ' + subscriptionName + ' | Entitys: ' + producers.size() +
                ' | Licenses: ' + licenses.size() + ' | Appointments: ' + carrierAppointments.size(),
                null);

            Logger.commitAsync();
        } catch (Exception e) {
            Logger.errorWithCritical(CLASS_NAME, methodName,
                    CorrelationIdUtils.formatLogMessage('PDB Alert Processing Error - ' + subscriptionName),
                    'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
                    ' | Error Type: ' + NIPREnums.EntityInfoError.UNKOWN_ISSUE + ' | Error Message: ' + e.getMessage(),
                    e.getStackTraceString(),
                    true);
            
            Logger.commitAsync();

            throw new PDBAlertReportException('UNKNOWN_ISSUE' + ': ' + e.getMessage());
        }
    }

    /**
     *********************************************************
     * @methodName      : processEntitys
     * @description     : Processes a list of NIPR producers, retrieves existing related data 
     *                    (communications, addresses, licenses, and carrier appointments),
     *                    and maps each producer into a Salesforce d4c_Entity__c record.
     * @param niprEntitys : List of NIPR producer DTOs to process.
     *********************************************************     
     */
    private void processEntitys(List<LicensingReportDTO.NIPREntity> niprEntitys) {
        Set<String> producerNpns = new Set<String>();

        // Collects unique producer NPNs (National Entity Numbers).
        for (LicensingReportDTO.NIPREntity niprEntity : niprEntitys) {
            // Put producer
            setNIPREntityIdentifierByReferenceKey(niprEntity);

            String producerNPN = niprEntity.mainIdentifier;
            producerNpns.add(producerNPN);
        }

        // Fetch existing producer communication records by producer NPN we will later on need when deciding which licenses we need to delete
        Map<String, List<d4c_EntityCommunication__c>> existingEntityCommsByEntity = getEntityCommunicationsByEntity(producerNpns);

        // Fetch existing producer communication records from Salesforce we will later on need when deciding which licenses we need to delete
        Map<String, List<d4c_EntityAddress__c>> existingEntityAddressesByEntity = getEntityAddressesByEntity(producerNpns);

        // Go through each producr and do all the necessary data mapping from DTOs to Salesforce objects in order to import data into Salesforce
        for (LicensingReportDTO.NIPREntity niprEntity : niprEntitys) {
            String extIdentifier = niprEntity.mainIdentifier;

            d4c_Entity__c producerToUpsert = processEntity(niprEntity, existingEntityCommsByEntity.get(extIdentifier), existingEntityAddressesByEntity.get(extIdentifier));
            
            if (producerToUpsert != null) {
                producers.add(producerToUpsert);
            }
        }
    }

    /**
     ******************************************************B***
     * @methodName      : processCarriers
     * @description     : Processes a list of NIPR carriers and maps them into Salesforce 
     *                    d4c_Carrier__c records.
     * @param niprCarriers : List of NIPR carrier DTOs to process.
     *********************************************************
     */
    private void processCarriers(List<LicensingReportDTO.Organization> niprCarriers) {
        for (LicensingReportDTO.Organization niprCarrier : niprCarriers) {
            // Set entry of carrier CoCode by all nipr key references for that CoCode
            setNIPREntityIdentifierByReferenceKeyForCarriers(niprCarrier);

            d4c_Carrier__c carrier = processCarrier(niprCarrier);

            if (carrier != null) {
                carriers.add(carrier);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processJurisdictionReports
     * @description     : Processes all jurisdiction reports, builds licenses, LOAs, and carrier
     *                    appointments, and determines which records need to be deleted based on differences.
     *                    Uses eligible deletion maps to only query records for producer+state combinations
     *                    that have data in the NIPR payload.
     * @param jurisdictionReports : List of jurisdiction report DTOs from NIPR.
     * @param eligibleRecords : Maps of producer+state combinations that have data in payload.
     *********************************************************
     */
    private void processJurisdictionReports(
        List<LicensingReportDTO.JurisdictionReport> jurisdictionReports,
        LicensingReportDTO.EligibleRecordsForDeletion eligibleRecords
    ) {
        System.debug(eligibleRecords);
        // Query licenses and carrier appointments only for producer+state combinations that have data in the payload
        existingLicensesByEntity = getEligibleLicensesForDeletionByEntitysAndStates(eligibleRecords.eligibleLicenses);
        existingCarrierAppointmentsByEntity = getEligibleCarrierAppointmentsForDeletionByEntitysAndStates(eligibleRecords.eligibleCarrierAppointments);

        System.debug('existingCarrierAppointmentsByEntity');
        for (List<d4c_CarrierAppointment__c> ca : existingCarrierAppointmentsByEntity.values()) {
            System.debug(ca);
        }

        for (LicensingReportDTO.JurisdictionReport jurisdictionReport : jurisdictionReports) {
            // Process individual Jurisdiction Report
            processJurisdictionReport(jurisdictionReport);
        }

        // Get license Unique Identifiers(External Id for licenses) out of all licenses processed in the report so we can later on group LOA by license number so we can find out which LOA to delete
        Set<String> licenseUniqueIdentifiers = new Set<String>();

        for (d4c_License__c lic : licenses) {
            licenseUniqueIdentifiers.add(lic.d4c_UniqueIdentifier__c);
        }

        // Get LOA by License Numbers map
        Map<String, List<d4c_LineOfAuthority__c>> existingLOAByLicense = getLOAByUniqueIdentifier(licenseUniqueIdentifiers);

        // Get Ids of Licenses that are not in the report anymore
        licenseIdsForDeletion = getRecordIdsForDeletion(existingLicensesByEntity, licenses, 'd4c_Entity__r.d4c_NPN__c', 'd4c_UniqueIdentifier__c');

        // Get Ids of Carrier Appointments that are not in the report anymore
        carrierAppointmentIdsForDeletion = getRecordIdsForDeletion(existingCarrierAppointmentsByEntity, carrierAppointments, 'd4c_Entity__r.d4c_NPN__c', 'd4c_UniqueIdentifier__c');

        // Get Ids of LOA that are not in the report anymore
        licenseLineOfAuthorityIdsForDeletion = getRecordIdsForDeletion(existingLOAByLicense, linesOfAuthority, 'd4c_License__r.d4c_UniqueIdentifier__c', 'd4c_UniqueIdentifier__c');
    }

    /**
     *********************************************************
     * @methodName      : processEntity
     * @description     : Processes a single NIPR producer entity (either a Person or Organization),
     *                    maps it into a `d4c_Entity__c` Salesforce record, and also prepares related
     *                    communication and address records. Also identifies which of the existing
     *                    records should be deleted based on what's missing from the current API response.
     * @param niprEntity : The producer entity to process (can be a Person or Organization).
     * @param existingProdComms : Previously existing communication records for the producer.
     * @param existingProdAddr  : Previously existing address records for the producer.
     * @return          : A new or updated `d4c_Entity__c` record for upsert.
     *********************************************************
     */
    private d4c_Entity__c processEntity(LicensingReportDTO.NIPREntity niprEntity, List<d4c_EntityCommunication__c> existingProdComms, List<d4c_EntityAddress__c> existingProdAddr) {
        d4c_Entity__c producer;

        if (niprEntity instanceOf LicensingReportDTO.Person) {
            LicensingReportDTO.Person agentEntity = (LicensingReportDTO.Person) niprEntity;

            producer = createEntityRecord(agentEntity);

            // Process person communication record from nipr (Every person has at most one person and one business communication record)
            processEntityCommunication(agentEntity.personCommunication, agentEntity.mainIdentifier);
            // Process Business communication record from nipr (Every person at most one person and one business communication record)
            processEntityCommunication(agentEntity.businessCommunication, agentEntity.mainIdentifier);
        } else {
            LicensingReportDTO.Organization agencyEntity = (LicensingReportDTO.Organization) niprEntity;

            producer = createEntityRecord(agencyEntity);

            // Process person communication record from nipr (Every person has at most one person and one business communication record)
            processEntityCommunication(agencyEntity.organizationCommunication, agencyEntity.mainIdentifier);
        }
        
        // Get all existing Entity Communication record Ids for deletion
        producerCommunicationIdsForDeletion.addAll(getRecordIdsForDeletion(existingProdComms, producerCommunications, 'd4c_UniqueIdentifier__c'));

        // Get all existing Entity Adress record Ids for deletion
        producerAddressIdsForDeletion.addAll(getRecordIdsForDeletion(existingProdAddr, producerAddresses, 'd4c_UniqueIdentifier__c'));

        return producer;
    }

    /**
     *********************************************************
     * @methodName      : processCarrier
     * @description     : Converts a NIPR Organization record representing a carrier into a
     *                    `d4c_Carrier__c` Salesforce record.
     * @param niprCarrier : NIPR Organization DTO representing the carrier.
     * @return           : A new or updated `d4c_Carrier__c` record.
     *********************************************************
     */
    private d4c_Carrier__c processCarrier(LicensingReportDTO.Organization niprCarrier) {
        d4c_Carrier__c carrier = createCarrierRecord(niprCarrier);

        return carrier;
    }

    /**
     * @methodName      : processEntityCommunication
     * @description     : Processes the communication section of a producer record (person, business, or organization).
     *                    Converts phone and email DTOs into `d4c_EntityCommunication__c` records, and address DTOs
     *                    into `d4c_EntityAddress__c` records, appending them to respective instance lists.
     * @param comms     : The communication DTO (can be Person, Business, or Organization).
     * @param producerExtId : External NPN identifier used to relate communications to the producer.
     */
    private void processEntityCommunication(LicensingReportDTO.EntityCommunication comms, String producerExtId) {
        Set<String> emailAndPhoneUniqueIds = new Set<String>();

        // Process all NIPR Phones into Entity Communication Records
        producerCommunications.addAll(processEntityPhoneRecords(comms?.telephoneList, producerExtId));
        // Process all NIPR Emails into Entity Communication Records
        producerCommunications.addAll(processEntityEmailRecords(comms?.emailList, producerExtId));

        // Process NIPR Address records belonging to this Entity Communication
        producerAddresses.addAll(processEntityAddressRecords(comms, producerExtId));
    }

    /**
     *********************************************************
     * @methodName      : processEntityAddressRecords
     * @description     : Extracts and processes address records from the communication DTO.
     *                    Depending on the type of communication (Person, Business, or Organization),
     *                    it maps residential, mailing, physical, and principal addresses into Salesforce.
     * @param comms     : Communication object (Person, Business, or Organization) with address references.
     * @param producerExtId : NPN identifier of the producer.
     * @return          : List of `d4c_EntityAddress__c` records to be created or upserted.
     *********************************************************
     */
    private List<d4c_EntityAddress__c> processEntityAddressRecords(LicensingReportDTO.EntityCommunication comms, String producerExtId) {
        Set<String> addressUniqueIds = new Set<String>();
        List<d4c_EntityAddress__c> prodAddresses = new List<d4c_EntityAddress__c>();

        d4c_EntityAddress__c mailingEntityAddress = processEntityAddress(comms?.mailingAddress, producerExtId, 'Mailing');
        if (mailingEntityAddress != null) {
            prodAddresses.add(mailingEntityAddress);
        }

        if (comms instanceOf LicensingReportDTO.PersonCommunication) {
            LicensingReportDTO.PersonCommunication personComms = (LicensingReportDTO.PersonCommunication) comms;
            d4c_EntityAddress__c residentialEntityAddress = processEntityAddress(personComms?.residentialAddress, producerExtId, 'Residential');
            
            if (residentialEntityAddress != null) {
                prodAddresses.add(residentialEntityAddress);
            }
            
        } else if (comms instanceOf LicensingReportDTO.BusinessCommunication) {
            LicensingReportDTO.BusinessCommunication businessComms = (LicensingReportDTO.BusinessCommunication) comms;
            d4c_EntityAddress__c physicalEntityAddress = processEntityAddress(businessComms?.physicalAddress, producerExtId, 'Physical');

            if (physicalEntityAddress != null) {
                prodAddresses.add(physicalEntityAddress);
            }

        } else if (comms instanceOf LicensingReportDTO.OrganizationCommunication) {
            LicensingReportDTO.OrganizationCommunication orgComms = (LicensingReportDTO.OrganizationCommunication) comms;
            d4c_EntityAddress__c physicalEntityAddress = processEntityAddress(orgComms?.physicalAddress, producerExtId, 'Physical');
            d4c_EntityAddress__c principalEntityAddress = processEntityAddress(orgComms?.principalAddress, producerExtId, 'Principal');

            if (physicalEntityAddress != null) {
                prodAddresses.add(physicalEntityAddress);
            }

            if (principalEntityAddress != null) {
                prodAddresses.add(principalEntityAddress);
            }
        }

        return prodAddresses;
        
    }

    /**
     *********************************************************
     * @methodName      : processEntityPhoneRecords
     * @description     : Converts a list of telephone DTOs into Salesforce `d4c_EntityCommunication__c` records
     *                    of type phone, assigning them to the specified producer.
     * @param telephoneList : List of telephone DTOs from NIPR.
     * @param producerExtId : NPN identifier of the producer.
     * @return           : List of new phone communication records.
     *********************************************************
     */
    private List<d4c_EntityCommunication__c> processEntityPhoneRecords(List<LicensingReportDTO.Telephone> telephoneList, String producerExtId) {
        List<d4c_EntityCommunication__c> producerPhones = new List<d4c_EntityCommunication__c>();

        // Process phone records and store them in a map to track uniqueness.
        if (telephoneList != null && !telephoneList.isEmpty()) {
            for (LicensingReportDTO.Telephone phone : telephoneList) {
                String formattedPhoneNumber = StringUtils.formatNIPRPDBAlertNumber(phone?.phoneNumber);
                
                String phoneKey = formattedPhoneNumber + (phone.typeCode != null ? phone.typeCode : '') + producerExtId;

                d4c_EntityCommunication__c phoneEntityCommunication = createPhoneCommunicationRecord(phoneKey, phone);

                phoneEntityCommunication.d4c_Entity__r = new d4c_Entity__c (
                    d4c_NPN__c = producerExtId
                );
                
                producerPhones.add(phoneEntityCommunication);
            }
        }

        return producerPhones;
    }

    /**
     *********************************************************
     * @methodName      : processEntityEmailRecords
     * @description     : Converts a list of email DTOs into Salesforce `d4c_EntityCommunication__c` records
     *                    of type email, assigning them to the specified producer.
     * @param emailList     : List of email DTOs from NIPR.
     * @param producerExtId : NPN identifier of the producer.
     * @return              : List of new email communication records.
     *********************************************************
     */
    private List<d4c_EntityCommunication__c> processEntityEmailRecords(List<LicensingReportDTO.Email> emailList, String producerExtId) {
        List<d4c_EntityCommunication__c> producerEmails = new List<d4c_EntityCommunication__c>();

        // Process email records and store them in a map to track uniqueness.
        if (emailList != null && !emailList.isEmpty()) {
            for (LicensingReportDTO.Email email : emailList) {
                String emailKey = email.emailAddress + (email.typeCode != null ? email.typeCode : '') + producerExtId;

                d4c_EntityCommunication__c emailEntityCommunication = createEmailCommunicationRecord(emailKey, email);

                if (emailEntityCommunication != null) {
                    emailEntityCommunication.d4c_Entity__r = new d4c_Entity__c (
                    d4c_NPN__c = producerExtId
                );

                    producerEmails.add(emailEntityCommunication);
                }
            }
        }

        return producerEmails;
    }

    /**
     *********************************************************
     * @methodName      : processEntityAddress
     * @description     : Maps a single EntityAddress DTO (reference + asOfDate) to a
     *                    `d4c_EntityAddress__c` Salesforce record using the global address map.
     * @param address        : The EntityAddress DTO with reference key and asOfDate.
     * @param producerExtId  : NPN identifier of the producer.
     * @param addressType    : Type of address (Mailing, Residential, Physical, Principal).
     * @return               : Populated producer address record.
     *********************************************************
     */
    private d4c_EntityAddress__c processEntityAddress(LicensingReportDTO.EntityAddress address, String producerExtId, String addressType) {
        d4c_EntityAddress__c producerAddress;
        d4c_Entity__c producerForExtId =  new d4c_Entity__c(
                d4c_NPN__c = producerExtId
        );

        if (address != null) {

            producerAddress = createEntityAddressRecord(address);

            producerAddress.d4c_Entity__r = producerForExtId;
            producerAddress.d4c_UniqueIdentifier__c = address.addressReferences + addressType + producerExtId;
            producerAddress.d4c_AddressType__c = addressType;
        }

        return producerAddress;
    }

    /**
     *********************************************************
     * @methodName      : processJurisdictionReport
     * @description     : Processes a single jurisdiction report by iterating through all
     *                    contained items and handling licenses and appointments tied to the
     *                    associated producer or carrier references.
     * @param jurisdictionReport : DTO object representing a single jurisdiction report.
     *********************************************************
     */
    private void processJurisdictionReport(LicensingReportDTO.JurisdictionReport jurisdictionReport) {
        if (jurisdictionReport?.jurisdictionReportItemList != null) {
            for (LicensingReportDTO.JurisdictionReportItem item : jurisdictionReport.jurisdictionReportItemList) {
                processJurisdictionReportItem(item, jurisdictionReport.personReference, jurisdictionReport.organizationReference);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processJurisdictionReportItem
     * @description     : Processes a single jurisdiction report item, extracting both
     *                    licenses and carrier appointments related to the given producer or agency.
     * @param item               : Jurisdiction report item DTO.
     * @param personReference    : NIPR reference key for the individual producer.
     * @param organizationReference : NIPR reference key for the organization.
     *********************************************************
     */
    private void processJurisdictionReportItem(LicensingReportDTO.JurisdictionReportItem item, String personReference, String organizationReference) {
       processLicenses(item, personReference, organizationReference);
       processCarrierAppointments(item, personReference, OrganizationReference);
    }

    /**
     *********************************************************
     * @methodName      : processLicenses
     * @description     : Creates and stores license records for a given jurisdiction report item.
     *                    Maps licenses to their respective producers using references.
     * @param item                : Jurisdiction report item containing license data.
     * @param personReference     : Reference to the person producer (if applicable).
     * @param organizationReference : Reference to the organization producer (if applicable).
     *********************************************************
     */
    private void processLicenses(LicensingReportDTO.JurisdictionReportItem item, String personReference, String organizationReference) {
        List<d4c_License__c> processedLicenses = new List<d4c_License__c>();
        
        if (item == null || item.licensee == null) {
            return;
        }

        if (!item.licensee.insuranceLicenses.isEmpty()) {
            for (LicensingReportDTO.InsuranceLicense insuranceLicense : item.licensee.insuranceLicenses) {
                Set<String> licenseUniqueIdentifiers = new Set<String>();

                // Create License record with basic info from InsuranceLicense node
                // This record will be cloned becaause there is a possibility of multiple License records creation base on how many Licensees it refers to
                d4c_License__c baseLicense = createLicenseRecord(insuranceLicense);


                String licenseUniqueId = baseLicense.d4c_LicenseNumber__c + StringUtils.safeParseNullString(baseLicense.d4c_StateOrProvinceCode__c) + StringUtils.safeParseNullString(baseLicense.d4c_LicenseClassCode__c);

                baseLicense.d4c_UniqueIdentifier__c = licenseUniqueId;

                if (baseLicense == null) {
                    return;
                }

                List<String> licenseeRefs = item?.licensee?.licenseeReference;

                // Each InsuranceLicense record in the API response matches to a Licensee by either a LicenseeRefs list of references or Person/Organization node provided as the top level element in Juristiction Report Item Node
                if (licenseeRefs == null || licenseeRefs.isEmpty()) {
                    // Fall back to person/organization reference
                    if (personReference != null) {
                        d4c_License__c clonedLicense = cloneLicenseWithEntity(baseLicense, personReference);

                        if (clonedLicense.d4c_Entity__r.d4c_NPN__c != null) {
                            processedLicenses.add(clonedLicense);
                            // Add the License number to the global list as we need it later on to determine which licenses to delete
                            licenseUniqueIdentifiers.add(clonedLicense.d4c_UniqueIdentifier__c);
                        }
                    }
                    if (organizationReference != null) {
                        d4c_License__c clonedLicense = cloneLicenseWithEntity(baseLicense, organizationReference);

                        if (clonedLicense.d4c_Entity__r.d4c_NPN__c != null) {
                            processedLicenses.add(clonedLicense);

                            // Add the License number to the global list as we need it later on to determine which licenses to delete
                            licenseUniqueIdentifiers.add(clonedLicense.d4c_UniqueIdentifier__c);
                        }
                    }
                } else {
                    for (String licenseeRef : licenseeRefs) {
                        d4c_License__c clonedLicense = cloneLicenseWithEntity(baseLicense, licenseeRef);

                        if (clonedLicense.d4c_Entity__r.d4c_NPN__c != null) {
                            processedLicenses.add(clonedLicense);

                            // Add the License number to the global list as we need it later on to determine which licenses to delete
                            licenseUniqueIdentifiers.add(clonedLicense.d4c_UniqueIdentifier__c);
                        }
                    }
                }

                if (!licenseUniqueIdentifiers.isEmpty()) {
                    linesOfAuthority.addAll(createLineOfAuthorityRecords(insuranceLicense, licenseUniqueIdentifiers));
                }
            }
        }

        licenses.addAll(processedLicenses);
    }

    /**
     *********************************************************
     * @methodName      : processCarrierAppointments
     * @description     : Creates and stores carrier appointment records for the jurisdiction report item.
     *                    Assigns appointments to producers and carriers based on references.
     * @param item               : Jurisdiction report item containing appointment data.
     * @param personReference    : NIPR person reference key.
     * @param organizationReference : NIPR organization reference key.
     *********************************************************
     */
    private void processCarrierAppointments(LicensingReportDTO.JurisdictionReportItem item, String personReference, String organizationReference) {
        List<d4c_CarrierAppointment__c> carrierApps = new List<d4c_CarrierAppointment__c>();
        List<LicensingReportDTO.InsuranceAppointment> appointments = item?.licensee?.insuranceAppointments;

        if (appointments != null && !appointments.isEmpty()) {
            for (LicensingReportDTO.InsuranceAppointment niprApp : appointments) {

                // Create carrier appointment record with basic info found in the InsuranceAppointment DTO class
                d4c_CarrierAppointment__c app = createCarrierAppointment(niprApp);

                if (app != null) {
                    // Get producer(agent/agency) npn so we can match it to producer parent record. Uses nipr key(reference) stored in the map to retrieve the producer NPN
                    String producerNpn = identifiersByKeyReferences.get(niprApp.licenseeReferences);
                    // Get the combination of carrier CoCode and FEIN because carrier unique id will always be that
                    List<String> coCodeAndFein = identifiersByKeyReferences.get(niprApp.insurerReferences).split('-');
  
                    // Get carrier appointment CoCode so we can match it to Carrier parent record. Uses nipr key(reference) stored in the map to retrieve the Carrier CoCode
                    String carrierCoCode = coCodeAndFein[0];
                    // Get carrier FEIN to construct unique id
                    String carrierFein = coCodeAndFein.size() > 1 ? coCodeAndFein[1] : '';

                    String carrierUniqueIdentifier = StringUtils.safeParseNullString(carrierCoCode + StringUtils.safeParseNullString(carrierFein));

                    // Construct a unique identifier (external id) for a carrier appointment record. This data is not unique enough and child LOA data will also be used later on in the code
                    String carrierAppIdentifier = producerNpn + carrierUniqueIdentifier + app.d4c_StateOrProvinceCode__c + app.d4c_StatusCode__c;

                    app.d4c_UniqueIdentifier__c = carrierAppIdentifier;

                    // Use indexing to match carrier appointment record to parent producer and carrier records without having to know their Ids
                    app.d4c_Entity__r = new d4c_Entity__c(
                        d4c_NPN__c = producerNpn
                    );

                    app.d4c_Carrier__r = new d4c_Carrier__c(
                        d4c_UniqueIdentifier__c = carrierUniqueIdentifier
                    );

                    // Do not create CarrierAppointment records if NPN or carrier unique identifier are not found since we can not insert carrier appointment record into the database without it
                    if (app.d4c_Entity__r.d4c_NPN__c != null && app.d4c_Carrier__r.d4c_UniqueIdentifier__c != null) {

                        List<LicensingReportDTO.LineOfAuthority> niprCPLOAList = niprApp.linesOfAuthority;

                        // Populate LOA fields directly on carrier appointment using FIRST LOA only
                        if (niprCPLOAList != null && !niprCPLOAList.isEmpty()) {
                            // Take only the first LOA from the list
                            LicensingReportDTO.LineOfAuthority firstLoa = niprCPLOAList[0];

                            // Set LOA fields directly on carrier appointment
                            app.d4c_LineOfAuthorityCode__c = StringUtils.truncateField(firstLoa.lineOfAuthorityCode, 50);
                            app.d4c_LineOfAuthorityDescription__c = StringUtils.truncateField(firstLoa.lineOfAuthorityDescription, 255);
                            app.d4c_RenewalDate__c = DateUtils.safeParseDateFromString(firstLoa.renewalDate);

                            // Construct LOA unique identifier component
                            String loaUniqueId = producerNpn + carrierAppIdentifier + StringUtils.safeParseFromDate(app.d4c_RenewalDate__c) + StringUtils.safeParseNullString(app.d4c_LineOfAuthorityCode__c);

                            // Update carrier appointment unique identifier to include LOA info
                            carrierAppIdentifier += loaUniqueId;
                        }

                        app.d4c_UniqueIdentifier__c = carrierAppIdentifier;

                        carrierApps.add(app);
                    }
                }
            }
        }

        carrierAppointments.addAll(carrierApps);
    }

    /**
     *********************************************************
     * @methodName      : createEntityRecord
     * @description     : Creates a new producer (Agent) record from NIPR API response.
     * @param niprAgent : The agent data received from NIPR API.
     * @return          : A populated d4c_Entity__c record.
     *********************************************************
     */
    private d4c_Entity__c createEntityRecord(LicensingReportDTO.Person niprAgent) {
        d4c_Entity__c agent = new d4c_Entity__c();

        agent.d4c_NPN__c = niprAgent.mainIdentifier;
        agent.d4c_Type__c = 'Agent';

        // This will only occur when the person node in NIPR holds no actual info and we flag it as isExisting = true
        // NIPR uses these nodes to only match child records(Licenses for example) to the person record and we do not want to empty out the data in SF if we continue the mapping
        if (niprAgent.isExisting) {
            return agent;
        }

        agent.d4c_BirthDate__c = DateUtils.safeParseDateFromString(niprAgent.birthDate);

        LicensingReportDTO.PersonName agentName = niprAgent?.personName;

        if (agentName != null) {
            agent.d4c_NameTypeCode__c = agentName.typeCode;
            agent.d4c_NameSuffix__c = agentName.nameSuffix;
            agent.d4c_FullName__c = StringUtils.truncateField(agentName.fullName, 255);
            agent.d4c_SurName__c = agentName.surName;
            agent.d4c_MiddleName__c = agentName.middleName;
            agent.d4c_GivenName__c = agentName.givenName;
            agent.d4c_OtherGivenName__c = agentName.otherGivenName;
        }
    
        agent.d4c_NPNStatus__c = 'Active';
        agent.d4c_LastNIPRSync__c = Datetime.now();

        return agent;
    }

    /**
     *********************************************************
     * @methodName      : createEntityRecord
     * @description     : Creates a new producer (Agency) record from NIPR API response.
     * @param niprAgency : The agent data received from NIPR API.
     * @return          : A populated d4c_Entity__c record.
     *********************************************************
     **/
    private d4c_Entity__c createEntityRecord(LicensingReportDTO.Organization niprAgency) {
        d4c_Entity__c agency = new d4c_Entity__c();

        agency.d4c_NPN__c = niprAgency.mainIdentifier;
        agency.d4c_Type__c = 'Agency';

        // This will only occur when the Organization node in NIPR holds no actual info and we flag it as isExisting = true
        // NIPR uses these nodes to only match child records(Licenses for example) to the person record and we do not want to empty out the data in SF if we continue the mapping
        if (niprAgency.isExisting) {
            return agency;
        }

        String feinId;
        String branchId;

        for (LicensingReportDTO.ExternalIdentifier identifier : niprAgency.externalIdentifierList) {
            if (identifier.typeCode == 'FEINId') {
                feinId = identifier.Id;
            } else if (identifier.typeCode == 'BranchID') {
                branchId = identifier.id;
            }
        }

        agency.d4c_FEIN__c = StringUtils.truncateField(feinId, 9);
        agency.d4c_BranchId__c = branchId;

        LicensingReportDTO.OrganizationName agencyName = niprAgency.organizationNameList[0];

        if (agencyName != null) {
            agency.d4c_NameTypeCode__c = agencyName.typeCode;
            agency.d4c_FullName__c = StringUtils.truncateField(agencyName.fullName, 255);
        }
    
        agency.d4c_NPNStatus__c = 'Active';
        agency.d4c_LastNIPRSync__c = Datetime.now();

        return agency;
    }

    /**
     *********************************************************
     * @methodName      : createCarrierRecord
     * @description     : Converts a NIPR Organization record into a Carrier record in Salesforce.
     *                    Maps key identity fields like CoCode and Name.
     * @param niprCarrier : The DTO Organization object representing the carrier.
     * @return           : A populated d4c_Carrier__c record.
     *********************************************************
     */
    private d4c_Carrier__c createCarrierRecord(LicensingReportDTO.Organization niprCarrier) {
        d4c_Carrier__c carrier = new d4c_Carrier__c();

        carrier.d4c_CoCode__c = niprCarrier.mainIdentifier;

        for (LicensingReportDTO.ExternalIdentifier identifier : niprCarrier.externalIdentifierList) {
            if (identifier.typeCode == 'FEINId') {
                carrier.d4c_FEIN__c = StringUtils.truncateField(identifier.Id, 9);
            } 
        }

        carrier.d4c_UniqueIdentifier__c = StringUtils.safeParseNullString(carrier.d4c_CoCode__c) + StringUtils.safeParseNullString(carrier.d4c_FEIN__c);

        // This will only occur when the carrier node in NIPR holds no actual info and we flag it as isExisting = true
        // NIPR uses these nodes to only match child records(Licenses for example) to the person record and we do not want to empty out the data in SF if we continue the mapping
        if (niprCarrier.isExisting) {
            return carrier;
        }

        LicensingReportDTO.OrganizationName carrierName = niprCarrier.organizationNameList[0];
        carrier.d4c_FullName__c = StringUtils.truncateField(carrierName.fullName, 255);
        carrier.Name = StringUtils.truncateField(carrierName.fullName, 80);

        return carrier;
    }

    /**
     *********************************************************
     * @methodName      : createEntityAddress
     * @description     : Creates a Entity Address record based on provided producer Address object(only reference and as of date) and based on global map of all address info
     * @param niprEntityAddress : Unique identifier for the phone record.
     * @return      : A new d4c_EntityAddress__c record.
     *********************************************************
     **/
    private d4c_EntityAddress__c createEntityAddressRecord(LicensingReportDTO.EntityAddress niprEntityAddress) {
        d4c_EntityAddress__c producerAddress = new d4c_EntityAddress__c();

        if (niprEntityAddress != null) {
            LicensingReportDTO.Address niprAddress = niprAddressesByKeys.get(niprEntityAddress.addressReferences);

            if (niprAddress != null) {
                producerAddress.d4c_AsOfDate__c = DateUtils.safeParseDateFromString(niprEntityAddress.asOfDate);
                producerAddress.d4c_AddressLineOne__c = niprAddress.lineOne;
                producerAddress.d4c_AddressLineTwo__c = niprAddress.lineTwo;
                producerAddress.d4c_AddressLineThree__c = niprAddress.lineThree;
                producerAddress.d4c_City__c = niprAddress.cityName;
                producerAddress.d4c_CountryCode__c = niprAddress.countryCode;
                producerAddress.d4c_PostalCode__c = niprAddress.postalCode;
                producerAddress.d4c_State__c = niprAddress.stateOrProvinceCode;
            }
        }

        return producerAddress;
    }

    /**
     *********************************************************
     * @methodName      : createPhoneCommunicationRecord
     * @description     : Creates a communication record for a phone number.
     * @param key : Unique identifier for the phone record.
     * @param phone : The phone details from the API response.
     * @return      : A new d4c_EntityCommunication__c record.
     *********************************************************
     **/
    private d4c_EntityCommunication__c createPhoneCommunicationRecord(String key, LicensingReportDTO.Telephone phone) {
        d4c_EntityCommunication__c prodComm = new d4c_EntityCommunication__c();

        prodComm.d4c_UniqueIdentifier__c = key;
        prodComm.d4c_PhoneType__c = phone.typeCode;
        prodComm.d4c_PhoneNumber__c = StringUtils.formatNIPRPDBAlertNumber(phone?.phoneNumber);

        return prodComm;
    }

    /**
     *********************************************************
     * @methodName      : createEmailCommunicationRecord
     * @description     : Creates a communication record for an email.
     * @param key : Unique identifier for the email record.
     * @param email : The email details from the API response.
     * @return      : A new d4c_EntityCommunication__c record.
     *********************************************************
     **/
    private d4c_EntityCommunication__c createEmailCommunicationRecord(String key, LicensingReportDTO.Email email) {
        if(!StringUtils.isValidEmail(email.emailAddress)) {
            return null;
        }

        d4c_EntityCommunication__c prodComm = new d4c_EntityCommunication__c();

        prodComm.d4c_UniqueIdentifier__c = key;
        prodComm.d4c_EmailType__c = email.typeCode;
        prodComm.d4c_EmailAddress__c = email.emailAddress;

        return prodComm;
    }

    /**
     *********************************************************
     * @methodName      : cloneLicenseWithEntity
     * @description     : Creates a deep copy of a base license and assigns the producer reference to it.
     * @param baseLicense : The license to clone.
     * @param licenseeRef : Entity reference key used to link the license to the producer.
     * @return            : Cloned license with producer relationship assigned.
     *********************************************************
     */
    private d4c_License__c cloneLicenseWithEntity(d4c_License__c baseLicense, String licenseeRef) {
        d4c_License__c cloned = baseLicense.clone(false, true, false, false);
        String producerNPN;

        cloned.d4c_Entity__r = new d4c_Entity__c(
            d4c_NPN__c = identifiersByKeyReferences.get(licenseeRef)
        );

        return cloned;
    }

    /**
     *********************************************************
     * @methodName      : createLicenseRecord
     * @description     : Constructs a License record from a NIPR InsuranceLicense DTO, 
     *                    including metadata and Continuing Education (CE) details if present.
     * @param insuranceLicense : The InsuranceLicense DTO from the NIPR API response.
     * @return          : A populated d4c_License__c record, or null if input is invalid.
     *********************************************************
     */
    private d4c_License__c createLicenseRecord(LicensingReportDTO.InsuranceLicense insuranceLicense){
        d4c_License__c license;      

        LicensingReportDTO.License niprLicense = insuranceLicense?.license;
        LicensingReportDTO.ContinuingEducation niprCE = niprLicense?.continuingEducation;

        List<LicensingReportDTO.LineOfAuthority> niprLOAs = insuranceLicense?.lineOfAuthorityList;

        if (insuranceLicense != null) {
            license = new d4c_License__c();

            license.d4c_ResidentLicenseIndicator__c = insuranceLicense.residentLicenseIndicator == null ? false : insuranceLicense.residentLicenseIndicator;
            license.d4c_QualifyingInsuranceLicenseIndicator__c = insuranceLicense.qualifyingInsuranceLicenseIndicator == null ? false: insuranceLicense.qualifyingInsuranceLicenseIndicator;
            license.d4c_TypeCode__c = insuranceLicense.typeCode;

            if (niprLicense != null) {
                license.d4c_LicenseNumber__c = niprLicense.licenseNumberId;

                license.d4c_StartDate__c = DateUtils.safeParseDateFromString(niprLicense.startDate);
                license.d4c_EndDate__c = DateUtils.safeParseDateFromString(niprLicense.endDate);
                license.d4c_StatusCode__c = niprLicense.statusCode;
                license.d4c_StatusDescription__c = StringUtils.truncateField(niprLicense.statusDescription, 255);
                license.d4c_IssueDate__c = DateUtils.safeParseDateFromString(niprLicense.issueDate);
                license.d4c_LicenseClassCode__c = niprLicense.licenseClassCode;
                license.d4c_LicenseClassDescription__c = StringUtils.truncateField(niprLicense.licenseClassDescription, 255);
                license.d4c_StateOrProvinceCode__c = niprLicense.stateOrProvinceCode;
                license.d4c_StateOrProvinceName__c = niprLicense.stateOrProvinceName;
                license.d4c_AsOfDate__c = DateUtils.safeParseDateFromString(niprLicense.asOfDate);

                if (niprCE != null) {
                    license.d4c_CEStateOrProvince_Code__c = niprCE.stateOrProvinceCode;
                    license.d4c_CEStatusDescription__c = StringUtils.truncateField(niprCE.statusDescription, 255);
                    license.d4c_CEStartDate__c = DateUtils.safeParseDateFromString(niprCE.startDate);
                    license.d4c_CEEndDate__c = DateUtils.safeParseDateFromString(niprCE.endDate);
                    license.d4c_PeriodDuration__c = !String.isBlank(niprCE.periodDuration) ? Integer.valueOf(niprCE.periodDuration) : null;
                    license.d4c_CEUnitsRequiredMeasure__c = niprCE.unitsRequiredMeasure;
                }

            }
        }
        
        return license;
    }

    /**
     *********************************************************
     * @methodName      : createLineOfAuthorityRecords
     * @description     : Creates a list of Line of Authority records from a license,
     *                    assigning each to a corresponding license number.
     * @param insuranceLicense : License DTO with LOAs.
     * @param licenseUniqueIdentifiers   : License numbers to which LOAs belong.
     * @return                : List of `d4c_LineOfAuthority__c` records.
     *********************************************************
     */
private List<d4c_LineOfAuthority__c> createLineOfAuthorityRecords(LicensingReportDTO.InsuranceLicense insuranceLicense, Set<String> licenseUniqueIdentifiers) {
        List<d4c_LineOfAuthority__c> lineOfAuthorityRecords = new List<d4c_LineOfAuthority__c>();
        List<LicensingReportDTO.LineOfAuthority> niprLOAList = insuranceLicense?.lineOfAuthorityList;
        
        if (niprLOAList != null && !niprLOAList.isEmpty()) {
            for (LicensingReportDTO.LineOfAuthority niprLOA : niprLOAList) {
                for (String licenseUniqueId : licenseUniqueIdentifiers) {
                    d4c_LineOfAuthority__c loa = createLineOfAuthority(niprLOA, licenseUniqueId);

                    if (loa != null) {
                        lineOfAuthorityRecords.add(loa);
                    }
                }
            }
        }

        return lineOfAuthorityRecords;
    }

    /**
     *********************************************************
     * @methodName      : createLineOfAuthority
     * @description     : Creates a `d4c_LineOfAuthority__c` record and assigns it to a license.
     *                    Includes full metadata and CE section if present.
     * @param niprLOA       : Line of Authority DTO from NIPR.
     * @param licenseUniqueIdentifier : License UniqueIdentifier this LOA is related to.
     * @return              : A populated Line of Authority record.
     *********************************************************
     */
    private d4c_LineOfAuthority__c createLineOfAuthority(LicensingReportDTO.LineOfAuthority niprLOA, String licenseUniqueIdentifier) {
        d4c_LineOfAuthority__c loa;

        if (niprLOA != null) {
            loa = new d4c_LineOfAuthority__c();
            
            loa.d4c_UniqueIdentifier__c = niprLOA.lineOfAuthorityCode + niprLOA.stateOrProvinceCode + StringUtils.safeParseNullString(niprLOA.issueDate) + licenseUniqueIdentifier;
            loa.d4c_License__r = new d4c_License__c(d4c_UniqueIdentifier__c = licenseUniqueIdentifier);

            loa.d4c_IssueDate__c = DateUtils.safeParseDateFromString(niprLOA.issueDate);
            loa.d4c_RenewalDate__c = DateUtils.safeParseDateFromString(niprLOA.renewalDate);
            loa.d4c_StateOrProvinceCode__c = niprLOA.stateOrProvinceCode;
            loa.d4c_StateOrProvinceName__c = niprLOA.stateOrProvinceName;
            loa.d4c_LineOfAuthorityCode__c = niprLOA.lineOfAuthorityCode;
            loa.d4c_LineOfAuthorityDescription__c = StringUtils.truncateField(niprLOA.lineOfAuthorityDescription, 255);
            loa.d4c_StatusCode__c = niprLOA.statusCode;
            loa.d4c_StatusDescription__c = niprLOA.statusDescription;
            loa.d4c_StatusReasonDescription__c = StringUTils.truncateField(niprLOA.statusReasonDescription, 255);
            loa.d4c_StatusReasonCode__c = niprLOA.statusReasonCode;
            loa.d4c_StartDate__c = DateUtils.safeParseDateFromString(niprLOA.startDate);

            if (niprLOA.continuingEducation != null) {
                loa.d4c_CEStateOrProvinceCode__c = niprLOA.continuingEducation.stateOrProvinceCode;
                loa.d4c_CEStatusCode__c = niprLOA.continuingEducation.statusCode;
                loa.d4c_CEStatusDescription__c = StringUtils.truncateField(niprLOA.continuingEducation.statusDescription, 255);
                loa.d4c_CEEndDate__c = DateUtils.safeParseDateFromString(niprLOA.continuingEducation.endDate);
                loa.d4c_CEUnitsRequiredMeasure__c = niprLOA.continuingEducation.unitsRequiredMeasure;
                loa.d4c_CEUnitsRemainingMeasure__c = niprLOA.continuingEducation.unitsRemainingMeasure;
                loa.d4c_CEAsOfDate__c = DateUtils.safeParseDateFromString(niprLOA.continuingEducation.asOfDate);
            }
        }

        return loa;
    }

    /**
     *********************************************************
     * @methodName      : createLineOfAuthority
     * @description     : Creates a simplified Line of Authority record used for
     *                    carrier appointments (LOA attached to a carrier appointment).
     * @param niprLOA   : Line of Authority DTO from NIPR.
     * @return          : A partial `d4c_LineOfAuthority__c` record (used internally).
     *********************************************************
     */

    /**
     *********************************************************
     * @methodName      : createCarrierAppointment
     * @description     : Creates a `d4c_CarrierAppointment__c` record from a NIPR InsuranceAppointment DTO.
     *                    Maps key fields including status, state, dates, and reason codes.
     * @param niprAppointment : DTO object representing a carrier appointment.
     * @return                : A populated d4c_CarrierAppointment__c record.
     *********************************************************
     */
    private d4c_CarrierAppointment__c createCarrierAppointment(LicensingReportDTO.InsuranceAppointment niprAppointment) {
        d4c_CarrierAppointment__c carrierApp;

        if (niprAppointment != null) {
            carrierApp = new d4c_CarrierAppointment__c();

            carrierApp.d4c_StateOrProvinceCode__c = niprAppointment.stateOrProvinceCode;
            carrierApp.d4c_StatusCode__c = niprAppointment.statusCode;
            carrierApp.d4c_StatusDescription__c = StringUtils.truncateField(niprAppointment.statusDescription, 255);
            carrierApp.d4c_StatusReasonCode__c = niprAppointment.statusReasonCode;
            carrierApp.d4c_StatusReasonDescription__c = StringUtils.truncateField(niprAppointment.statusReasonDescription, 255);
            carrierApp.d4c_AppointmentEffectiveDate__c = DateUtils.safeParseDateFromString(niprAppointment.appointmentEffectiveDate);
            carrierApp.d4c_TerminationEffectiveDate__c = DateUtils.safeParseDateFromString(niprAppointment.terminationEffectiveDate);
            carrierapp.d4c_AsOfDate__c = DateUtils.safeParseDateFromString(niprAppointment.asOfDate);
        }

        return carrierApp;
    }

    /**
     *********************************************************
     * @methodName      : getRecordIdsForDeletion
     * @description     : Given two lists of SObjects (existing and new), this method returns a set of Ids
     *                    for records in the existing list whose unique field values do not exist in the new list.
     * @param existingRecords   : List of existing records (from DB).
     * @param newRecords        : List of new records (from API).
     * @param uniqueFieldApiName : API name of the unique string field used to compare (e.g. 'd4c_UniqueIdentifier__c').
     * @return                  : Set of Ids to delete from existing records.
     *********************************************************
     */
    private Set<Id> getRecordIdsForDeletion(List<SObject> existingRecords, List<SObject> newRecords, String uniqueFieldApiName) {
        Set<String> newUniqueIdentifiers = new Set<String>();
        Set<Id> recordIdsForDeletion = new Set<Id>();

        if ((existingRecords == null || existingRecords.isEmpty()) || String.isBlank(uniqueFieldApiName)) {
            return recordIdsForDeletion;
        }

        for (SObject record : newRecords) {
            String val = String.valueOf(record.get(uniqueFieldApiName));

            if (val != null) {
                newUniqueIdentifiers.add(val);
            }
        }

        for (SObject record : existingRecords) {
            String val = String.valueOf(record.get(uniqueFieldApiName));

            if (val != null && !newUniqueIdentifiers.contains(val)) {
                recordIdsForDeletion.add(record.Id);
            }
        }

        return recordIdsForDeletion;
    }

    /**
     *********************************************************
     * @methodName      : getRecordIdsForDeletion
     * @description     : Dynamically compares existing SObjects grouped by a key (like NPN or License Number)
     *                    with new records and identifies which existing ones should be deleted based on unique identifiers.
     * @param existingGroupedRecords : Map of existing SObjects grouped by a common key (e.g., NPN, License Number).
     * @param newRecords             : Flat list of new SObjects from API.
     * @param relationshipFieldPath : Dot notation path to reach the grouping key (e.g., 'd4c_Entity__r.d4c_NPN__c').
     * @param uniqueFieldApiName    : Field to compare uniqueness on (e.g., 'd4c_UniqueIdentifier__c').
     * @return                      : Set of Ids to delete from existing records.
     **********************************************************
     */
    private Set<Id> getRecordIdsForDeletion(Map<String, List<SObject>> existingGroupedRecords, List<SObject> newRecords, String relationshipFieldPath, String uniqueFieldApiName) {
        Map<String, Set<String>> newValuesByGroup = new Map<String, Set<String>>();
        Set<Id> recordIdsForDeletion = new Set<Id>();

        if (String.isBlank(relationshipFieldPath)) {
            return recordIdsForDeletion;
        }

        List<String> fieldPathParts = relationshipFieldPath.split('\\.');

        // Loop through new records and set a map which for each parent external id (Eg. lciense number, producer npn etc...) holds the external Ids of all the records attached to that parent record
        for (SObject newRec : newRecords) {
            SObject parentObject = newRec.getSObject(fieldPathParts[0]);

            if (parentObject != null) {
                String groupKey = String.valueOf(parentObject.get(fieldPathParts[1]));
                String uniqueVal = String.valueOf(newRec.get(uniqueFieldApiName));

                if (!newValuesByGroup.containsKey(groupKey)) {
                    newValuesByGroup.put(groupKey, new Set<String>());
                }
                
                newValuesByGroup.get(groupKey).add(uniqueVal);
            }
        }   

        // Loop through existing records by parent external id (Eg. LOA by License number) and make sure to compare only the 2 sets of child records that belong to the same parent
        // Records not found in new records should be deleted since they are not there any more
        for (String groupKey : existingGroupedRecords.keySet()) {
            List<SObject> existingRecords = existingGroupedRecords.get(groupKey);
            Set<String> newIdentifiers = newValuesByGroup.get(groupKey);

            for (SObject record : existingRecords) {
                String existingVal = String.valueOf(record.get(uniqueFieldApiName));

                if (String.isNotBlank(existingVal) && (newIdentifiers == null || !newIdentifiers.contains(existingVal))) {
                    recordIdsForDeletion.add(record.Id);
                }
            }
        }

        return recordIdsForDeletion;
    }

    /**
     *********************************************************
     * @methodName      : getEntityCommunicationsByEntity
     * @description     : Retrieves existing producer communications from Salesforce.
     * @param producerNpns : Set of NPNs for which existing communications are fetched.
     * @return          : Map of existing producer communications grouped by NPN.
     *********************************************************
     **/
    private Map<String, List<d4c_EntityCommunication__c>> getEntityCommunicationsByEntity(Set<String> producerNpns) {
        Map<String, List<d4c_EntityCommunication__c>> existingEntityCommsByEntity = new Map<String, List<d4c_EntityCommunication__c>>();

        EntityCommunicationSelector prodCommSelector = new EntityCommunicationSelector();
        List<d4c_EntityCommunication__c> existingEntityComms = prodCommSelector.getEntityCommsByEntityNPNs(producerNpns);

        for (d4c_EntityCommunication__c producerComm : existingEntityComms) {
            if (existingEntityCommsByEntity.containsKey(producerComm.d4c_Entity__r.d4c_NPN__c)) {
                existingEntityCommsByEntity.get(producerComm.d4c_Entity__r.d4c_NPN__c).add(producerComm);

                continue;
            }

            existingEntityCommsByEntity.put(producerComm.d4c_Entity__r.d4c_NPN__c, new List<d4c_EntityCommunication__c> { producerComm });
        }

        return existingEntityCommsByEntity;
    }

    /**
     *********************************************************
     * @methodName      : getEntityAddressesByEntity
     * @description     : Retrieves existing producer addresses from Salesforce.
     * @param producerNpns : Set of NPNs for which existing addresses are fetched.
     * @return          : Map of existing producer addresses grouped by NPN.
     *********************************************************
     **/
    private Map<String, List<d4c_EntityAddress__c>> getEntityAddressesByEntity(Set<String> producerNpns) {
        Map<String, List<d4c_EntityAddress__c>> existingEntityAddressesByEntity = new Map<String, List<d4c_EntityAddress__c>>();

        EntityAddressSelector prodAddressSelector = new EntityAddressSelector();
        List<d4c_EntityAddress__c> existingEntityAddresses = prodAddressSelector.getEntityAddressByEntityNPNs(producerNpns);

        for (d4c_EntityAddress__c producerAddr : existingEntityAddresses) {
            if (existingEntityAddressesByEntity.containsKey(producerAddr.d4c_Entity__r.d4c_NPN__c)) {
                existingEntityAddressesByEntity.get(producerAddr.d4c_Entity__r.d4c_NPN__c).add(producerAddr);

                continue;
            }

            existingEntityAddressesByEntity.put(producerAddr.d4c_Entity__r.d4c_NPN__c, new List<d4c_EntityAddress__c> { producerAddr });
        }

        return existingEntityAddressesByEntity;
    }

    /**
     *********************************************************
     * @methodName      : getLicensesByEntity
     * @description     : Retrieves existing licenses from Salesforce grouped by producer NPN.
     * @param producerNpns : Set of producer NPNs.
     * @return           : Map of license records grouped by NPN.
     *********************************************************
     */
    private Map<String, List<d4c_License__c>> getLicensesByEntity(Set<String> producerNpns) {
        Map<String, List<d4c_License__c>> existingLicensesByEntity = new Map<String, List<d4c_License__c>>();

        LicenseSelector licenseSelector = new LicenseSelector();
        List<d4c_License__c> existingLicenses = licenseSelector.getLicensesByEntityNpn(producerNpns);

        for (d4c_License__c license : existingLicenses) {
            if (existingLicensesByEntity.containsKey(license.d4c_Entity__r.d4c_NPN__c)) {
                existingLicensesByEntity.get(license.d4c_Entity__r.d4c_NPN__c).add(license);

                continue;
            }

            existingLicensesByEntity.put(license.d4c_Entity__r.d4c_NPN__c, new List<d4c_License__c> { license });
        }

        return existingLicensesByEntity;
    }

    /**
     *********************************************************
     * @methodName      : getCarrierAppointmentsByEntity
     * @description     : Retrieves existing carrier appointments from Salesforce grouped by producer NPN.
     * @param producerNpns : Set of producer NPNs.
     * @return           : Map of carrier appointments grouped by NPN.
     *********************************************************
     */
    private Map<String, List<d4c_CarrierAppointment__c>> getCarrierAppointmentsByEntity(Set<String> producerNpns) {
        Map<String, List<d4c_CarrierAppointment__c>> existingCarrierApoointmentsByEntity = new Map<String, List<d4c_CarrierAppointment__c>>();

        CarrierAppointmentSelector carrierAppSelector = new CarrierAppointmentSelector();
        List<d4c_CarrierAppointment__c> existingCarrierApoointments = carrierAppSelector.getCarrierAppointmentsByEntityNpn(producerNpns);

        for (d4c_CarrierAppointment__c carApp : existingCarrierApoointments) {
            if (existingCarrierApoointmentsByEntity.containsKey(carApp.d4c_Entity__r.d4c_NPN__c)) {
                existingCarrierApoointmentsByEntity.get(carApp.d4c_Entity__r.d4c_NPN__c).add(carApp);

                continue;
            }

            existingCarrierApoointmentsByEntity.put(carApp.d4c_Entity__r.d4c_NPN__c, new List<d4c_CarrierAppointment__c> { carApp });
        }

        return existingCarrierApoointmentsByEntity;
    }

    /**
     *********************************************************
     * @methodName      : getLOAByUniqueIdentifier
     * @description     : Retrieves existing Lines of Authority from Salesforce based on license numbers.
     * @param licenseUniqueIdentifiers : Set of external license numbers.
     * @return          : Map of existing LOAs grouped by license number.
     *********************************************************
     */
    private Map<String, List<d4c_LineOfAuthority__c>> getLOAByUniqueIdentifier(Set<String> licenseUniqueIdentifiers) {
        Map<String, List<d4c_LineOfAuthority__c>> existingLOAByLicNum = new Map<String, List<d4c_LineOfAuthority__c>>();

        LineOfAuthoritySelector LOASelector = new LineOfAuthoritySelector();
        List<d4c_LineOfAuthority__c> existingLOA = LOASelector.getLOAByUniqueIdentifier(licenseUniqueIdentifiers);

        for (d4c_LineOfAuthority__c loa : existingLOA) {
            if (existingLOAByLicNum.containsKey(loa.d4c_License__r.d4c_UniqueIdentifier__c)) {
                existingLOAByLicNum.get(loa.d4c_License__r.d4c_UniqueIdentifier__c).add(loa);

                continue;
            }

            existingLOAByLicNum.put(loa.d4c_License__r.d4c_UniqueIdentifier__c, new List<d4c_LineOfAuthority__c> { loa });
        }

        return existingLOAByLicNum;
        
    }


    /**
     *********************************************************
     * @methodName      : getNiprAddressesByAddressKey
     * @description     : Creates a map out of Nipr addresses and their address keys
     * @param niprAddresses : List of DTO classes representing NIPR Address
     * @return niprAddresses: Map of existing producer addresses grouped by their address keys
     *********************************************************
     **/
    private Map<String, LicensingReportDTO.Address> getNiprAddressesByAddressKey(List<LicensingReportDTO.Address> niprAddresses) {
        Map<String, LicensingReportDTO.Address> addressesByAddressKey = new Map<String, LicensingReportDTO.Address>();

        if (niprAddresses == null || niprAddresses.isEmpty()) {
            return addressesByAddressKey;
        }

        for (LicensingReportDTO.Address address : niprAddresses) {
            addressesByAddressKey.put(address.key, address);
        }

        return addressesByAddressKey;
    }

    /**
     *********************************************************
     * @methodName      : setNIPREntityIdentifierByReferenceKey
     * @description     : Sets a map entry of NIPR reference keys to Person/Organization NPNs and Organization CoCodes for quick lookup.
     *                  : This method stores all unique identifiers(external ids) for all agents/agencies and carriers by their nipr reference keys
     * @return          : Map of reference keys to agent/agency NPNs/carrier CoCodes
     *********************************************************
     */
    private void setNIPREntityIdentifierByReferenceKey(LicensingReportDTO.NIPREntity niprEntity) {
        for (String key : niprEntity.combinedKeys) {
            identifiersByKeyReferences.put(key, niprEntity.mainIdentifier);
        }
    }

    /**
     *********************************************************
     * @methodName      : setNIPREntityIdentifierByReferenceKeyForCarriers
     * @description     : Sets a map entry of NIPR reference keys Carrier CoCode + Fein combination for quick lookup.
     *                  : This method stores all unique identifiers(external ids) for all carriers by their nipr reference keys
     * @return          : Map of reference keys carrier CoCodes
     *********************************************************
     */
    private void setNIPREntityIdentifierByReferenceKeyForCarriers(LicensingReportDTO.Organization niprEntity) {
        for (String key : niprEntity.combinedKeys) {
            String mainIdentifier = '';
            String coCode = '';
            String feinId = '';

            for (LicensingReportDTO.ExternalIdentifier extId : niprEntity.externalIdentifierList) {
                if (extId.typeCode == 'NAICInsurerCode') {
                    coCode = extId.id;
                } else if (extId.typeCode == 'FEINId') {
                    feinId = extId.id;
                }
            }
            
            mainIdentifier += coCode + '-' + feinId;

            identifiersByKeyReferences.put(key, mainIdentifier);
        }
    }

    /**
     *********************************************************
     * @methodName      : getEligibleLicensesForDeletionByEntitysAndStates
     * @description     : Wrapper method that queries licenses for producer+state combinations
     *                    that have license data in the NIPR payload. Only these licenses are
     *                    eligible for deletion via delta comparison.
     * @param eligibleLicensesMap : Map of producer key reference -> states with license data.
     * @return          : Map of licenses grouped by producer NPN, filtered to eligible pairs only.
     *********************************************************
     */
    private Map<String, List<d4c_License__c>> getEligibleLicensesForDeletionByEntitysAndStates(
        Map<String, Set<String>> eligibleLicensesMap
    ) {
        return getEligibleRecordsForDeletionByEntitysAndStates(
            eligibleLicensesMap,
            'License'
        );
    }

    /**
     *********************************************************
     * @methodName      : getEligibleCarrierAppointmentsForDeletionByEntitysAndStates
     * @description     : Wrapper method that queries carrier appointments for producer+state combinations
     *                    that have appointment data in the NIPR payload. Only these appointments are
     *                    eligible for deletion via delta comparison.
     * @param eligibleAppointmentsMap : Map of producer key reference -> states with appointment data.
     * @return          : Map of carrier appointments grouped by producer NPN, filtered to eligible pairs only.
     *********************************************************
     */
    private Map<String, List<d4c_CarrierAppointment__c>> getEligibleCarrierAppointmentsForDeletionByEntitysAndStates(
        Map<String, Set<String>> eligibleAppointmentsMap
    ) {
        return getEligibleRecordsForDeletionByEntitysAndStates(
            eligibleAppointmentsMap,
            'CarrierAppointment'
        );
    }

    /**
     *********************************************************
     * @methodName      : getEligibleRecordsForDeletionByEntitysAndStates
     * @description     : Generic method that queries licenses or carrier appointments for specific
     *                    producer+state combinations, then filters results to only include records
     *                    where the producer+state pair is eligible (has data in NIPR payload).
     *                    This prevents deletion of records when NIPR payload contains no data for that state.
     * @param eligibleRecordsMap : Map of producer key reference -> states that have data in payload.
     * @param recordType : Type of record to query ('License' or 'CarrierAppointment').
     * @return          : Map of records grouped by producer NPN, filtered to eligible pairs only.
     *********************************************************
     */
    private Map<String, List<SObject>> getEligibleRecordsForDeletionByEntitysAndStates(
        Map<String, Set<String>> eligibleRecordsMap,
        String recordType
    ) {
        // Build sets of NPNs and states from eligible records map
        Set<String> producerNpns = new Set<String>();
        Set<String> states = new Set<String>();

        for (String producerKeyRef : eligibleRecordsMap.keySet()) {
            String npn = identifiersByKeyReferences.get(producerKeyRef);

            if (npn != null) {
                producerNpns.add(npn);
                states.addAll(eligibleRecordsMap.get(producerKeyRef));
            }
        }

        // If no eligible records, return empty map
        if (producerNpns.isEmpty() || states.isEmpty()) {
            return new Map<String, List<SObject>>();
        }

        // Query all records for these producer+state combinations
        List<SObject> queriedRecords;
        if (recordType == 'License') {
            LicenseSelector licenseSelector = new LicenseSelector();
            queriedRecords = licenseSelector.getLicensesByEntityNpnAndStates(producerNpns, states);
        } else if (recordType == 'CarrierAppointment') {
            CarrierAppointmentSelector carrierAppSelector = new CarrierAppointmentSelector();
            queriedRecords = carrierAppSelector.getCarrierAppointmentsByEntityNpnAndStates(producerNpns, states);
        } else {
            return new Map<String, List<SObject>>();
        }


        // Filter queried records to only include those in eligible producer+state pairs
        List<SObject> filteredRecords = filterRecordsByEligiblePairs(queriedRecords, eligibleRecordsMap);

        // Group filtered records by producer NPN
        Map<String, List<SObject>> recordsByEntity = new Map<String, List<SObject>>();
        for (SObject record : filteredRecords) {
            SObject producerRelation = record.getSObject('d4c_Entity__r');
            String npn = String.valueOf(producerRelation.get('d4c_NPN__c'));

            if (!recordsByEntity.containsKey(npn)) {
                recordsByEntity.put(npn, new List<SObject>());
            }
            recordsByEntity.get(npn).add(record);
        }


        return recordsByEntity;
    }

    /**
     *********************************************************
     * @methodName      : filterRecordsByEligiblePairs
     * @description     : Filters a list of queried records to only include those where the
     *                    producer+state combination exists in the eligible map.
     * @param queriedRecords : All records queried from database.
     * @param eligibleRecordsMap : Map of producer key reference -> eligible states.
     * @return          : Filtered list of records.
     *********************************************************
     */
    private List<SObject> filterRecordsByEligiblePairs(
        List<SObject> queriedRecords,
        Map<String, Set<String>> eligibleRecordsMap
    ) {
        List<SObject> filteredRecords = new List<SObject>();

        for (SObject record : queriedRecords) {
            if (isRecordEligible(record, eligibleRecordsMap)) {
                filteredRecords.add(record);
            }
        }

        return filteredRecords;
    }

    /**
     *********************************************************
     * @methodName      : isRecordEligible
     * @description     : Checks if a specific record's producer+state combination exists
     *                    in the eligible map (meaning it has data in NIPR payload).
     *                    Uses O(1) map lookups instead of looping.
     * @param record : The record to check.
     * @param eligibleRecordsMap : Map of producer key reference -> eligible states.
     * @return          : True if record is eligible for deletion logic, false otherwise.
     *********************************************************
     */
    private Boolean isRecordEligible(
        SObject record,
        Map<String, Set<String>> eligibleRecordsMap
    ) {

        SObject producerRelation = record.getSObject('d4c_Entity__r');
        String npn = String.valueOf(producerRelation.get('d4c_NPN__c'));
        String state = String.valueOf(record.get('d4c_StateOrProvinceCode__c'));

        // Find the producer key reference for this NPN - O(1) lookup
        String producerKeyRef = null;
        for (String keyRef : identifiersByKeyReferences.keySet()) {
            if (identifiersByKeyReferences.get(keyRef) == npn) {
                producerKeyRef = keyRef;
                break;
            }
        }

        if (producerKeyRef == null) {
            return false;
        }

        // O(1) map lookup + O(1) Set.contains() check
        Set<String> eligibleStates = eligibleRecordsMap.get(producerKeyRef);
        return eligibleStates != null && eligibleStates.contains(state);
    }

    /**
     *********************************************************
     * @methodName      : syncNIPRDataWithSalesforce
     * @description     : Handles all the DML operations in a single location. Deletes old records,
     *                      upserts new or updated producers, licenses, appointments, LOAs, etc.
     *                      Logs CPU and heap usage for debug purposes. Uses DMLExecutor queueable
     *                      to safely handle large record volumes via batched and chained execution.
     *********************************************************
     */
    private void syncNIPRDataWithSalesforce() {
        String methodName = 'syncNIPRDataWithSalesforce';
    
        // Deduplicate all upsert lists by their unique external ID field(For edge cases, when NIPR sends the same address twice for the same agent for example)

        ListUtils.deduplicateByField(producers, 'd4c_NPN__c');
        ListUtils.deduplicateByField(producerCommunications, 'd4c_UniqueIdentifier__c');
        ListUtils.deduplicateByField(producerAddresses, 'd4c_UniqueIdentifier__c');
        ListUtils.deduplicateByField(carriers, 'd4c_UniqueIdentifier__c');
        ListUtils.deduplicateByField(licenses, 'd4c_UniqueIdentifier__c');
        ListUtils.deduplicateByField(linesOfAuthority, 'd4c_UniqueIdentifier__c');
        ListUtils.deduplicateByField(carrierAppointments, 'd4c_UniqueIdentifier__c');

        // Log after deduplication
        String upsertDetails =
            'Entitys: ' + producers.size() + '\n' +
            'Entity Communications: ' + producerCommunications.size() + '\n' +
            'Entity Addresses: ' + producerAddresses.size() + '\n' +
            'Carriers: ' + carriers.size() + '\n' +
            'Licenses: ' + licenses.size() + '\n' +
            'License LOAs: ' + linesOfAuthority.size() + '\n' +
            'Carrier Appointments: ' + carrierAppointments.size();
    
        Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('Records prepared for upsert'),
            'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() + ' | ' + upsertDetails, null);

        // Chained DML upserts
        DMLExecutor carrierAppointmentUpsert = new DMLExecutor(
            carrierAppointments,
            d4c_CarrierAppointment__c.d4c_UniqueIdentifier__c,
            null,
            CLASS_NAME
        );
    
        DMLExecutor loaUpsert = new DMLExecutor(
            linesOfAuthority,
            d4c_LineOfAuthority__c.d4c_UniqueIdentifier__c,
            carrierAppointmentUpsert,
            CLASS_NAME
        );
    
        DMLExecutor licenseUpsert = new DMLExecutor(
            licenses,
            d4c_License__c.d4c_UniqueIdentifier__c,
            loaUpsert,
            CLASS_NAME
        );
    
        DMLExecutor carrierUpsert = new DMLExecutor(
            carriers,
            d4c_Carrier__c.d4c_UniqueIdentifier__c,
            licenseUpsert,
            CLASS_NAME
        );
    
        DMLExecutor producerAddrUpsert = new DMLExecutor(
            producerAddresses,
            d4c_EntityAddress__c.d4c_UniqueIdentifier__c,
            carrierUpsert,
            CLASS_NAME
        );
    
        DMLExecutor producerCommsUpsert = new DMLExecutor(
            producerCommunications,
            d4c_EntityCommunication__c.d4c_UniqueIdentifier__c,
            producerAddrUpsert,
            CLASS_NAME
        );
    
        DMLExecutor producerUpsert = new DMLExecutor(
            producers,
            d4c_Entity__c.d4c_NPN__c,
            producerCommsUpsert,
            CLASS_NAME
        );

        // Consolidate record counts in a single detailed log
        String deletionDetails =
            'Entity Communications: ' + producerCommunicationIdsForDeletion.size() + '\n' +
            'Entity Addresses: ' + producerAddressIdsForDeletion.size() + '\n' +
            'Licenses: ' + licenseIdsForDeletion.size() + '\n' +
            'License LOAs: ' + licenseLineOfAuthorityIdsForDeletion.size() + '\n' +
            'Carrier Appointments: ' + carrierAppointmentIdsForDeletion.size();
    
        Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('Records identified for deletion'),
            'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() + ' | ' + deletionDetails, null);

        // Start the tail as the upsert head; deletes will chain *before* this
        Queueable tail = producerUpsert;

        tail = new DMLExecutor(new List<Id>(carrierAppointmentIdsForDeletion), tail, CLASS_NAME);
        tail = new DMLExecutor(new List<Id>(licenseIdsForDeletion), tail, CLASS_NAME);
        tail = new DMLExecutor(new List<Id>(licenseLineOfAuthorityIdsForDeletion), tail, CLASS_NAME);
        tail = new DMLExecutor(new List<Id>(producerAddressIdsForDeletion), tail, CLASS_NAME);
        tail = new DMLExecutor(new List<Id>(producerCommunicationIdsForDeletion), tail, CLASS_NAME);

        Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('Completed synchronous DML operations for test'),
        'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
        ' | Heap Size: ' + Limits.getHeapSize() + ' bytes | CPU Usage: ' + Limits.getCpuTime() + ' ms', null);

        if (!Test.isRunningTest()) {
            Logger.info(CLASS_NAME, methodName, CorrelationIdUtils.formatLogMessage('Starting chained DML operations'),
                'CorrelationId: ' + CorrelationIdUtils.getCurrentCorrelationId() +
                ' | First operation: Delete ' + allIdsToDelete.size() + ' records', null);

            AsyncOptions asyncOptions = new AsyncOptions();
            asyncOptions.MaximumQueueableStackDepth = 50;
    
            System.enqueueJob(tail, asyncOptions);
            
            return;
        }
    
        importDataForApexTest();
    }

    // Private method that does DML synchronously so we can test our records
    private void importDataForApexTest() {
        Database.delete(new List<Id>(producerCommunicationIdsForDeletion));
        Database.delete(new List<Id>(producerAddressIdsForDeletion));
        Database.delete(new List<Id>(licenseLineOfAuthorityIdsForDeletion));
        Database.delete(new List<Id>(licenseIdsForDeletion));
        Database.delete(new List<Id>(carrierAppointmentIdsForDeletion));

        Database.upsert(producers, d4c_Entity__c.d4c_NPN__c, true);
        Database.upsert(producerCommunications, d4c_EntityCommunication__c.d4c_UniqueIdentifier__c, true);
        Database.upsert(producerAddresses, d4c_EntityAddress__c.d4c_UniqueIdentifier__c, true);
        Database.upsert(carriers, d4c_Carrier__c.d4c_CoCode__c, true);
        Database.upsert(licenses, d4c_License__c.d4c_UniqueIdentifier__c, true);
        Database.upsert(linesOfAuthority, d4c_LineOfAuthority__c.d4c_UniqueIdentifier__c, true);
        Database.upsert(carrierAppointments, d4c_CarrierAppointment__c.d4c_UniqueIdentifier__c, true);
    }

    public class PDBAlertReportException extends Exception {} 
}