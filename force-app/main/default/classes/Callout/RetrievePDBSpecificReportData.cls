/**
 *********************************************************
 * Apex Class Name    : RetrievePDBSpecificAlertData
 * Created Date       : 03-18-2025
 * @description       : Parses SOAP response from PDB Alerts API and extracts Licensing Report data.
 *                      Manual XML Processing using DOM.XMLNode apex classes is required as the api returns MOTM XML response which Apex WebService class can not parse
 *                      The reponse is serialized into LicensingReportDTO apex classes. The DTO contains data about all agents/agencies/carriers and their details, licenses, lines of authority and carrier appointments
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-18-2025   Dev4Clouds          Initial Version
 *********************************************************
 **/
public class RetrievePDBSpecificReportData {
    // private property used for logging purposes
    private String CLASS_NAME = 'RetrievePDBSpecificReportData';

    /**
     *********************************************************
     * @methodName      : retrieveData
     * @description     : Sends a SOAP request and processes the response.
     * @param reportDate : This date will return data that NIPR returned on that given day
     * @param subscriptionName : The subscription name for the request. Each subscription holds certain number of NPN's and data will be retreived for each NPN if there were changes for that NPN on that given date
     *********************************************************
     **/
    public LicensingReportDTO retrieveData(String reportDate, String subscriptionName) {
        // private property used for logging purposes
        String methodName = 'retrieveData';

        LicensingReportDTO pdbAlertsResponse = new LicensingReportDTO();
        
        // Start logging
        Logger.info(CLASS_NAME, methodName, 'Starting data retrieval process', 
                'Report Date: ' + reportDate + ', Subscription: ' + subscriptionName, null);
        
        try {
            String responseBody;
            d4c_NIPR_Sync_Settings__mdt settings = getNIPRSyncSettings();

            if (settings?.d4c_TestXMLActive__c && !Test.isRunningTest()) {
                responseBody = settings.d4c_TestXMLData__c;
                Logger.debug(CLASS_NAME, methodName, 'Using test XML response data',
                        'Test XML response is active', null);
            } else {
                // Build the SOAP request body using DOM
                String requestBody = buildSOAPRequestBody(reportDate, subscriptionName);
                Logger.debug(CLASS_NAME, methodName, 'Built SOAP request body', 
                        'Request body length: ' + requestBody.length(), null);

                // Build HTTP Request
                BaseApiInvoker invoker = new BaseApiInvoker()
                        .setInvokeType(BaseApiInvoker.InvokeType.NAMEDCREDENTIAL)
                        .setNamedCredential('NIPR_API')
                        .setResource('/pdb-alerts-industry-services/services/industry-ws')
                        .setTimeout(60000)
                        .setHeaders(new Map<String, String>{ 'Content-Type' => 'text/xml; charset=UTF-8' })
                        .setRestMethod(BaseApiInvoker.RestMethod.POST)
                        .setJsonBody(requestBody);

                // Invoke the HTTP Request
                Logger.debug(CLASS_NAME, methodName, 'Sending HTTP request to NIPR API', null, null);

                invoker.sendRequest();

                // Store the response body
                responseBody = String.valueOf(invoker.getApiResponse());
            }


            // Extract pure XML from MTOM format of the SOAP API response
            String extractedXML = XMLUtils.extractPureXMLFromMTOM('<LicensingReportProcessResult', '</LicensingReportProcessResult>', responseBody);

            // Process the PDB Alert
            pdbAlertsResponse = processPDBAlert(extractedXML);
            pdbAlertsResponse.isSuccess = true;
            
            // Log the response summary
            List<LicensingReportDTO.Person> entitys = pdbAlertsResponse?.licensingReportProcessResult?.licensingReport?.personList;
            Integer entityCount = entitys != null ? entitys.size() : 0;
            
            Logger.info(CLASS_NAME, methodName, 'Successfully processed PDB Alert data', 
                    'Report Date: ' + reportDate + 
                    ', Subscription: ' + subscriptionName + 
                    ', Entity Count: ' + entityCount, 
                    null);
        } catch(Exception ex) {
            // Process exception
            Logger.error(CLASS_NAME, methodName, ex, null);
            
            pdbAlertsResponse.isSuccess = false;
            pdbAlertsResponse.errorMessage = ex.getMessage();
            
            String errorDetails = 'Report Date: ' + reportDate + 
                                ', Subscription: ' + subscriptionName + 
                                ', Error Type: ';
            
            if (ex.getMessage().contains('There are no alerts scheduled for the day') || 
                ex.getMessage().contains('The requested report is not available or complete')) {
                pdbAlertsResponse.errorType = NIPREnums.PDBAlertError.REPORT_NOT_AVAILABLE;
                errorDetails += 'REPORT_NOT_AVAILABLE';
            } else {
                pdbAlertsResponse.errorType = NIPREnums.PDBAlertError.UNKOWN_ISSUE;
                errorDetails += 'UNKNOWN_ISSUE';
            }
            
            Logger.warning(CLASS_NAME, methodName, 'Failed to process PDB Alert data', 
                        errorDetails, null);
        }

        List<LicensingReportDTO.Person> entitys = pdbAlertsResponse?.licensingReportProcessResult?.licensingReport?.personList;
        
        Logger.debug(CLASS_NAME, methodName, 'PDB Alerts Response', 
            JSON.serialize(pdbAlertsResponse), null);

        Logger.commitAsync();

        return pdbAlertsResponse;
    }

    /**
     *********************************************************
     * @methodName      : buildSoapRequestBody
     * @description     : Constructs a SOAP request body.
     * @param reportDate : The report date for the SOAP request.
     * @param subscriptionName : The subscription name for the SOAP request.
     * @return          : A string representation of the SOAP XML request.
     *********************************************************
     **/
    private String buildSoapRequestBody(String reportDate, String subscriptionName) {
        DOM.Document doc = new DOM.Document();

        // Correctly create root Envelope element with namespace binding
        DOM.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setNamespace('soapenv', 'http://schemas.xmlsoap.org/soap/envelope/');
        envelope.setNamespace('ind', 'https://pdb-services.nipr.com/pdb-alerts-industry-services/industry-ws');

        // Add empty Header (mandatory for proper SOAP structure)
        envelope.addChildElement('soapenv:Header', null, null);

        // Add Body
        DOM.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        DOM.XmlNode requestNode = body.addChildElement('ind:receiveSpecificReportForSubscription', 'ind', '');
        
        // Add request parameters (correctly namespaced)
        requestNode.addChildElement('ind:reportDate', 'ind', '').addTextNode(reportDate);
        requestNode.addChildElement('ind:subscriptionName', 'ind', '').addTextNode(subscriptionName);

        // Return fully formed SOAP XML
        return doc.toXmlString();
    }

    /**
     *********************************************************
     * @methodName      : processPDBAlert
     * @description     : Parses the extracted XML and processes PDB Specific Report data returned from NIPR API
     * @param xmlString : The extracted XML string containing PDB Alert Details
     *********************************************************
     **/
    private LicensingReportDTO processPDBAlert(String xmlString) {
        LicensingReportDTO pdbAlertsResponse = new LicensingReportDTO();

        // Convert string to XML Document
        DOM.Document doc = new DOM.Document();
        doc.load(xmlString);

        // Extract Root Element
        DOM.XmlNode root = doc.getRootElement();

        if (root == null) {
            return pdbAlertsResponse;
        }

        // Instantiate main DTO class that holds all of the NIPR data
        LicensingReportDTO.LicensingReportProcessResult reportResult = new LicensingReportDTO.LicensingReportProcessResult();

        // Process PDB Alerts Message Header
        reportResult.messageHeader = processMessageHeader(root);
        
        // Process PDB Alerts Message Result
        reportResult.messageResult = processMessageResult(root);

        // Process PDB Alerts Licensing Report
        reportResult.licensingReport = processLicensingReport(root);

        pdbAlertsResponse.licensingReportProcessResult = reportResult;
        
        return pdbAlertsResponse;
    }

    /**
     *********************************************************
     * @methodName      : processMessageHeader
     * @description     : Extracts and maps the Message Header Node details from the XML response.
     * @param root      : The root XML node containing the message header.
     * @return         : A populated MessageHeader DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.MessageHeader processMessageHeader(DOM.XmlNode root) {
        LicensingReportDTO.MessageHeader messageHeader = new LicensingReportDTO.MessageHeader();

        //  Map MessageHeader
        DOM.XmlNode headerNode = root.getChildElement('MessageHeader', root.getNamespace());
        if (headerNode == null) {
            return messageHeader;
        }

        messageHeader.messageId = XMLUtils.getNodeStringValue(headerNode, 'MessageId');
        messageHeader.correlationId = XMLUtils.getNodeStringValue(headerNode, 'CorrelationId');
        messageHeader.messageDateTime = XMLUtils.getNodeStringValue(headerNode, 'MessageDateTime');
        messageHeader.messageDocumentCount = XMLUtils.getNodeIntegerValue(headerNode, 'MessageDocumentCount');

        return messageHeader;
    }

    /**
     *********************************************************
     * @methodName      : processMessageResult
     * @description     : Extracts and maps the Message Result Node details from the XML response.
     * @param root      : The root XML node containing the message result.
     * @return         : A populated MessageResult DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.MessageResult processMessageResult(DOM.XmlNode root) {
        LicensingReportDTO.MessageResult messageResult = new LicensingReportDTO.MessageResult();

        DOM.XmlNode resultNode = root.getChildElement('MessageResult', root.getNamespace());
        if (resultNode == null) {
            return messageResult;
        }
        
        messageResult.statusCode = XMLUtils.getNodeStringValue(resultNode, 'StatusCode');
        
        DOM.XmlNode docResultNode = resultNode.getChildElement('MessageDocumentResult', resultNode.getNamespace());

        messageResult.messageDocumentResult = new LicensingReportDTO.MessageDocumentResult();
        messageResult.messageDocumentResult.statusCode = XMLUtils.getNodeStringValue(docResultNode, 'StatusCode');
        messageResult.messageDocumentResult.successCode = XMLUtils.getNodeStringValue(docResultNode, 'SuccessCode');
        
        DOM.XmlNode docRefNode = docResultNode.getChildElement('MessageDocumentReferences', docResultNode.getNamespace());
   
        messageResult.messageDocumentResult.messageDocumentReferences = XMLUtils.getNodeStringValue(docRefNode, 'DocumentId');
        
        return messageResult;
    }

    /**
     *********************************************************
     * @methodName      : processLicensingReport
     * @description     : Extracts and processes Licensing Report Node details from the XML response.
     * @param root      : The root XML node containing the licensing report.
     * @return         : A populated LicensingReport DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.LicensingReport processLicensingReport(DOM.XmlNode root) {
        LicensingReportDTO.LicensingReport licensingReport = new LicensingReportDTO.LicensingReport();
        // Map containing all agent nodes by their NPN. PDB Alert contains multiple nodes that relate to the same agent as data is sparsed.
        Map<String, List<LicensingReportDTO.Person>> personRecordsByNpn = new Map<String, List<LicensingReportDTO.Person>>();
        // Map containing all agency nodes by their NPN. PDB Alert contains multiple nodes that relate to the same agency as data is sparsed.
        Map<String, List<LicensingReportDTO.Organization>> organizationRecordsById = new Map<String, List<LicensingReportDTO.Organization>>();
        // List Of Carrier organizations that do not posses CoCode but FEIN only
        List<LicensingReportDTO.Organization> feinOnlyCarriers = new List<LicensingReportDTO.Organization>();

        DOM.XmlNode reportNode = root.getChildElement('LicensingReport', root.getNamespace());
        
        if (reportNode == null) {
            return licensingReport;
        }

        licensingReport.documentId = XMLUtils.getNodeStringValue(reportNode, 'DocumentId');
        licensingReport.typeCode = XMLUtils.getNodeStringValue(reportNode, 'TypeCode');

        // Initialize the report lists
        licensingReport.addressList = new List<LicensingReportDTO.Address>();
        licensingReport.personList = new List<LicensingReportDTO.Person>();
        licensingReport.agencyList = new List<LicensingReportDTO.Organization>();
        licensingReport.carrierList = new List<LicensingReportDTO.Organization>();
        licensingReport.jurisdictionReportList = new List<LicensingReportDTO.JurisdictionReport>();

        // Get all child elements of reportNode (Processes Address, Agent, Agencies and Carrier Nodes)
        for (DOM.XmlNode childNode : reportNode.getChildElements()) {
            String childNodeName = childNode.getName();

            if (childNodeName == 'Address') {
                // Process Address Node and add it to a list of all addresses in the report
                LicensingReportDTO.Address address = processLicensingAddress(childNode);
                licensingReport.addressList.add(address);
            } else if (childNodeName == 'Person') {
                // Process PErson node and add it to a map which contains all person nodes per Unique NPN (Person info is spread among different nodes which all tie to the same NPN and this data will be merged later on)
                LicensingReportDTO.Person person = processLicensingPerson(childNode);

                if (personRecordsByNpn.containsKey(person.externalIdentifier.id)) {
                    personRecordsByNpn.get(person.externalIdentifier.id).add(person);

                    continue;
                }

                personRecordsByNpn.put(person.externalIdentifier.id, new List<LicensingReportDTO.Person>{ person });

            } else if (childNodeName == 'Organization') {
                // Process Organization node
                LicensingReportDTO.Organization organization = processLicensingOrganization(childNode);
                
                // Track if this organization has a NAICEntityCode or NAICInsurerCode
                Boolean hasMainIdentifier = false;
                String feinId = null;
                
                // First pass: look for NAICEntityCode, NAICInsurerCode, and collect FEIN
                for (LicensingReportDTO.ExternalIdentifier extId : organization.externalIdentifierList) {
                    if (extId.typeCode == 'NAICEntityCode' || extId.typeCode == 'NAICInsurerCode') {
                        hasMainIdentifier = true;
                        String orgIdentifier = extId.id;
            
                        if (organizationRecordsById.containsKey(orgIdentifier)) {
                            organizationRecordsById.get(orgIdentifier).add(organization);
                        } else {
                            organizationRecordsById.put(orgIdentifier, new List<LicensingReportDTO.Organization> { organization });
                        }
                    } else if (extId.typeCode == 'FEINId') {
                        feinId = extId.id;
                    }
                }
                
                // If no main identifier(NPN) but has FEIN, add directly to carriers list
                // There are scenarios where in the response a carrier is returned without a CoCode value, but just the FEIN value.
                // Here we make an assumption that nodes like that will always be carriers, as entitys without an NPN do not make sense
                if (!hasMainIdentifier && feinId != null) {
                    // Create a simplified organization just for this FEIN carrier
                    organization.combinedKeys = new List<String> { organization.key };
                    feinOnlyCarriers.add(organization);
                }
            } else if(childNodeName == 'JurisdictionReport') {
                // Process Jurisdiction Report node - this node holds info about Licenses, LOA and Carrier Appointments
                LicensingReportDTO.JurisdictionReport report = processJurisdictionReport(childNode, licensingReport);
                licensingReport.jurisdictionReportList.add(report);
            }
        }

        // Person and Organization info is split among multiple nodes that have the same npn, these methods merge those nodes into single unique node
        licensingReport.personList = mergeSameNPNPersonRecords(personRecordsByNpn);
        licensingReport.organizationList = mergeSameIdentifierOrganizations(organizationRecordsById);

        licensingReport.entityList = new List<LicensingReportDTO.NIPREntity>();

        // After the Organization nodes have been merged to one single node, now we separate them into agencies and carriers for easier processing later on
        Map<String, List<LicensingReportDTO.Organization>> carriersAndAgentsSeparated = separateAgenciesAndCarriers(licensingReport.organizationList);
        List<LicensingReportDTO.Organization> agencyList = carriersAndAgentsSeparated.get('agencies');
        List<LicensingReportDTO.Organization> carrierList = carriersAndAgentsSeparated.get('carriers');
                
        if (licensingReport.personList != null && !licensingReport.personList.isEmpty()) {
            licensingReport.entityList.addAll(licensingReport.personList);
        }

        if (agencyList != null && !agencyList.isEmpty()) {
            licensingReport.entityList.addAll(agencyList);
        }

        licensingReport.carrierList = carrierList;

        // Add Fein Only carriers in the end to this final list of carriers
        licensingReport.carrierList.addAll(feinOnlyCarriers);
        
        return licensingReport;
    }

    /**
     *********************************************************
     * @methodName      : processLicensingAddress
     * @description     : Extracts and maps Address Node details from the XML response.
     * @param addressNode : The XML node containing the address details.
     * @return          : A populated Address DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Address processLicensingAddress(DOM.XmlNode addressNode) {
        LicensingReportDTO.Address address = new LicensingReportDTO.Address();

        address.key = addressNode.getAttribute('key', null);
        address.lineOne = XMLUtils.getNodeStringValue(addressNode, 'LineOne');
        address.lineTwo = XMLUtils.getNodeStringValue(addressNode, 'LineTwo');
        address.lineThree = XMLUtils.getNodeStringValue(addressNode, 'LineThree');
        address.cityName = XMLUtils.getNodeStringValue(addressNode, 'CityName');
        address.stateOrProvinceCode = XMLUtils.getNodeStringValue(addressNode, 'StateOrProvinceCode');
        address.postalCode = XMLUtils.getNodeStringValue(addressNode, 'PostalCode');
        address.countryCode = XMLUtils.getNodeStringValue(addressNode, 'CountryCode');

        return address;
    }

    /**
     *********************************************************
     * @methodName      : processLicensingPerson
     * @description     : Extracts and maps Person Node details from the XML response.
     * @param personNode : The XML node containing the person details.
     * @return          : A populated Person DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Person processLicensingPerson(DOM.XmlNode personNode) {
        LicensingReportDTO.Person person = new LicensingReportDTO.Person();
        person.key = personNode.getAttribute('key', null);

        DOM.XmlNode externalIdNode = personNode.getChildElement('ExternalIdentifier', personNode.getNamespace());
        // Process Person External Identifier Node, this is where NPN is found
        if (externalIdNode != null) {
            person.externalIdentifier = processExternalIdentifier(externalIdNode);
            person.mainIdentifier = person.externalIdentifier.id;
            person.mainIdentifierType = person.externalIdentifier.typeCode;
        }

        // Process PersonName
        DOM.XmlNode personNameNode = personNode.getChildElement('PersonName', personNode.getNamespace());
        if (personNameNode != null) {
            person.personName = processPersonName(personNameNode);
        }

        // Process PersonCommunication
        DOM.XmlNode personCommNode = personNode.getChildElement('PersonCommunication', personNode.getNamespace());
        if (personCommNode != null) {
            person.personCommunication = processPersonCommunication(personCommNode);
        }

        // Process BusinessCommunication
        DOM.XmlNode businessCommNode = personNode.getChildElement('BusinessCommunication', personNode.getNamespace());
        if (businessCommNode != null) {
            person.businessCommunication = processBusinessCommunication(businessCommNode);
        }
        
        person.birthDate = XMLUtils.getNodeStringValue(personNode, 'BirthDate');
        
        return person;
    }
    
    /**
     *********************************************************
     * @methodName      : processLicensingOrganization
     * @description     : Extracts and maps Person details from the XML response.
     * @param organizationNode : The XML node containing the person details.
     * @return          : A populated Person DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Organization processLicensingOrganization(DOM.XmlNode organizationNode) {
        LicensingReportDTO.Organization organization = new LicensingReportDTO.Organization();

        organization.externalIdentifierList = new List<LicensingReportDTO.ExternalIdentifier>();
        organization.organizationNameList = new List<LicensingReportDTO.OrganizationName>();
        organization.assignedIdentifierList = new List<LicensingReportDTO.AssignedIdentifier>();
        organization.organizationCommunication = new LicensingReportDTO.OrganizationCommunication();

        organization.key = organizationNode.getAttribute('key', null);

        // Go through all child nodes of each organization
        for (DOM.XmlNode orgChildNode : organizationNode.getChildElements()) {
            String orgChildNodeName = orgChildNode.getName();

            if (orgChildNodeName == 'ExternalIdentifier') {
                // Process organization identifiers (NPN/CoCodes/BranchIDs)
                LicensingReportDTO.ExternalIdentifier orgExId = processExternalIdentifier(orgChildNode);
                organization.externalIdentifierList.add(orgExId);
            } else if (orgChildNodeName == 'OrganizationName') {
                // Process organization name
                LicensingReportDTO.OrganizationName orgName = processOrganizationName(orgChildNode);
                organization.organizationNameList.add(orgName);
            } else if (orgChildNodeName == 'AssignedIdentifier') {
                // Process assigned identifier
                LicensingReportDTO.AssignedIdentifier assignedIdentifier = processAssignedIdentifier(orgChildNode);
                organization.assignedIdentifierList.add(assignedIdentifier);
            } else if (orgChildNodeName == 'OrganizationCommunication') {
                // Process organization communication (addresses, phones, emails)
                organization.organizationCommunication = processOrganizationCommunication(orgChildNode);
            }
        }

        return organization;
    }

    /**
     *********************************************************
     * @methodName      : separateAgenciesAndCarriers
     * @description     : Separates NIPR organizations(agencies and carriers) into 2 separate lists divided by their type code
     * @param orgList   : List of Organization DTOs representing agents and carriers mapped from NIPR API
     * @return          : A populated Person DTO object.
     *********************************************************
     **/
    private Map<String, List<LicensingReportDTO.Organization>> separateAgenciesAndCarriers(List<LicensingReportDTO.Organization> orgList) {
        Map<String, List<LicensingReportDTO.Organization>> agenciesAndCarriersLists = new Map<String, List<LicensingReportDTO.Organization>>();

        List<LicensingReportDTO.Organization> agencyList = new List<LicensingReportDTO.Organization>();
        List<LicensingReportDTO.Organization> carrierList = new List<LicensingReportDTO.Organization>();

        for (LicensingReportDTO.Organization org : orgList) {
            // NAICEntityCode - Agency | NAICInsurerCode - Carrier
            if (org.mainIdentifierType == 'NAICEntityCode') {
                agencyList.add(org);

                continue;
            }

            carrierList.add(org);
        }

        agenciesAndCarriersLists.put('agencies', agencyList);
        agenciesAndCarriersLists.put('carriers', carrierList);

        return agenciesAndCarriersLists;
    }

    /**
     *********************************************************
     * @methodName      : mergeSameNPNPersonRecords
     * @description     : The PDB alerts response returns multiple person nodes which have the same NPN. This is an issue for us as NPN
     *                   is our unique identifier for a given person. This method merges the multiple person nodes into a single
     *                   record. The record node with Primary Name has advantage over the node with Alias name as for now we can't keep both information
     * @param personMapByNpn : Map where the key is the NPN and the value is a list of Person nodes that hold the info for that agent's NPN
     * @return          : A populated Person DTO object.
     *********************************************************
     **/
    private List<LicensingReportDTO.Person> mergeSameNPNPersonRecords(Map<String, List<LicensingReportDTO.Person>> personMapByNpn) {
        List<LicensingReportDTO.Person> mergedPersonList = new List<LicensingReportDTO.Person>();

        for (String key : personMapByNpn.keySet()) {
            List<LicensingReportDTO.Person> personList = personMapByNpn.get(key);

            LicensingReportDTO.Person newPerson;
            LicensingReportDTO.Person primaryNode;
            LicensingReportDTO.Person secondaryNode;
            LicensingReportDTO.Person tertiaryNode;

            // IMPORTANT !!! - This list holds all Keys which are identifiers found in the NIPR API Response
            // Each person node can have multiple keys that belong to the same npn, and using these identifiers we match the other records such as Licenses, LOA etc... to person records
            // It is extremely important that during the merge, we store all the keys per NPN, as later one whichever service processes this response, it won't be able to match the rest of the data to Person records correctly without all Keys
            // Lastly NIPR can sometimes return nodes without any info used for matching it with child records and we use IsExisting field to indicate we expect this record to already exist in Salesforce
            List<String> combinedKeys = new List<String>();

            // CRITICAL FIX (2026-02-12): Collect ALL PersonCommunication and BusinessCommunication from ALL nodes
            // NIPR can return 27+ Person nodes for one NPN (see CLAUDE.md - NPN 9306586 example)
            // Communication data (phones, emails, addresses) is spread across different state-specific nodes
            // We MUST collect ALL communication data to prevent data loss
            List<LicensingReportDTO.PersonCommunication> allPersonComms = new List<LicensingReportDTO.PersonCommunication>();
            List<LicensingReportDTO.BusinessCommunication> allBusinessComms = new List<LicensingReportDTO.BusinessCommunication>();

            for (LicensingReportDTO.Person person : personList) {
                combinedKeys.add(person.key);

                // Collect communication data from ALL nodes
                if (person.personCommunication != null) {
                    allPersonComms.add(person.personCommunication);
                }
                if (person.businessCommunication != null) {
                    allBusinessComms.add(person.businessCommunication);
                }

                if (person.personName != null && person.personName.typeCode == 'Primary') {
                    primaryNode = new LicensingReportDTO.Person();

                    primaryNode = person;
                    primaryNode.mainIdentifier = person.externalIdentifier.id;
                    primaryNode.mainIdentifierType = person.externalIdentifier.typeCode;
                } else if (person.personName != null && person.personName.typeCode == 'Alias') {
                    secondaryNode = new LicensingReportDTO.Person();

                    secondaryNode = person;
                    secondaryNode.mainIdentifier = person.externalIdentifier.id;
                    secondaryNode.mainIdentifierType = person.externalIdentifier.typeCode;
                } else if (person.personName == null && person.personCommunication == null && person.businessCommunication == null) {
                    tertiaryNode = new LicensingReportDTO.Person();

                    tertiaryNode.birthDate = person.birthDate;
                    tertiaryNode.externalIdentifier = person.externalIdentifier;
                    tertiaryNode.mainIdentifier = person.mainIdentifier;
                    tertiaryNode.mainIdentifierType = person.mainIdentifierType;
                    tertiaryNode.isExisting = true;
                }
            }

            if (primaryNode != null || secondaryNode != null || tertiaryNode != null) {
                newPerson = primaryNode != null ? primaryNode : secondaryNode != null ? secondaryNode : tertiaryNode;

                if (primaryNode != null || secondaryNode != null) {
                    newPerson.birthDate = tertiaryNode.birthDate;
                }

                newPerson.combinedKeys = combinedKeys;

                // CRITICAL FIX (2026-02-12): Merge ALL collected communication data into the chosen node
                // This ensures we capture unique phones, emails, addresses from all 27+ state-specific Person nodes
                // ListUtils.deduplicateByField() will handle duplicates via d4c_UniqueIdentifier__c later
                newPerson.personCommunication = mergePersonCommunications(allPersonComms);
                newPerson.businessCommunication = mergeBusinessCommunications(allBusinessComms);
            }

            mergedPersonList.add(newPerson);
        }

        return mergedPersonList;
    }

    /**
     *********************************************************
     * @methodName      : mergePersonCommunications
     * @description     : Merges PersonCommunication data from multiple Person nodes into a single PersonCommunication object.
     *                   NIPR returns communication data (addresses, phones, emails) spread across multiple state-specific Person nodes.
     *                   This method collects ALL unique communication data to prevent data loss.
     * @param allComms  : List of PersonCommunication objects from all Person nodes for the same NPN
     * @return          : A single merged PersonCommunication object containing all unique data
     * @created         : 2026-02-12
     *********************************************************
     **/
    private LicensingReportDTO.PersonCommunication mergePersonCommunications(List<LicensingReportDTO.PersonCommunication> allComms) {
        if (allComms == null || allComms.isEmpty()) {
            return null;
        }

        LicensingReportDTO.PersonCommunication merged = new LicensingReportDTO.PersonCommunication();
        merged.telephoneList = new List<LicensingReportDTO.Telephone>();
        merged.emailList = new List<LicensingReportDTO.Email>();
        merged.addressList = new List<LicensingReportDTO.Address>();

        // Collect all communication data from all nodes
        for (LicensingReportDTO.PersonCommunication comm : allComms) {
            if (comm.telephoneList != null && !comm.telephoneList.isEmpty()) {
                merged.telephoneList.addAll(comm.telephoneList);
            }
            if (comm.emailList != null && !comm.emailList.isEmpty()) {
                merged.emailList.addAll(comm.emailList);
            }
            if (comm.addressList != null && !comm.addressList.isEmpty()) {
                merged.addressList.addAll(comm.addressList);
            }
        }

        // Return null if no data was collected (all lists empty)
        if (merged.telephoneList.isEmpty() && merged.emailList.isEmpty() && merged.addressList.isEmpty()) {
            return null;
        }

        return merged;
    }

    /**
     *********************************************************
     * @methodName      : mergeBusinessCommunications
     * @description     : Merges BusinessCommunication data from multiple Person nodes into a single BusinessCommunication object.
     *                   NIPR returns communication data (addresses, phones, emails) spread across multiple state-specific Person nodes.
     *                   This method collects ALL unique communication data to prevent data loss.
     * @param allComms  : List of BusinessCommunication objects from all Person nodes for the same NPN
     * @return          : A single merged BusinessCommunication object containing all unique data
     * @created         : 2026-02-12
     *********************************************************
     **/
    private LicensingReportDTO.BusinessCommunication mergeBusinessCommunications(List<LicensingReportDTO.BusinessCommunication> allComms) {
        if (allComms == null || allComms.isEmpty()) {
            return null;
        }

        LicensingReportDTO.BusinessCommunication merged = new LicensingReportDTO.BusinessCommunication();
        merged.telephoneList = new List<LicensingReportDTO.Telephone>();
        merged.emailList = new List<LicensingReportDTO.Email>();
        merged.addressList = new List<LicensingReportDTO.Address>();

        // Collect all communication data from all nodes
        for (LicensingReportDTO.BusinessCommunication comm : allComms) {
            if (comm.telephoneList != null && !comm.telephoneList.isEmpty()) {
                merged.telephoneList.addAll(comm.telephoneList);
            }
            if (comm.emailList != null && !comm.emailList.isEmpty()) {
                merged.emailList.addAll(comm.emailList);
            }
            if (comm.addressList != null && !comm.addressList.isEmpty()) {
                merged.addressList.addAll(comm.addressList);
            }
        }

        // Return null if no data was collected (all lists empty)
        if (merged.telephoneList.isEmpty() && merged.emailList.isEmpty() && merged.addressList.isEmpty()) {
            return null;
        }

        return merged;
    }

    /**
     *********************************************************
     * @methodName      : mergeSameIdentifierOrganizations
     * @description     : The PDB alerts response returns multiple Organization nodes which have the same NPN or CoCode. This is an issue for us as NPN or CoCode
     *                   is our unique identifier for a given agency/carrier. This method merges the multiple organization nodes into a single
     *                   record.
     * @param orgsById : Map where the key is the NPN/CoCode and the value is a list of organization nodes that hold the info for that organization/carrier
     * @return          : A populated Person DTO object.
     *********************************************************
     **/
    private List<LicensingReportDTO.Organization> mergeSameIdentifierOrganizations(Map<String, List<LicensingReportDTO.Organization>> orgsById) {
        List<LicensingReportDTO.Organization> mergedOrgList = new List<LicensingReportDTO.Organization>();

        // Go through all the NPN/CoCodes
        for (String key : orgsById.keySet()) {
            List<LicensingReportDTO.Organization> orgs = orgsById.get(key);
            List<String> orgsKeys = new List<String>();

            LicensingReportDTO.Organization newOrg;
            LicensingReportDTO.Organization primaryNode;
            LicensingReportDTO.Organization secondaryNode;
            LicensingReportDTO.Organization tertiaryNode;

            // Go through all organization node per Unique NPN/CoCode
            for (LicensingReportDTO.Organization org : orgs) {
                // IMPORTANT !!! - This list holds all Keys which are identifiers found in the NIPR API Response
                // Each organization node can have multiple keys that belong to the same NPN/CoCode, and using these identifiers we match the other records such as Licenses, LOA etc... to organization records
                // It is extremely important that during the merge, we store all the keys per NPN, as later one whichever service processes this response, it won't be able to match the rest of the data to organization records correctly without all Keys
                orgsKeys.add(org.key);

                // Go through External Id for each Organization - (They have multiple, NPN/CoCode, Fein BranchId etc...)
                for (LicensingReportDTO.ExternalIdentifier extId : org.externalIdentifierList) {
                    // Conditions to find out if the node is with/without info
                    Boolean filterNodeWithInfoCond = (extid.typeCode == 'NAICInsurerCode' || extId.typeCode == 'NAICEntityCode') && org.organizationNameList != null && !org.organizationNameList.isEmpty();
                   
                    Boolean filterNodeWithoutInfoCond = (extid.typeCode == 'NAICInsurerCode' || extId.typeCode == 'NAICEntityCode') && (org.organizationNameList == null || org.organizationNameList.isEmpty());

                    if (filterNodeWithInfoCond) {
                        // When going through all organization nodes, some NPNs will have duplicate nodes where only difference will be Name Type, we want to prioritize the name type = 'Primary'
                        // We still need to go through the duplicate nodes as well as they hold the previously mention NIPR Key used for matching it with other data later on
                        // It is important to not leave out the key for any node, but in the end only keep the data of the Primary node if found, if not we can take the secondary node with name type = 'Alias'
                        // Lastly NIPR sometimes returns nodes without any info except their NPN and key identifier used to match other child records to it, this is our tertiary node and we have to account for it if the primary and secondary ones are empty so we do not miss out on any records
                        if (org.organizationNameList[0].typeCode == 'Primary') {
                            primaryNode = new LicensingReportDTO.Organization();

                            primaryNode = org;
                            primaryNode.mainIdentifier = extId.id;
                            primaryNode.mainIdentifierType = extId.typeCode;

                            continue;
                        }

                        secondaryNode = new LicensingReportDTO.Organization();

                        secondaryNode = org;
                        secondaryNode.mainIdentifier = extId.id;
                        secondaryNode.mainIdentifierType = extId.typeCode;
                    } else if (filterNodeWithoutInfoCond) {
                        tertiaryNode = org;
                        tertiaryNode.mainIdentifier = extId.id;
                        tertiaryNode.mainIdentifierType = extId.typeCode;
                        tertiaryNode.isExisting = true;
                    }
                }
            }

            // Decide if we have primary or alias node to take, but again most importantly, we added and kept the keys of all the nodes
            if (primaryNode != null || secondaryNode != null || tertiaryNode != null) {
                newOrg = primaryNode != null ? primaryNode : secondaryNode != null ? secondaryNode : tertiaryNode;
                newOrg.combinedKeys = orgsKeys;
                mergedOrgList.add(newOrg);
            }

        }

        return mergedOrgList;
    }

    /**
     *********************************************************
     * @methodName      : createFeinOnlyCarrier
     * @description     : Creates a carrier organization record from an organization that only has a FEIN identifier.
     *                    This helps handle cases where an organization doesn't have NAICEntityCode or NAICInsurerCode.
     * @param organization : The original organization DTO containing FEIN identifier
     * @param feinId       : The FEIN identifier to use as the main identifier
     * @return           : A new Organization DTO configured as a carrier with FEIN as the main identifier
     *********************************************************
     **/
    private LicensingReportDTO.Organization createFeinOnlyCarrier(LicensingReportDTO.Organization organization, String feinId) {
        // Create a simplified organization just for this FEIN carrier
        LicensingReportDTO.Organization feinCarrier = new LicensingReportDTO.Organization();

        feinCarrier.externalIdentifierList = organization.externalIdentifierList;
        feinCarrier.organizationNameList = organization.organizationNameList;

        feinCarrier.combinedKeys = new List<String>{ organization.key };
    
        
        return feinCarrier;
    }

    /**
     *********************************************************
     * @methodName      : processExternalIdentifier
     * @description     : Extracts and maps External Identifier details from the XML response.
     * @param externalIdentifierNode : The XML node containing the external identifier details.
     * @return          : A populated ExternalIdentifier DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.ExternalIdentifier processExternalIdentifier(DOM.XmlNode externalIdentifierNode) {
        LicensingReportDTO.ExternalIdentifier externalIdentifier = new LicensingReportDTO.ExternalIdentifier();

        externalIdentifier.typeCode = XMLUtils.getNodeStringValue(externalIdentifierNode, 'TypeCode');
        externalIdentifier.id = XMLUtils.getNodeStringValue(externalIdentifierNode, 'Id');

        return externalIdentifier;
    }

    /**
     *********************************************************
     * @methodName      : processPersonName
     * @description     : Extracts and maps Person Name details from the XML response.
     * @param personNameNode : The XML node containing the person name details.
     * @return          : A populated PersonName DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.PersonName processPersonName(DOM.XmlNode personNameNode) {
        LicensingReportDTO.PersonName personName = new LicensingReportDTO.PersonName();

        personName.typeCode = XMLUtils.getNodeStringValue(personNameNode, 'TypeCode');
        personName.fullName = XMLUtils.getNodeStringValue(personNameNode, 'FullName');
        personName.surname = XMLUtils.getNodeStringValue(personNameNode, 'Surname');
        personName.givenName = XMLUtils.getNodeStringValue(personNameNode, 'GivenName');
        personName.otherGivenName = XMLUtils.getNodeStringValue(personNameNode, 'OtherGivenName');
        personName.middleName = XMLUtils.getNodeStringValue(personNameNode, 'MiddleName');
        personName.nameSuffix = XMLUtils.getNodeStringValue(personNameNode, 'NameSuffix');

        return personName;
    }

    /**
     *********************************************************
     * @methodName      : processOrganizationName
     * @description     : Extracts and maps Organization Name details from the XML response.
     * @param orgNameNode : The XML node containing the organization name details.
     * @return          : A populated OrganizationName DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.OrganizationName processOrganizationName(DOM.XmlNode orgNameNode) {
        LicensingReportDTO.OrganizationName orgName = new LicensingReportDTO.OrganizationName();

        orgName.typeCode = XMLUtils.getNodeStringValue(orgNameNode, 'TypeCode');
        orgName.fullName = XMLUtils.getNodeStringValue(orgNameNode, 'FullName');

        return orgName;
    }

    /**
     *********************************************************
     * @methodName      : processPersonCommunication
     * @description     : Extracts and maps Person Communication details from the XML response.
     * @param personCommNode : The XML node containing the person communication details.
     * @return          : A populated PersonCommunication DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.PersonCommunication processPersonCommunication(DOM.XmlNode personCommNode) {
        LicensingReportDTO.PersonCommunication personCommunication = new LicensingReportDTO.PersonCommunication();

        personCommunication.telephoneList = new List<LicensingReportDTO.Telephone>();
        personCommunication.emailList = new List<LicensingReportDTO.Email>();
        
        // Go through child nodes for person communication
        for (DOM.XmlNode personCommChildNode : personCommNode.getChildElements()) {
            String personCommNodeName = personCommChildNode.getName();

            if (personCommNodeName == 'Telephone') {
                LicensingReportDTO.Telephone telephone = processTelephone(personCommChildNode);
                personcommunication.telephoneList.add(telephone);
            } else if (personCommNodeName == 'Email') {
                LicensingReportDTO.Email email = processEmail(personCommChildNode);
                personCommunication.emailList.add(email);
            } else if (personCommChildNode.getName() == 'MailingAddress') {
                personCommunication.mailingAddress = processProducerAddress(personCommChildNode);
            } else if (personCommChildNode.getName() == 'ResidentialAddress') {
                personCommunication.residentialAddress = processProducerAddress(personCommChildNode);
            }
        }

        return personCommunication;
    }

    /**
     *********************************************************
     * @methodName      : processBusinessCommunication
     * @description     : Extracts and maps Business Communication details from the XML response.
     * @param businessCommNode : The XML node containing the person communication details.
     * @return          : A populated BusinessCommunication DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.BusinessCommunication processBusinessCommunication(DOM.XmlNode businessCommNode) {
        LicensingReportDTO.BusinessCommunication businessCommunication = new LicensingReportDTO.BusinessCommunication();
        businessCommunication.telephoneList = new List<LicensingReportDTO.Telephone>();
        businessCommunication.emailList = new List<LicensingReportDTO.Email>();

        // Loop through all child elements once and process each based on its name
        for (DOM.XmlNode businessCommChildNode : businessCommNode.getChildElements()) {
            String businessCommChildName = businessCommChildNode.getName();

            if (businessCommChildName == 'Telephone') {
                LicensingReportDTO.Telephone telephone = processTelephone(businessCommChildNode);
                businessCommunication.telephoneList.add(telephone);
            } else if (businessCommChildName == 'Email') {
                LicensingReportDTO.Email email = processEmail(businessCommChildNode);
                businessCommunication.emailList.add(email);
            } else if (businessCommChildName == 'MailingAddress') {
                businessCommunication.mailingAddress = processProducerAddress(businessCommChildNode);
            } else if (businessCommChildName == 'PhysicalAddress') {
                businessCommunication.physicalAddress = processProducerAddress(businessCommChildNode);
            }
        }

        return businessCommunication;
    }

    /**
     *********************************************************
     * @methodName      : processOrganizationCommunication
     * @description     : Extracts and maps Organization Communication details from the XML response.
     * @param orgCommNode : The XML node containing the person communication details.
     * @return          : A populated organizationCommunication DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.OrganizationCommunication processOrganizationCommunication(DOM.XmlNode orgCommNode) {
        LicensingReportDTO.OrganizationCommunication orgCommunication = new LicensingReportDTO.OrganizationCommunication();
        orgCommunication.telephoneList = new List<LicensingReportDTO.Telephone>();
        orgCommunication.emailList = new List<LicensingReportDTO.Email>();

        for (DOM.XmlNode orgCommChildNode : orgCommNode.getChildElements()) {
            String orgCommChildName = orgCommChildNode.getName();
            if (orgCommChildName == 'Telephone') {
                LicensingReportDTO.Telephone phone = processTelephone(orgCommChildNode);
                orgCommunication.telephoneList.add(phone);
            } else if (orgCommChildName == 'Email') {
                LicensingReportDTO.Email email = processEmail(orgCommChildNode);
                orgCommunication.emailList.add(email);
            } else if (orgCommChildName == 'MailingAddress') {
                orgCommunication.mailingAddress = processProducerAddress(orgCommChildNode);
            } else if (orgCommChildName == 'PhysicalAddress') {
                orgCommunication.physicalAddress = processProducerAddress(orgCommChildNode);
            } else if (orgCommChildName == 'PrincipalAddress') {
                orgCommunication.principalAddress = processProducerAddress(orgCommChildNode);
            }
        }

        return orgCommunication;
    }

    /**
     *********************************************************
     * @methodName      : processTelephone
     * @description     : Extracts and maps Telephone details from the XML response.
     * @param telephoneNode : The XML node containing the telephone details.
     * @return          : A populated Telephone DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Telephone processTelephone(DOM.XmlNode telephoneNode) {
        LicensingReportDTO.Telephone telephone = new LicensingReportDTO.Telephone();

        telephone.typeCode = XMLUtils.getNodeStringValue(telephoneNode, 'TypeCode');
        telephone.phoneNumber = XMLUtils.getNodeStringValue(telephoneNode, 'PhoneNumber');

        return telephone;
    }

    /**
     *********************************************************
     * @methodName      : processEmail
     * @description     : Extracts and maps Email details from the XML response.
     * @param emailNode  : The XML node containing the email details.
     * @return          : A populated Email DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Email processEmail(DOM.XmlNode emailNode) {
        LicensingReportDTO.Email email = new LicensingReportDTO.Email();

        email.typeCode = XMLUtils.getNodeStringValue(emailNode, 'TypeCode');
        email.emailAddress = XMLUtils.getNodeStringValue(emailNode, 'EmailAddress');
        
        return email;
    }

    /**
     *********************************************************
     * @methodName      : processProducerAddress
     * @description     : Extracts and maps Entity Address details from the XML response. IMPORTANT !!! - Entity Adress just holds the reference and to the actual Address node which is processed in the beginning of the report and holds actual address data
     * @param addressNode : The XML node containing the entity address details.
     * @return          : A populated ProducerAddress DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.ProducerAddress processProducerAddress(DOM.XmlNode addressNode) {
        LicensingReportDTO.ProducerAddress producerAddress = new LicensingReportDTO.ProducerAddress();

        producerAddress.asOfDate = XMLUtils.getNodeStringValue(addressNode, 'AsOfDate');
        producerAddress.addressReferences = addressNode.getChildElement('AddressReferences', addressNode.getNamespace())?.getAttribute('addressReference', null);

        return producerAddress;
    }

    /**
     *********************************************************
     * @methodName      : processAssignedIdentifier
     * @description     : Extracts and maps Assigned Identifier details from the XML response.
     * @param addressNode : The XML node containing the entity address details.
     * @return          : A populated AssignedIdentifier DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.AssignedIdentifier processAssignedIdentifier(DOM.XmlNode assignedIdNode) {
        LicensingReportDTO.AssignedIdentifier assignedIdentifier = new LicensingReportDTO.AssignedIdentifier();

        assignedIdentifier.roleCode = XMLUtils.getNodeStringValue(assignedIdNode, 'RoleCode');
        assignedIdentifier.id = XMLUtils.getNodeStringValue(assignedIdNode, 'Id');

        return assignedIdentifier;
    }

    /**
     *********************************************************
     * @methodName      : trackEligibleDeletion
     * @description     : Tracks which entity+state combinations have license or appointment data in the payload.
     *                    This allows the service to only query and delete records that actually have data changes.
     * @param entityKeyRef : The NIPR key reference (e.g., PersonPRI704070910)
     * @param stateCode : The state code (e.g., VA, FL)
     * @param hasLicenses : Whether this state has license data in the payload
     * @param hasAppointments : Whether this state has appointment data in the payload
     * @param licensingReport : The licensing report to add eligible tracking to
     *********************************************************
     **/
    private void trackEligibleDeletion(
        String entityKeyRef,
        String stateCode,
        Boolean hasLicenses,
        Boolean hasAppointments,
        LicensingReportDTO.LicensingReport licensingReport
    ) {
        if (String.isBlank(entityKeyRef) || String.isBlank(stateCode)) {
            return;
        }

        // Track licenses - O(1) map lookup instead of looping
        if (hasLicenses) {
            if (!licensingReport.eligibleRecordsForDeletion.eligibleLicenses.containsKey(entityKeyRef)) {
                licensingReport.eligibleRecordsForDeletion.eligibleLicenses.put(entityKeyRef, new Set<String>());
            }
            licensingReport.eligibleRecordsForDeletion.eligibleLicenses.get(entityKeyRef).add(stateCode);
        }

        // Track carrier appointments - O(1) map lookup instead of looping
        if (hasAppointments) {
            if (!licensingReport.eligibleRecordsForDeletion.eligibleCarrierAppointments.containsKey(entityKeyRef)) {
                licensingReport.eligibleRecordsForDeletion.eligibleCarrierAppointments.put(entityKeyRef, new Set<String>());
            }
            licensingReport.eligibleRecordsForDeletion.eligibleCarrierAppointments.get(entityKeyRef).add(stateCode);
        }
    }

    /**
     *********************************************************
     * @methodName      : checkForDeletionMarker
     * @description     : Checks if a Licensee node contains deletion markers (empty license/appointment nodes).
     *                    Deletion markers are nodes with only TypeCode and no actual data.
     * @param licenseeNode : The XML node to check
     * @return          : Map with 'hasLicenseDeletion' and 'hasAppointmentDeletion' flags
     *********************************************************
     **/
    private Map<String, Boolean> checkForDeletionMarker(DOM.XmlNode licenseeNode) {
        Map<String, Boolean> result = new Map<String, Boolean>{
            'hasLicenseDeletion' => false,
            'hasAppointmentDeletion' => false
        };

        if (licenseeNode == null) {
            return result;
        }

        for (DOM.XmlNode childNode : licenseeNode.getChildElements()) {
            String nodeName = childNode.getName();

            // Check for license deletion marker
            if (nodeName == 'InsuranceLicense') {
                String typeCode = XMLUtils.getNodeStringValue(childNode, 'TypeCode');
                DOM.XmlNode licenseNode = childNode.getChildElement('License', childNode.getNamespace());
                

                // Deletion marker: has TypeCode but no License node
                if (typeCode == 'Entity' && licenseNode == null) {
                    result.put('hasLicenseDeletion', true);
                }
            }

            // Check for appointment deletion marker
            if (nodeName == 'InsuranceAppointment') {
                String stateCode = XMLUtils.getNodeStringValue(childNode, 'StateOrProvinceCode');
                DOM.XmlNode insurerRef = childNode.getChildElement('InsurerReferences', childNode.getNamespace());
                DOM.XmlNode licenseeRef = childNode.getChildElement('LicenseeReferences', childNode.getNamespace());

                // Deletion marker: empty fields (already filtered by processInsuranceAppointment returning null)
                if (String.isBlank(stateCode) && insurerRef == null && licenseeRef == null) {
                    result.put('hasAppointmentDeletion', true);
                }

            }
        }

        return result;
    }

    /**
     *********************************************************
     * @methodName      : processJurisdictionReport
     * @description     : Extracts and maps the data Jurisdiction Report holds - (Insurance License, LOA and Insurance Appointment and all the references to Person and Organization nodes)
     * @param jurisdictionReportNode : The XML node containing the entity address details.
     * @param licensingReport : The licensing report to populate eligible deletion tracking
     * @return          : A populated jurisdictionReport DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.JurisdictionReport processJurisdictionReport(
        DOM.XmlNode jurisdictionReportNode,
        LicensingReportDTO.LicensingReport licensingReport
    ) {
        LicensingReportDTO.JurisdictionReport jurisdictionReport = new LicensingReportDTO.JurisdictionReport();
        jurisdictionReport.jurisdictionReportItemList = new List<LicensingReportDTO.JurisdictionReportItem>();
        jurisdictionReport.personReference = jurisdictionReportNode.getChildElement('PersonReferences', jurisdictionReportNode.getNamespace())?.getAttribute('personReference', null);
        jurisdictionReport.organizationReference = jurisdictionReportNode.getChildElement('OrganizationReferences', jurisdictionReportNode.getNamespace())?.getAttribute('organizationReference', null);

        // Determine which entity key reference to use (Person or Organization)
        String entityKeyRef = jurisdictionReport.personReference != null
            ? jurisdictionReport.personReference
            : jurisdictionReport.organizationReference;

        for (DOM.XmlNode childNode : jurisdictionReportNode.getChildElements()) {
            String childNodeName = childNode.getName();

            if (childNodeName == 'JurisdictionReportItem') {
                LicensingReportDTO.JurisdictionReportItem item = new LicensingReportDTO.JurisdictionReportItem();
                item.key = childNode.getAttribute('key', null);
                item.stateOrProvinceCode = XMLUtils.getNodeStringValue(childNode, 'StateOrProvinceCode');

                DOM.XmlNode licenseeNode = childNode.getChildElement('Licensee', childNode.getNamespace());
                if (licenseeNode != null) {
                    item.licensee = processLicensee(licenseeNode);

                    // NEW: Track eligibility for deletion based on what data exists
                    if (item.licensee != null && entityKeyRef != null) {

                        Boolean hasLicenseData = licenseeNode.getChildElement('InsuranceLicense', licenseeNode.getNamespace()) != null;
                        Boolean hasAppointmentData = licenseeNode.getChildElement('InsuranceAppointment', licenseeNode.getNamespace()) != null;

                        // Track this state as eligible if it has data OR a deletion marker
                        trackEligibleDeletion(
                            entityKeyRef,
                            item.stateOrProvinceCode,
                            hasLicenseData,
                            hasAppointmentData,
                            licensingReport
                        );
                    }
                }

                jurisdictionReport.jurisdictionReportItemList.add(item);
            }
        }

        return jurisdictionReport;
    }


    /**
     *********************************************************
     * @methodName      : processLicensee
     * @description     : Extracts and maps Licensee details from the XML response. Holds info of License, LOA and Insurance Appointment of a Licensee which is an agent or an agency
     * @param licenseeNode : The XML node containing the entity address details.
     * @return          : A populated Licensee DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.Licensee processLicensee(DOM.XmlNode licenseeNode) {
        LicensingReportDTO.Licensee licensee = new LicensingReportDTO.Licensee();
        licensee.insuranceAppointments = new List<LicensingReportDTO.InsuranceAppointment>();
        licensee.licenseeReference = new List<String>();

        // Process LicenseeReferences. These are nipr keys that point to person/organization nodes which hold the info of which agent/agency the data applies to
        for (DOM.XmlNode licenseeChildNode : licenseeNode.getChildElements()) {
            if (licenseeChildNode.getName() == 'LicenseeReferences') {
                DOM.XmlNode personRefNode = licenseeChildNode.getChildElement('PersonReferences', licenseeChildNode.getNamespace());
                DOM.XmlNode orgRefNode = licenseeChildNode.getChildElement('OrganizationReferences', licenseeChildNode.getNamespace());

                if (personRefNode != null) {
                    licensee.licenseeReference.add(personRefNode.getAttribute('personReference', null));
                }

                if (orgRefNode != null) {
                    licensee.licenseeReference.add(orgRefNode.getAttribute('organizationReference', null));
                }
            }
        }

        // Process Insurance Appointments and Insurance Licenses
        licensee.insuranceAppointments = new List<LicensingReportDTO.InsuranceAppointment>();
        licensee.insuranceLicenses = new List<LicensingReportDTO.InsuranceLicense>();

        for (DOM.XmlNode childNode : licenseeNode.getChildElements()) {
            String cName = childNode.getName();

            if (cName == 'InsuranceLicense') {
                LicensingReportDTO.InsuranceLicense insuranceLicense = processInsuranceLicense(childNode);

                if (insuranceLicense != null) {
                    licensee.insuranceLicenses.add(insuranceLicense);
                }
            }

            if (childNode.getName() == 'InsuranceAppointment') {
                LicensingReportDTO.InsuranceAppointment appointment = processInsuranceAppointment(childNode);

                if (appointment != null) {
                    licensee.insuranceAppointments.add(appointment);
                 }
            }
        }

        return licensee;
    }

    /**
     *********************************************************
     * @methodName      : processInsuranceLicense
     * @description     : Extracts and maps Insurance License details from XML.
     * @param insuranceLicenseNode : The XML node containing Insurance License details.
     * @return          : A populated InsuranceLicense DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.InsuranceLicense processInsuranceLicense(DOM.XmlNode insuranceLicenseNode) {
        LicensingReportDTO.InsuranceLicense insuranceLicense = new LicensingReportDTO.InsuranceLicense();

        insuranceLicense.residentLicenseIndicator = XMLUtils.getNodeBooleanValue(insuranceLicenseNode, 'ResidentLicenseIndicator');
        insuranceLicense.qualifyingInsuranceLicenseIndicator = XMLUtils.getNodeBooleanValue(insuranceLicenseNode, 'QualifyingInsuranceLicenseIndicator');
        insuranceLicense.typeCode = XMLUtils.getNodeStringValue(insuranceLicenseNode, 'TypeCode');

        // Process License
        DOM.XmlNode licenseNode = insuranceLicenseNode.getChildElement('License', insuranceLicenseNode.getNamespace());

        // NEW: Check for deletion marker - if TypeCode is 'Entity' and no License node, this is a deletion marker
        // Return null to avoid creating a DTO object, but the state will still be tracked as eligible for deletion
        if (insuranceLicense.typeCode == 'Entity' && licenseNode == null) {
            return null;
        }

        if (licenseNode != null) {
            insuranceLicense.license = processLicense(licenseNode);
        }

        // Process Lines of Authority. Each license can have multiple lines of authority
        insuranceLicense.lineOfAuthorityList = new List<LicensingReportDTO.LineOfAuthority>();

        for (DOM.XmlNode childNode : insuranceLicenseNode.getChildElements()) {
            if (childNode.getName() == 'LineOfAuthority') {
                LicensingReportDTO.LineOfAuthority loa = processLineOfAuthority(childNode);
                insuranceLicense.lineOfAuthorityList.add(loa);
            }
        }

        return insuranceLicense;
    }
    
    /**
     *********************************************************
     * @methodName      : processLicense
     * @description     : Extracts and maps License details from XML.
     * @param licenseNode : The XML node containing License details.
     * @return          : A populated License DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.License processLicense(DOM.XmlNode licenseNode) {
        LicensingReportDTO.License license = new LicensingReportDTO.License();
        license.continuingEducation = new LicensingReportDTO.ContinuingEducation();

        license.key = licenseNode.getAttribute('key', null);
        license.licenseNumberId = XMLUtils.getNodeStringValue(licenseNode, 'LicenseNumberId');
        license.statusCode = XMLUtils.getNodeStringValue(licenseNode, 'StatusCode');
        license.statusDescription = XMLUtils.getNodeStringValue(licenseNode, 'StatusDescription');
        license.issueDate = XMLUtils.getNodeStringValue(licenseNode, 'IssueDate');
        license.licenseClassCode = XMLUtils.getNodeStringValue(licenseNode, 'LicenseClassCode');
        license.licenseClassDescription = XMLUtils.getNodeStringValue(licenseNode, 'LicenseClassDescription');
        license.stateOrProvinceCode = XMLUtils.getNodeStringValue(licenseNode, 'StateOrProvinceCode');
        license.stateOrProvinceName = XMLUtils.getNodeStringValue(licenseNode, 'StateOrProvinceName');
        license.asOfDate = XMLUtils.getNodeStringValue(licenseNode, 'AsOfDate');

        DOM.XmlNode licensePeriod = licenseNode.getChildElement('LicensePeriod', licenseNode.getNamespace());
        
        if (licensePeriod != null) {
            license.endDate = XMLUtils.getNodeStringValue(licensePeriod, 'EndDate');
            license.startDate = XMLUtils.getNodeStringValue(licensePeriod, 'StartDate');
        }

        DOM.XmlNode continuingEducation = licenseNode.getChildElement('ContinuingEducation', licenseNode.getNamespace());

        if (continuingEducation != null) {
            license.continuingEducation.stateOrProvinceCode = XMLUtils.getNodeStringValue(continuingEducation, 'StateOrProvinceCode');
            license.continuingEducation.statusDescription = XMLUtils.getNodeStringValue(continuingEducation, 'StatusDescription');
            license.continuingEducation.unitsRequiredMeasure = XMLUtils.getNodeStringValue(continuingEducation, 'ContinuingEducationUnitsRequiredMeasure');

            DOM.XmlNode continuingEducationPeriod = continuingEducation.getChildElement('ContinuingEducationPeriod', continuingEducation.getNamespace());

            if (continuingEducationPeriod != null) {
                license.continuingEducation.startDate = XMLUtils.getNodeStringValue(continuingEducationPeriod, 'StartDate');
                license.continuingEducation.endDate = XMLUtils.getNodeStringValue(continuingEducationPeriod, 'EndDate');
                license.continuingEducation.periodDuration = XMLUtils.getNodeStringValue(continuingEducationPeriod, 'PeriodDuration');
            }

        }

        return license;
    }

    /**
     *********************************************************
     * @methodName      : processLineOfAuthority
     * @description     : Extracts and maps Line Of Authority details from XML.
     * @param loaNode : The XML node containing Line Of Authority details.
     * @return          : A populated LineOfAuthority DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.LineOfAuthority processLineOfAuthority(DOM.XmlNode loaNode) {
        LicensingReportDTO.LineOfAuthority loa = new LicensingReportDTO.LineOfAuthority();

        loa.issueDate = XMLUtils.getNodeStringValue(loaNode, 'IssueDate');
        loa.renewalDate = XMLUtils.getNodeStringValue(loaNode, 'RenewalDate');
        loa.stateOrProvinceCode = XMLUtils.getNodeStringValue(loaNode, 'StateOrProvinceCode');
        loa.stateOrProvinceName = XMLUtils.getNodeStringValue(loaNode, 'StateOrProvinceName');
        loa.lineOfAuthorityCode = XMLUtils.getNodeStringValue(loaNode, 'LineOfAuthorityCode');
        loa.lineOfAuthorityDescription = XMLUtils.getNodeStringValue(loaNode, 'LineOfAuthorityDescription');
        loa.statusCode = XMLUtils.getNodeStringValue(loaNode, 'StatusCode');
        loa.statusDescription = XMLUtils.getNodeStringValue(loaNode, 'StatusDescription');
        loa.statusReasonCode = XMLUtils.getNodeStringValue(loaNode, 'StatusReasonCode');
        loa.statusReasonDescription = XMLUtils.getNodeStringValue(loaNode, 'StatusReasonDescription');

        // Extract StatusPeriod StartDate
        DOM.XmlNode statusPeriodNode = loaNode.getChildElement('StatusPeriod', loaNode.getNamespace());
        if (statusPeriodNode != null) {
            loa.startDate = XMLUtils.getNodeStringValue(statusPeriodNode, 'StartDate');
        }

        DOM.XmlNode continuingEducationNode = loaNode.getChildElement('ContinuingEducation', loaNode.getNamespace());
        if (continuingEducationNode != null) {
            loa.continuingEducation = new LicensingReportDTO.ContinuingEducation();
            
            loa.continuingEducation.stateOrProvinceCode = XMLUtils.getNodeStringValue(continuingEducationNode, 'StateOrProvinceCode');
            loa.continuingEducation.statusCode = XMLUtils.getNodeStringValue(continuingEducationNode, 'StatusCode');
            loa.continuingEducation.statusDescription = XMLUtils.getNodeStringValue(continuingEducationNode, 'StatusDescription');
            loa.continuingEducation.unitsRequiredMeasure = XMLUtils.getNodeStringValue(continuingEducationNode, 'ContinuingEducationUnitsRequiredMeasure');
            loa.continuingEducation.unitsRemainingMeasure = XMLUtils.getNodeStringValue(continuingEducationNode, 'ContinuingEducationUnitsRemainingMeasure');
            loa.continuingEducation.asOfDate = XMLUtils.getNodeStringValue(continuingEducationNode, 'AsOfDate');

            DOM.XmlNode continuingEducationPeriodNode = continuingEducationNode.getChildElement('ContinuingEducationPeriod', continuingEducationNode.getNamespace());
            if (continuingEducationPeriodNode != null) {
                loa.continuingEducation.endDate = XMLUtils.getNodeStringValue(continuingEducationPeriodNode, 'EndDate');                
            }
        }

        return loa;
    }

    /**
     *********************************************************
     * @methodName      : processInsuranceAppointment
     * @description     : Extracts and maps Insurance Appointment details from XML.
     * @param appointmentNode : The XML node containing Insurance Appointment details.
     * @return          : A populated InsuranceAppointment DTO object.
     *********************************************************
     **/
    private LicensingReportDTO.InsuranceAppointment processInsuranceAppointment(DOM.XmlNode appointmentNode) {
        LicensingReportDTO.InsuranceAppointment appointment = new LicensingReportDTO.InsuranceAppointment();
        appointment.linesOfAuthority = new List<LicensingReportDTO.LineOfAuthority>();

        appointment.stateOrProvinceCode = XMLUtils.getNodeStringValue(appointmentNode, 'StateOrProvinceCode');
        appointment.statusCode = XMLUtils.getNodeStringValue(appointmentNode, 'StatusCode');
        appointment.statusDescription = XMLUtils.getNodeStringValue(appointmentNode, 'StatusDescription');
        appointment.statusReasonCode = XMLUtils.getNodeStringValue(appointmentNode, 'StatusReasonCode');
        appointment.statusReasonDescription = XMLUtils.getNodeStringValue(appointmentNode, 'StatusReasonDescription');
        appointment.terminationEffectiveDate = XMLUtils.getNodeStringValue(appointmentNode, 'TerminationEffectiveDate');
        appointment.appointmentEffectiveDate = XMLUtils.getNodeStringValue(appointmentNode, 'AppointmentEffectiveDate');
        appointment.asOfDate = XMLUtils.getNodeStringValue(appointmentNode, 'AsOfDate');

        // Extract Insurer References (Organization)
        DOM.XmlNode insurerReferencesNode = appointmentNode.getChildElement('InsurerReferences', appointmentNode.getNamespace());
        if (insurerReferencesNode != null) {
            DOM.XmlNode orgRefNode = insurerReferencesNode.getChildElement('OrganizationReferences', insurerReferencesNode.getNamespace());
            
            if (orgRefNode != null) {
                appointment.insurerReferences = orgRefNode.getAttribute('organizationReference', null);
            }
        }   

        // Extract Licensee References (Person)
        DOM.XmlNode licenseeReferencesNode = appointmentNode.getChildElement('LicenseeReferences', appointmentNode.getNamespace());
        if (licenseeReferencesNode != null) {
            DOM.XmlNode personRefNode = licenseeReferencesNode.getChildElement('PersonReferences', licenseeReferencesNode.getNamespace());
            if (personRefNode != null) {
                appointment.licenseeReferences = personRefNode.getAttribute('personReference', null);
            } else {
                DOM.XmlNode organizationRefNode = licenseeReferencesNode.getChildElement('OrganizationReferences', licenseeReferencesNode.getNamespace());
                if (organizationRefNode != null) {
                    appointment.licenseeReferences = organizationRefNode.getAttribute('organizationReference', null);
                }
            }
        }

        // Extract Line of Authority nodes
        for (DOM.XmlNode childNode : appointmentNode.getChildElements()) {
            if (childNode.getName() == 'LineOfAuthority') {
                LicensingReportDTO.LineOfAuthority loa = processLineOfAuthority(childNode);

                if (loa != null) {
                    appointment.linesOfAuthority.add(loa);
                }
            }
        }

        if (appointment.licenseeReferences == null && appointment.insurerReferences == null) {
            return null;
        }
        
        return appointment;
    }
    
    private d4c_NIPR_Sync_Settings__mdt getNIPRSyncSettings() {
        MetadataTypeSelector mtdSelector = new MetadataTypeSelector();
        return mtdSelector.getNIPRSyncSettings();
    }
}