/**
 * @description       : 
 * @author            : Stefan Nidzovic
 * @group             : 
 * @last modified on  : 09-11-2025
 * @last modified by  : Stefan Nidzovic
**/
@isTest
private class ProcessEntityInfoApiService_Test {
    private static final String AGENT_NPN = '12345678';
    private static final String AGENCY_NPN = '87654321';

    // TEST METHODS
    @isTest
    static void processData_testAgentData() {
        // Set mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);
        
        // Execute
        Test.startTest();
        ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
        service.processData(AGENT_NPN);
        Test.stopTest();
        
        // Assert
        assertRecordCountsIndividualNode();
        assertExternalIdsIndividualNode();
        assertFieldMappingsIndividualNode();
    }

    @isTest
    static void processData_testAgencyData() {
        // Set Mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIFirmlXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);
        
        // Execute
        Test.startTest();
        ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
        service.processData(AGENCY_NPN);
        Test.stopTest();
        
        // Assert
        assertRecordCountsFirmNode();

        // No need to assert external Ids as they were asserted for Individual(Agent) node and the logic is the same

        assertFieldMappingsFirmNode();
    }

    @isTest
    static void processData_testAgencyDataLargeProducer() {
        // Set Mock - same as regular agency test
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIFirmlXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);
        
        // Set the static test flag to simulate large producer behavior
        RetrieveEntityInfoApiData.testLargeProducer = true;
        
        // Execute
        Test.startTest();
        ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
        service.processData(AGENCY_NPN);
        Test.stopTest();
        
        // Reset the flag
        RetrieveEntityInfoApiData.testLargeProducer = false;
        
        // Assert record counts - same as regular agency test but 0 carrier appointments
        assertRecordCountsFirmNodeLargeProducer();
    }

    @isTest
    static void processData_testUpdateExistingData() {
        //Create Data
        TestDataFactory.createEntityInfoTestData();
        
        // Assert initial record counts
        assertInitialRecordCounts();
        
        // set mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPIIndividualXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);
        
        // execute
        Test.startTest();
        ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
        service.processData(AGENT_NPN);
        Test.stopTest();

        // Assert
        assertRecordCountsPerParentObject();
    }

    @isTest
    static void processData_testApiSystemError() {
        // Set Mock
        HttpMockFactory mockFactory = new HttpMockFactory(500, TestDataFactory.getEntityInfoAPIFirmlXmlResponse(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        try {
            ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
            service.processData(AGENCY_NPN);
        } catch (ProcessEntityInfoApiService.EntityInfoAPIException ex) {
            System.assert(ex.getMessage().contains(NIPREnums.EntityInfoError.UNKOWN_ISSUE.toString()));
        }
        Test.stopTest();
    }

    @isTest
    static void processData_testNoProducerData() {
        // Set Mock
        HttpMockFactory mockFactory = new HttpMockFactory(200, TestDataFactory.getEntityInfoAPINoProducerData(), false);
        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
        try {
            ProcessEntityInfoApiService service = new ProcessEntityInfoApiService();
            service.processData(AGENCY_NPN);
        } catch (ProcessEntityInfoApiService.EntityInfoAPIException ex) {
            System.assert(ex.getMessage().contains(NIPREnums.EntityInfoError.NO_PRODUCER_DATA.toString()));
        }
        Test.stopTest();
    }
    
    // ASSERT METHODS

    private static void assertInitialRecordCounts() {
        System.assertEquals(1, getCount('ht_Producer__c'), 'Should have one initial Producer');
        System.assertEquals(2, getCount('ht_ProducerAddress__c'), 'Should have two initial Producer Addresses');
        System.assertEquals(5, getCount('ht_ProducerCommunication__c'), 'Should have five initial Producer Communications');
        System.assertEquals(2, getCount('ht_License__c'), 'Should have two initial Licenses');
        System.assertEquals(3, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__c != NULL'), 'Should have three initial License Lines of Authority');
        System.assertEquals(2, getCount('ht_Carrier__c'), 'Should have two initial Carriers');
        System.assertEquals(3, getCount('ht_CarrierAppointment__c'), 'Should have three initial Carrier Appointments');
        // No carrier appointment LOAs - LOA fields are now directly on CarrierAppointment object
    }
    
    private static void assertRecordCountsIndividualNode() {
        System.assertEquals(1, getCount('ht_Producer__c'), 'Should create one Producer');
        System.assertEquals(3, getCount('ht_ProducerAddress__c'), 'Should create three Producer Addresses');
        System.assertEquals(8, getCount('ht_ProducerCommunication__c'), 'Should create eight Producer Communications');
        System.assertEquals(3, getCount('ht_License__c'), 'Should create three Licenses');
        System.assertEquals(5, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__c != NULL'), 'Should create five License Lines of Authority');
        System.assertEquals(2, getCount('ht_Carrier__c'), 'Should create two Carriers');
        System.assertEquals(4, getCount('ht_CarrierAppointment__c'), 'Should create four Carrier Appointments');
        System.assertEquals(4, getCount('ht_CarrierAppointment__c', 'WHERE ht_LineOfAuthorityCode__c != NULL'), 'Should create four Carrier Appointments with LOA fields populated');
    }

    private static void assertRecordCountsFirmNode() {
        System.assertEquals(1, getCount('ht_Producer__c'), 'Should create one Producer');
        System.assertEquals(3, getCount('ht_ProducerAddress__c'), 'Should create three Producer Addresses');
        System.assertEquals(8, getCount('ht_ProducerCommunication__c'), 'Should create five Producer Communications');
        System.assertEquals(3, getCount('ht_License__c'), 'Should create three Licenses');
        System.assertEquals(5, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__c != NULL'), 'Should create five License Lines of Authority');
        System.assertEquals(2, getCount('ht_Carrier__c'), 'Should create two Carriers');
        System.assertEquals(4, getCount('ht_CarrierAppointment__c'), 'Should create four Carrier Appointments');
        System.assertEquals(4, getCount('ht_CarrierAppointment__c', 'WHERE ht_LineOfAuthorityCode__c != NULL'), 'Should create four Carrier Appointments with LOA fields populated');
    }

    private static void assertRecordCountsPerParentObject() {
        System.assertEquals(8, getCount('ht_ProducerCommunication__c', 'WHERE ht_Producer__r.ht_NPN__c = \'' + AGENT_NPN + '\''), 'Should have 8 communications for producer ' + AGENT_NPN);
        System.assertEquals(3, getCount('ht_ProducerAddress__c', 'WHERE ht_Producer__r.ht_NPN__c = \'' + AGENT_NPN + '\''), 'Should have 3 addresses for producer ' + AGENT_NPN);
        System.assertEquals(3, getCount('ht_License__c', 'WHERE ht_Producer__r.ht_NPN__c = \'' + AGENT_NPN + '\''), 'Should have 3 licenses for producer ' + AGENT_NPN);
        System.assertEquals(1, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__r.ht_LicenseNumber__c = \'CA123456\''), 'Should have 1 LOA for license CA123456');
        System.assertEquals(3, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__r.ht_LicenseNumber__c = \'NY789012\''), 'Should have 3 LOAs for license NY789012');
        System.assertEquals(1, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__r.ht_LicenseNumber__c = \'NY345678\''), 'Should have 1 LOA for license NY345678');
        System.assertEquals(1, getCount('ht_CarrierAppointment__c', 'WHERE ht_Carrier__r.ht_CoCode__c = \'54321\''), 'Should have 1 appointment for carrier 54321');
        System.assertEquals(3, getCount('ht_CarrierAppointment__c', 'WHERE ht_Carrier__r.ht_CoCode__c = \'98765\''), 'Should have 3 appointments for carrier 98765');

        // Verify carrier appointments have LOA fields populated
        System.assertEquals(1, getCount('ht_CarrierAppointment__c', 'WHERE ht_UniqueIdentifier__c = \'1234567854321123456789CA001Terminated12345678543211234567892026-02-012023-02-0100116\' AND ht_LineOfAuthorityCode__c = \'16\''), 'CA appointment should have LOA code 16');
        System.assertEquals(1, getCount('ht_CarrierAppointment__c', 'WHERE ht_UniqueIdentifier__c = \'1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503616\' AND ht_LineOfAuthorityCode__c = \'16\''), 'NY Life appointment should have LOA code 16');
        System.assertEquals(1, getCount('ht_CarrierAppointment__c', 'WHERE ht_UniqueIdentifier__c = \'1234567898765987654321NY036Terminated12345678987659876543212026-03-152024-03-1503612\' AND ht_LineOfAuthorityCode__c = \'12\''), 'NY Property appointment should have LOA code 12');
        System.assertEquals(1, getCount('ht_CarrierAppointment__c', 'WHERE ht_UniqueIdentifier__c = \'1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503611\' AND ht_LineOfAuthorityCode__c = \'11\''), 'NY Casualty appointment should have LOA code 11');
    }

    private static void assertExternalIdsIndividualNode() {
        assertIndividualProducerNPNs();
        assertIndividualProducerAddressIds();
        assertIndividualProducerCommunicationIds();
        assertIndividualCarrierIds();
        assertIndividualLicenseIds();
        assertIndividualLineOfAuthorityIds();
        assertIndividualCarrierAppointmentIds();
    }

    private static void assertIndividualProducerNPNs() {
        Set<String> expectedNPNs = new Set<String>{'12345678'};
        Set<String> actualNPNs = queryProducerNPNs();
        
        System.assertEquals(expectedNPNs.size(), actualNPNs.size(), 'Number of Producer NPNs does not match');
        for (String npn : expectedNPNs) {
            System.assert(actualNPNs.contains(npn), 'Producer NPN not found: ' + npn);
        }
    }

    private static void assertIndividualProducerAddressIds() {
        Set<String> expectedIds = new Set<String>{
            '123MainStreetApt4BBuildingCLosAngelesCA90001U.S.A.Residential12345678',
            '456ParkAvenueSuite789NewYorkNY10022U.S.A.Business12345678',
            '789BroadwayFloor10NewYorkNY10003U.S.A.Mailing12345678'
        };
        
        Set<String> actualIds = queryProducerAddressIds();
        
        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of Producer Address IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'Producer Address ID not found: ' + id);
        }
    }

    private static void assertIndividualProducerCommunicationIds() {
        Set<String> expectedIds = new Set<String>{
            '+1-213-555-1234Wired12345678',
            '+1-213-555-5678Fax12345678',
            'mjohnson@example.comBusiness12345678',
            '+1-212-555-9876Wired12345678',
            '+1-212-555-5432Fax12345678',
            'michael.johnson@example.comBusiness12345678',
            '+1-917-555-1111Wired12345678',
            'm.johnson.ny@example.comBusiness12345678'
        };
        
        Set<String> actualIds = queryProducerCommunicationIds();
        
        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of Producer Communication IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'Producer Communication ID not found: ' + id);
        }
    }

    private static void assertIndividualCarrierIds() {
        Set<String> expectedIds = new Set<String>{
            '54321123456789',
            '98765987654321'
        };
        
        Set<String> actualIds = queryCarrierIds();
        
        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of Carrier IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'Carrier ID not found: ' + id);
        }
    }

    private static void assertIndividualLicenseIds() {
        Set<String> expectedIds = new Set<String>{
            'CA123456CA3',
            'NY789012NY3',
            'NY345678NY4'
        };
        
        Set<String> actualIds = queryLicenseIds();
        
        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of License IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'License ID not found: ' + id);
        }
    }

    private static void assertIndividualLineOfAuthorityIds() {
        // Only License LOAs - Carrier Appointment LOAs no longer created as separate records
        Set<String> expectedIds = new Set<String>{
            '16CA2023-01-15CA123456CA3',
            '16NY2023-03-01NY789012NY3',
            '12NY2023-03-01NY789012NY3',
            '11NY2023-03-01NY789012NY3',
            '25NY2023-03-15NY345678NY4'
        };

        Set<String> actualIds = queryLineOfAuthorityIds();

        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of Line of Authority IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'Line of Authority ID not found: ' + id);
        }
    }

    private static void assertIndividualCarrierAppointmentIds() {
        Set<String> expectedIds = new Set<String>{
            '1234567854321123456789CA001Terminated12345678543211234567892026-02-012023-02-0100116',
            '1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503616',
            '1234567898765987654321NY036Terminated12345678987659876543212026-03-152024-03-1503612',
            '1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503611'
        };
        
        Set<String> actualIds = queryCarrierAppointmentIds();
        
        System.assertEquals(expectedIds.size(), actualIds.size(), 'Number of Carrier Appointment IDs does not match');
        for (String id : expectedIds) {
            System.assert(actualIds.contains(id), 'Carrier Appointment ID not found: ' + id);
        }
    }

    private static void assertFieldMappingsIndividualNode() {
        assertIndividualProducerFields();
        assertIndividualProducerAddressFields();
        assertIndividualProducerCommunicationFields();
        assertIndividualLicenseFields();
        assertIndividualLineOfAuthorityFields();
        assertIndividualCarrierFields();
        assertIndividualCarrierAppointmentFields();
        assertIndividualAppointmentLineOfAuthorityFields();
    }

    // Most of the fields are the same as in the INDIVIDUAL node, so no need to assert them again except for the producer node
    private static void assertFieldMappingsFirmNode() {
        assertFirmProducerFields();
    }

    private static void assertIndividualProducerFields() {
        ht_Producer__c producer = queryProducer(AGENT_NPN);
        
        System.assertEquals(AGENT_NPN, producer.ht_NPN__c, 'NPN should match');
        System.assertEquals('Active', producer.ht_NPNStatus__c, 'NPN Status should be Active');
        System.assertEquals('Michael', producer.ht_GivenName__c, 'Given Name should match');
        System.assertEquals('R', producer.ht_MiddleName__c, 'Middle Name should match');
        System.assertEquals('Johnson', producer.ht_SurName__c, 'Surname should match');
        System.assertEquals('JR', producer.ht_NameSuffix__c, 'Name Suffix should match');
        System.assertEquals('123-45-6789', producer.ht_SSN__c, 'SSN should match');
        System.assertEquals(Date.newInstance(1980, 6, 15), producer.ht_BirthDate__c, 'Birth date should match');
        System.assertEquals('Agent', producer.ht_Type__c, 'Type should be Agent');
        System.assertEquals('Primary', producer.ht_NameTypeCode__c, 'Name type code should match');
    }

    private static void assertFirmProducerFields() {
        ht_Producer__c producer = queryProducer(AGENCY_NPN);

        System.assertEquals(AGENCY_NPN, producer.ht_NPN__c, 'NPN should match');
        System.assertEquals('Active', producer.ht_NPNStatus__c, 'NPN Status should be Active');
        System.assertEquals('Johnson Insurance Agency, LLC', producer.ht_FullName__c, 'Full name should match');
        System.assertEquals('JIA12345', producer.ht_StateCOID__c, 'State CO ID should match');
        System.assertEquals('CA', producer.ht_StateDomicile__c, 'State Domicile should match');
        System.assertEquals('987654321', producer.ht_FEIN__c, 'FEIN should match');
        System.assertEquals('DBA', producer.ht_NameTypeCode__c, 'Name type code should match');
        System.assertEquals('Agency', producer.ht_Type__c, 'Type should be Agency');
    }

    private static void assertIndividualProducerAddressFields() {
        ht_ProducerAddress__c address = queryProducerAddress();
        
        System.assertEquals('Residential', address.ht_AddressType__c, 'Address type should be Residential');
        System.assertEquals('123 Main Street', address.ht_AddressLineOne__c, 'Address line 1 should match');
        System.assertEquals('Apt 4B', address.ht_AddressLineTwo__c, 'Address line 2 should match');
        System.assertEquals('Building C', address.ht_AddressLineThree__c, 'Address line 3 should match');
        System.assertEquals('Los Angeles', address.ht_City__c, 'City should match');
        System.assertEquals('CA', address.ht_State__c, 'State should match');
        System.assertEquals('90001', address.ht_PostalCode__c, 'Postal code should match');
        System.assertEquals('U.S.A.', address.ht_CountryCode__c, 'Country code should match');
        System.assertEquals(Date.newInstance(2025, 3, 15), address.ht_AsOfDate__c, 'As of date should match');
    }

    private static void assertIndividualProducerCommunicationFields() {
        ht_ProducerCommunication__c phone = queryProducerPhone();
        System.assertEquals('Wired', phone.ht_PhoneType__c, 'Phone type should be Wired');
        System.assertEquals('+1-213-555-1234', phone.ht_PhoneNumber__c, 'Phone number should match');
        
        ht_ProducerCommunication__c email = queryProducerEmail();
        System.assertEquals('Business', email.ht_EmailType__c, 'Email type should be Business');
        System.assertEquals('mjohnson@example.com', email.ht_EmailAddress__c, 'Email address should match');
    }

    private static void assertIndividualLicenseFields() {
        ht_License__c license = queryLicense();
        
        System.assertEquals('CA123456', license.ht_LicenseNumber__c, 'License number should match');
        System.assertEquals('CA', license.ht_StateOrProvinceCode__c, 'State code should match');
        System.assertEquals('CA', license.ht_StateOrProvinceName__c, 'State name should match');
        System.assertEquals('Insurance Producer', license.ht_LicenseClassDescription__c, 'License class should match');
        System.assertEquals('3', license.ht_LicenseClassCode__c, 'License class code should match');
        System.assertEquals('Active', license.ht_StatusCode__c, 'Status code should match');
        System.assertEquals(true, license.ht_ResidentLicenseIndicator__c, 'Resident indicator should be true');
        System.assertEquals('Producer', license.ht_TypeCode__c, 'Type code should match');
        System.assertEquals(Date.newInstance(2023, 1, 15), license.ht_IssueDate__c, 'Issue date should match');
        System.assertEquals(Date.newInstance(2026, 1, 15), license.ht_EndDate__c, 'End date should match');
        System.assertEquals(Date.newInstance(2025, 4, 1), license.ht_AsOfDate__c, 'As of date should match');
    }

    private static void assertIndividualLineOfAuthorityFields() {
        ht_LineOfAuthority__c loa = queryLicenseLOA();
        
        System.assertEquals('16', loa.ht_LineOfAuthorityCode__c, 'LOA code should match');
        System.assertEquals('Life', loa.ht_LineOfAuthorityDescription__c, 'LOA description should match');
        System.assertEquals('CA', loa.ht_StateOrProvinceCode__c, 'State code should match');
        System.assertEquals('CA', loa.ht_StateOrProvinceName__c, 'State name should match');
        System.assertEquals('Active', loa.ht_StatusCode__c, 'Status code should match');
        System.assertEquals('Initial Issue', loa.ht_StatusReasonCode__c, 'Status reason should match');
        System.assertEquals(Date.newInstance(2023, 1, 15), loa.ht_IssueDate__c, 'Issue date should match');
        System.assertEquals(Date.newInstance(2023, 1, 15), loa.ht_StartDate__c, 'Start date should match');
        System.assertEquals('Compliant', loa.ht_CEStatusDescription__c, 'CE status should match');
        System.assertEquals('24', loa.ht_CEUnitsRequiredMeasure__c, 'CE units required should match');
        System.assertEquals(Date.newInstance(2026, 1, 15), loa.ht_CERenewalDate__c, 'CE renewal date should match');
    }

    private static void assertIndividualCarrierFields() {
        ht_Carrier__c carrier = queryCarrier();
        
        System.assertEquals('98765', carrier.ht_CoCode__c, 'CoCode should match');
        System.assertEquals('XYZ Insurance Company', carrier.ht_FullName__c, 'Full name should match');
        System.assertEquals('987654321', carrier.ht_FEIN__c, 'FEIN should match');
    }

    private static void assertIndividualCarrierAppointmentFields() {
        ht_CarrierAppointment__c appointment = queryCarrierAppointment();
        
        System.assertEquals('NY', appointment.ht_StateOrProvinceCode__c, 'State code should match');
        System.assertEquals('036', appointment.ht_CountyCode__c, 'County code should match');
        System.assertEquals('XYZ789', appointment.ht_AppointerStateCOID__c, 'Appointer State CO ID should match');
        System.assertEquals('Appointed', appointment.ht_StatusCode__c, 'Status code should match');
        System.assertEquals(null, appointment.ht_TerminationReason__c, 'Termination reason should be null');
        System.assertEquals(Date.newInstance(2023, 3, 15), appointment.ht_StatusReasonDate__c, 'Status reason date should match');
        System.assertEquals(Date.newInstance(2026, 3, 15), appointment.ht_RenewalDate__c, 'Renewal date should match');
    }

    private static void assertIndividualAppointmentLineOfAuthorityFields() {
        ht_CarrierAppointment__c appointment = queryCarrierAppointment();

        // Assert LOA fields are populated directly on carrier appointment
        System.assertEquals('16', appointment.ht_LineOfAuthorityCode__c, 'LOA code should match');
        System.assertEquals('Life', appointment.ht_LineOfAuthorityDescription__c, 'LOA description should match');
        System.assertEquals(Date.newInstance(2026, 3, 15), appointment.ht_RenewalDate__c, 'Renewal date should match');
    }
    
    // ASSERT METHODS FOR LARGE PRODUCER TESTS
    private static void assertRecordCountsFirmNodeLargeProducer() {
        System.assertEquals(1, getCount('ht_Producer__c'), 'Should create one Producer');
        System.assertEquals(3, getCount('ht_ProducerAddress__c'), 'Should create three Producer Addresses');
        System.assertEquals(8, getCount('ht_ProducerCommunication__c'), 'Should create five Producer Communications');
        System.assertEquals(3, getCount('ht_License__c'), 'Should create three Licenses');
        System.assertEquals(5, getCount('ht_LineOfAuthority__c', 'WHERE ht_License__c != NULL'), 'Should create five License Lines of Authority');
        System.assertEquals(0, getCount('ht_Carrier__c'), 'Should create 0 Carriers');
        System.assertEquals(0, getCount('ht_CarrierAppointment__c'), 'Should create zero Carrier Appointments (removed by XML surgery)');
        // No carrier appointment LOAs - LOA fields are now directly on CarrierAppointment object
    }
    
    // SELECTOR METHODS AND HELPERS
    private static Integer getCount(String objectName) {
        String queryString = 'SELECT count() FROM ' + objectName;
        return Database.countQuery(queryString);
    }

    private static Integer getCount(String objectName, String whereClause) {
        String queryString = 'SELECT count() FROM ' + objectName + ' ' + whereClause;
        return Database.countQuery(queryString);
    }
    
    private static Set<String> queryProducerNPNs() {
        Set<String> npns = new Set<String>();
        for (ht_Producer__c producer : [SELECT ht_NPN__c FROM ht_Producer__c]) {
            npns.add(producer.ht_NPN__c);
        }
        return npns;
    }
    
    private static Set<String> queryProducerAddressIds() {
        Set<String> ids = new Set<String>();
        for (ht_ProducerAddress__c address : [SELECT ht_UniqueIdentifier__c FROM ht_ProducerAddress__c]) {
            ids.add(address.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static Set<String> queryProducerCommunicationIds() {
        Set<String> ids = new Set<String>();
        for (ht_ProducerCommunication__c comm : [SELECT ht_UniqueIdentifier__c FROM ht_ProducerCommunication__c]) {
            ids.add(comm.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static Set<String> queryCarrierIds() {
        Set<String> ids = new Set<String>();
        for (ht_Carrier__c carrier : [SELECT ht_UniqueIdentifier__c FROM ht_Carrier__c]) {
            ids.add(carrier.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static Set<String> queryLicenseIds() {
        Set<String> ids = new Set<String>();
        for (ht_License__c license : [SELECT ht_UniqueIdentifier__c FROM ht_License__c]) {
            ids.add(license.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static Set<String> queryLineOfAuthorityIds() {
        Set<String> ids = new Set<String>();
        for (ht_LineOfAuthority__c loa : [SELECT ht_UniqueIdentifier__c FROM ht_LineOfAuthority__c]) {
            ids.add(loa.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static Set<String> queryCarrierAppointmentIds() {
        Set<String> ids = new Set<String>();
        for (ht_CarrierAppointment__c appointment : [SELECT ht_UniqueIdentifier__c FROM ht_CarrierAppointment__c]) {
            ids.add(appointment.ht_UniqueIdentifier__c);
        }
        return ids;
    }
    
    private static ht_Producer__c queryProducer(String npn) {
        return [
            SELECT
                ht_NPN__c, 
                ht_NPNStatus__c, 
                ht_FullName__c, 
                ht_GivenName__c, 
                ht_MiddleName__c, 
                ht_StateCOID__c, 
                ht_StateDomicile__c,
                ht_SurName__c, 
                ht_NameSuffix__c, 
                ht_SSN__c, 
                ht_FEIN__c, 
                ht_BirthDate__c, 
                ht_Type__c, 
                ht_NameTypeCode__c,
                ht_ExcludeCarrierAppointments__c
            FROM 
                ht_Producer__c
            WHERE
                 ht_NPN__c = :npn
            LIMIT 1
        ];
    }
    
    private static ht_ProducerAddress__c queryProducerAddress() {
        return [
            SELECT 
                ht_AddressType__c, 
                ht_AddressLineOne__c, 
                ht_AddressLineTwo__c, 
                ht_AddressLineThree__c,
                ht_City__c, 
                ht_State__c, 
                ht_PostalCode__c, 
                ht_CountryCode__c, 
                ht_AsOfDate__c
            FROM 
                ht_ProducerAddress__c
            WHERE 
                ht_Producer__r.ht_NPN__c = :AGENT_NPN 
            AND 
                ht_AddressType__c = 'Residential'
            LIMIT 1
        ];
    }
    
    private static ht_ProducerCommunication__c queryProducerPhone() {
        return [
            SELECT 
                ht_PhoneType__c, 
                ht_PhoneNumber__c
            FROM 
                ht_ProducerCommunication__c
            WHERE 
                ht_Producer__r.ht_NPN__c = :AGENT_NPN
            AND 
                ht_PhoneNumber__c = '+1-213-555-1234'
            LIMIT 1
        ];
    }
    
    private static ht_ProducerCommunication__c queryProducerEmail() {
        return [
            SELECT 
                ht_EmailType__c, 
                ht_EmailAddress__c
            FROM 
                ht_ProducerCommunication__c
            WHERE 
                ht_Producer__r.ht_NPN__c = :AGENT_NPN
            AND 
                ht_EmailAddress__c = 'mjohnson@example.com'
            LIMIT 1
        ];
    }
    
    private static ht_License__c queryLicense() {
        return [
            SELECT 
                ht_LicenseNumber__c, 
                ht_StateOrProvinceCode__c, 
                ht_StateOrProvinceName__c,
                ht_LicenseClassDescription__c, 
                ht_LicenseClassCode__c, 
                ht_StatusCode__c,
                ht_ResidentLicenseIndicator__c, 
                ht_TypeCode__c, 
                ht_IssueDate__c, 
                ht_EndDate__c, 
                ht_AsOfDate__c
            FROM
                 ht_License__c
            WHERE 
                ht_Producer__r.ht_NPN__c = :AGENT_NPN
            AND 
                ht_LicenseNumber__c = 'CA123456'
            LIMIT 1
        ];
    }
    
    private static ht_LineOfAuthority__c queryLicenseLOA() {
        return [
            SELECT 
                ht_LineOfAuthorityCode__c, 
                ht_LineOfAuthorityDescription__c,
                ht_StateOrProvinceCode__c, 
                ht_StateOrProvinceName__c, 
                ht_StatusCode__c,
                ht_StatusReasonCode__c, 
                ht_IssueDate__c, 
                ht_StartDate__c,
                ht_CEStatusDescription__c, 
                ht_CEUnitsRequiredMeasure__c, 
                ht_CERenewalDate__c
            FROM 
                ht_LineOfAuthority__c
            WHERE 
                ht_License__r.ht_LicenseNumber__c = 'CA123456'
            AND 
                ht_License__r.ht_Producer__r.ht_NPN__c = :AGENT_NPN
            LIMIT 1
        ];
    }
    
    private static ht_Carrier__c queryCarrier() {
        return [
            SELECT 
                ht_CoCode__c, 
                ht_FullName__c, 
                ht_FEIN__c
            FROM 
                ht_Carrier__c
            WHERE 
                ht_CoCode__c = '98765'
            LIMIT 1
        ];
    }
    
    private static ht_CarrierAppointment__c queryCarrierAppointment() {
        return [
            SELECT
                ht_StateOrProvinceCode__c,
                ht_CountyCode__c,
                ht_AppointerStateCOID__c,
                ht_StatusCode__c,
                ht_TerminationReason__c,
                ht_StatusReasonDate__c,
                ht_RenewalDate__c,
                ht_LineOfAuthorityCode__c,
                ht_LineOfAuthorityDescription__c
            FROM
                ht_CarrierAppointment__c
            WHERE
                ht_Producer__r.ht_NPN__c = :AGENT_NPN
            AND
                ht_Carrier__r.ht_CoCode__c = '98765'
            AND
                ht_StatusCode__c = 'Appointed'
            AND
                ht_CountyCode__c = '036'
            AND
                ht_LineOfAuthorityCode__c = '16'
            LIMIT 1
        ];
    }
}