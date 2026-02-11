/**
 *********************************************************
 * Apex Class Name    : ProcessPDBAlertReportService_Test
 * Created Date       : 03-19-2025
 * @description       : Test Class used for ProcessPDBAlertReportService. Asserts all records fields used in the integration and tests delete scenarios
 * @author            : Dev4Clouds
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Dev4Clouds          Initial Version
 * 1.1   12-25-2025   Dev4Clouds          Renamed from ImportNIPRDataToSalesforceService_Test
 *********************************************************
 **/
@isTest
private class ProcessPDBAlertReportService_Test {
    
    // TEST METHODS
    @isTest
    private static void importData_testInsertOfPDBAlertData() {
        // Prepare Mocks
        HttpSoapMultiMockFactory mockFactory = new HttpSoapMultiMockFactory()
            .addMock(
                'ind:receiveSpecificReportForSubscription', 
                200, 
                TestDataFactory.getPDBSpecificAlertResponse(),
                false
            );

        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
            ProcessPDBAlertReportService service = new ProcessPDBAlertReportService();
            service.importData('2025-03-31', 'TestTwo');
        Test.stopTest();

        // Assert
        assertRecordCounts();
        assertExternalIds();
        assertFieldValues();
    }

    @isTest
    private static void importData_testUpdateDeleteOfPDBAlertData() {
        // Prepare Mocks
        TestDataFactory.createNIPRPDBAlertTestData();

        HttpSoapMultiMockFactory mockFactory = new HttpSoapMultiMockFactory()
            .addMock(
                'ind:receiveSpecificReportForSubscription',
                200,
                TestDataFactory.getPDBSpecificAlertResponse(),
                false
            );


        // Assert that desired counts of records are currently in the database (from test setup)
        assertRecordCountsFromTestSetup();

        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Disable subscription validation for bulk data import
        EntityTriggerHandler.disableSubscriptionValidation = true;

        // Execute
        Test.startTest();
            ProcessPDBAlertReportService service = new ProcessPDBAlertReportService();
            service.importData('2025-03-31', 'TestTwo');
        Test.stopTest();

        // Assert that desired counts are in the database after running the service
        assertRecordCountsPerParentObject();
    }

    @isTest
    private static void importData_testMixedScenarioLicenseAndAppointmentNodes() {
        // Prepare Mock - first with initial data, then with mixed scenario
        HttpSoapMultiMockFactory mockFactory = new HttpSoapMultiMockFactory()
            .addMock(
                'ind:receiveSpecificReportForSubscription',
                200,
                TestDataFactory.getPDBSpecificAlertResponse(),
                false
            );

        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Disable subscription validation for bulk data import
        EntityTriggerHandler.disableSubscriptionValidation = true;

        // Execute - First import
        ProcessPDBAlertReportService service = new ProcessPDBAlertReportService();
        service.importData('2025-03-31', 'Test Initial Import');

        HttpSoapMultiMockFactory.mockResponses =  new Map<String, HttpSoapMultiMockFactory.MockResponseData>();

        mockFactory.addMock(
            'ind:receiveSpecificReportForSubscription',
            200,
            TestDataFactory.getPDBMixedDeleteScenarioResponse(),
            false
        );
        Test.setMock(HttpCalloutMock.class, mockFactory);

        Test.startTest();
            ProcessPDBAlertReportService secondService = new ProcessPDBAlertReportService();
            secondService.importData('2025-03-31', 'TestMixedScenario');
        Test.stopTest();

        // Assert - reusing updateDeletePDBAlertResponse, so expect same counts
        assertRecordCountsMixedDelete();
    }

    @isTest
    private static void importData_invalidPDBAlertsResponse() {
        // Prepare mock
        HttpSoapMultiMockFactory mockFactory = new HttpSoapMultiMockFactory()
            .addMock(
                'ind:receiveSpecificReportForSubscription', 
                500, 
                '',
                false
            );

        Test.setMock(HttpCalloutMock.class, mockFactory);

        // Execute
        Test.startTest();
            try {
                ProcessPDBAlertReportService service = new ProcessPDBAlertReportService();
                service.importData('2025-03-31', 'TestTwo');
            } catch (ProcessPDBAlertReportService.PDBAlertReportException ex) {
                // Assert
                assertRecordCountsInvalidResponse();
            }

        Test.stopTest();
    }


    // ASSERT METHODS
    private static void assertRecordCounts() {
        System.assertEquals(5, getCount('d4c_Entity__c'), 'Entity count mismatch');
        System.assertEquals(5, getCount('d4c_NIPR_Address__c'), 'Address count mismatch - Junction model deduplicates addresses via External ID');
        System.assertEquals(9, getCount('d4c_NIPR_Communication__c'), 'Communications count mismatch - Junction model deduplicates communications via External ID');
        System.assertEquals(1, getCount('d4c_Carrier__c'), 'Carrier count mismatch');
        System.assertEquals(12, getCount('d4c_License__c'), 'License count mismatch');
        System.assertEquals(36, getCount('d4c_LineOfAuthority__c'), 'LOA count mismatch - only License LOAs, no Carrier Appointment LOAs');
        System.assertEquals(6, getCount('d4c_CarrierAppointment__c'), 'Appointment count mismatch');
        System.assertEquals(5, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_LineOfAuthorityCode__c != NULL'), 'Should have 5 carrier appointments with LOA fields populated (1 appointment has no LOA data)');
    }

    // Assert counts for test setup data (before importData runs)
    private static void assertRecordCountsFromTestSetup() {
        System.assertEquals(5, getCount('d4c_Entity__c'), 'Entity count mismatch');
        System.assertEquals(5, getCount('d4c_NIPR_Address__c'), 'Address count from test setup - 5 unique addresses after deduplication (7 created, 2 duplicates removed)');
        System.assertEquals(9, getCount('d4c_NIPR_Communication__c'), 'Communications count from test setup - 9 unique communications after deduplication (13 created, 4 duplicates removed)');
        System.assertEquals(1, getCount('d4c_Carrier__c'), 'Carrier count mismatch');
        System.assertEquals(12, getCount('d4c_License__c'), 'License count mismatch');
        System.assertEquals(36, getCount('d4c_LineOfAuthority__c'), 'LOA count mismatch');
        System.assertEquals(6, getCount('d4c_CarrierAppointment__c'), 'Appointment count mismatch');
    }

    // ASSERT METHODS
    private static void assertRecordCountsMixedDelete() {
        System.assertEquals(5, getCount('d4c_Entity__c'), 'Entity count mismatch');
        System.assertEquals(5, getCount('d4c_NIPR_Address__c'), 'Address count mismatch - Junction model deduplicates addresses via External ID');
        System.assertEquals(9, getCount('d4c_NIPR_Communication__c'), 'Communications count mismatch - Junction model deduplicates communications via External ID');
        System.assertEquals(1, getCount('d4c_Carrier__c'), 'Carrier count mismatch');
        System.assertEquals(9, getCount('d4c_License__c'), 'License count mismatch');
        System.assertEquals(3, getCount('d4c_CarrierAppointment__c'), 'Appointment count mismatch');
    }

    private static void assertRecordCountsPerParentObject() {
        // Count via junction objects (addresses/communications are now standalone)
        // Junction counts must match old Master-Detail counts (see PDB_ALERT_TEST_DATA_COUNTS.md)
        System.assertEquals(9, getCommunicationCountForEntity('22138233'), 'Communication count for entity 22138233 - 5 exclusive + 4 shared = 9 total junctions');
        System.assertEquals(4, getCommunicationCountForEntity('22166967'), 'Communication count for entity 22166967 - 0 exclusive + 4 shared = 4 total junctions');
        System.assertEquals(4, getAddressCountForEntity('22138233'), 'Address count for entity 22138233 - 1 exclusive + 3 shared = 4 total junctions');
        System.assertEquals(3, getAddressCountForEntity('22166967'), 'Address count for entity 22166967 - 1 exclusive + 2 shared = 3 total junctions');
        System.assertEquals(4, getCount('d4c_LineOfAuthority__c', 'WHERE d4c_License__r.d4c_UniqueIdentifier__c = \'675353522CA3\''));
        System.assertEquals(2, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\''));
        System.assertEquals(1, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\''));
    }

    private static void assertRecordCountsInvalidResponse() {
        System.assertEquals(0, getCount('d4c_Entity__c'), 'Entity count mismatch');
        System.assertEquals(0, getCount('d4c_NIPR_Address__c'), 'Address count mismatch');
        System.assertEquals(0, getCount('d4c_NIPR_Communication__c'), 'Communications count mismatch');
        System.assertEquals(0, getCount('d4c_Carrier__c'), 'Carrier count mismatch');
        System.assertEquals(0, getCount('d4c_License__c'), 'License count mismatch');
        System.assertEquals(0, getCount('d4c_LineOfAuthority__c'), 'LOA count mismatch - only License LOAs');
        System.assertEquals(0, getCount('d4c_CarrierAppointment__c'), 'Appointment count mismatch');
    }

    private static void assertMixedScenarioRecordCountsPerParentObject() {
        // Entity 22138233 - CA: Both present, NE: No licenses, CT: No appointments
        System.assertEquals(2, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'CA\''),
            'Entity 22138233 should have 2 CA licenses (has license nodes)');
        System.assertEquals(2, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'CA\''),
            'Entity 22138233 should have 2 CA appointments (has appointment nodes)');
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'NE\''),
            'Entity 22138233 should still have 1 NE license (NO license nodes in payload = no deletion)');
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'CT\''),
            'Entity 22138233 should have 1 CT license (has license nodes)');

        // Entity 22138253 - GA: No appointments, CT: No licenses
        System.assertEquals(2, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138253\' AND d4c_StateOrProvinceCode__c = \'GA\''),
            'Entity 22138253 should have 2 GA licenses (has license nodes)');
        System.assertEquals(2, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138253\' AND d4c_StateOrProvinceCode__c = \'CT\''),
            'Entity 22138253 should have 2 CT appointments (has appointment nodes)');

        // Entity 22166967 - SC: No appointments, CA: Neither, TN: No licenses
        System.assertEquals(2, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\' AND d4c_StateOrProvinceCode__c = \'SC\''),
            'Entity 22166967 should have 2 SC licenses (has license nodes)');
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\' AND d4c_StateOrProvinceCode__c = \'CA\''),
            'Entity 22166967 should still have 1 CA license (NO nodes in payload = no deletion)');
        System.assertEquals(1, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\' AND d4c_StateOrProvinceCode__c = \'TN\''),
            'Entity 22166967 should have 1 TN appointment (has appointment nodes)');

        // Entity 22166100 - ID: No appointments, TN: Neither, SC: No licenses
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166100\' AND d4c_StateOrProvinceCode__c = \'ID\''),
            'Entity 22166100 should have 1 ID license (has license nodes)');
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166100\' AND d4c_StateOrProvinceCode__c = \'TN\''),
            'Entity 22166100 should still have 1 TN license (NO nodes in payload = no deletion)');
        System.assertEquals(1, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166100\' AND d4c_StateOrProvinceCode__c = \'SC\''),
            'Entity 22166100 should have 1 SC appointment (has appointment nodes)');

        // Entity 22234021 - GA: No appointments
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22234021\' AND d4c_StateOrProvinceCode__c = \'GA\''),
            'Entity 22234021 should have 1 GA license (has license nodes)');

        // Verify LOA counts remain stable
        System.assertEquals(43, getCount('d4c_LineOfAuthority__c'), 'Total LOA count should remain 43');

        // Verify total counts match expected
        System.assertEquals(12, getCount('d4c_License__c'), 'Total license count should be 12');
        System.assertEquals(6, getCount('d4c_CarrierAppointment__c'), 'Total appointment count should be 6');
    }

    private static void assertDeletionMarkerRecordCounts() {
        // Entity 22138233 - TX licenses and appointments should be DELETED
        System.assertEquals(0, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'TX\''),
            'Entity 22138233 TX licenses should be deleted via deletion marker');
        System.assertEquals(0, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'TX\''),
            'Entity 22138233 TX appointments should be deleted via deletion marker');

        // Entity 22138233 - CA data should remain untouched
        System.assertEquals(2, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'CA\''),
            'Entity 22138233 CA licenses should remain (normal data in payload)');
        System.assertEquals(2, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138233\' AND d4c_StateOrProvinceCode__c = \'CA\''),
            'Entity 22138233 CA appointments should remain (normal data in payload)');

        // Entity 22166967 - FL appointments should be DELETED
        System.assertEquals(0, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\' AND d4c_StateOrProvinceCode__c = \'FL\''),
            'Entity 22166967 FL appointments should be deleted via deletion marker');

        // Entity 22166967 - SC data should remain
        System.assertEquals(2, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166967\' AND d4c_StateOrProvinceCode__c = \'SC\''),
            'Entity 22166967 SC licenses should remain (normal data in payload)');

        // Verify total counts match expected (12 licenses initially + 2 TX added - 2 TX deleted = 12)
        System.assertEquals(12, getCount('d4c_License__c'), 'Total license count after deletion marker should be 12');
        // Appointments: 6 initially + 1 TX + 2 FL added - 1 TX - 2 FL deleted = 6
        System.assertEquals(6, getCount('d4c_CarrierAppointment__c'), 'Total appointment count after deletion marker should be 6');

        // Verify other entitys unaffected
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138253\' AND d4c_StateOrProvinceCode__c = \'CT\''),
            'Entity 22138253 CT license should remain');
        System.assertEquals(2, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22138253\' AND d4c_StateOrProvinceCode__c = \'CT\''),
            'Entity 22138253 CT appointments should remain');
        System.assertEquals(1, getCount('d4c_CarrierAppointment__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22166100\' AND d4c_StateOrProvinceCode__c = \'SC\''),
            'Entity 22166100 SC appointment should remain');
        System.assertEquals(1, getCount('d4c_License__c', 'WHERE d4c_Entity__r.d4c_NPN__c = \'22234021\' AND d4c_StateOrProvinceCode__c = \'GA\''),
            'Entity 22234021 GA license should remain');
    }

    private static void assertExternalIds() {
        assertEntityNPNs();
        assertProducerCommunicationIds();
        assertProducerAddressIds();
        assertCarrierCoCodes();
        assertLicenseNumbers();
        assertLineOfAuthorityIds();
        assertCarrierAppointmentIds();
    }
    
    private static void assertFieldValues() {
        assertEntityFields();
        assertProducerCommunicationFields();
        assertCarrierFields();
        assertLicenseFields();
        assertLineOfAuthorityFields();
        assertCarrierAppointmentFields();
        assertCarrierAppointmentLOAFields();
    }
    
    private static Integer getCount(String objectName) {
        String queryString = 'SELECT count() FROM ' + objectName;
        return Database.countQuery(queryString);
    }

    private static Integer getCount(String objectName, String whereClause) {
        String queryString = 'SELECT count() FROM ' + objectName + ' ' + whereClause;
        return Database.countQuery(queryString);
    }

    /**
     * Counts communication records for a given Entity NPN via junction records
     */
    private static Integer getCommunicationCountForEntity(String entityNpn) {
        return [SELECT COUNT()
                FROM d4c_Entity_Communication_Junction__c
                WHERE d4c_Entity__r.d4c_NPN__c = :entityNpn];
    }

    /**
     * Counts address records for a given Entity NPN via junction records
     */
    private static Integer getAddressCountForEntity(String entityNpn) {
        return [SELECT COUNT()
                FROM d4c_Entity_Address_Junction__c
                WHERE d4c_Entity__r.d4c_NPN__c = :entityNpn];
    }

    private static void assertEntityNPNs() {
        Set<String> entityNPNs = new Set<String>{
            '22138253', '22138233', '22234021', '22166967', '22166100'
        };

        List<d4c_Entity__c> entitys = getAllEntitys();

        for (d4c_Entity__c entity : entitys) {
            System.assert(entityNPNs.contains(entity.d4c_NPN__c), 
                'Unexpected entity NPN: ' + entity.d4c_NPN__c);
        }
    }
    
private static void assertProducerCommunicationIds() {
        // Junction model: Communications are standalone without NPN in External ID
        // Shared communications are deduplicated (e.g., +1-219-313-6370Wired used by both entities)
        Set<String> producerCommunicationIds = new Set<String>{
            '+1-219-313-6379Wired',
            '+1-419-906-3223Fax',
            '+1-419-906-3221Wired',
            'silvana1.zapoticky@cblmaycfqw.comBusiness',
            'silvana2.zapoticky@cblmaycfqw.comPersonal',
            '+1-219-313-6370Wired',  // Shared by both entities
            '+1-419-906-3229Fax',  // Shared by both entities
            'silvana3.zapoticky@cblmaycfqw.comBusiness',  // Shared by both entities
            'silvana4.zapoticky@cblmaycfqw.comPersonal'  // Shared by both entities
        };
    
        List<d4c_NIPR_Communication__c> communications = getAllProducerCommunications();

        for (d4c_NIPR_Communication__c comm : communications) {
            System.assert(producerCommunicationIds.contains(comm.d4c_UniqueIdentifier__c),
                'Unexpected entity communication ID: ' + comm.d4c_UniqueIdentifier__c);
        }
    }
    
    private static void assertProducerAddressIds() {
        // Junction model: Addresses are standalone without NPN in External ID
        // Shared addresses are deduplicated
        Set<String> producerAddressIds = new Set<String>{
            '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Mailing',
            '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Residential',
            '7SeBishopAve#9SanBernardinoCA92410U.S.A.Mailing',  // Shared by both entities
            '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Physical',  // Shared by both entities
            '7SeBishopAve#9SanBernardinoCA92410U.S.A.Principal'
        };

        List<d4c_NIPR_Address__c> addresses = getAllProducerAddresses();

        for (d4c_NIPR_Address__c address : addresses) {
            System.assert(producerAddressIds.contains(address.d4c_UniqueIdentifier__c),
                'Unexpected entity address ID: ' + address.d4c_UniqueIdentifier__c);
        }
    }
    
    private static void assertCarrierCoCodes() {
        Set<String> carrierCoCodes = new Set<String>{'19232'};

        List<d4c_Carrier__c> carriers = getAllCarriers();

        for (d4c_Carrier__c carrier : carriers) {
            System.assert(carrierCoCodes.contains(carrier.d4c_CoCode__c),
                'Unexpected carrier CoCode: ' + carrier.d4c_CoCode__c);
        }
    }
    
    private static void assertLicenseNumbers() {
        Set<String> licenseNumbers = new Set<String>{
            '12043222', '273647826', '832938456', '675353522', '671453522', '22138233',
            '57355422', '12950', '856932547', '854698745', '345127867', '458975823'
        };

        List<d4c_License__c> licenses = getAllLicenses();

        for (d4c_License__c license : licenses) {
            System.assert(licenseNumbers.contains(license.d4c_LicenseNumber__c),
                'Unexpected license number: ' + license.d4c_LicenseNumber__c);
        }
    }
    
    private static void assertLineOfAuthorityIds() {
        Set<String> loaIds = new Set<String>{
            // License LOAs
            '11CA2023-10-10675353522CA3', '12CA2023-10-10675353522CA3', '16CA2023-10-10675353522CA3', '935CA2023-10-10675353522CA3',
            '11CA2023-10-10671453522CA3', '12CA2023-10-10671453522CA3', '16CA2023-10-10671453522CA3', '935CA2023-10-10671453522CA3',
            '11NE2023-04-1122138233NE3', '12NE2023-04-1122138233NE3', '16NE2023-04-1122138233NE3', '935NE2023-04-1122138233NE3',
            '11CT2023-10-1057355422CT3', '12CT2023-10-1057355422CT3', '16CT2023-10-1057355422CT3', '935CT2023-10-1057355422CT3',
            '11SC2023-10-1112950SC3', '12SC2023-10-1112950SC3', '16SC2023-10-1112950SC3', '935SC2023-10-1112950SC3',
            '11CA2023-11-11856932547CA3', '12CA2023-11-11856932547CA3', '16CA2023-11-11856932547CA3', '935CA2023-11-11856932547CA3',
            '101SC2023-04-11854698745SC4', '11ID2023-11-11345127867ID3', '12ID2023-11-11345127867ID3', '16ID2023-11-11345127867ID3', '935ID2023-11-11345127867ID3',
            '13343TN2023-04-11458975823TN1405', '5139GA2023-02-2712043222GA1929', '5140GA2023-02-2712043222GA1929',
            '5133GA2025-03-29273647826GA1931', '5134GA2025-03-29273647826GA1931', '5139GA2025-03-29832938456GA1929', '5140GA2025-03-29832938456GA1929'
        };

        List<d4c_LineOfAuthority__c> loas = getAllLinesOfAuthority();

        for (d4c_LineOfAuthority__c loa : loas) {
            System.assert(loaIds.contains(loa.d4c_UniqueIdentifier__c),
                'Unexpected Line of Authority ID: ' + loa.d4c_UniqueIdentifier__c);
        }
    }
    
    private static void assertCarrierAppointmentIds() {
        Set<String> carrierAppointmentIds = new Set<String>{
            // Updated: This carrier appt had multiple LOAs in XML, now uses only first LOA (code 11)
            '2213823319232360719665CATerminated221382332213823319232360719665CATerminated2025-04-3011',
            '2213823319232360719665CATerminated221382332213823319232360719665CATerminated2025-04-3016',
            '2213825319232360719665CTTerminated221382532213825319232360719665CTTerminated2025-04-3016',
            '2213825319232360719665CTTerminated221382532213825319232360719665CTTerminated2025-04-3011',
            '2216610019232360719665SCAppointed221661002216610019232360719665SCAppointed2025-04-29101',
            '2216696719232360719665TNAppointed221669672216696719232360719665TNAppointed2025-04-29'
        };

        List<d4c_CarrierAppointment__c> appointments = getAllCarrierAppointments();

        for (d4c_CarrierAppointment__c app : appointments) {
            System.assert(carrierAppointmentIds.contains(app.d4c_UniqueIdentifier__c),
                'Unexpected Carrier Appointment ID: ' + app.d4c_UniqueIdentifier__c);
        }
    }
    
    // Methods for asserting field values
    
    private static void assertEntityFields() {
        d4c_Entity__c entity = getEntityByNPN('22138233');
        
        System.assertEquals('22138233', entity.d4c_NPN__c, 'Incorrect NPN');
        System.assertEquals(Date.newInstance(1950, 4, 22), entity.d4c_BirthDate__c, 'Incorrect Date of Birth');
        System.assertEquals('Primary', entity.d4c_NameTypeCode__c, 'Incorrect Name Type Code');
        System.assertEquals('MR', entity.d4c_NameSuffix__c, 'Incorrect Name Suffix');
        System.assertEquals('Rory W Destefanis', entity.d4c_FullName__c, 'Incorrect Full Name');
        System.assertEquals('Destefanis', entity.d4c_SurName__c, 'Incorrect Surname');
        System.assertEquals('W', entity.d4c_MiddleName__c, 'Incorrect Middle Name');
        System.assertEquals('Rory', entity.d4c_GivenName__c, 'Incorrect Given Name');
        System.assertEquals('Rory', entity.d4c_OtherGivenName__c, 'Incorrect Other Given Name');
        System.assertEquals('Agent', entity.d4c_Type__c);
    }
    
    private static void assertProducerCommunicationFields() {
        d4c_Entity__c entity = getEntityByNPN('22138233');

        // Assert Phone communication data
        // Junction model: External ID is phoneNumber + type (no NPN suffix)
        d4c_NIPR_Communication__c phoneComm = getProducerCommunicationByIdentifier('+1-219-313-6379Wired');

        System.assertEquals('+1-219-313-6379Wired', phoneComm.d4c_UniqueIdentifier__c, 'Incorrect Unique Identifier for Phone Communication');
        System.assertEquals('Wired', phoneComm.d4c_PhoneType__c, 'Incorrect Phone Type');
        System.assertEquals('+1-219-313-6379', phoneComm.d4c_PhoneNumber__c, 'Incorrect Phone Number');
        // Note: Communication is now standalone - entity relationship via junction

        // Assert Email Communication data
        // Junction model: External ID is email + type (no NPN suffix)
        d4c_NIPR_Communication__c emailComm = getProducerCommunicationByIdentifier('silvana1.zapoticky@cblmaycfqw.comBusiness');

        System.assertEquals('silvana1.zapoticky@cblmaycfqw.comBusiness', emailComm.d4c_UniqueIdentifier__c, 'Incorrect Unique Identifier for Email Communication');
        System.assertEquals('Business', emailComm.d4c_EmailType__c, 'Incorrect Email Type');
        System.assertEquals('silvana1.zapoticky@cblmaycfqw.com', emailComm.d4c_EmailAddress__c, 'Incorrect Email Address');
        // Note: Communication is now standalone - entity relationship via junction
    }
    
    private static void assertCarrierFields() {
        d4c_Carrier__c carrier = getCarrierByCoCode('19232');
        
        System.assertEquals('19232', carrier.d4c_CoCode__c, 'Incorrect Carrier CoCode');
        System.assertEquals('Allstate Ins Co', carrier.d4c_FullName__c, 'Incorrect Carrier Name');
        System.assertEquals('360719665', carrier.d4c_FEIN__c, 'Incorrect FEIN');
        System.assertEquals('19232360719665', carrier.d4c_UniqueIdentifier__c, 'Incorrect Carrier Unique Identifier');
    }
    
    private static void assertLicenseFields() {
        d4c_License__c license = getLicenseByNumber('675353522');
        d4c_Entity__c entity = getEntityByNPN('22138233');
        
        // Basic license fields
        System.assertEquals(true, license.d4c_ResidentLicenseIndicator__c, 'Incorrect Resident License Indicator');
        System.assertEquals(true, license.d4c_QualifyingInsuranceLicenseIndicator__c, 'Incorrect Qualifying Insurance License Indicator');
        System.assertEquals('Entity', license.d4c_TypeCode__c, 'Incorrect License TypeCode');
        System.assertEquals('675353522', license.d4c_LicenseNumber__c, 'Incorrect License Number');
        System.assertEquals(Date.valueOf('2024-03-29'), license.d4c_StartDate__c, 'Incorrect License Start Date');
        System.assertEquals(Date.valueOf('2025-03-29'), license.d4c_EndDate__c, 'Incorrect License End Date');
        System.assertEquals('Inactive', license.d4c_StatusCode__c, 'Incorrect License Status Code');
        System.assertEquals('Test description', license.d4c_StatusDescription__c, 'Incorrect License Status Description');
        System.assertEquals(Date.valueOf('2023-10-10'), license.d4c_IssueDate__c, 'Incorrect License Issue Date');
        System.assertEquals('3', license.d4c_LicenseClassCode__c, 'Incorrect License Class Code');
        System.assertEquals('Insurance Entity', license.d4c_LicenseClassDescription__c, 'Incorrect License Class Description');
        System.assertEquals('CA', license.d4c_StateOrProvinceCode__c, 'Incorrect License StateOrProvinceCode');
        System.assertEquals('CA', license.d4c_StateOrProvinceName__c, 'Incorrect License StateOrProvinceName');
        System.assertEquals(Date.valueOf('2025-03-28'), license.d4c_AsOfDate__c, 'Incorrect License As Of Date');
        System.assertEquals('675353522CA3', license.d4c_UniqueIdentifier__c, 'Incorrect License Unique Identifier');
        
        // Continuing Education fields
        System.assertEquals('CA', license.d4c_CEStateOrProvince_Code__c, 'Incorrect CE StateOrProvinceCode');
        System.assertEquals('IN COMPLIANCE', license.d4c_CEStatusDescription__c, 'Incorrect CE Status Description');
        System.assertEquals(Date.valueOf('2025-03-29'), license.d4c_CEStartDate__c, 'Incorrect CE Start Date');
        System.assertEquals(Date.valueOf('2026-03-29'), license.d4c_CEEndDate__c, 'Incorrect CE End Date');
        System.assertEquals(1, license.d4c_PeriodDuration__c, 'Incorrect CE Period Duration');
        System.assertEquals('Test measure', license.d4c_CEUnitsRequiredMeasure__c, 'Incorrect CE Units Required Measure');
        
        // Verify the License is linked to the correct Entity
        System.assertEquals(entity.Id, license.d4c_Entity__c, 'License linked to incorrect Entity');
    }
    
    private static void assertLineOfAuthorityFields() {
        String loaUniqueId = '11CA2023-10-10675353522CA3';
        d4c_LineOfAuthority__c loa = getLineOfAuthorityByIdentifier(loaUniqueId);
        d4c_License__c license = getLicenseByNumber('675353522');
        
        // Assertions for LOA fields
        System.assertEquals(Date.valueOf('2023-10-10'), loa.d4c_IssueDate__c, 'Incorrect LOA Issue Date');
        System.assertEquals(Date.valueOf('2025-10-10'), loa.d4c_RenewalDate__c, 'Incorrect LOA Renewal Date');
        System.assertEquals('CA', loa.d4c_StateOrProvinceCode__c, 'Incorrect LOA StateOrProvinceCode');
        System.assertEquals('CA', loa.d4c_StateOrProvinceName__c, 'Incorrect LOA StateOrProvinceName');
        System.assertEquals('11', loa.d4c_LineOfAuthorityCode__c, 'Incorrect LOA Code');
        System.assertEquals('Casualty', loa.d4c_LineOfAuthorityDescription__c, 'Incorrect LOA Description');
        System.assertEquals('Inactive', loa.d4c_StatusCode__c, 'Incorrect LOA Status Code');
        System.assertEquals('Inactive', loa.d4c_StatusDescription__c, 'Incorrect LOA Status Description');
        System.assertEquals('Cancelled', loa.d4c_StatusReasonCode__c, 'Incorrect LOA Status Reason Code');
        System.assertEquals('Inactive test', loa.d4c_StatusReasonDescription__c, 'Incorrect LOA Status Reason Description');
        System.assertEquals(Date.valueOf('2025-02-25'), loa.d4c_StartDate__c, 'Incorrect LOA Status Period Start Date');
        
        // Assert that LOA is correctly related to the License
        System.assertEquals(license.Id, loa.d4c_License__c, 'LOA linked to incorrect License');
    }
    
    private static void assertCarrierAppointmentFields() {
        // Updated: This carrier appt had multiple LOAs in XML, now uses only first LOA (code 11)
        String carrierAppUniqueIdentifier = '2213823319232360719665CATerminated221382332213823319232360719665CATerminated2025-04-3011';

        d4c_CarrierAppointment__c carrierApp = getCarrierAppointmentByIdentifierPattern(carrierAppUniqueIdentifier);
        d4c_Entity__c entity = getEntityByNPN('22138233');
        d4c_Carrier__c carrier = getCarrierByCoCode('19232');
        
        // Assertions for Carrier Appointment fields
        System.assertEquals('CA', carrierApp.d4c_StateOrProvinceCode__c, 'Incorrect State or Province Code');
        System.assertEquals('Terminated', carrierApp.d4c_StatusCode__c, 'Incorrect Status Code');
        System.assertEquals('Test descr', carrierApp.d4c_StatusDescription__c, 'Incorrect Status Description');
        System.assertEquals('Terminated reason', carrierApp.d4c_StatusReasonCode__c, 'Incorrect Status Reason Code');
        System.assertEquals('Test Reason Description', carrierApp.d4c_StatusReasonDescription__c, 'Incorrect Status Reason Description');
        System.assertEquals(Date.valueOf('2025-03-30'), carrierApp.d4c_AppointmentEffectiveDate__c, 'Incorrect Appointment Effective Date');
        System.assertEquals(Date.valueOf('2025-03-29'), carrierApp.d4c_TerminationEffectiveDate__c, 'Incorrect Termination Effective Date');
        System.assertEquals(Date.valueOf('2025-03-28'), carrierApp.d4c_AsOfDate__c, 'Incorrect As Of Date');
        
        // Assertions to verify related Entity and Carrier Ids
        System.assertEquals(entity.Id, carrierApp.d4c_Entity__c, 'Carrier Appointment linked to incorrect Entity');
        System.assertEquals(carrier.Id, carrierApp.d4c_Carrier__c, 'Carrier Appointment linked to incorrect Carrier');
    }
    
    private static void assertCarrierAppointmentLOAFields() {
        // Query carrier appointment that should have LOA fields populated
        d4c_CarrierAppointment__c carrierApp = getCarrierAppointmentByIdentifierPattern('2213825319232360719665CTTerminated221382532213825319232360719665CTTerminated2025-04-3011');

        // Assertions for LOA fields directly on Carrier Appointment
        System.assertEquals(Date.valueOf('2025-04-30'), carrierApp.d4c_RenewalDate__c, 'Incorrect LOA Renewal Date');
        System.assertEquals('11', carrierApp.d4c_LineOfAuthorityCode__c, 'Incorrect LOA Code');
        System.assertEquals('Casualty', carrierApp.d4c_LineOfAuthorityDescription__c, 'Incorrect LOA Description');
    }
    
    // QUERY METHODS
    private static List<d4c_Entity__c> getAllEntitys() {
        return [
            SELECT 
                Id,
                d4c_NPN__c 
            FROM d4c_Entity__c
        ];
    }
    
    private static d4c_Entity__c getEntityByNPN(String npn) {
        return [
            SELECT 
                Id, 
                d4c_NPN__c, 
                d4c_BirthDate__c, 
                d4c_NameTypeCode__c,
                d4c_NameSuffix__c,
                d4c_FullName__c,
                d4c_SurName__c,
                d4c_MiddleName__c,
                d4c_GivenName__c,
                d4c_OtherGivenName__c,
                d4c_Type__c
            FROM 
                d4c_Entity__c
            WHERE 
                d4c_NPN__c = :npn
            LIMIT 1
        ];
    }
    
    private static List<d4c_NIPR_Communication__c> getAllProducerCommunications() {
        return [
            SELECT 
                Id, 
                d4c_UniqueIdentifier__c 
            FROM d4c_NIPR_Communication__c
        ];
    }
    
    private static d4c_NIPR_Communication__c getProducerCommunicationByIdentifier(String identifier) {
        return [
            SELECT
                Id,
                d4c_UniqueIdentifier__c,
                d4c_PhoneType__c,
                d4c_PhoneNumber__c,
                d4c_EmailType__c,
                d4c_EmailAddress__c
            FROM d4c_NIPR_Communication__c
            WHERE d4c_UniqueIdentifier__c = :identifier
            LIMIT 1
        ];
    }
    
    private static List<d4c_NIPR_Address__c> getAllProducerAddresses() {
        return [
            SELECT 
                Id, 
                d4c_UniqueIdentifier__c 
            FROM d4c_NIPR_Address__c
        ];
    }
    
    private static List<d4c_Carrier__c> getAllCarriers() {
        return [
            SELECT 
                Id, 
                d4c_CoCode__c, 
                d4c_UniqueIdentifier__c
            FROM d4c_Carrier__c
        ];
    }
    
    private static d4c_Carrier__c getCarrierByCoCode(String coCode) {
        return [
            SELECT 
                Id, 
                d4c_CoCode__c, 
                d4c_FullName__c, 
                d4c_FEIN__c, 
                d4c_UniqueIdentifier__c
            FROM d4c_Carrier__c
            WHERE d4c_CoCode__c = :coCode
            LIMIT 1
        ];
    }
    
    private static List<d4c_License__c> getAllLicenses() {
        return [
            SELECT 
                Id, 
                d4c_LicenseNumber__c, 
                d4c_UniqueIdentifier__c 
            FROM d4c_License__c
        ];
    }
    
    private static d4c_License__c getLicenseByNumber(String licenseNumber) {
        return [
            SELECT
                Id,
                d4c_ResidentLicenseIndicator__c,
                d4c_QualifyingInsuranceLicenseIndicator__c,
                d4c_TypeCode__c,
                d4c_LicenseNumber__c,
                d4c_StartDate__c,
                d4c_EndDate__c,
                d4c_StatusCode__c,
                d4c_StatusDescription__c,
                d4c_IssueDate__c,
                d4c_LicenseClassCode__c,
                d4c_LicenseClassDescription__c,
                d4c_StateOrProvinceCode__c,
                d4c_StateOrProvinceName__c,
                d4c_AsOfDate__c,
                d4c_CEStateOrProvince_Code__c,
                d4c_CEStatusDescription__c,
                d4c_CEStartDate__c,
                d4c_CEEndDate__c,
                d4c_PeriodDuration__c,
                d4c_CEUnitsRequiredMeasure__c,
                d4c_Entity__c,
                d4c_UniqueIdentifier__c
            FROM d4c_License__c
            WHERE d4c_LicenseNumber__c = :licenseNumber
            LIMIT 1
        ];
    }
    
    private static List<d4c_LineOfAuthority__c> getAllLinesOfAuthority() {
        return [
            SELECT 
                Id, 
                d4c_UniqueIdentifier__c 
            FROM d4c_LineOfAuthority__c
        ];
    }
    
    private static d4c_LineOfAuthority__c getLineOfAuthorityByIdentifier(String identifier) {
        return [
            SELECT 
                Id,
                d4c_IssueDate__c,
                d4c_RenewalDate__c,
                d4c_StateOrProvinceCode__c,
                d4c_StateOrProvinceName__c,
                d4c_LineOfAuthorityCode__c,
                d4c_LineOfAuthorityDescription__c,
                d4c_StatusCode__c,
                d4c_StatusDescription__c,
                d4c_StatusReasonCode__c,
                d4c_StatusReasonDescription__c,
                d4c_StartDate__c,
                d4c_License__c
            FROM d4c_LineOfAuthority__c
            WHERE d4c_UniqueIdentifier__c = :identifier
            LIMIT 1
        ];
    }
    
    private static List<d4c_CarrierAppointment__c> getAllCarrierAppointments() {
        return [
            SELECT 
                Id, 
                d4c_UniqueIdentifier__c 
            FROM d4c_CarrierAppointment__c
        ];
    }
    
    private static d4c_CarrierAppointment__c getCarrierAppointmentByIdentifierPattern(String identifierPattern) {
        return [
            SELECT
                Id,
                d4c_StateOrProvinceCode__c,
                d4c_StatusCode__c,
                d4c_StatusDescription__c,
                d4c_StatusReasonCode__c,
                d4c_StatusReasonDescription__c,
                d4c_AppointmentEffectiveDate__c,
                d4c_TerminationEffectiveDate__c,
                d4c_AsOfDate__c,
                d4c_Entity__c,
                d4c_Carrier__c,
                d4c_LineOfAuthorityCode__c,
                d4c_LineOfAuthorityDescription__c,
                d4c_RenewalDate__c
            FROM d4c_CarrierAppointment__c
            WHERE d4c_UniqueIdentifier__c LIKE :identifierPattern + '%'
            LIMIT 1
        ];
    }
}