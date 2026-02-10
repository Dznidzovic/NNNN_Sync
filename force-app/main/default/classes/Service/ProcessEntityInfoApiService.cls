/**
 *********************************************************
 * Apex Class Name    : ProcessEntityInfoApiService
 * Created Date       : 04-08-2025
 * @description       : Imports data from the NIPR Entity Info API and maps it to Salesforce records.
 *                      This class processes the EntityInfoDTO structure and generates records for
 *                      d4c_Entity__c, d4c_ProducerCommunication__c, d4c_ProducerAddress__c, d4c_License__c,
 *                      d4c_LineOfAuthority__c, and d4c_CarrierAppointment__c.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author             Modification
 * 1.0   04-08-2025   Dev4Clouds    Initial Version
 * 1.1   10-24-2025   Dev4Clouds    Added Exclude Carrier Appointments flag handling
 *********************************************************
 **/
public with sharing class ProcessEntityInfoApiService {
    // Stores the NPN of the entity being processed
    private String entityNPN;
    // Stores the entity record to be upserted
    private d4c_Entity__c entity;
    // Stores new or updated entity communication records (Phone, Email)
    private List<d4c_ProducerCommunication__c> producerCommunications = new List<d4c_ProducerCommunication__c>();
    // Stores new or updated entity address records
    private List<d4c_ProducerAddress__c> producerAddresses = new List<d4c_ProducerAddress__c>();
    // Stores new or updated license records
    private List<d4c_License__c> licenses = new List<d4c_License__c>();
    // Stores new or updated Line of Authority records for licenses
    private List<d4c_LineOfAuthority__c> licenseLoas = new List<d4c_LineOfAuthority__c>();
    // Stores new or updated carrier appointment records
    private List<d4c_CarrierAppointment__c> carrierAppointments = new List<d4c_CarrierAppointment__c>();
    // Stores new or updated Line of Authority records for carrier appointments
    // Stores new or updatedCarrier records for carriers upsert
    private list<d4c_Carrier__c> carriers = new List<d4c_Carrier__c>();
    // Tracks unique record Identifiers to remove duplicates where needed
    private Set<String> uniqueRecordIds = new Set<String>();

    private final String CLASS_NAME = 'ProcessEntityInfoApiService';

    /**
     *********************************************************
     * @methodName      : processData
     * @description     : Main entry point for importing a single EntityInfoDTO record into Salesforce.
     * @param npn       : The National Entity Number to retrieve and process.
     *********************************************************
     **/
    public void processData(String npn) {
        String methodName = 'processData';

        entityNPN = npn;

        // Execute request to NIPR EntityInfo API
        RetrieveEntityInfoApiData entityInfoCallout = new RetrieveEntityInfoApiData();
        EntityInfoDTO entityInfoDTO = entityInfoCallout.retrieveData(npn);

        // Check if this is an error response
        if (!entityInfoDTO.isSuccess) {
            Logger.error(CLASS_NAME, methodName,
                    'NPN: ' + entityNPN + ' - Entity Info API returned error',
                    'Error Type: ' + entityInfoDTO.errorType +
                    ', Error Message: ' + entityInfoDTO.errorMessage,
                    null);

            Logger.commitAsync();

            throw new EntityInfoAPIException(entityInfoDTO.errorMessage + ': ' + entityInfoDTO.errorType);
        }

        // Create a sanitized clone for logging with masked SSN
        // EntityInfoDTO sanitizedDTO = createSanitizedClone(entityInfoDTO);
        // Logger.debug(CLASS_NAME, methodName, 'Entity Info API Data for NPN: ' + npn, JSON.serialize(sanitizedDTO), null);

        // Process entity data if available (either Individual or Firm)
        if (entityInfoDTO?.PRODUCER?.INDIVIDUAL != null) {
            processEntity(entityInfoDTO.PRODUCER.INDIVIDUAL);
        } else if (entityInfoDTO?.PRODUCER?.FIRM != null) {
            processEntity(entityInfoDTO.PRODUCER.FIRM);
        }

        entity.d4c_NPNSyncError__c = null;
        entity.d4c_IntegrationError__c = null;
        entity.d4c_LastNIPRSync__c = Datetime.now();

        // Set exclude carrier appointments flag based on what was determined in RetrieveEntityInfoApiData
        // That class handles checking existing entity value and payload size
        entity.d4c_ExcludeCarrierAppointments__c = entityInfoCallout.shouldExcludeCarrierAppointments;

        try {
            syncDataWithSalesforce();
        } catch (Exception ex) {
            Logger.commitAsync();

            throw ex;
        }

        // Log heap and CPU usage
        Logger.debug(CLASS_NAME, methodName, 'NPN: ' + entityNPN + ' - Finished processing Entity Info',
                'Heap Size: ' + Limits.getHeapSize() + ' bytes, ' +
                'CPU Usage: ' + Limits.getCpuTime() + ' ms', 
                null);
        
        Logger.commitAsync();
    }

    /**
     *********************************************************
     * @methodName      : processEntity
     * @description     : Maps the INDIVIDUAL(AGENT) node to a d4c_Entity__c record and queues
     *                    related communications for upsert.
     * @param individual : INDIVIDUAL node from the DTO.
     *********************************************************
     **/
    private void processEntity(EntityInfoDTO.INDIVIDUAL individual) {
        if (individual == null || individual.ENTITY_BIOGRAPHIC == null || individual.ENTITY_BIOGRAPHIC.BIOGRAPHIC == null) {
            return;
        }

        EntityInfoDTO.BIOGRAPHIC bio = individual.ENTITY_BIOGRAPHIC.BIOGRAPHIC;
        
        entity = createEntityRecord(bio);
        entity.d4c_Type__c = 'Agent';

        // Process communications if available
        if (individual.ENTITY_BIOGRAPHIC?.CONTACT_INFOS != null) {
            processProducerCommunications(individual.ENTITY_BIOGRAPHIC.CONTACT_INFOS);
        }

        if (individual.ENTITY_BIOGRAPHIC?.ADDRESSES != null) {
            processProducerAddresses(individual.ENTITY_BIOGRAPHIC.ADDRESSES);
        }

        if (individual.PRODUCER_LICENSING?.LICENSE_INFORMATION != null) {
            processLicenseRecords(individual.PRODUCER_LICENSING?.LICENSE_INFORMATION);
        }
    }

    /**
     *********************************************************
     * @methodName      : processEntity
     * @description     : Maps the FIRM(AGENCY) node to a d4c_Entity__c record and queues
     *                    related communications for upsert.
     * @param firm      : FIRM node from the DTO.
     *********************************************************
     **/
    private void processEntity(EntityInfoDTO.FIRM firm) {
        if (firm == null || firm.ENTITY_BIOGRAPHIC == null || firm.ENTITY_BIOGRAPHIC.BIOGRAPHIC == null) {
            return;
        }

        EntityInfoDTO.BIOGRAPHIC bio = firm.ENTITY_BIOGRAPHIC.BIOGRAPHIC;
        
        entity = createEntityRecord(bio, true);
        entity.d4c_Type__c = 'Agency';

        // Process communications if available
        if (firm.ENTITY_BIOGRAPHIC?.CONTACT_INFOS != null) {
            processProducerCommunications(firm.ENTITY_BIOGRAPHIC.CONTACT_INFOS);
        }

        if (firm.ENTITY_BIOGRAPHIC?.ADDRESSES != null) {
            processProducerAddresses(firm.ENTITY_BIOGRAPHIC.ADDRESSES);
        }

        if (firm.PRODUCER_LICENSING?.LICENSE_INFORMATION != null) {
            processLicenseRecords(firm.PRODUCER_LICENSING?.LICENSE_INFORMATION);
        }
    }

    /**
     *********************************************************
     * @methodName      : processProducerCommunications
     * @description     : Extracts business phones, faxes, and emails from CONTACT_INFOS and
     *                    stores them as `d4c_ProducerCommunication__c` records for the given NPN.
     * @param contactInfos : Contact info section of the EntityInfoDTO.
     *********************************************************
     **/
    private void processProducerCommunications(EntityInfoDTO.CONTACT_INFOS contactInfos) {
        if (contactInfos == null || contactInfos.STATE == null) {
            return;
        }

        for (EntityInfoDTO.STATE_CONTACT stateContact : contactInfos.STATE) {
            if (stateContact == null || stateContact.CONTACT_INFO == null || stateContact.CONTACT_INFO.isEmpty()) {
                continue;
            }

            // Process all CONTACT_INFO nodes for this STATE
            for (EntityInfoDTO.CONTACT_INFO info : stateContact.CONTACT_INFO) {
                if (info == null) {
                    continue;
                }
                
                // Process business phone
                processPhoneCommunication(info.BUSINESS_PHONE, 'Wired');
                
                // Process fax
                processPhoneCommunication(info.FAX, 'Fax');
                
                // Process email
                processEmail(info.BUSINESS_EMAIL, 'Business');
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processPhoneCommunication
     * @description     : Creates a phone communication record for various phone types.
     * @param phoneNumber : number of the phone
     * @param phoneType   : Type of phone ('Wired', 'Fax', etc).
     *********************************************************
     **/
    private void processPhoneCommunication(String phoneNumber, String phoneType) {
        
        // Return if blank
        if (String.isBlank(phoneNumber)) {
            return;
        }
        
        String formattedPhone = StringUtils.formatNIPREntityInfoNumber(phoneNumber);

        if (String.isNotBlank(formattedPhone)) {
            String uniqueId = formattedPhone + phoneType;

            if (!uniqueRecordIds.contains(uniqueId)) {
                d4c_ProducerCommunication__c comm = new d4c_ProducerCommunication__c();

                comm.d4c_PhoneType__c = phoneType;
                comm.d4c_PhoneNumber__c = formattedPhone;
                comm.d4c_UniqueIdentifier__c = uniqueId;

                producerCommunications.add(comm);
                uniqueRecordIds.add(uniqueId);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processEmail
     * @description     : Creates an email communication record from email data.
     * @param email     : Email address
     * @param emailType : Type of Email address
     * 
     *********************************************************
     **/
    private void processEmail(String email, String emailType) {
        if (String.isBlank(email) || !StringUtils.isValidEmail(email)) {
            return;
        }

        String uniqueId = email + emailType;

        if (!uniqueRecordIds.contains(uniqueId)) {
            d4c_ProducerCommunication__c emailComm = new d4c_ProducerCommunication__c();

            emailComm.d4c_EmailType__c = emailType;
            emailComm.d4c_EmailAddress__c = email;
            emailComm.d4c_UniqueIdentifier__c = uniqueId;

            producerCommunications.add(emailComm);
            uniqueRecordIds.add(uniqueId);
        }
    }

    /**
     *********************************************************
     * @methodName      : processProducerAddresses
     * @description     : Processes addresses from the entity biography and creates entity address records.
     * @param addresses : Addresses from the Entity Info DTO.
     *********************************************************
     **/
    private void processProducerAddresses(EntityInfoDTO.ADDRESSES addresses) {
        if (addresses == null || addresses.STATE == null) {
            return;
        }

        for (EntityInfoDTO.STATE_ADDRESS stateAddress : addresses.STATE) {
            if (stateAddress == null || stateAddress.ADDRESS == null || stateAddress.ADDRESS.isEmpty()) {
                continue;
            }
            
            processStateAddresses(stateAddress);
        }
    }

    /**
     *********************************************************
     * @methodName      : processStateAddresses
     * @description     : Processes addresses for a specific state and creates entity address records.
     * @param stateAddress : State address information from the Entity Info DTO.
     *********************************************************
     **/
    private void processStateAddresses(EntityInfoDTO.STATE_ADDRESS stateAddress) {
        for (EntityInfoDTO.ADDRESS address : stateAddress.ADDRESS) {
            if (address == null) {
                continue;
            }
            
            d4c_ProducerAddress__c producerAddress = createProducerAddressRecord(address);

            if (producerAddress != null && !uniqueRecordIds.contains(producerAddress.d4c_UniqueIdentifier__c)) {
                producerAddresses.add(producerAddress);
                uniqueRecordIds.add(producerAddress.d4c_UniqueIdentifier__c);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processLicenseRecords
     * @description     : Processes license information and creates license records with lines of authority.
     * @param licenseInfo : LICENSE_INFORMATION node from the DTO.
     *********************************************************
     **/
    private void processLicenseRecords(EntityInfoDTO.LICENSE_INFORMATION licenseInfo) {
        if (licenseInfo == null || licenseInfo.STATE == null) {
            return;
        }
        
        for (EntityInfoDTO.STATE_LICENSE stateLicense : licenseInfo.STATE) {
            if (stateLicense == null || stateLicense.LICENSE == null) {
                continue;
            }
            
            // Process each license in the list
            for (EntityInfoDTO.LICENSE license : stateLicense.LICENSE) {
                // Create license record
                d4c_License__c licenseRecord = createLicenseRecord(license, stateLicense.attributes?.name);

                String licenseUniqueId = licenseRecord.d4c_LicenseNumber__c + StringUtils.safeParseNullString(licenseRecord.d4c_StateOrProvinceCode__c) + StringUtils.safeParseNullString(licenseRecord.d4c_LicenseClassCode__c);

                licenseRecord.d4c_UniqueIdentifier__c = licenseUniqueId;
                
                if (licenseRecord != null) {
                    licenses.add(licenseRecord);
                    
                    // Process lines of authority if available
                    if (license.DETAILS != null && license.DETAILS.DETAIL != null) {
                        processLinesOfAuthority(license.DETAILS.DETAIL, licenseRecord.d4c_UniqueIdentifier__c, stateLicense.attributes?.name);
                    }
                }
            }
            
            // Process carrier appointments if available
            if (stateLicense.APPOINTMENT_INFORMATION != null && stateLicense.APPOINTMENT_INFORMATION.APPOINTMENT != null) {
                processCarrierAppointments(stateLicense.APPOINTMENT_INFORMATION.APPOINTMENT, null, stateLicense.attributes?.name);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processLinesOfAuthority
     * @description     : Processes lines of authority for a license from DETAILS.DETAIL nodes.
     * @param details   : List of DETAIL nodes containing line of authority information.
     * @param licenseUniqueId : The license unique Id to associate with these lines of authority.
     * @param stateCode : The state code for the license.
     *********************************************************
     **/
    private void processLinesOfAuthority(List<EntityInfoDTO.DETAIL> details, String licenseUniqueId, String stateCode) {
        if (details == null || details.isEmpty() || String.isBlank(licenseUniqueId)) {
            return;
        }
        
        for (EntityInfoDTO.DETAIL detail : details) {
            if (detail == null || String.isBlank(detail.LOA_CODE)) {
                continue;
            }
            
            d4c_LineOfAuthority__c loaRecord = createLineOfAuthorityRecord(detail, licenseUniqueId, stateCode);
            
            if (loaRecord != null) {
                // Generate a unique identifier for this LOA
                String uniqueId = loaRecord.d4c_LineOfAuthorityCode__c + stateCode + StringUtils.safeParseFromDate(loaRecord.d4c_IssueDate__c) + licenseUniqueId;
                loaRecord.d4c_UniqueIdentifier__c = uniqueId;
                licenseLoas.add(loaRecord);
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : processCarrierAppointments
     * @description     : Processes carrier appointments from APPOINTMENT nodes.
     * @param appointments : List of APPOINTMENT nodes containing carrier appointment information.
     * @param licenseNumber : The license number associated with these appointments.
     * @param stateCode : The state code for the appointments.
     *********************************************************
     **/
    private void processCarrierAppointments(List<EntityInfoDTO.APPOINTMENT> appointments, String licenseNumber, String stateCode) {
        if (appointments == null || appointments.isEmpty()) {
            return;
        }
        
        for (EntityInfoDTO.APPOINTMENT appointment : appointments) {
            if (appointment == null || (String.isBlank(appointment.COCODE) && String.isBlank(appointment.FEIN))) {
                continue;
            }

            // Create a Carrier Record
            d4c_Carrier__c carrierRecord = createCarrierRecord(appointment);

            // Make sure only one carrier record is being added to the list for upsert, as multiple nodes can contain carrier information
            if (carrierRecord != null && !uniqueRecordIds.contains(carrierRecord.d4c_UniqueIdentifier__c)) {
                carriers.add(carrierRecord);
                uniqueRecordIds.add(carrierRecord.d4c_UniqueIdentifier__c);
            }
            
            d4c_CarrierAppointment__c appointmentRecord = createCarrierAppointmentRecord(appointment, stateCode);
            
            if (appointmentRecord != null) {       
                // Set the entity lookup using external ID
                appointmentRecord.d4c_Entity__r = new d4c_Entity__c(d4c_NPN__c = entityNPN);
                appointmentRecord.d4c_Carrier__r = new d4c_Carrier__c(d4c_UniqueIdentifier__c = carrierRecord.d4c_UniqueIdentifier__c);

                String countyCode = StringUtils.safeParseNullString(appointmentRecord.d4c_CountyCode__c);

                // Generate a unique identifier for this carrier appointment
                String carrierAppIdentifier = entityNPN + carrierRecord.d4c_UniqueIdentifier__c + stateCode + countyCode + appointment.STATUS;
                appointmentRecord.d4c_UniqueIdentifier__c = carrierAppIdentifier;
                
                // Populate LOA fields directly on carrier appointment if available
                if (String.isNotBlank(appointment.LINE_OF_AUTHORITY)) {
                    // Set LOA fields directly on carrier appointment
                    appointmentRecord.d4c_LineOfAuthorityCode__c = StringUtils.truncateField(appointment.LOA_CODE, 50);
                    appointmentRecord.d4c_LineOfAuthorityDescription__c = StringUtils.truncateField(appointment.LINE_OF_AUTHORITY, 255);

                    // Parse renewal date - format from 'MM/dd/yyyy' to 'yyyy-MM-dd' and convert to Date
                    String formattedRenewalDate = StringUtils.convertToISODateFormat(
                        StringUtils.swapCharacters(appointment.APPONT_RENEWAL_DATE, '/', '-')
                    );
                    appointmentRecord.d4c_RenewalDate__c = DateUtils.safeParseDateFromString(formattedRenewalDate);

                    String loaCode = StringUtils.safeParseNullString(appointment.LOA_CODE);
                    String loaRenewalDate = StringUtils.safeParseFromDate(appointmentRecord.d4c_RenewalDate__c);
                    String statusReasonDate = StringUtils.safeParseFromDate(appointmentRecord.d4c_StatusReasonDate__c);

                    // Create the unique identifier component for the LOA info
                    String loaUniqueId = entityNPN + carrierRecord.d4c_UniqueIdentifier__c + loaRenewalDate + statusReasonDate + countyCode + loaCode;

                    // Carrier appointment Unique Id has to be combined with it's LOA information in order to stay Unique
                    carrierAppIdentifier += loaUniqueId;
                    appointmentRecord.d4c_UniqueIdentifier__c = carrierAppIdentifier;
                }

                if (!uniqueRecordIds.contains(appointmentRecord.d4c_UniqueIdentifier__c)) {
                    carrierAppointments.add(appointmentRecord);
                    uniqueRecordIds.add(appointmentRecord.d4c_UniqueIdentifier__c);
                }
            }
        }
    }

    /**
     *********************************************************
     * @methodName      : createEntityRecord
     * @description     : Creates a entity (Individual) record with data from the biographic section.
     * @param bio       : Biographic data from the Entity Info DTO.
     * @return          : Populated d4c_Entity__c record.
     *********************************************************
     **/
    private d4c_Entity__c createEntityRecord(EntityInfoDTO.BIOGRAPHIC bio) {
        return createEntityRecord(bio, false);
    }

    /**
     *********************************************************
     * @methodName      : createEntityRecord
     * @description     : Creates a entity record with data from the biographic section.
     *                    Can create either an Individual (Agent) or Firm (Agency) record.
     * @param bio       : Biographic data from the Entity Info DTO.
     * @param isFirm    : Boolean flag indicating if this is a Firm (Agency) record.
     * @return          : Populated d4c_Entity__c record.
     *********************************************************
     **/
    private d4c_Entity__c createEntityRecord(EntityInfoDTO.BIOGRAPHIC bio, Boolean isFirm) {
        d4c_Entity__c entityRecord = new d4c_Entity__c();
        
        entityRecord.d4c_NPN__c = entityNPN;
        entityRecord.d4c_NPNStatus__c = 'Active';
        entityRecord.d4c_SyncRecordToNIPR__c = 'On';

        if (isFirm) {
            // Set Agency-specific fields
            entityRecord.d4c_FullName__c = StringUtils.truncateField(bio.NAME_COMPANY, 255);
            entityRecord.d4c_FEIN__c = StringUtils.truncateField(StringUtils.swapCharacters(bio.ID_FEIN, '-', ''), 9);
            entityRecord.d4c_StateCOID__c = bio.STATE_CO_ID;
            entityRecord.d4c_StateDomicile__c = bio.STATE_DOMICILE;
            
            // Set name type code if available
            if (bio?.OTHER_NAME?.STATE?.NAME?.attributes != null) {
                entityRecord.d4c_NameTypeCode__c = bio.OTHER_NAME.STATE.NAME.attributes.type;
            }
        } else {
            // Set Individual-specific fields
            entityRecord.d4c_GivenName__c = bio.NAME_FIRST;
            entityRecord.d4c_MiddleName__c = bio.NAME_MIDDLE;
            entityRecord.d4c_SurName__c = bio.NAME_LAST;
            entityRecord.d4c_NameSuffix__c = bio.NAME_SUFFIX;
            entityRecord.d4c_SSN__c = bio.ID_SSN;

            // Format and parse birth date
            String formattedBirthDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(bio.DATE_BIRTH, '/', '-')
            );

            entityRecord.d4c_BirthDate__c = DateUtils.safeParseDateFromString(formattedBirthDate);
            
            // Set name type code if available
            if (bio?.OTHER_NAME?.STATE?.NAME?.attributes != null) {
                entityRecord.d4c_NameTypeCode__c = bio.OTHER_NAME.STATE.NAME.attributes.type;
            }
        }

        return entityRecord;
    }

    /**
     *********************************************************
     * @methodName      : createProducerAddressRecord
     * @description     : Creates a Entity Address record based on provided address information.
     * @param address   : Address information from the Entity Info DTO.
     * @return          : A new d4c_ProducerAddress__c record.
     *********************************************************
     **/
    private d4c_ProducerAddress__c createProducerAddressRecord(EntityInfoDTO.ADDRESS address) {
        d4c_ProducerAddress__c producerAddress = new d4c_ProducerAddress__c();
        
        if (address != null) {
            // Format and parse as of date
            String formattedAsOfDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(address.DATE_UPDATED, '/', '-')
            );

            producerAddress.d4c_AsOfDate__c = DateUtils.safeParseDateFromString(formattedAsOfDate);
            producerAddress.d4c_AddressLineOne__c = address.ADDR_LINE_1;
            producerAddress.d4c_AddressLineTwo__c = address.ADDR_LINE_2;
            producerAddress.d4c_AddressLineThree__c = address.ADDR_LINE_3;
            producerAddress.d4c_City__c = address.NAME_CITY;
            producerAddress.d4c_CountryCode__c = address.COUNTRY;
            producerAddress.d4c_PostalCode__c = address.ZIP;
            producerAddress.d4c_State__c = address.NAME_STATE;

            String addressType = address.ADDR_TYPE == 'Residence' ? 'Residential' : address.ADDR_TYPE;
            producerAddress.d4c_AddressType__c = addressType;

            String uniqueId =
                producerAddress.d4c_AddressLineOne__c +
                producerAddress.d4c_AddressLineTwo__c +
                producerAddress.d4c_AddressLineThree__c +
                producerAddress.d4c_City__c +
                producerAddress.d4c_State__c +
                producerAddress.d4c_PostalCode__c +
                producerAddress.d4c_CountryCode__c +
                producerAddress.d4c_AddressType__c;

            // Remove spaces and nulls
            List<String> patternsToRemove = new List<String>{ '\\s+', 'null' };
            producerAddress.d4c_UniqueIdentifier__c = StringUtils.cleanString(uniqueId, patternsToRemove);

        }
        
        return producerAddress;
    }


    /**
     *********************************************************
     * @methodName      : createCarrierAppointmentRecord
     * @description     : Creates a carrier appointment record from an APPOINTMENT node.
     * @param appointment : APPOINTMENT node containing carrier appointment information.
     * @param stateCode : The state code for the appointment.
     * @return          : A populated d4c_CarrierAppointment__c record.
     *********************************************************
     **/
    private d4c_CarrierAppointment__c createCarrierAppointmentRecord(EntityInfoDTO.APPOINTMENT appointment, String stateCode) {
        if (appointment == null) {
            return null;
        }
        
        d4c_CarrierAppointment__c carrierApp = new d4c_CarrierAppointment__c();
        
        // Map basic appointment fields
        carrierApp.d4c_StateOrProvinceCode__c = stateCode;
        carrierApp.d4c_CountyCode__c = appointment.COUNTY_CODE;
        carrierApp.d4c_AppointerStateCOID__c = appointment.APPOINTER_STATE_CO_ID;
        carrierApp.d4c_StatusCode__c = appointment.STATUS;
        carrierApp.d4c_TerminationReason__c = StringUtils.truncateField(appointment.TERMINATION_REASON, 255);
        
        // Format and parse dates
        if (String.isNotBlank(appointment.STATUS_REASON_DATE)) {
            String formattedStatusReasonDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(appointment.STATUS_REASON_DATE, '/', '-')
            );

            carrierApp.d4c_StatusReasonDate__c = DateUtils.safeParseDateFromString(formattedStatusReasonDate);
        }
        
        if (String.isNotBlank(appointment.APPONT_RENEWAL_DATE)) {
            String formattedRenewalDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(appointment.APPONT_RENEWAL_DATE, '/', '-')
            );

            carrierApp.d4c_RenewalDate__c = DateUtils.safeParseDateFromString(formattedRenewalDate);
        }
        
        return carrierApp;
    }

    /**
     *********************************************************
     * @methodName      : createCarrierRecord
     * @description     : Creates a carrier record from an APPOINTMENT node.
     * @param appointment : APPOINTMENT node containing carrier information.
     * @return          : A populated d4c_Carrier__c record.
     *********************************************************
     **/
    private d4c_Carrier__c createCarrierRecord(EntityInfoDTO.APPOINTMENT appointment) {
        if (appointment == null || (String.isBlank(appointment.COCODE) && String.isBlank(appointment.FEIN))) {
            return null;
        }
        
        d4c_Carrier__c carrier = new d4c_Carrier__c();
        
        // Set the key fields
        carrier.d4c_CoCode__c = appointment.COCODE;
        carrier.d4c_FullName__c = StringUtils.truncateField(appointment.COMPANY_NAME, 255);
        carrier.Name = StringUtils.truncateField(appointment.COMPANY_NAME, 80);
        carrier.d4c_FEIN__c = StringUtils.truncateField(StringUtils.swapCharacters(appointment.FEIN, '-', ''), 9);

        // Concatenate CoCode and FEIN
        String uniqueIdentifier = StringUtils.safeParseNullString(carrier.d4c_CoCode__c) + StringUtils.safeParseNullString(carrier.d4c_FEIN__c);
        carrier.d4c_UniqueIdentifier__c = uniqueIdentifier;

        return carrier;
    }

    /**
     *********************************************************
     * @methodName      : createLineOfAuthorityRecord
     * @description     : Creates a line of authority record from a DETAIL node.
     * @param detail    : DETAIL node containing line of authority information.
     * @param licenseUniqueId : The license unique Id to associate with this line of authority.
     * @param stateCode : The state code for the license.
     * @return          : A populated d4c_LineOfAuthority__c record.
     *********************************************************
     **/
    private d4c_LineOfAuthority__c createLineOfAuthorityRecord(EntityInfoDTO.DETAIL detail, String licenseUniqueId, String stateCode) {
        if (detail == null) {
            return null;
        }
        
        d4c_LineOfAuthority__c loa = new d4c_LineOfAuthority__c();
        
        // Set the license lookup using external ID
        loa.d4c_License__r = new d4c_License__c(d4c_UniqueIdentifier__c = licenseUniqueId);
        
        // Map fields from DETAIL to d4c_LineOfAuthority__c
        loa.d4c_LineOfAuthorityCode__c = detail.LOA_CODE;
        loa.d4c_LineOfAuthorityDescription__c = StringUtils.truncateField(detail.LOA, 255);
        loa.d4c_StateOrProvinceCode__c = stateCode;
        loa.d4c_StateOrProvinceName__c = stateCode;
        loa.d4c_StatusCode__c = detail.STATUS;
        loa.d4c_StatusReasonCode__c = detail.STATUS_REASON;
        
        // Map CE (Continuing Education) fields if available
        loa.d4c_CEStatusDescription__c = StringUtils.truncateField(detail.CE_COMPLIANCE, 255);
        loa.d4c_CEUnitsRequiredMeasure__c = detail.CE_CREDITS_NEEDED;

        // Format and parse dates
        if (String.isNotBlank(detail.AUTHORITY_ISSUE_DATE)) {
            String formattedIssueDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(detail.AUTHORITY_ISSUE_DATE, '/', '-')
            );

            loa.d4c_IssueDate__c = DateUtils.safeParseDateFromString(formattedIssueDate);
        }

        if (String.isNotBlank(detail.STATUS_REASON_DATE)) {
            String formattedIssueDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(detail.STATUS_REASON_DATE, '/', '-')
            );

            loa.d4c_StartDate__c = DateUtils.safeParseDateFromString(formattedIssueDate);
        }

        if (String.isNotBlank(detail.CE_RENEWAL_DATE)) {
            String formattedIssueDate = StringUtils.convertToISODateFormat(
                StringUtils.swapCharacters(detail.CE_RENEWAL_DATE, '/', '-')
            );

            loa.d4c_CERenewalDate__c = DateUtils.safeParseDateFromString(formattedIssueDate);
        }
        
        
        return loa;
    }

    /**
     *********************************************************
     * @methodName      : createLicenseRecord
     * @description     : Creates a license record from license data.
     * @param license   : LICENSE node from the DTO.
     * @param stateCode : State code from the STATE node attributes.
     * @return          : A populated d4c_License__c record.
     *********************************************************
     **/
    private d4c_License__c createLicenseRecord(EntityInfoDTO.LICENSE license, String stateCode) {
        if (license == null) {
            return null;
        }
        
        d4c_License__c licenseRecord = new d4c_License__c();
        
        // Set the entity lookup using external ID
        licenseRecord.d4c_Entity__r = new d4c_Entity__c(d4c_NPN__c = entityNPN);
        
        // Set basic license fields
        licenseRecord.d4c_LicenseNumber__c = license.LICENSE_NUM;
        licenseRecord.d4c_StateOrProvinceCode__c = stateCode;
        licenseRecord.d4c_StateOrProvinceName__c = stateCode;
        licenseRecord.d4c_LicenseClassCode__c = license.LICENSE_CLASS_CODE;
        licenseRecord.d4c_LicenseClassDescription__c = StringUtils.truncateField(license.LICENSE_CLASS, 255);
        licenseRecord.d4c_StatusCode__c = license.ACTIVE == 'Yes' ? 'Active' : 'Inactive';
        licenseRecord.d4c_ResidentLicenseIndicator__c = license.RESIDENCY_STATUS == 'R' ? true: false;
        licenseRecord.d4c_TypeCode__c = 'Entity';
        
        // Format and parse dates
        String formattedIssueDate = StringUtils.convertToISODateFormat(
            StringUtils.swapCharacters(license.DATE_ISSUE_LICENSE_ORIG, '/', '-')
        );

        licenseRecord.d4c_IssueDate__c = DateUtils.safeParseDateFromString(formattedIssueDate);
        
        String formattedExpirationDate = StringUtils.convertToISODateFormat(
            StringUtils.swapCharacters(license.DATE_EXPIRE_LICENSE, '/', '-')
        );

        licenseRecord.d4c_EndDate__c = DateUtils.safeParseDateFromString(formattedExpirationDate);

        String formattedDateUpdated = StringUtils.convertToISODateFormat(
            StringUtils.swapCharacters(license.DATE_UPDATED, '/', '-')
        );

        licenseRecord.d4c_AsOfDate__c = DateUtils.safeParseDateFromString(formattedDateUpdated);
                
        return licenseRecord;
    }

    /**
     *********************************************************
     * @methodName      : createCommunicationJunctions
     * @description     : Creates junction records linking the Entity to Communication records.
     *                    Called after Communications are upserted and have IDs.
     * @return          : List of junction records to insert
     *********************************************************
     **/
    private List<d4c_Entity_Communication_Junction__c> createCommunicationJunctions() {
        List<d4c_Entity_Communication_Junction__c> junctions = new List<d4c_Entity_Communication_Junction__c>();

        for (d4c_ProducerCommunication__c comm : producerCommunications) {
            d4c_Entity_Communication_Junction__c junction = new d4c_Entity_Communication_Junction__c();
            junction.d4c_Entity__c = entity.Id;
            junction.d4c_NIPR_Communication__c = comm.Id;
            // UniqueIdentifier will be auto-populated by trigger
            junctions.add(junction);
        }

        return junctions;
    }

    /**
     *********************************************************
     * @methodName      : createAddressJunctions
     * @description     : Creates junction records linking the Entity to Address records.
     *                    Called after Addresses are upserted and have IDs.
     * @return          : List of junction records to insert
     *********************************************************
     **/
    private List<d4c_Entity_Address_Junction__c> createAddressJunctions() {
        List<d4c_Entity_Address_Junction__c> junctions = new List<d4c_Entity_Address_Junction__c>();

        for (d4c_ProducerAddress__c address : producerAddresses) {
            d4c_Entity_Address_Junction__c junction = new d4c_Entity_Address_Junction__c();
            junction.d4c_Entity__c = entity.Id;
            junction.d4c_NIPR_Address__c = address.Id;
            // UniqueIdentifier will be auto-populated by trigger
            junctions.add(junction);
        }

        return junctions;
    }

    /**
     *********************************************************
     * @methodName      : deleteExistingRelatedRecords
     * @description     : Deletes existing entity communications and addresses
     *                    associated with the NPN being processed.
     *********************************************************
     **/
    private void deleteExistingRelatedRecords() {
        try {
            // Use a set for the NPN to pass to selector methods
            Set<String> npnSet = new Set<String>{ entityNPN };
            
            // Delete existing entity communication junctions (NOT the communications themselves)
            deleteExistingCommunicationJunctions(npnSet);

            // Delete existing entity address junctions (NOT the addresses themselves)
            deleteExistingAddressJunctions(npnSet);

            // Delete existing entity licenses
            deleteExistingLicenses(npnSet);

            // Delete existing Carrier Appointments
            deleteExistingCarrierAppointments(npnSet);
        } catch(Exception e) {
            throw new EntityInfoDMLException(e.getMessage() + '\n' + JSON.serialize(e.getStackTraceString()));
        }
    }

    /**
     *********************************************************
     * @methodName      : deleteExistingCommunicationJunctions
     * @description     : Deletes existing entity-communication junction records.
     *                    The actual communication records are NEVER deleted (many-to-many pattern).
     * @param npnSet    : Set of entity NPNs to query for related junctions.
     *********************************************************
     **/
    private void deleteExistingCommunicationJunctions(Set<String> npnSet) {
        // Query for existing junctions
        EntityCommunicationJunctionSelector junctionSelector = new EntityCommunicationJunctionSelector();
        List<d4c_Entity_Communication_Junction__c> existingJunctions = junctionSelector.getJunctionsByEntityNPNs(npnSet);

        if (!existingJunctions.isEmpty()) {
            Logger.debug(CLASS_NAME, 'deleteExistingCommunicationJunctions', 'Deleting ' + existingJunctions.size() + ' existing Entity-Communication junction records for NPN: ' + entityNPN,
                null,
                null);

            delete existingJunctions;
        }
    }

    /**
     *********************************************************
     * @methodName      : deleteExistingAddressJunctions
     * @description     : Deletes existing entity-address junction records.
     *                    The actual address records are NEVER deleted (many-to-many pattern).
     * @param npnSet    : Set of entity NPNs to query for related junctions.
     *********************************************************
     **/
    private void deleteExistingAddressJunctions(Set<String> npnSet) {
        // Query for existing junctions
        EntityAddressJunctionSelector junctionSelector = new EntityAddressJunctionSelector();
        List<d4c_Entity_Address_Junction__c> existingJunctions = junctionSelector.getJunctionsByEntityNPNs(npnSet);

        if (!existingJunctions.isEmpty()) {
            Logger.debug(CLASS_NAME, 'deleteExistingAddressJunctions', 'Deleting ' + existingJunctions.size() + ' existing Entity-Address junction records for NPN: ' + entityNPN,
                null,
                null);

            delete existingJunctions;
        }
    }

    /**
     *********************************************************
     * @methodName      : deleteExistingLicenses
     * @description     : Deletes existing entity licenses associated with the NPNs.
     * @param npnSet    : Set of entity NPNs to query for related licenses.
     *********************************************************
     **/
    private void deleteExistingLicenses(Set<String> npnSet) {
        // Query for existing entity addresses
        LicenseSelector LicenseSelector = new LicenseSelector();
        List<d4c_License__c> existinglicenses = LicenseSelector.getLicensesByEntityNpn(npnSet);
        
        if (!existinglicenses.isEmpty()) {
            Logger.debug(CLASS_NAME, 'deleteExistingProducerAddresses', 'Deleting ' + existinglicenses.size() + ' existing Entity Licenses records for NPN: ' + entityNPN,
                null,
                null);
            
            delete existinglicenses;
        }
    }

    /**
     *********************************************************
     * @methodName      : deleteExistingCarrierAppointments
     * @description     : Deletes existing carrier appointments associated with the NPNs.
     * @param npnSet    : Set of entity NPNs to query for related carrier appointments.
     *********************************************************
     **/
    private void deleteExistingCarrierAppointments(Set<String> npnSet) {
        // Query for existing carrier appointments
        CarrierAppointmentSelector appointmentSelector = new CarrierAppointmentSelector();
        List<d4c_CarrierAppointment__c> existingAppointments = appointmentSelector.getCarrierAppointmentsByEntityNpn(npnSet);
        
        if (!existingAppointments.isEmpty()) {
            Logger.debug(CLASS_NAME, 'deleteExistingProducerAddresses', 'Deleting ' + existingAppointments.size() + ' existing Carrier Appointment records for NPN: ' + entityNPN,
                null,
                null);
            
            delete existingAppointments;
        }
    }

    /**
     *********************************************************
     * @methodName      : syncDataWithSalesforce
     * @description     : Performs DML operations to sync all processed data to Salesforce.
     *********************************************************
     **/
    private void syncDataWithSalesforce() {
        String methodName = 'syncDataWithSalesforce';
        
        try {
            Logger.info(CLASS_NAME, methodName, 'Starting deletion of existing related records',
                    'NPN: ' + entityNPN, null);
            
            deleteExistingRelatedRecords();

            ListUtils.deduplicateByField(producerCommunications, 'd4c_UniqueIdentifier__c');
            ListUtils.deduplicateByField(producerAddresses, 'd4c_UniqueIdentifier__c');
            ListUtils.deduplicateByField(carriers, 'd4c_UniqueIdentifier__c');
            ListUtils.deduplicateByField(licenses, 'd4c_UniqueIdentifier__c');
            ListUtils.deduplicateByField(licenseLoas, 'd4c_UniqueIdentifier__c');
            ListUtils.deduplicateByField(carrierAppointments, 'd4c_UniqueIdentifier__c');
            
            Logger.info(CLASS_NAME, methodName, 'Beginning upsert operations for entity',
                    'NPN: ' + entityNPN, null);
            
            upsert entity d4c_NPN__c;
            
            Logger.info(CLASS_NAME, methodName, 'Entity Communication records for Upsert', 
                    'Count: ' + producerCommunications.size() + ', NPN: ' + entityNPN, null);
            
            upsert producerCommunications d4c_UniqueIdentifier__c;

            // Create junction records linking Entity to Communications
            List<d4c_Entity_Communication_Junction__c> communicationJunctions = createCommunicationJunctions();
            Logger.info(CLASS_NAME, methodName, 'Entity-Communication Junction records for Insert',
                    'Count: ' + communicationJunctions.size() + ', NPN: ' + entityNPN, null);
            insert communicationJunctions;

            Logger.info(CLASS_NAME, methodName, 'Entity Address records for Upsert',
                    'Count: ' + producerAddresses.size() + ', NPN: ' + entityNPN, null);

            upsert producerAddresses d4c_UniqueIdentifier__c;

            // Create junction records linking Entity to Addresses
            List<d4c_Entity_Address_Junction__c> addressJunctions = createAddressJunctions();
            Logger.info(CLASS_NAME, methodName, 'Entity-Address Junction records for Insert',
                    'Count: ' + addressJunctions.size() + ', NPN: ' + entityNPN, null);
            insert addressJunctions;

            Logger.info(CLASS_NAME, methodName, 'Carrier records for Upsert', 
                    'Count: ' + carriers.size() + ', NPN: ' + entityNPN, null);
            
            upsert carriers d4c_UniqueIdentifier__c;
            
            Logger.info(CLASS_NAME, methodName, 'Entity License records for Upsert', 
                    'Count: ' + licenses.size() + ', NPN: ' + entityNPN, null);
            
            upsert licenses d4c_UniqueIdentifier__c;
            
            Logger.info(CLASS_NAME, methodName, 'Line Of Authority records for Upsert', 
                    'Count: ' + licenseLoas.size() + ', NPN: ' + entityNPN, null);
            
            upsert licenseLoas d4c_uniqueIdentifier__c;
            
            Logger.info(CLASS_NAME, methodName, 'Carrier Appointment records for Upsert',
                    'Count: ' + carrierAppointments.size() + ', NPN: ' + entityNPN, null);

            upsert carrierAppointments d4c_UniqueIdentifier__c;

            Logger.info(CLASS_NAME, methodName, 'Successfully completed all upsert operations',
                    'NPN: ' + entityNPN + ', Total records processed: ' +
                    (1 + producerCommunications.size() + producerAddresses.size() +
                        producerCommunications.size() + producerAddresses.size() + // Junction records
                        carriers.size() + licenses.size() + licenseLoas.size() +
                        carrierAppointments.size()), null);
            
        } catch(Exception e) {
            Logger.error(CLASS_NAME, methodName, 
                        'Error syncing data with Salesforce', 
                        'NPN: ' + entityNPN + ', Error: ' + e.getMessage(), 
                        e.getStackTraceString(), null);
            
            // Commit logs before throwing the exception to ensure they're saved
            Logger.commitAsync();
            
            throw new EntityInfoDMLException(e.getMessage() + '\n' + JSON.serialize(e.getStackTraceString()));
        }
    }

    public class EntityInfoDMLException extends Exception {}

    public class EntityInfoAPIException extends Exception {} 
}