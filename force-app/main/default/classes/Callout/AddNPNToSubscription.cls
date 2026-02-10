/**
 *******************************************************************
 * Apex Class Name    : AddNPNToSubscription
 * Created Date       : 04-23-2025
 * @description       : Handles the addition of National Producer Numbers (NPNs) to NIPR subscriptions
 *                      through the NIPR API service
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-23-2025   Dev4Clouds          Initial Version
 * 1.1   04-23-2025   Dev4Clouds          Updated to use DTO for response processing
 *******************************************************************
 **/
public with sharing class AddNPNToSubscription {
    private final String NAMED_CREDENTIAL = 'NIPR_API';
    private final String RESOURCE_PATH = '/pdb-alerts-industry-services/services/industry-ws';
    
    /**
     ********************************************************
     * @Method Name    : addNPN
     * @description    : Sends the request to add NPNs to an existing NIPR subscription
     *                   using BaseApiInvoker to handle the API callout
     * @param          : npnList - List of National Producer Numbers to add to subscription
     * @param          : subscriptionName - Name of the subscription to add NPNs to
     * @return         : AddNPNToSubscriptionDTO - The parsed response from the API
     ********************************************************
     **/
    public AddNPNToSubscriptionDTO addNPN(List<String> npnList, String subscriptionName) {
        String requestBody = generateAddNPNsRequest(npnList, subscriptionName);
                
        BaseApiInvoker apiInvoker = new BaseApiInvoker();
        apiInvoker.setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
                    .setNamedCredential(NAMED_CREDENTIAL)
                    .setResource(RESOURCE_PATH)
                    .setRestMethod(BaseApiInvoker.RestMethod.POST)
                    .setJsonBody(requestBody)
                    .setTimeout(120000);
        
        apiInvoker.sendRequest();
        
        // Get response as string
        String responseStr = (String)apiInvoker.getApiResponse();
        
        // Parse the response into DTO
        return parseResponse(responseStr);
    }

    /**
     *********************************************************
     * @Method Name    : generateAddNPNsRequest
     * @description    : Generates a SOAP request to add NPNs to an existing subscription
     *                   using DOM classes instead of string concatenation
     * @param          : npns - List of NPNs to add to the subscription
     * @param          : subscriptionName - Name of the subscription to add NPNs to
     * @return         : String - SOAP XML request string
     *********************************************************
     **/
    public String generateAddNPNsRequest(List<String> npns, String subscriptionName) {
        DOM.Document doc = new DOM.Document();
        
        // Create root Envelope element with namespace binding
        DOM.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setNamespace('soapenv', 'http://schemas.xmlsoap.org/soap/envelope/');
        envelope.setNamespace('ind', 'https://pdb-services.nipr.com/pdb-alerts-industry-services/industry-ws');
        
        // Add empty Header (mandatory for proper SOAP structure)
        envelope.addChildElement('soapenv:Header', null, null);
        
        // Add Body
        DOM.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        DOM.XmlNode addTargets = body.addChildElement('ind:addTargets', 'ind', '');
        
        // Add subscription name
        addTargets.addChildElement('ind:subscriptionName', 'ind', '').addTextNode(subscriptionName);
        
        // Add target input data section
        DOM.XmlNode targetInputData = addTargets.addChildElement('ind:targetInputData', 'ind', '');
        targetInputData.addChildElement('ind:inputFormat', 'ind', '').addTextNode('NPN');
        
        // Add target input list with all NPNs
        DOM.XmlNode targetInputList = targetInputData.addChildElement('ind:targetInputList', 'ind', '');
        for (String npn : npns) {
            targetInputList.addChildElement('ind:npnList', 'ind', '').addTextNode(npn);
        }
        
        // Return fully formed SOAP XML
        return doc.toXmlString();
    }
    
    /**
     *********************************************************
     * @Method Name    : parseResponse
     * @description    : Parses the SOAP response from the API into a DTO object
     * @param          : responseStr - The raw SOAP response string
     * @return         : AddNPNToSubscriptionDTO - The parsed response
     *********************************************************
     **/
    private AddNPNToSubscriptionDTO parseResponse(String responseStr) {
        AddNPNToSubscriptionDTO dto = new AddNPNToSubscriptionDTO();
        dto.targetResultsData = new AddNPNToSubscriptionDTO.TargetResultsData();
        dto.targetResultsData.validNPNs = new List<String>();
        dto.targetResultsData.invalidInputs = new List<AddNPNToSubscriptionDTO.InvalidInputItem>();
        
        try {
            // Extract the SOAP envelope from the MTOM response
            String soapEnvelopeStart = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">';
            String soapEnvelopeEnd = '</soap:Envelope>';
            String extractedXML = XMLUtils.extractPureXMLFromMTOM(soapEnvelopeStart, soapEnvelopeEnd, responseStr);
            
            if (extractedXML == null) {
                // Try alternate format if the first attempt fails
                soapEnvelopeStart = '<soapenv:Envelope';
                soapEnvelopeEnd = '</soapenv:Envelope>';
                extractedXML = XMLUtils.extractPureXMLFromMTOM(soapEnvelopeStart, soapEnvelopeEnd, responseStr);
            }
            
            if (extractedXML == null) {
                dto.isSuccess = false;
                dto.errorMessage = 'Failed to extract SOAP envelope from response';
                return dto;
            }
            
            // Parse the XML
            DOM.Document doc = new DOM.Document();
            doc.load(extractedXML);
            
            // Convert XML to a map structure
            Map<String, Object> responseMap = new Map<String, Object>();
            XMLUtils.convertXMLToMap(doc.getRootElement(), responseMap);
            
            // Navigate to the targetResultsData in the map
            Map<String, Object> soapBody = (Map<String, Object>) responseMap.get('Body');
            if (soapBody == null) {
                dto.isSuccess = false;
                dto.errorMessage = 'Response does not contain Body element';
                return dto;
            }
            
            Map<String, Object> addTargetsResponse = (Map<String, Object>) soapBody.get('addTargetsResponse');
            if (addTargetsResponse == null) {
                dto.isSuccess = false;
                dto.errorMessage = 'Response does not contain addTargetsResponse element';
                return dto;
            }
            
            Map<String, Object> targetResultsData = (Map<String, Object>) addTargetsResponse.get('targetResultsData');
            if (targetResultsData == null) {
                dto.isSuccess = false;
                dto.errorMessage = 'Response does not contain targetResultsData element';
                return dto;
            }
            
            // Process valid target lists
            extractValidNPNs(targetResultsData, dto);
            
            // Process invalid input lists
            extractInvalidInputs(targetResultsData, dto);
            
            dto.isSuccess = true;
        } catch (Exception ex) {            
            dto.isSuccess = false;
            dto.errorMessage = ex.getMessage();
        }
        
        return dto;
    }
    
    /**
     *********************************************************
     * @Method Name    : extractValidNPNs
     * @description    : Extracts all valid NPNs from the targetResultsData map
     * @param          : targetResultsData - The target results data map
     * @param          : dto - The DTO to populate with valid NPNs
     *********************************************************
     **/
    private void extractValidNPNs(Map<String, Object> targetResultsData, AddNPNToSubscriptionDTO dto) {
        Object validTargetListObj = targetResultsData.get('validTargetList');
        
        if (validTargetListObj == null) {
            return;
        }
        
        // Handle case where there's a single validTargetList
        if (validTargetListObj instanceof Map<String, Object>) {
            Map<String, Object> validTargetList = (Map<String, Object>) validTargetListObj;
            Object npnObj = validTargetList.get('npn');
            
            if (npnObj != null) {
                if (npnObj instanceof List<Object>) {
                    // Multiple NPNs in a single validTargetList
                    for (Object npn : (List<Object>) npnObj) {
                        if (npn != null) {
                            dto.targetResultsData.validNPNs.add(String.valueOf(npn));
                        }
                    }
                } else {
                    // Single NPN in a single validTargetList
                    dto.targetResultsData.validNPNs.add(String.valueOf(npnObj));
                }
            }
        }
        // Handle case where there are multiple validTargetList elements
        else if (validTargetListObj instanceof List<Object>) {
            List<Object> validTargetLists = (List<Object>) validTargetListObj;
            
            for (Object listObj : validTargetLists) {
                if (listObj instanceof Map<String, Object>) {
                    Map<String, Object> validTargetList = (Map<String, Object>) listObj;
                    Object npnObj = validTargetList.get('npn');
                    
                    if (npnObj != null) {
                        if (npnObj instanceof List<Object>) {
                            // Multiple NPNs in one validTargetList
                            for (Object npn : (List<Object>) npnObj) {
                                if (npn != null) {
                                    dto.targetResultsData.validNPNs.add(String.valueOf(npn));
                                }
                            }
                        } else {
                            // Single NPN in one validTargetList
                            dto.targetResultsData.validNPNs.add(String.valueOf(npnObj));
                        }
                    }
                }
            }
        }
    }
    
    /**
     *********************************************************
     * @Method Name    : extractInvalidInputs
     * @description    : Extracts all invalid inputs from the targetResultsData map
     * @param          : targetResultsData - The target results data map
     * @param          : dto - The DTO to populate with invalid inputs
     *********************************************************
     **/
    private void extractInvalidInputs(Map<String, Object> targetResultsData, AddNPNToSubscriptionDTO dto) {
        Object invalidInputListObj = targetResultsData.get('invalidInputList');
        
        if (invalidInputListObj == null) {
            return;
        }
        
        // Handle case where there's a single invalidInputList
        if (invalidInputListObj instanceof Map<String, Object>) {
            Map<String, Object> invalidInputMap = (Map<String, Object>) invalidInputListObj;
            Object inputObj = invalidInputMap.get('input');
            Object reasonObj = invalidInputMap.get('invalidReason');
            
            if (inputObj != null && reasonObj != null) {
                AddNPNToSubscriptionDTO.InvalidInputItem item = new AddNPNToSubscriptionDTO.InvalidInputItem();
                item.input = String.valueOf(inputObj);
                item.invalidReason = String.valueOf(reasonObj);
                dto.targetResultsData.invalidInputs.add(item);
            }
        }
        // Handle case where there are multiple invalidInputList elements
        else if (invalidInputListObj instanceof List<Object>) {
            List<Object> invalidInputLists = (List<Object>) invalidInputListObj;
            
            for (Object listObj : invalidInputLists) {
                if (listObj instanceof Map<String, Object>) {
                    Map<String, Object> invalidInputMap = (Map<String, Object>) listObj;
                    Object inputObj = invalidInputMap.get('input');
                    Object reasonObj = invalidInputMap.get('invalidReason');
                    
                    if (inputObj != null && reasonObj != null) {
                        AddNPNToSubscriptionDTO.InvalidInputItem item = new AddNPNToSubscriptionDTO.InvalidInputItem();
                        item.input = String.valueOf(inputObj);
                        item.invalidReason = String.valueOf(reasonObj);
                        dto.targetResultsData.invalidInputs.add(item);
                    }
                }
            }
        }
    }
}