/**
 *******************************************************************
 * Apex Class Name    : CreateSubscription
 * Created Date       : 04-23-2025
 * @description       : Handles the creation of subscriptions through the NIPR API service
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   04-23-2025   Stefan Nidzovic          Initial Version
 * 1.1   04-23-2025   Stefan Nidzovic          Updated to use DOM for XML generation
 * 1.2   10-24-2025   Stefan Nidzovic          Added support for Exclude Carrier Appointments mode
 *******************************************************************
 **/
public with sharing class CreateSubscription {
    private final String NAMED_CREDENTIAL = 'NIPR_API';
    private final String RESOURCE_PATH = '/pdb-alerts-industry-services/services/industry-ws';
    private String SUBSCRIPTION_EMAIL = 'hiptenadmins@hipten.com';
    
    // Flag to determine if this subscription excludes carrier appointments
    private Boolean excludeCarrierAppointments = false;

    private final MetadataTypeSelector mtdSelector = new MetadataTypeSelector();

    public CreateSubscription() {
        d4c_NIPR_Sync_Settings__mdt settings = mtdSelector.getNIPRSyncSettings();
        SUBSCRIPTION_EMAIL = settings?.d4c_SubscriptionEmail__c != null ? settings.d4c_SubscriptionEmail__c : SUBSCRIPTION_EMAIL;
    }

    /**
     ********************************************************
     * @Method Name    : setExcludeCarrierAppointmentsMode
     * @description    : Sets the flag for excluding carrier appointments
     *                   Producers with this flag get licensing-only subscriptions (no appointments)
     * @param          : exclude - true if this subscription should exclude carrier appointments
     ********************************************************
     **/
    public void setExcludeCarrierAppointmentsMode(Boolean exclude) {
        this.excludeCarrierAppointments = exclude;
    }
    
    /**
     ********************************************************
     * @Method Name    : createSubscription
     * @description    : Sends the request to create a new NIPR subscription
     *                   using BaseApiInvoker to handle the API callout
     * @param          : subscriptionName - Name of the subscription to create
     * @return         : String - The response body from the API call
     ********************************************************
     **/
    public String createSubscription(String subscriptionName) {
        String requestBody = generateCreateSubscriptionRequest(subscriptionName);
                
        BaseApiInvoker apiInvoker = new BaseApiInvoker();
        apiInvoker.setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
                    .setNamedCredential(NAMED_CREDENTIAL)
                    .setResource(RESOURCE_PATH)
                    .setRestMethod(BaseApiInvoker.RestMethod.POST)
                    .setJsonBody(requestBody)
                    .setTimeout(120000);
        
        apiInvoker.sendRequest();
        
        // Check response
        Object responseObj = apiInvoker.getApiResponse();

        return (String)responseObj;
    }

    /**
     ********************************************************
     * @Method Name    : generateCreateSubscriptionRequest
     * @description    : Generates a SOAP request to create a new subscription
     *                   using DOM classes instead of string concatenation
     * @param          : subscriptionName - Name of the subscription to create
     * @return         : String - SOAP XML request string
     ********************************************************
     **/
    public String generateCreateSubscriptionRequest(String subscriptionName) {
        DOM.Document doc = new DOM.Document();
        
        // Create root Envelope element with namespace binding
        DOM.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setNamespace('soapenv', 'http://schemas.xmlsoap.org/soap/envelope/');
        envelope.setNamespace('ind', 'https://pdb-services.nipr.com/pdb-alerts-industry-services/industry-ws');
        
        // Add empty Header (mandatory for proper SOAP structure)
        envelope.addChildElement('soapenv:Header', null, null);
        
        // Add Body
        DOM.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        DOM.XmlNode addSubscription = body.addChildElement('ind:addSubscription', 'ind', '');
        
        // Add subscription input data section
        DOM.XmlNode subscriptionInputData = addSubscription.addChildElement('ind:subscriptionInputData', 'ind', '');
        
        // Add subscription name
        subscriptionInputData.addChildElement('ind:subscriptionName', 'ind', '').addTextNode(subscriptionName);
        
        // Add email
        subscriptionInputData.addChildElement('ind:email', 'ind', '').addTextNode(SUBSCRIPTION_EMAIL);
        
        // Add affiliation list
        DOM.XmlNode affiliationList = subscriptionInputData.addChildElement('ind:affiliationList', 'ind', '');
        affiliationList.addChildElement('ind:None', 'ind', '').addTextNode('true');
        
        // Add state list
        DOM.XmlNode stateList = subscriptionInputData.addChildElement('ind:stateList', 'ind', '');
        stateList.addChildElement('ind:allStates', 'ind', '').addTextNode('true');
        
        // Add alert type list - conditional based on producer size
        DOM.XmlNode alertTypeList = subscriptionInputData.addChildElement('ind:alertTypeList', 'ind', '');
        alertTypeList.addChildElement('ind:alertTypeList', 'ind', '').addTextNode('LICENSING');
        
        // Only include APPOINTMENTS if not excluding carrier appointments
        if (!this.excludeCarrierAppointments) {
            alertTypeList.addChildElement('ind:alertTypeList', 'ind', '').addTextNode('APPOINTMENTS');
        }
        
        alertTypeList.addChildElement('ind:alertTypeList', 'ind', '').addTextNode('RIRS');
        alertTypeList.addChildElement('ind:alertTypeList', 'ind', '').addTextNode('DEMOGRAPHICS');
        
        // Return fully formed SOAP XML
        return doc.toXmlString();
    }
}