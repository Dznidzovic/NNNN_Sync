/**
 *********************************************************
 * Apex Class Name    : EntityInfoDTO
 * Created Date       : 04-12-2025
 * @description       : Data Transfer Object (DTO) for representing Entity Info API responses.
 *                      This class defines the structure for processing both Individual (Agent) 
 *                      and Firm (Agency) data from NIPR Entity Info API. It maps XML elements
 *                      to Apex objects for easy processing in Salesforce.
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author             Modification
 * 1.0   04-12-2025   Dev4Clouds    Initial Version
 *********************************************************
 **/
public class EntityInfoDTO {
    // Non XML related elements for response processing
    public Boolean isSuccess;
    public NIPREnums.EntityInfoError errorType;
    public String errorMessage;

    // Root-level elements
    public TRANSACTION_TYPE TRANSACTION_TYPE;
    public PRODUCER PRODUCER;
    public ERROR ERROR;

    // Contains error information if the transaction returns an error
    public class ERROR {
        public String DESCRIPTION;
    }

    // Contains the type of transaction (INDIVIDUAL, FIRM, or ERROR)
    public class TRANSACTION_TYPE {
        public String TYPE;
    }

    // Contains either Individual or Firm data based on entity type
    public class PRODUCER {
        public INDIVIDUAL INDIVIDUAL;
        public FIRM FIRM;
    }

    // Represents an Individual (Agent) producer with biographical and licensing information
    public class INDIVIDUAL {
        public ENTITY_BIOGRAPHIC ENTITY_BIOGRAPHIC;
        public PRODUCER_LICENSING PRODUCER_LICENSING;
    }

    // Represents a Firm (Agency) producer with biographical and licensing information
    public class FIRM {
        public ENTITY_BIOGRAPHIC ENTITY_BIOGRAPHIC;
        public PRODUCER_LICENSING PRODUCER_LICENSING;
    }

    // Contains biographical information, addresses, and contact information
    public class ENTITY_BIOGRAPHIC {
        public BIOGRAPHIC BIOGRAPHIC;
        public ADDRESSES ADDRESSES;
        public CONTACT_INFOS CONTACT_INFOS;
    }

    // Contains basic biographical data - differs between Individual and Firm
    public class BIOGRAPHIC {
        // Individual fields
        public String ID_SSN;
        public String NAME_LAST;
        public String NAME_FIRST;
        public String NAME_MIDDLE;
        public String NAME_SUFFIX;
        public String DATE_BIRTH;
        public String NPN;
        
        // Firm fields
        public String ID_FEIN;
        public String NAME_COMPANY;
        public String STATE_CO_ID;
        public String STATE_DOMICILE;
        
        public OTHER_NAME OTHER_NAME;
    }

    // Contains alternate name information for the entity
    public class OTHER_NAME {
        public STATE_OTHER_NAME STATE;
    }

    // State-specific other name information
    public class STATE_OTHER_NAME {
        public NAME NAME;
        public StateOtherNameAttributes attributes;
    }

    // Contains the state code for the other name
    public class StateOtherNameAttributes {
        public String name;
    }

    // Contains the alternate name value and type
    public class NAME {
        public String value;
        public NameAttributes attributes;
    }

    // Type of alternate name (Primary, DBA, etc.)
    public class NameAttributes {
        public String type;
    }

    // Contains a list of addresses organized by state
    public class ADDRESSES {
        public List<STATE_ADDRESS> STATE;
    }

    // State-specific address information
    public class STATE_ADDRESS {
        public List<ADDRESS> ADDRESS;
        public StateAddressAttributes attributes;
    }

    // Contains the state code for the address
    public class StateAddressAttributes {
        public String name;
    }

    // Contains detailed address information
    public class ADDRESS {
        public String DATE_UPDATED;
        public String ADDRESS_TYPE_CODE;
        public String ADDR_TYPE;
        public String ADDR_LINE_1;
        public String ADDR_LINE_2;
        public String ADDR_LINE_3;
        public String NAME_CITY;
        public String NAME_STATE;
        public String ZIP;
        public String COUNTRY;
    }

    // Contains contact information organized by state
    public class CONTACT_INFOS {
        public List<STATE_CONTACT> STATE;
    }

    // State-specific contact information
    public class STATE_CONTACT {
        public List<CONTACT_INFO> CONTACT_INFO;
        public StateContactAttributes attributes;
    }

    // Contains the state code for the contact information
    public class StateContactAttributes {
        public String name;
    }

    // Contains detailed contact information (phone, fax, email)
    public class CONTACT_INFO {
        public String BUSINESS_PHONE;
        public String BUSINESS_PHONE_UPDATE_DATE;
        public String FAX;
        public String FAX_UPDATE_DATE;
        public String BUSINESS_EMAIL;
        public String BUSINESS_EMAIL_UPDATE_DATE;
    }

    // Contains licensing and appointment information
    public class PRODUCER_LICENSING {
        public LICENSE_INFORMATION LICENSE_INFORMATION;
        //public String CLEARANCE_CERTIFICATION_INFO;
        //public REGULATORY_ACTION REGULATORY_ACTION;
        //public NASD_EXAM NASD_EXAM;
    }

    // Contains license information organized by state
    public class LICENSE_INFORMATION {
        public List<STATE_LICENSE> STATE;
    }

    // State-specific license information
    public class STATE_LICENSE {
        public List<LICENSE> LICENSE;
        public APPOINTMENT_INFORMATION APPOINTMENT_INFORMATION;
        public StateLicenseAttributes attributes;
    }

    // Contains the state code for the license information
    public class StateLicenseAttributes {
        public String name;
    }

    // Contains detailed license information
    public class LICENSE {
        public String LICENSE_NUM;
        public String DATE_UPDATED;
        public String DATE_ISSUE_LICENSE_ORIG;
        public String DATE_EXPIRE_LICENSE;
        public String LICENSE_CLASS;
        public String LICENSE_CLASS_CODE;
        public String RESIDENCY_STATUS;
        public String ACTIVE;
        //public String ADHS;
        public DETAILS DETAILS;
    }

    // Contains a list of lines of authority details
    public class DETAILS {
        public List<DETAIL> DETAIL;
    }

    // Contains line of authority information
    public class DETAIL {
        public String LOA;
        public String LOA_CODE;
        public String AUTHORITY_ISSUE_DATE;
        public String STATUS;
        public String STATUS_REASON;
        public String STATUS_REASON_DATE;
        public String CE_COMPLIANCE;
        public String CE_RENEWAL_DATE;
        public String CE_CREDITS_NEEDED;
    }

    // Contains a list of carrier appointments
    public class APPOINTMENT_INFORMATION {
        public List<APPOINTMENT> APPOINTMENT;
    }

    // Contains detailed carrier appointment information
    public class APPOINTMENT {
        public String COMPANY_NAME;
        public String APPOINTER_STATE_CO_ID;
        public String FEIN;
        public String COCODE;
        public String LINE_OF_AUTHORITY;
        public String LOA_CODE;
        public String STATUS;
        public String TERMINATION_REASON;
        public String STATUS_REASON_DATE;
        public String APPONT_RENEWAL_DATE;
        public String COUNTY_CODE;
        public String Agency_Affiliations;
    }

    // Contains regulatory action information organized by state
    public class REGULATORY_ACTION {
        public List<STATE_REGULATORY> STATE;
    }

    // Contains detailed regulatory action information
    public class STATE_REGULATORY {
        public String ACTION_ID;
        public String ORIGIN_OF_ACTION;
        public String REASON_FOR_ACTION;
        public String DISPOSITION;
        public String DATE_OF_ACTION;
        public String EFFECTIVE_DATE;
        public String ENTER_DATE;
        public String FILE_REF;
        public String PENALTY_FINE_FORFEITURE;
        public String LENGTH_OF_ORDER;
        public StateRegulatroyAttibutes attributes;
    }

    // Contains the state code for the regulatory action
    public class StateRegulatroyAttibutes {
        public String name;
    }
}