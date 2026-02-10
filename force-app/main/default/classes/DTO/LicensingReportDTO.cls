/**
 *********************************************************
 * Apex Class Name    : LicensingReportDTO
 * Created Date       : 03-18-2025
 * @description       : Data Transfer Object (DTO) for representing Licensing Report details 
 *                      extracted from the PDB Alerts API response. This class defines the 
 *                      structure for message headers, results, licensing reports, and associated 
 *                      entities such as persons, organizations, and addresses. This class is used to deserialize XML string into Apex objects
 *                      FOR MORE DETAILS SEE THE FOLLOWING LINK -> https://wiki.nipr.com/display/NTD/PDB+Alerts+Schema
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-18-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
public class LicensingReportDTO {
    public Boolean isSuccess;
    public NIPREnums.PDBAlertError errorType;
    public String errorMessage;

    public LicensingReportProcessResult licensingReportProcessResult;

    public class LicensingReportProcessResult {
        public MessageHeader messageHeader;
        public MessageResult messageResult;
        public LicensingReport licensingReport;
    }
    
    public class MessageHeader {
        public String messageId;
        public String correlationId;
        public String messageDateTime;
        public Integer messageDocumentCount;
    }
    
    public class MessageResult {
        public String statusCode;
        public MessageDocumentResult messageDocumentResult;
    }
    
    public class MessageDocumentResult {
        public String statusCode;
        public String messageDocumentReferences;
        public String successCode;
    }
    
    public class LicensingReport {
        // List of Addresses in the report with their data, which will be referenced by multiple agents and agencies
        public List<Address> addressList;
        // List that holds only agent records(Person nodes in NIPR response). Used for easier processing later on
        public List<Person> personList;
        // List that holds only agent records(Organization nodes in NIPR response of type NAICEntityCode). Used for easier processing later on
        public List<Organization> agencyList;
        // List of agents and agencies
        public List<NIPREntity> producerList;
        // List that holds only agent records(Organization nodes in NIPR response of type NAICInsurerCode). Used for easier processing later on
        public List<Organization> carrierList;
        // list of agencies and carriers
        public List<Organization> organizationList;
        public String documentId;
        public String typeCode;
        public List<JurisdictionReport> jurisdictionReportList;

        // NEW: Tracks which producer+state combinations have data in the payload (eligible for deletion logic)
        public EligibleRecordsForDeletion eligibleRecordsForDeletion;

        public LicensingReport() {
            this.eligibleRecordsForDeletion = new EligibleRecordsForDeletion();
        }
    }

    // Represents an Address
    public class Address {
        public String key;
        public String lineOne;
        public String lineTwo;
        public String lineThree;
        public String cityName;
        public String stateOrProvinceCode;
        public String postalCode;
        public String countryCode;
    }
    
    // Represents an Agent
    public class Person extends NIPREntity {
        public ExternalIdentifier externalIdentifier;
        public PersonName personName;
        public PersonCommunication personCommunication;
        public BusinessCommunication businessCommunication;
        public String birthDate;
    }

    // Represents an Agency
    public virtual class Organization extends NIPREntity {
        public List<ExternalIdentifier> externalIdentifierList;
        public List<OrganizationName> organizationNameList;
        public List<AssignedIdentifier> assignedIdentifierList;
        public OrganizationCommunication organizationCommunication;
    }

    // Person and Organization Nodes extend the same NIPREntity node which will allow us to use same methods to process them later on in our services as they contain overlapping data
    // This node represents the base of classes that will represent agents/agencies/carriers
    public virtual class NIPREntity {
        public String key;
        public List<String> combinedKeys;
        public String mainIdentifier;
        public String mainIdentifierType;
        // Boolean value to indicate if no actual data has been returned for us and the entity information is not present in the response, so we assume it exists in Salesforce
        public Boolean isExisting = false;
    }

    /**
     * Tracks which producer+state combinations are eligible for deletion logic.
     * Uses Maps for O(1) lookup performance instead of looping through lists.
     * Structure: Map<EntityKeyReference, Set<StateCodes>>
     *
     * This allows the service to only query and compare records that actually have data in the NIPR payload.
     */
    public class EligibleRecordsForDeletion {
        // Map of producer key reference -> states with license data
        // Key: PersonPRI704070910 or OrgPRI123456789
        // Value: Set of state codes (e.g., {'CA', 'NY', 'TX'})
        public Map<String, Set<String>> eligibleLicenses;

        // Map of producer key reference -> states with carrier appointment data
        public Map<String, Set<String>> eligibleCarrierAppointments;

        public EligibleRecordsForDeletion() {
            this.eligibleLicenses = new Map<String, Set<String>>();
            this.eligibleCarrierAppointments = new Map<String, Set<String>>();
        }
    }

    // This is a wrapper node in NIPR api response containing License, LOA, Carrier Appointment data and more
    public class JurisdictionReport {
        public String personReference;
        public String organizationReference;
        public List<JurisdictionReportItem> jurisdictionReportItemList;
    }
    
    // This is a wrapper node in NIPR api response containing License, LOA, Carrier Appointment data and more
    public class JurisdictionReportItem {
        public String key;
        public String stateOrProvinceCode;
        public Licensee licensee;
        public List<RegulatoryAction> regulatoryActions;
    }
    
    // This is a wrapper node in NIPR api response containing License, LOA, Carrier Appointment data and more
    public class Licensee {
        public List<String> licenseeReference;
        public List<InsuranceLicense> insuranceLicenses;
        public List<InsuranceAppointment> insuranceAppointments;
    }

    // Contains Insurance License and LOA data
    public class InsuranceLicense {
        public Boolean residentLicenseIndicator;
        public Boolean qualifyingInsuranceLicenseIndicator;
        public String typeCode;
        public License license;
        public List<LineOfAuthority> lineOfAuthorityList;
    }
    
    // Contains Insurance License Data
    public class License {
        public String key;
        public String licenseNumberId;
        public String startDate;
        public String endDate;
        public String statusCode;
        public String statusDescription;
        public String issueDate;
        public String licenseClassCode;
        public String licenseClassDescription;
        public String stateOrProvinceCode;
        public String stateOrProvinceName;
        public ContinuingEducation continuingEducation;
        public String asOfDate;
    }

    // A wrapper node containing Continuing Education data which can be found in License and LOA data
    public class ContinuingEducation {
        public String statusCode;
        public String stateOrProvinceCode;
        public String statusDescription;
        public String startDate;
        public String endDate;
        public String periodDuration;
        public String unitsRequiredMeasure;
        public String unitsRemainingMeasure;
        public String asOfDate;
    }
    
    // Contains LOA data that can be found in License and Carrier Appointments data
    public class LineOfAuthority {
        public String issueDate;
        public String stateOrProvinceCode;
        public String stateOrProvinceName;
        public String lineOfAuthorityCode;
        public String lineOfAuthorityDescription;
        public String renewalDate;
        public String statusCode;
        public String statusReasonCode;
        public String statusReasonDescription;
        public String statusDescription;
        public String startDate;
        public ContinuingEducation continuingEducation;
    }

    // Contains Carrier Appointment data
    public class InsuranceAppointment {
        public String stateOrProvinceCode;
        public String insurerReferences;
        public String licenseeReferences;
        public String statusCode;
        public String statusReasonDescription;
        public String statusDescription;
        public String statusReasonCode;
        public String terminationEffectiveDate;
        public String appointmentEffectiveDate;
        public String asOfDate;
        public List<LineOfAuthority> linesOfAuthority;
    }

    // Contains Regulatory Action data - Not yet utilized
    public class RegulatoryAction {
        public String personReference;
        public String organizationReference;
        public ExternalIdentifier externalIdentifier;
        public AssignedIdentifier assignedIdentifier;
        public String stateOrProvinceCode;
        public String penaltyAmount;
        public String actionInceptionCode;
        public String actionReasonDescription;
        public String disposition;
        public String actionDate;
        public String actionRegulatoryEntryDate;
        public RegulatoryActionPeriod regulatoryActionPeriod;
        public String asOfDate;
    }

    public class RegulatoryActionPeriod {
        public String startDate;
        public String periodDuration;
    }

    // IMPORTANT!!! - Contains unique identifiers for All Enities in the PDB Alerts Report.
    // Represents the person’s NPN if contained within the Person tag and the TypeCode attribute is “NAICEntityCode”.
    // Represents the Organization NPN (Agency on NIPR XML) if contained within the Organization tag and the TypeCode attribute is “NAICEntityCode”.
    // Represents the Organization FEIN (Agency on NIPR XML) if contained within the Organization tag and the TypeCode attribute is “FEINId”.
    // Represents the Organization COCODE (Insurer on NIPR XML) if contained within the Organization tag and the TypeCode attribute is “NAICInsurerCode”.
    // Represents the Organization FEIN (Insurer on NIPR XML) if contained within the Organization tag and the TypeCode attribute is “FEINId”.
    // Represents the jurisdiction-assigned file reference number for the regulatory action if contained within the RegulatoryAction tag and the TypeCode attribute is “RegulatoryAgencyFileReferenceNumber”.
    // Represents the jurisdiction-assigned state RIRS Id if contained within the RegulatoryAction tag and the TypeCode attribute is “RegulatoryAgencyRIRSId”
    public class ExternalIdentifier {
        public String typeCode;
        public String id;
    }
    
    // Represents Agent Name data
    public class PersonName {
        public String typeCode;
        public String fullName;
        public String surName;
        public String givenName;
        public String otherGivenName;
        public String middleName;
        public String nameSuffix;
    }

    // Represents Organization Name Data
    public class OrganizationName {
        public String typeCode;
        public String fullName;
    }
    
    // All Communication Nodes represent Agent, Agency and Carrier data. They all extend the same node as the processing for all of them is overlapping and we can utilize the same methods later on
    public virtual class EntityCommunication {
        public List<Telephone> telephoneList;
        public List<Email> emailList;
        public EntityAddress mailingAddress;
    }

    public class PersonCommunication extends EntityCommunication {
        public EntityAddress residentialAddress;
    }
    
    public class BusinessCommunication extends EntityCommunication {
        public EntityAddress physicalAddress;
    }

    public class OrganizationCommunication extends EntityCommunication {
        public EntityAddress principalAddress;
        public EntityAddress physicalAddress;
    }
    
    // Represents phone data for multiple entities
    public class Telephone {
        public String typeCode;
        public String phoneNumber;
    }
    
    // Represents email data for multiple entities
    public class Email {
        public String typeCode;
        public String emailAddress;
    }
    
    // Represents data that connects a NIPR entity(agent, agency and carrier) to an Address node which contains the actual data
    public class EntityAddress {
        public String asOfDate;
        public String addressReferences;
    }

    public class AssignedIdentifier {
        public String roleCode;
        public String id;
    }
}