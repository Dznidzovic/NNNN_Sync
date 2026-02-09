/*******************************************************************
 * Apex Class Name    : RetrieveEntityInfoApiData
 * Created Date       : 04-01-2025
 * @description       : Retrieves and parses the NIPR Entity Info API XML response.
 *                      The response is mapped into the EntityInfoDTO Apex class.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-01-2025   Stefan Nidzovic          Initial Version
 * 1.1   10-24-2025   Stefan Nidzovic          Added Exclude Carrier Appointments logic for large payloads
 *******************************************************************
 **/
public with sharing class RetrieveEntityInfoApiData {
    private EntityInfoDTO entityInfoDTO = new EntityInfoDTO();

    // For Logging Purposes
    String CLASS_NAME = 'RetrieveEntityInfoApiData';
    private final Integer CARRIER_APPT_FILTER_THRESHOLD = 2400000;

    // Flag indicating carrier appointments should be excluded - set when payload exceeds threshold
    public Boolean shouldExcludeCarrierAppointments = false;
    
    @TestVisible
    private static Boolean testLargeProducer = false;

    /**
     *********************************************************
     * @methodName      : retrieveData
     * @description     : Performs GET request to NIPR Entity Info API using
     *                   BaseApiInvoker, parses the XML response, and maps
     *                   it into an EntityInfoDTO object.
     * @param          : entityNPN - The NPN (ID) of the entity to retrieve.
     * @return         : EntityInfoDTO - The deserialized DTO object.
     *********************************************************
     **/
    public EntityInfoDTO retrieveData(String entityNPN) {
        String methodName = 'retrieveData';

        Logger.info(CLASS_NAME, methodName, 'Starting Entity Info API retrieval',
                'Entity NPN: ' + entityNPN, null);

        try {
            // Query existing producer to check if user manually set exclude flag
            // Producer will always exist when this callout runs
            ProducerSelector producerSelector = new ProducerSelector();
            List<d4c_Producer__c> existingProducers = producerSelector.getProducersByNPNs(new Set<String>{ entityNPN });
            Boolean existingExcludeValue = false;
            if (!existingProducers.isEmpty()) {
                existingExcludeValue = existingProducers[0].d4c_ExcludeCarrierAppointments__c;
            }

            // Build the HTTP Request
            BaseApiInvoker invoker = new BaseApiInvoker()
                .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
                .setNamedCredential('NIPR_EntityInfo_API')
                .setRestMethod(BaseApiInvoker.RestMethod.GET)
                .setResource('/entityinfo_xml.cgi')
                .setQueryParams(new Map<String, String>{ 'id_entity' => entityNPN })
                .setTimeout(60000);

            // Execute request
            Logger.debug(CLASS_NAME, methodName, 'Sending request to NIPR Entity Info API', null, null);
            invoker.sendRequest();

            String apiResponse = String.valueOf(invoker.getApiResponse());

            // Determine if carrier appointments should be excluded
            // If user has manually set exclude flag to true, always exclude
            // Otherwise, only exclude if payload exceeds threshold
            if (existingExcludeValue || (apiResponse.length() > CARRIER_APPT_FILTER_THRESHOLD) || (testLargeProducer && test.isRunningTest())) {
                this.shouldExcludeCarrierAppointments = true;
                apiResponse = XMLUtils.filterCarrierAppointments(apiResponse);
            }

            // Instantiate DOM class to parse XML
            DOM.Document doc = new DOM.Document();
            doc.load(apiResponse);

            Map<String, Object> jsonData = new Map<String, Object>();

            XMLUtils.convertXMLToMap(doc.getRootElement(), jsonData);
            
            // Normalize the nodes, some nodes can be singles or lists, and we need to convert them all to lists so we can deserialize into DTO
            normalizeData(jsonData);

            entityInfoDTO = (EntityInfoDTO) JSON.deserialize(JSON.serialize(jsonData), EntityInfoDTO.class);
            
            if (entityInfoDTO.ERROR != null) {
                entityInfoDTO.isSuccess = false;
                entityInfoDTO.errorMessage = EntityInfoDTO.ERROR.DESCRIPTION;
                entityInfoDTO.errorType = NIPREnums.EntityInfoError.NO_PRODUCER_DATA;
            } else {
                entityInfoDTO.isSuccess = true;
            } 
        } catch (Exception ex) {
            Logger.error(CLASS_NAME, methodName, ex, null);
            
            entityInfoDTO.isSuccess = false;
            entityInfoDTO.errorMessage = ex.getMessage();
            entityInfoDTO.errorType = NIPREnums.EntityInfoError.UNKOWN_ISSUE;
        }
                
        return entityInfoDTO;
    }

     /**
     ********************************************************
     * @Method Name    : normalizeData
     * @description    : Main normalization method that calls specific normalization
     *                   methods for different parts of the data structure.
     * @param          : jsonMap - The parsed Map<String, Object> structure.
     ********************************************************
     **/
    private void normalizeData(Map<String, Object> jsonMap) {
        try {
            // Get the entity from PRODUCER (either INDIVIDUAL or FIRM)
            Map<String, Object> entity = getEntityMap(jsonMap);
            if (entity == null) {
                return;
            }

            // Normalize entity biographic data
            normalizeEntityBiographic(entity);
            
            // Normalize producer licensing data
            normalizeProducerLicensing(entity);
            
        } catch (Exception ex) {
            // Replace with Logger.error call
            Logger.error(CLASS_NAME, 'normalizeData', ex);

            throw ex;
        }
    }
    

    /**
     ********************************************************
     * @Method Name    : getEntityMap
     * @description    : Gets the entity map (either INDIVIDUAL or FIRM) from the PRODUCER.
     * @param          : jsonMap - The parsed Map<String, Object> structure.
     * @return         : Map<String, Object> - Either INDIVIDUAL or FIRM map.
     ********************************************************
     **/
    private Map<String, Object> getEntityMap(Map<String, Object> jsonMap) {
        Map<String, Object> producer = (Map<String, Object>) jsonMap.get('PRODUCER');
        if (producer == null) {
            return null;
        }

        Map<String, Object> individual = (Map<String, Object>) producer.get('INDIVIDUAL');
        Map<String, Object> firm = (Map<String, Object>) producer.get('FIRM');
        
        if (individual != null) {
            return individual;
        } else if (firm != null) {
            return firm;
        }
        
        return null;
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeEntityBiographic
     * @description    : Normalizes the entity biographic data, specifically ADDRESSES and CONTACT_INFOS.
     * @param          : entity - The entity map (INDIVIDUAL or FIRM).
     ********************************************************
     **/
    private void normalizeEntityBiographic(Map<String, Object> entity) {
        Map<String, Object> biographic = (Map<String, Object>) entity.get('ENTITY_BIOGRAPHIC');
        if (biographic == null) {
            return;
        }

        // Add this code to handle empty OTHER_NAME
        Map<String, Object> bio = (Map<String, Object>) biographic.get('BIOGRAPHIC');

        if (bio != null) {
            normalizeOtherName(bio);
        }
        
        // Normalize ADDRESSES
        normalizeAddresses(biographic);
        
        // Normalize CONTACT_INFOS
        normalizeContactInfos(biographic);
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeOtherName
     * @description    : Normalizes the OTHER_NAME structure in BIOGRAPHIC data. Handles both empty OTHER_NAME
     *                   and OTHER_NAME with multiple STATE and NAME nodes, ensuring compatibility with the DTO structure.
     * @param          : bio - The biographic data map containing OTHER_NAME.
     ********************************************************
     **/
    private void normalizeOtherName(Map<String, Object> bio) {
        if (!bio.containsKey('OTHER_NAME')) {
            return;
        }
        
        Object otherName = bio.get('OTHER_NAME');
        
        // Case 1: OTHER_NAME is empty string or null
        if (otherName == null || (otherName instanceof String && String.isBlank((String)otherName))) {
            bio.put('OTHER_NAME', new Map<String, Object>());
        }

        // Case 2: OTHER_NAME has content but might have multiple STATE nodes
        else if (otherName instanceof Map<String, Object>) {
            Map<String, Object> otherNameMap = (Map<String, Object>) otherName;
            
            // Check if STATE is a list (multiple states) or single object
            Object stateObj = otherNameMap.get('STATE');
            if (stateObj instanceof List<Object> && !((List<Object>)stateObj).isEmpty()) {
                // Keep only the first STATE node if it's a list
                otherNameMap.put('STATE', ((List<Object>) stateObj)[0]);
            }
            
            // Now handle the case where there are multiple NAME nodes inside STATE
            if (stateObj instanceof Map<String, Object>) {
                Map<String, Object> stateMap = (Map<String, Object>) stateObj;
                Object nameObj = stateMap.get('NAME');
                
                // If NAME is a list, keep only the first NAME node
                if (nameObj instanceof List<Object> && !((List<Object>)nameObj).isEmpty()) {
                    stateMap.put('NAME', ((List<Object>) nameObj)[0]);
                }
            } else if (stateObj instanceof List<Object> && !((List<Object>)stateObj).isEmpty()) {
                // Handle the case where we kept the first STATE from a list
                Map<String, Object> stateMap = (Map<String, Object>) ((List<Object>) stateObj)[0];
                Object nameObj = stateMap.get('NAME');
                
                // If NAME is a list, keep only the first NAME node
                if (nameObj instanceof List<Object> && !((List<Object>)nameObj).isEmpty()) {
                    stateMap.put('NAME', ((List<Object>) nameObj)[0]);
                }
            }
        }
    }

    /**
     ********************************************************
     * @Method Name    : normalizeAddresses
     * @description    : Normalizes the ADDRESSES section, ensuring STATE and ADDRESS are always lists.
     * @param          : biographic - The entity biographical data.
     ********************************************************
     **/
    private void normalizeAddresses(Map<String, Object> biographic) {
        Map<String, Object> addresses = (Map<String, Object>) biographic.get('ADDRESSES');
        if (addresses == null) {
            return;
        }
        
        // Check if STATE is a list or single object
        Object stateObj = addresses.get('STATE');
        if (stateObj != null && !(stateObj instanceof List<Object>)) {
            addresses.put('STATE', new List<Object>{ stateObj });
        }
        
        // Now ensure each STATE contains ADDRESS as a list
        List<Object> states = (List<Object>) addresses.get('STATE');
        if (states == null) {
            return;
        }
        
        for (Object state : states) {
            if (!(state instanceof Map<String, Object>)) {
                continue;
            }
            
            Map<String, Object> stateMap = (Map<String, Object>) state;
            Object addressObj = stateMap.get('ADDRESS');
            
            if (addressObj != null && !(addressObj instanceof List<Object>)) {
                stateMap.put('ADDRESS', new List<Object>{ addressObj });
            }
        }
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeContactInfos
     * @description    : Normalizes the CONTACT_INFOS section, ensuring STATE and CONTACT_INFO are always lists.
     * @param          : biographic - The entity biographical data.
     ********************************************************
     **/
    private void normalizeContactInfos(Map<String, Object> biographic) {
        Map<String, Object> contactInfos = (Map<String, Object>) biographic.get('CONTACT_INFOS');
        if (contactInfos == null) {
            return;
        }
        
        // Check if STATE is a list or single object
        Object stateObj = contactInfos.get('STATE');
        if (stateObj != null && !(stateObj instanceof List<Object>)) {
            contactInfos.put('STATE', new List<Object>{ stateObj });
        }
        
        // Now ensure each STATE contains CONTACT_INFO as a list
        List<Object> states = (List<Object>) contactInfos.get('STATE');
        if (states == null) {
            return;
        }
        
        for (Object state : states) {
            if (!(state instanceof Map<String, Object>)) {
                continue;
            }
            
            Map<String, Object> stateMap = (Map<String, Object>) state;
            Object contactInfoObj = stateMap.get('CONTACT_INFO');
            
            if (contactInfoObj != null && !(contactInfoObj instanceof List<Object>)) {
                stateMap.put('CONTACT_INFO', new List<Object>{ contactInfoObj });
            }
        }
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeProducerLicensing
     * @description    : Normalizes the PRODUCER_LICENSING section, including LICENSE_INFORMATION and REGULATORY_ACTION.
     * @param          : entity - The entity map (INDIVIDUAL or FIRM).
     ********************************************************
     **/
    private void normalizeProducerLicensing(Map<String, Object> entity) {
        Map<String, Object> licensing = (Map<String, Object>) entity.get('PRODUCER_LICENSING');
        if (licensing == null) {
            return;
        }
        
        // Normalize LICENSE_INFORMATION
        normalizeLicenseInfo(licensing);
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeLicenseInfo
     * @description    : Normalizes the LICENSE_INFORMATION section, ensuring STATE is always a list
     *                   and handling nested structures.
     * @param          : licensing - The producer licensing data.
     ********************************************************
     **/
    private void normalizeLicenseInfo(Map<String, Object> licensing) {
        Map<String, Object> licenseInfo = (Map<String, Object>) licensing.get('LICENSE_INFORMATION');
        if (licenseInfo == null) {
            return;
        }
        
        // Check if STATE is a list or single object
        Object stateObj = licenseInfo.get('STATE');
        if (stateObj != null && !(stateObj instanceof List<Object>)) {
            licenseInfo.put('STATE', new List<Object>{ stateObj });
        }
        
        // Now normalize nested elements in each STATE
        List<Object> states = (List<Object>) licenseInfo.get('STATE');
        if (states == null) {
            return;
        }
        
        for (Object state : states) {
            if (!(state instanceof Map<String, Object>)) {
                continue;
            }
            
            Map<String, Object> stateMap = (Map<String, Object>) state;
            
            // Handle multiple LICENSE elements - ensure LICENSE is a list
            Object licenseObj = stateMap.get('LICENSE');
            if (licenseObj != null) {
                if (!(licenseObj instanceof List<Object>)) {
                    stateMap.put('LICENSE', new List<Object>{ licenseObj });
                }
                
                // Now normalize DETAILS -> DETAIL for each LICENSE
                List<Object> licenses = (List<Object>) stateMap.get('LICENSE');
                for (Object license : licenses) {
                    if (license instanceof Map<String, Object>) {
                        normalizeDetails((Map<String, Object>) license);
                    }
                }
            }
            
            // Normalize APPOINTMENT_INFORMATION -> APPOINTMENT
            normalizeAppointments(stateMap);
        }
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeDetails
     * @description    : Normalizes the DETAILS -> DETAIL section, ensuring DETAIL is always a list.
     * @param          : licenseMap - The license information.
     ********************************************************
     **/
    private void normalizeDetails(Map<String, Object> licenseMap) {
        Map<String, Object> details = (Map<String, Object>) licenseMap.get('DETAILS');
        if (details == null) {
            return;
        }
        
        // Check if DETAIL is a list or single object
        Object detailObj = details.get('DETAIL');
        if (detailObj != null && !(detailObj instanceof List<Object>)) {
            details.put('DETAIL', new List<Object>{ detailObj });
        }
    }
    
    /**
     ********************************************************
     * @Method Name    : normalizeAppointments
     * @description    : Normalizes the APPOINTMENT_INFORMATION -> APPOINTMENT section, ensuring APPOINTMENT is always a list.
     * @param          : stateMap - The state license information.
     ********************************************************
     **/
    private void normalizeAppointments(Map<String, Object> stateMap) {
        Map<String, Object> appointmentInfo = (Map<String, Object>) stateMap.get('APPOINTMENT_INFORMATION');
        if (appointmentInfo == null) {
            return;
        }
        
        // Check if APPOINTMENT is a list or single object
        Object appointmentObj = appointmentInfo.get('APPOINTMENT');
        if (appointmentObj != null && !(appointmentObj instanceof List<Object>)) {
            appointmentInfo.put('APPOINTMENT', new List<Object>{ appointmentObj });
        }
    }
}