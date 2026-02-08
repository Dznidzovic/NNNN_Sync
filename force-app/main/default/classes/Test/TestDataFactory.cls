/**
 *********************************************************
 * Apex Class Name    : TestDataFactory
 * Created Date       : 03-19-2025
 * @description       : Class used to create record data that we will use to test apex classes
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-19-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
@isTest
@TestVisible
private class TestDataFactory {
	@TestVisible
    private static Account createAccount(Boolean doInsert) {
		return createAccount('testAccount', doInsert);
	}
	
	@TestVisible
    private static Account createAccount(String name, Boolean doInsert) {
		Account acc = new Account(name = name);
		if(doInsert) {
			insert acc;
		}
		return acc;
	}
	
	@TestVisible
    private static Contact createContact(Boolean doInsert) {
		Account acc = createAccount(true);
		return createContact(acc.id, true);
	}
	
	@TestVisible
    private static Contact createContact(Id accountId, Boolean doInsert) {
		Contact c = new Contact(firstName = 'FirstName', lastName = 'LastName', accountId = accountId);
		if(doInsert) {
			insert c;
		}
		return c;
	}

    @TestVisible
    private static Contact createContact(String lastName, String npn) {
        Account acc = createAccount(true);
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = lastName,
            AccountId = acc.Id,
            ht_NPN__c = npn
        );
        return c;
    }

	@TestVisible
    private static List<Opportunity> createOpportunity(Id accountId, Integer numOpps) {
		List<Opportunity> opps = new List<Opportunity>();
		for(Integer i = 1; i <= numOpps; i++) {
			Opportunity opp = new Opportunity();
			opp.name = 'Account ' + i;
			opp.accountId = accountid;
			opp.amount = 1000;
			opp.closeDate = Date.today().addDays(5);
			opp.stageName = 'Prospecting';
			opps.add(opp);
		}
		return opps;
	}

    @TestVisible
    private static List<ht_Producer__c> createProducers(Set<String> npns){
        List<ht_Producer__c> producers = new List<ht_Producer__c>();
        for (String npn : npns) {
            producers.add(new ht_Producer__c(ht_NPN__c = npn));
        }
        return producers;
    }

    @TestVisible
    private static ht_Producer__c createProducer(String npn) {
        ht_Producer__c producer = new ht_Producer__c(ht_NPN__c = npn);
        return producer;
    }

	@TestVisible
	private static Lead createLead() {
		Lead l = new Lead(
			LastName = 'Test',
			Status = 'New',
			Company = 'Test'
		);
		return l;
	}

    @TestVisible
    private static ht_ProducerAddress__c createProducerAddress(Id producerId, String addressType, String addressLineText, String uniqueId) {
		return new ht_ProducerAddress__c(
			ht_UniqueIdentifier__c = uniqueId,
			ht_Producer__c = producerId,
			ht_AddressType__c = addressType,
			ht_AddressLineOne__c= addressLineText
		);
	}

    @TestVisible
    private static ht_ProducerCommunication__c createPhoneCommunication(Id producerId, String phoneNumber, String phoneType, String uniqueId ) {
		return new ht_ProducerCommunication__c(
			ht_UniqueIdentifier__c = uniqueId,
			ht_Producer__c = producerId,
			ht_PhoneNumber__c = phoneNumber,
			ht_PhoneType__c = phoneType
		);
	}

    @TestVisible
    private static ht_ProducerCommunication__c createEmailCommunication(Id producerId, String emailAddress, String emailType, String uniqueId) {
		return new ht_ProducerCommunication__c(
			ht_UniqueIdentifier__c = uniqueId,
			ht_Producer__c = producerId,
			ht_EmailAddress__c = emailAddress,
			ht_EmailType__c = emailType
		);
	}

    @TestVisible
    private static ht_License__c createLicense(String licenseNumber, Id producerId) {
        return new ht_License__c(
            ht_LicenseNumber__c = licenseNumber,
            ht_Producer__c = producerId
        );
    }

    @TestVisible
    private static ht_CarrierAppointment__c createCarrierAppointment(String uid, Id producerId, Id carrierId, String state, String status) {
        return new ht_CarrierAppointment__c(
            ht_UniqueIdentifier__c = uid,
            ht_Producer__c = producerId,
            ht_Carrier__c = carrierId,
            ht_StateOrProvinceCode__c = state,
            ht_StatusCode__c = status
        );
    }

    @TestVisible
    private static ht_LineOfAuthority__c createLineOfAuthority(String uid, Id licenseId, Id appointmentId, String state, String code) {
        return new ht_LineOfAuthority__c(
            ht_UniqueIdentifier__c = uid,
            ht_License__c = licenseId,
            //ht_CarrierAppointment__c = appointmentId,
            ht_StateOrProvinceCode__c = state,
            ht_LineOfAuthorityCode__c = code
        );
    }

    @TestVisible
    private static void addLicenseLoas(List<ht_LineOfAuthority__c> loas, Map<String, Id> licenseIds
	) {
		// Map of License Number => List of Explicit Unique IDs
		Map<String, List<String>> licenseUniqueIds = new Map<String, List<String>>{
			'675353522' => new List<String>{'11CA2023-10-10675353522', '12CA2023-10-10675353522', '16CA2023-10-10675353522', '935CA2023-10-10675353522'},
			'671453522' => new List<String>{'11CA2023-10-10671453522', '12CA2023-10-10671453522', '16CA2023-10-10671453522', '935CA2023-10-10671453522'},
			'22138233'  => new List<String>{'11NE2023-04-1122138233', '12NE2023-04-1122138233', '16NE2023-04-1122138233', '935NE2023-04-1122138233'},
			'57355422'  => new List<String>{'11CT2023-10-1057355422', '12CT2023-10-1057355422', '16CT2023-10-1057355422', '935CT2023-10-1057355422'},
			'12950' => new List<String>{'11SC2023-10-1112950', '12SC2023-10-1112950', '16SC2023-10-1112950', '935SC2023-10-1112950'},
			'856932547' => new List<String>{'11CA2023-11-11856932547', '12CA2023-11-11856932547', '16CA2023-11-11856932547', '935CA2023-11-11856932547'},
			'854698745' => new List<String>{'101SC2023-04-11854698745'},
			'345127867' => new List<String>{'11ID2023-11-11345127867', '12ID2023-11-11345127867', '16ID2023-11-11345127867', '935ID2023-11-11345127867'},
			'458975823' => new List<String>{'13343TN2023-04-11458975823'},
			'12043222'  => new List<String>{'5139GA2023-02-2712043222', '5140GA2023-02-2712043222'},
			'273647826' => new List<String>{'5133GA2025-03-29273647826', '5134GA2025-03-29273647826'},
			'832938456' => new List<String>{'5139GA2025-03-29832938456', '5140GA2025-03-29832938456'}
		};

		for (String licenseNumber : licenseUniqueIds.keySet()) {
			Id licenseId = licenseIds.get(licenseNumber);
			if (licenseId == null) continue;

			for (String uniqueId : licenseUniqueIds.get(licenseNumber)) {
				// Parse info from the uniqueId (state code, LOA code)
				String loaCode = extractLOACode(uniqueId);
				String state = extractStateCode(uniqueId);

				loas.add(createLineOfAuthority(uniqueId, licenseId, null, state, loaCode));
			}
		}
	}

	@TestVisible
	private static Map<String, List<SObject>> createNIPRPDBAlertTestData() {
		Map<String, List<SObject>> createdRecords = new Map<String, List<SObject>>();

		// Create producers
		Set<String> npns = new Set<String>{'22138233', '22138253', '22234021', '22166967', '22166100'};
		List<ht_Producer__c> producers = createProducers(npns);

		insert producers;

		createdRecords.put('ht_Producer__c', producers);

		Map<String, Id> producerIds = new Map<String, Id>();
		for (ht_Producer__c producer : producers) {
			producerIds.put(producer.ht_NPN__c, producer.Id);
		}

		// Create carriers
		List<ht_Carrier__c> carriers = new List<ht_Carrier__c>{
			new ht_Carrier__c(ht_CoCode__c = '19232', ht_FullName__c = 'Allstate Ins Co', Name = 'Allstate Ins Co', ht_FEIN__c = '360719665', ht_UniqueIdentifier__c = '19232360719665')
		};

		insert carriers;
		createdRecords.put('ht_Carrier__c', carriers);

		Id carrierId = carriers[0].Id;

		// Create Addresses
		List<ht_ProducerAddress__c> addresses = new List<ht_ProducerAddress__c>{
			createProducerAddress(producerIds.get('22138233'), 'Mailing', '245', '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Mailing22138233'),
			createProducerAddress(producerIds.get('22138233'), 'Residential', '245', '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Residential22138233'),
			createProducerAddress(producerIds.get('22138233'), 'Physical', '245', '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Physical22138233'),
			createProducerAddress(producerIds.get('22138233'), 'Mailing', '7', '7SeBishopAve#9SanBernardinoCA92410U.S.A.Mailing22138233'),
			createProducerAddress(producerIds.get('22166967'), 'Mailing', '7', '7SeBishopAve#9SanBernardinoCA92410U.S.A.Mailing22166967'),
			createProducerAddress(producerIds.get('22166967'), 'Physical', '245', '245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Physical22166967'),
			createProducerAddress(producerIds.get('22166967'), 'Principal', '7', '7SeBishopAve#9SanBernardinoCA92410U.S.A.Principal22166967')
		};

		insert addresses;

		createdRecords.put('ht_ProducerAddress__c', addresses);

		// Create Producer Communications
		List<ht_ProducerCommunication__c> communications = new List<ht_ProducerCommunication__c>{
			// Producer: 22138233
			createPhoneCommunication(producerIds.get('22138233'), '+1-219-313-6379', 'Wired', '+1-219-313-6379Wired22138233'),
			createPhoneCommunication(producerIds.get('22138233'), '+1-419-906-3223', 'Fax', '+1-419-906-3223Fax22138233'),
			createPhoneCommunication(producerIds.get('22138233'), '+1-419-906-3221', 'Wired', '+1-419-906-3221Wired22138233'),
			createEmailCommunication(producerIds.get('22138233'), 'silvana1.zapoticky@cblmaycfqw.com', 'Business', 'silvana1.zapoticky@cblmaycfqw.comBusiness22138233'),
			createEmailCommunication(producerIds.get('22138233'), 'silvana2.zapoticky@cblmaycfqw.com', 'Personal', 'silvana2.zapoticky@cblmaycfqw.comPersonal22138233'),
			createPhoneCommunication(producerIds.get('22138233'), '+1-219-313-6370', 'Wired', '+1-219-313-6370Wired22138233'),
			createPhoneCommunication(producerIds.get('22138233'), '+1-419-906-3229', 'Fax', '+1-419-906-3229Fax22138233'),
			createEmailCommunication(producerIds.get('22138233'), 'silvana3.zapoticky@cblmaycfqw.com', 'Business', 'silvana3.zapoticky@cblmaycfqw.comBusiness22138233'),
			createEmailCommunication(producerIds.get('22138233'), 'silvana4.zapoticky@cblmaycfqw.com', 'Personal', 'silvana4.zapoticky@cblmaycfqw.comPersonal22138233'),
		
			// Producer: 22166967
			createPhoneCommunication(producerIds.get('22166967'), '+1-219-313-6370', 'Wired', '+1-219-313-6370Wired22166967'),
			createPhoneCommunication(producerIds.get('22166967'), '+1-419-906-3229', 'Fax', '+1-419-906-3229Fax22166967'),
			createEmailCommunication(producerIds.get('22166967'), 'silvana3.zapoticky@cblmaycfqw.com', 'Business', 'silvana3.zapoticky@cblmaycfqw.comBusiness22166967'),
			createEmailCommunication(producerIds.get('22166967'), 'silvana4.zapoticky@cblmaycfqw.com', 'Personal', 'silvana4.zapoticky@cblmaycfqw.comPersonal22166967')
		};

		insert communications;

		createdRecords.put('ht_ProducerCommunication__c', communications);

		// Create Licenses with updated unique identifiers
		Map<String, Map<String, String>> licenseData = new Map<String, Map<String, String>>{
			'675353522' => new Map<String, String>{'npn' => '22138233', 'state' => 'CA', 'class' => '3', 'uid' => '675353522CA3'},
			'671453522' => new Map<String, String>{'npn' => '22138233', 'state' => 'CA', 'class' => '3', 'uid' => '671453522CA3'},
			'22138233' => new Map<String, String>{'npn' => '22138233', 'state' => 'NE', 'class' => '3', 'uid' => '22138233NE3'},
			'57355422' => new Map<String, String>{'npn' => '22138233', 'state' => 'CT', 'class' => '3', 'uid' => '57355422CT3'},
			'12950' => new Map<String, String>{'npn' => '22166967', 'state' => 'SC', 'class' => '3', 'uid' => '12950SC3'},
			'856932547' => new Map<String, String>{'npn' => '22166967', 'state' => 'CA', 'class' => '3', 'uid' => '856932547CA3'},
			'854698745' => new Map<String, String>{'npn' => '22166967', 'state' => 'SC', 'class' => '4', 'uid' => '854698745SC4'},
			'345127867' => new Map<String, String>{'npn' => '22166100', 'state' => 'ID', 'class' => '3', 'uid' => '345127867ID3'},
			'458975823' => new Map<String, String>{'npn' => '22166100', 'state' => 'TN', 'class' => '1405', 'uid' => '458975823TN1405'},
			'12043222' => new Map<String, String>{'npn' => '22138253', 'state' => 'GA', 'class' => '1929', 'uid' => '12043222GA1929'},
			'273647826' => new Map<String, String>{'npn' => '22138253', 'state' => 'GA', 'class' => '1931', 'uid' => '273647826GA1931'},
			'832938456' => new Map<String, String>{'npn' => '22234021', 'state' => 'GA', 'class' => '1929', 'uid' => '832938456GA1929'}
		};
		
		List<ht_License__c> licenses = new List<ht_License__c>();
		
		for (String licenseNum : licenseData.keySet()) {
			Map<String, String> data = licenseData.get(licenseNum);
			ht_License__c license = new ht_License__c(
				ht_LicenseNumber__c = licenseNum,
				ht_Producer__c = producerIds.get(data.get('npn')),
				ht_StateOrProvinceCode__c = data.get('state'),
				ht_LicenseClassCode__c = data.get('class'),
				ht_UniqueIdentifier__c = data.get('uid')
			);
			licenses.add(license);
		}

		insert licenses;

		createdRecords.put('ht_License__c', licenses);

		Map<String, Id> licenseIds = new Map<String, Id>();
		for (ht_License__c lic : licenses) {
			licenseIds.put(lic.ht_UniqueIdentifier__c, lic.Id);
		}

		// Create Carrier Appointments with LOA fields directly on them
		Map<String, Map<String, String>> appointmentDefs = new Map<String, Map<String, String>>{
			'2213823319232360719665CATerminated22138233192323607196652025-04-301122138233192323607196652025-04-3012' =>
				new Map<String, String>{'npn' => '22138233', 'state' => 'CA', 'status' => 'Terminated', 'loaCode' => '11', 'loaDesc' => 'Casualty'},
			'2213823319232360719665CATerminated22138233192323607196652025-04-3016' =>
				new Map<String, String>{'npn' => '22138233', 'state' => 'CA', 'status' => 'Terminated', 'loaCode' => '16', 'loaDesc' => 'Life'},
			'2213825319232360719665CTTerminated22138253192323607196652025-04-3016' =>
				new Map<String, String>{'npn' => '22138253', 'state' => 'CT', 'status' => 'Terminated', 'loaCode' => '16', 'loaDesc' => 'Life'},
			'2213825319232360719665CTTerminated22138253192323607196652025-04-3011' =>
				new Map<String, String>{'npn' => '22138253', 'state' => 'CT', 'status' => 'Terminated', 'loaCode' => '11', 'loaDesc' => 'Casualty'},
			'2216610019232360719665SCAppointed22166100192323607196652025-04-29101' =>
				new Map<String, String>{'npn' => '22166100', 'state' => 'SC', 'status' => 'Appointed', 'loaCode' => '101', 'loaDesc' => 'Surplus Lines'},
			'2216696719232360719665TNAppointed22166967192323607196652025-04-29' =>
				new Map<String, String>{'npn' => '22166967', 'state' => 'TN', 'status' => 'Appointed', 'loaCode' => null, 'loaDesc' => null}
		};

		List<ht_CarrierAppointment__c> appointments = new List<ht_CarrierAppointment__c>();

		for (String key : appointmentDefs.keySet()) {
			Map<String, String> def = appointmentDefs.get(key);
			ht_CarrierAppointment__c app = new ht_CarrierAppointment__c(
				ht_UniqueIdentifier__c = key,
				ht_Producer__c = producerIds.get(def.get('npn')),
				ht_Carrier__c = carrierId,
				ht_StateOrProvinceCode__c = def.get('state'),
				ht_StatusCode__c = def.get('status'),
				ht_LineOfAuthorityCode__c = def.get('loaCode'),
				ht_LineOfAuthorityDescription__c = def.get('loaDesc'),
				ht_RenewalDate__c = Date.valueOf('2025-04-30')
			);
			appointments.add(app);
		}

		insert appointments;

		createdRecords.put('ht_CarrierAppointment__c', appointments);

		Map<String, Id> appointmentIds = new Map<String, Id>();
		for (ht_CarrierAppointment__c app : appointments) {
			appointmentIds.put(app.ht_UniqueIdentifier__c, app.Id);
		}

		// Create License LOA with updated unique identifiers
		List<ht_LineOfAuthority__c> loas = new List<ht_LineOfAuthority__c>();

		// Updated license LOA unique identifiers
		Map<String, List<Map<String, String>>> licenseLoaMappings = new Map<String, List<Map<String, String>>>{
			'675353522CA3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11CA2023-10-10675353522CA3', 'code' => '11', 'state' => 'CA'},
				new Map<String, String>{'uid' => '12CA2023-10-10675353522CA3', 'code' => '12', 'state' => 'CA'},
				new Map<String, String>{'uid' => '16CA2023-10-10675353522CA3', 'code' => '16', 'state' => 'CA'},
				new Map<String, String>{'uid' => '935CA2023-10-10675353522CA3', 'code' => '935', 'state' => 'CA'}
			},
			'671453522CA3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11CA2023-10-10671453522CA3', 'code' => '11', 'state' => 'CA'},
				new Map<String, String>{'uid' => '12CA2023-10-10671453522CA3', 'code' => '12', 'state' => 'CA'},
				new Map<String, String>{'uid' => '16CA2023-10-10671453522CA3', 'code' => '16', 'state' => 'CA'},
				new Map<String, String>{'uid' => '935CA2023-10-10671453522CA3', 'code' => '935', 'state' => 'CA'}
			},
			'22138233NE3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11NE2023-04-1122138233NE3', 'code' => '11', 'state' => 'NE'},
				new Map<String, String>{'uid' => '12NE2023-04-1122138233NE3', 'code' => '12', 'state' => 'NE'},
				new Map<String, String>{'uid' => '16NE2023-04-1122138233NE3', 'code' => '16', 'state' => 'NE'},
				new Map<String, String>{'uid' => '935NE2023-04-1122138233NE3', 'code' => '935', 'state' => 'NE'}
			},
			'57355422CT3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11CT2023-10-1057355422CT3', 'code' => '11', 'state' => 'CT'},
				new Map<String, String>{'uid' => '12CT2023-10-1057355422CT3', 'code' => '12', 'state' => 'CT'},
				new Map<String, String>{'uid' => '16CT2023-10-1057355422CT3', 'code' => '16', 'state' => 'CT'},
				new Map<String, String>{'uid' => '935CT2023-10-1057355422CT3', 'code' => '935', 'state' => 'CT'}
			},
			'12950SC3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11SC2023-10-1112950SC3', 'code' => '11', 'state' => 'SC'},
				new Map<String, String>{'uid' => '12SC2023-10-1112950SC3', 'code' => '12', 'state' => 'SC'},
				new Map<String, String>{'uid' => '16SC2023-10-1112950SC3', 'code' => '16', 'state' => 'SC'},
				new Map<String, String>{'uid' => '935SC2023-10-1112950SC3', 'code' => '935', 'state' => 'SC'}
			},
			'856932547CA3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11CA2023-11-11856932547CA3', 'code' => '11', 'state' => 'CA'},
				new Map<String, String>{'uid' => '12CA2023-11-11856932547CA3', 'code' => '12', 'state' => 'CA'},
				new Map<String, String>{'uid' => '16CA2023-11-11856932547CA3', 'code' => '16', 'state' => 'CA'},
				new Map<String, String>{'uid' => '935CA2023-11-11856932547CA3', 'code' => '935', 'state' => 'CA'}
			},
			'854698745SC4' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '101SC2023-04-11854698745SC4', 'code' => '101', 'state' => 'SC'}
			},
			'345127867ID3' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '11ID2023-11-11345127867ID3', 'code' => '11', 'state' => 'ID'},
				new Map<String, String>{'uid' => '12ID2023-11-11345127867ID3', 'code' => '12', 'state' => 'ID'},
				new Map<String, String>{'uid' => '16ID2023-11-11345127867ID3', 'code' => '16', 'state' => 'ID'},
				new Map<String, String>{'uid' => '935ID2023-11-11345127867ID3', 'code' => '935', 'state' => 'ID'}
			},
			'458975823TN1405' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '13343TN2023-04-11458975823TN1405', 'code' => '13343', 'state' => 'TN'}
			},
			'12043222GA1929' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '5139GA2023-02-2712043222GA1929', 'code' => '5139', 'state' => 'GA'},
				new Map<String, String>{'uid' => '5140GA2023-02-2712043222GA1929', 'code' => '5140', 'state' => 'GA'}
			},
			'273647826GA1931' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '5133GA2025-03-29273647826GA1931', 'code' => '5133', 'state' => 'GA'},
				new Map<String, String>{'uid' => '5134GA2025-03-29273647826GA1931', 'code' => '5134', 'state' => 'GA'}
			},
			'832938456GA1929' => new List<Map<String, String>>{
				new Map<String, String>{'uid' => '5139GA2025-03-29832938456GA1929', 'code' => '5139', 'state' => 'GA'},
				new Map<String, String>{'uid' => '5140GA2025-03-29832938456GA1929', 'code' => '5140', 'state' => 'GA'}
			}
		};
		
		for (String licenseUid : licenseLoaMappings.keySet()) {
			Id licenseId = licenseIds.get(licenseUid);
			if (licenseId == null) continue;
			
			for (Map<String, String> loaData : licenseLoaMappings.get(licenseUid)) {
				ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
					ht_UniqueIdentifier__c = loaData.get('uid'),
					ht_License__c = licenseId,
					ht_StateOrProvinceCode__c = loaData.get('state'),
					ht_LineOfAuthorityCode__c = loaData.get('code')
				);
				loas.add(loa);
			}
		}

		insert loas;

		createdRecords.put('ht_LineOfAuthority__c', loas);

		return createdRecords;
	}

	@TestVisible
	private static Map<String, List<SObject>> createEntityInfoTestData() {
		Map<String, List<SObject>> createdRecords = new Map<String, List<SObject>>();

		// Create producer with the same NPN we'll be testing with
		Set<String> npns = new Set<String>{'12345678'};
		List<ht_Producer__c> producers = createProducers(npns);
		
		// Customize the producer to match some of the XML data
		producers[0].ht_GivenName__c = 'Michael';
		producers[0].ht_MiddleName__c = 'R';
		producers[0].ht_SurName__c = 'Johnson';
		producers[0].ht_NameSuffix__c = 'JR';
		producers[0].ht_SSN__c = '123-45-6789';
		producers[0].ht_BirthDate__c = Date.newInstance(1980, 6, 15);
		producers[0].ht_Type__c = 'Agent';

		insert producers;
		createdRecords.put('ht_Producer__c', producers);

		Map<String, Id> producerIds = new Map<String, Id>();
		for (ht_Producer__c producer : producers) {
			producerIds.put(producer.ht_NPN__c, producer.Id);
		}
		
		// Create carriers
		List<ht_Carrier__c> carriers = new List<ht_Carrier__c>{
			new ht_Carrier__c(ht_CoCode__c = '54321', ht_FullName__c = 'ABC Insurance Company', Name = 'ABC Insurance Company', ht_FEIN__c = '123456789', ht_UniqueIdentifier__c = '54321123456789'),
			new ht_Carrier__c(ht_CoCode__c = '98765', ht_FullName__c = 'XYZ Insurance Company', Name = 'XYZ Insurance Company', ht_FEIN__c = '987654321', ht_UniqueIdentifier__c = '98765987654321')
		};

		insert carriers;
		createdRecords.put('ht_Carrier__c', carriers);

		Map<String, Id> carrierIds = new Map<String, Id>();
		for (ht_Carrier__c carrier : carriers) {
			carrierIds.put(carrier.ht_UniqueIdentifier__c, carrier.Id);
		}

		// Create Addresses - intentionally creating 2 instead of 3 that will come from XML
		List<ht_ProducerAddress__c> addresses = new List<ht_ProducerAddress__c>{
			createProducerAddress(producerIds.get('12345678'), 'Residential', '123 Main Street', '123MainStreetApt4BBuildingCLosAngelesCA90001U.S.A.Residential12345678'),
			createProducerAddress(producerIds.get('12345678'), 'Mailing', '789 Broadway', '789BroadwayFloor10NewYorkNY10003U.S.A.Mailing12345678')
		};

		insert addresses;
		createdRecords.put('ht_ProducerAddress__c', addresses);

		// Create Producer Communications - intentionally creating 5 instead of 8 that will come from XML
		List<ht_ProducerCommunication__c> communications = new List<ht_ProducerCommunication__c>{
			createPhoneCommunication(producerIds.get('12345678'), '+1-213-555-1234', 'Wired', '+1-213-555-1234Wired12345678'),
			createPhoneCommunication(producerIds.get('12345678'), '+1-213-555-5678', 'Fax', '+1-213-555-5678Fax12345678'),
			createEmailCommunication(producerIds.get('12345678'), 'mjohnson@example.com', 'Business', 'mjohnson@example.comBusiness12345678'),
			createPhoneCommunication(producerIds.get('12345678'), '+1-212-555-9876', 'Wired', '+1-212-555-9876Wired12345678'),
			createEmailCommunication(producerIds.get('12345678'), 'm.johnson.ny@example.com', 'Business', 'm.johnson.ny@example.comBusiness12345678')
		};

		insert communications;
		createdRecords.put('ht_ProducerCommunication__c', communications);

		// Create Licenses - intentionally creating 2 instead of 3 that will come from XML
		List<ht_License__c> licenses = new List<ht_License__c>{
			new ht_License__c(
				ht_LicenseNumber__c = 'CA123456',
				ht_Producer__c = producerIds.get('12345678'),
				ht_StateOrProvinceCode__c = 'CA',
				ht_LicenseClassCode__c = '3',
				ht_UniqueIdentifier__c = 'CA123456CA3'
			),
			new ht_License__c(
				ht_LicenseNumber__c = 'NY789012',
				ht_Producer__c = producerIds.get('12345678'),
				ht_StateOrProvinceCode__c = 'NY',
				ht_LicenseClassCode__c = '3',
				ht_UniqueIdentifier__c = 'NY789012NY3'
			)
		};

		insert licenses;
		createdRecords.put('ht_License__c', licenses);

		Map<String, Id> licenseIds = new Map<String, Id>();
		for (ht_License__c lic : licenses) {
			licenseIds.put(lic.ht_UniqueIdentifier__c, lic.Id);
		}

		// Create Carrier Appointments - intentionally creating 3 instead of 4 that will come from XML
		List<ht_CarrierAppointment__c> appointments = new List<ht_CarrierAppointment__c>{
			new ht_CarrierAppointment__c(
				ht_UniqueIdentifier__c = '1234567854321123456789CA001Terminated12345678543211234567892026-02-012023-02-0100116',
				ht_Producer__c = producerIds.get('12345678'),
				ht_Carrier__c = carrierIds.get('54321123456789'),
				ht_StateOrProvinceCode__c = 'CA',
				ht_CountyCode__c = '001',
				ht_StatusCode__c = 'Terminated'
			),
			new ht_CarrierAppointment__c(
				ht_UniqueIdentifier__c = '1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503616',
				ht_Producer__c = producerIds.get('12345678'),
				ht_Carrier__c = carrierIds.get('98765987654321'),
				ht_StateOrProvinceCode__c = 'NY',
				ht_CountyCode__c = '036',
				ht_StatusCode__c = 'Appointed'
			),
			new ht_CarrierAppointment__c(
				ht_UniqueIdentifier__c = '1234567898765987654321NY036Appointed12345678987659876543212026-03-152023-03-1503611',
				ht_Producer__c = producerIds.get('12345678'),
				ht_Carrier__c = carrierIds.get('98765987654321'),
				ht_StateOrProvinceCode__c = 'NY',
				ht_CountyCode__c = '036',
				ht_StatusCode__c = 'Appointed'
			)
		};

		insert appointments;
		createdRecords.put('ht_CarrierAppointment__c', appointments);

		Map<String, Id> appointmentIds = new Map<String, Id>();
		for (ht_CarrierAppointment__c app : appointments) {
			appointmentIds.put(app.ht_UniqueIdentifier__c, app.Id);
		}

		// Create License Lines of Authority - intentionally creating 3 instead of 5 that will come from XML
		List<ht_LineOfAuthority__c> loas = new List<ht_LineOfAuthority__c>{
			new ht_LineOfAuthority__c(
				ht_UniqueIdentifier__c = '16CA2023-01-15CA123456CA3',
				ht_License__c = licenseIds.get('CA123456CA3'),
				ht_StateOrProvinceCode__c = 'CA',
				ht_LineOfAuthorityCode__c = '16',
				ht_LineOfAuthorityDescription__c = 'Life'
			),
			new ht_LineOfAuthority__c(
				ht_UniqueIdentifier__c = '12NY2023-03-01NY789012NY3',
				ht_License__c = licenseIds.get('NY789012NY3'),
				ht_StateOrProvinceCode__c = 'NY',
				ht_LineOfAuthorityCode__c = '12',
				ht_LineOfAuthorityDescription__c = 'Property'
			),
			new ht_LineOfAuthority__c(
				ht_UniqueIdentifier__c = '11NY2023-03-01NY789012NY3',
				ht_License__c = licenseIds.get('NY789012NY3'),
				ht_StateOrProvinceCode__c = 'NY',
				ht_LineOfAuthorityCode__c = '11',
				ht_LineOfAuthorityDescription__c = 'Casualty'
			)
		};

		insert loas;
		createdRecords.put('ht_LineOfAuthority__c', loas);

		return createdRecords;
	}

	private static String extractLOACode(String uniqueId) {
		// LOA code is the numeric prefix before the state code
		Matcher m = Pattern.compile('^(\\d+)[A-Z]{2}').matcher(uniqueId);
		return m.find() ? m.group(1) : null;
	}
	
	private static String extractStateCode(String uniqueId) {
		// State code is always 2 uppercase letters immediately after LOA code
		Matcher m = Pattern.compile('^\\d+([A-Z]{2})').matcher(uniqueId);
		return m.find() ? m.group(1) : null;
	}

	@TestVisible
	private static ht_Producer__c createProducerWithNPN(String npn, Boolean doInsert) {
		ht_Producer__c producer = new ht_Producer__c(ht_NPN__c = npn);
		if(doInsert) {
			insert producer;
		}
		return producer;
	}

	@TestVisible
	private static List<ht_Producer__c> createProducersWithNPNs(List<String> npns, Boolean doInsert) {
		List<ht_Producer__c> producers = new List<ht_Producer__c>();
		for(String npn : npns) {
			producers.add(new ht_Producer__c(ht_NPN__c = npn));
		}
		if(doInsert && !producers.isEmpty()) {
			insert producers;
		}
		return producers;
	}

	@TestVisible
	private static ht_Subscription__c createSubscription(Boolean doInsert) {
		// Get or initialize custom settings for tests
		ht_NIPRSubscriptionDetails__c settings = ht_NIPRSubscriptionDetails__c.getOrgDefaults();

		if (settings == null || settings.ht_Latest_Number__c == null) {
			settings = new ht_NIPRSubscriptionDetails__c(
				SetupOwnerId = UserInfo.getOrganizationId(),
				ht_Latest_Number__c = 0
			);
			upsert settings;
		}

		// Increment counter
		Decimal nextNumber = settings.ht_Latest_Number__c + 1;
		settings.ht_Latest_Number__c = nextNumber;
		update settings;

		// Format subscription name: S-0001, S-0002, etc.
		String subName = 'S-' + String.valueOf(nextNumber.intValue()).leftPad(4, '0');

		// Set ht_Subscription_Name__c - this is used for NIPR API calls
		// The trigger will also update the counter, but since we already updated it,
		// it will just verify the value is correct
		ht_Subscription__c subscription = new ht_Subscription__c(
			ht_Subscription_Name__c = subName
		);

		if(doInsert) {
			// Disable trigger to avoid double-counting in tests
			SubscriptionTriggerHandler.triggerDisabled = true;
			insert subscription;
			SubscriptionTriggerHandler.triggerDisabled = false;
		}
		return subscription;
	}

	@TestVisible
	private static String getPDBSpecificAlertResponse() {
		return PDBAlertResponseConstants.initialPDBAlertResponse;
	}

	@TestVisible
	private static String getPDBMixedDeleteScenarioResponse() {
		// Reuse the full updateDeletePDBAlertResponse and modify specific nodes
		return PDBAlertResponseConstants.mixedDeletePDBAlertsResponse;
	}

	@TestVisible
	private static String getCreateSubscriptionResponse() {
		return PDBAlertResponseConstants.createSubscriptionResponse;
	}

	@TestVisible
	private static String getCreateSubscriptionErrorResponse() {
		return PDBAlertResponseConstants.createSubscriptionErrorResponse;
	}

	@TestVisible
	private static String getAddNPNAllValidResponse() {
		return PDBAlertResponseConstants.addNPNAllValidResponse;
	}

	@TestVisible
	private static String getAddNPNMixedResponse() {
		return PDBAlertResponseConstants.addNPNMixedResponse;
	}

	@TestVisible
	private static String getMultipleListsResponse() {
		return PDBAlertResponseConstants.addMultipleListsResponse;
	}

	@TestVisible
	private static String getAddNPNErrorResponse() {
		return PDBAlertResponseConstants.addNPNErrorResponse;
	}

	@TestVisible
	private static String getRemoveNPNValidResponse() {
		return PDBAlertResponseConstants.removeNPNValidResponse;
	}

	@TestVisible
	private static String getRemoveNPNMixedResponse() {
		return PDBAlertResponseConstants.removeNPNMixedResponse;
	}

	@TestVisible
	private static String getRemoveNPNAllInvalidResponse() {
		return PDBAlertResponseConstants.removeNPNAllInvalidResponse;
	}

	@TestVisible
	private static String getRemoveNPNErrorResponse() {
		return PDBAlertResponseConstants.removeNPNErrorResponse;
	}

	@TestVisible
	private static String getRemoveNPNMultipleValidResponse() {
		return PDBAlertResponseConstants.removeNPNMultipleValidResponse;
	}

	@TestVisible
	private static String getRemoveNPNMultipleInvalidResponse() {
		return PDBAlertResponseConstants.removeNPNMultipleInvalidResponse;
	}

	@TestVisible
	private static String getRemoveNPNMultipleInSingleListResponse() {
		return PDBAlertResponseConstants.removeNPNMultipleInSingleListResponse;
	}
	
	@TestVisible
	private static String getEntityInfoAPIIndividualXmlResponse() {
		return EntityInfoConstants.individualXMLResponse;
	}

	@TestVisible
	private static String getEntityInfoAPIFirmlXmlResponse() {
		return EntityInfoConstants.firmXmlResponse;
	}

	@TestVisible
	private static String getEntityInfoAPINoProducerData() {
		return EntityInfoConstants.noProducerDataResponse;
	}

	// ============================================================
	// LOA PRODUCT CATEGORIZATION TEST DATA HELPERS
	// ============================================================

	/**
	 * Creates an LOA to Insurance Product Mapping record
	 * @param state - State code (e.g., 'CA')
	 * @param code - LOA code (e.g., '935')
	 * @param description - LOA description (e.g., 'Accident & Health or Sickness')
	 * @param doInsert - Whether to insert the record
	 * @return The created mapping record
	 */
	@TestVisible
	private static ht_LOA_Insurance_Product_Mapping__c createLOAInsuranceProductMapping(
		String state, String code, String description, Boolean doInsert
	) {
		ht_LOA_Insurance_Product_Mapping__c mapping = new ht_LOA_Insurance_Product_Mapping__c(
			ht_StateOrProvinceCode__c = state,
			ht_LineOfAuthorityCode__c = code,
			ht_LineOfAuthorityDescription__c = description,
			ht_UniqueIdentifier__c = state + '-' + code + '-' + description
		);
		if (doInsert) {
			insert mapping;
		}
		return mapping;
	}

	/**
	 * Creates an Insurance Product record
	 * @param name - Product name (e.g., 'Health Insurance')
	 * @param state - State code (e.g., 'CA')
	 * @param doInsert - Whether to insert the record
	 * @return The created product record
	 */
	@TestVisible
	private static ht_Insurance_Product__c createInsuranceProduct(
		String name, String state, Boolean doInsert
	) {
		ht_Insurance_Product__c product = new ht_Insurance_Product__c(
			ht_ProductName__c = name,
			ht_StateOrProvince__c = state,
			ht_UniqueIdentifier__c = state + '-' + name
		);
		if (doInsert) {
			insert product;
		}
		return product;
	}

	/**
	 * Creates a junction record linking Insurance Product to LOA Mapping
	 * @param productId - Insurance Product ID
	 * @param mappingId - LOA Mapping ID
	 * @param doInsert - Whether to insert the record
	 * @return The created junction record
	 */
	@TestVisible
	private static ht_Insurance_Product_LOA_Mapping__c createInsuranceProductLOAMappingJunction(
		Id productId, Id mappingId, Boolean doInsert
	) {
		ht_Insurance_Product_LOA_Mapping__c junction = new ht_Insurance_Product_LOA_Mapping__c(
			ht_InsuranceProduct__c = productId,
			ht_LOAMapping__c = mappingId,
			ht_UniqueIdentifier__c = String.valueOf(productId) + '-' + String.valueOf(mappingId)
		);
		if (doInsert) {
			insert junction;
		}
		return junction;
	}

	/**
	 * Creates a Line of Authority record with state/code/description for matching tests
	 * @param licenseId - Parent License ID
	 * @param state - State code (e.g., 'CA')
	 * @param code - LOA code (e.g., '935')
	 * @param description - LOA description (e.g., 'Accident & Health or Sickness')
	 * @param doInsert - Whether to insert the record
	 * @return The created LOA record
	 */
	@TestVisible
	private static ht_LineOfAuthority__c createLOAForMatching(
		Id licenseId, String state, String code, String description, Boolean doInsert
	) {
		ht_LineOfAuthority__c loa = new ht_LineOfAuthority__c(
			ht_License__c = licenseId,
			ht_StateOrProvinceCode__c = state,
			ht_LineOfAuthorityCode__c = code,
			ht_LineOfAuthorityDescription__c = description,
			ht_UniqueIdentifier__c = code + state + System.currentTimeMillis() + licenseId
		);
		if (doInsert) {
			insert loa;
		}
		return loa;
	}

	/**
	 * Creates a License Insurance Product junction record
	 * @param licenseId - License ID
	 * @param productId - Insurance Product ID
	 * @param doInsert - Whether to insert the record
	 * @return The created junction record
	 */
	@TestVisible
	private static ht_License_Insurance_Product__c createLicenseInsuranceProductJunction(
		Id licenseId, Id productId, Boolean doInsert
	) {
		ht_License_Insurance_Product__c junction = new ht_License_Insurance_Product__c(
			ht_License__c = licenseId,
			ht_InsuranceProduct__c = productId,
			ht_UniqueIdentifier__c = String.valueOf(licenseId) + '-' + String.valueOf(productId)
		);
		if (doInsert) {
			insert junction;
		}
		return junction;
	}

	/**
	 * Creates complete test data for LOA Product Categorization tests
	 * Creates: Producer, License, LOA Mapping, Insurance Product, and junction
	 * @return Map of object type to list of created records
	 */
	@TestVisible
	private static Map<String, List<SObject>> createLOAProductCategorizationTestData() {
		Map<String, List<SObject>> createdRecords = new Map<String, List<SObject>>();

		// Create Producer
		ht_Producer__c producer = createProducer('TEST123456');
		insert producer;
		createdRecords.put('ht_Producer__c', new List<SObject>{ producer });

		// Create License
		ht_License__c license = new ht_License__c(
			ht_LicenseNumber__c = 'LIC123456',
			ht_Producer__c = producer.Id,
			ht_StateOrProvinceCode__c = 'CA',
			ht_LicenseClassCode__c = '3',
			ht_UniqueIdentifier__c = 'LIC123456CA3'
		);
		insert license;
		createdRecords.put('ht_License__c', new List<SObject>{ license });

		// Create LOA Mapping
		ht_LOA_Insurance_Product_Mapping__c mapping = createLOAInsuranceProductMapping(
			'CA', '935', 'Accident & Health or Sickness', true
		);
		createdRecords.put('ht_LOA_Insurance_Product_Mapping__c', new List<SObject>{ mapping });

		// Create Insurance Product
		ht_Insurance_Product__c product = createInsuranceProduct('Health Insurance', 'CA', true);
		createdRecords.put('ht_Insurance_Product__c', new List<SObject>{ product });

		// Create junction between Product and Mapping
		ht_Insurance_Product_LOA_Mapping__c junction = createInsuranceProductLOAMappingJunction(
			product.Id, mapping.Id, true
		);
		createdRecords.put('ht_Insurance_Product_LOA_Mapping__c', new List<SObject>{ junction });

		return createdRecords;
	}
}