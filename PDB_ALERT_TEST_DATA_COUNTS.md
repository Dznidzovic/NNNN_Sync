# PDB Alert Test Data - Expected Counts Per Entity

This document defines the expected counts of addresses and communications per entity in the PDB Alert import test data. These counts are based on the import XML structure and should remain constant across junction model refactoring.

## Import XML Structure

The `getPDBSpecificAlertResponse()` mock XML contains data for 5 entities. The counts below reflect what should be created by the import process.

### Entity 22138233

**Communications (Phones + Emails): 9 total**
- Phone 1: `+1-219-313-6379` (Wired)
- Phone 2: `+1-419-906-3223` (Fax)
- Phone 3: `+1-419-906-3221` (Wired)
- Email 1: `silvana1.zapoticky@cblmaycfqw.com` (Business)
- Email 2: `silvana2.zapoticky@cblmaycfqw.com` (Personal)
- Phone 4: `+1-219-313-6370` (Wired) **← SHARED with 22166967**
- Phone 5: `+1-419-906-3229` (Fax) **← SHARED with 22166967**
- Email 3: `silvana3.zapoticky@cblmaycfqw.com` (Business) **← SHARED with 22166967**
- Email 4: `silvana4.zapoticky@cblmaycfqw.com` (Personal) **← SHARED with 22166967**

**Addresses: 4 total**
- Mailing: `245 Francis Lewis Blvd #9536, Gardena, CA 90248` **← SHARED with 22166967**
- Residential: `245 Francis Lewis Blvd #9536, Gardena, CA 90248`
- Mailing: `7 Se Bishop Ave #9, San Bernardino, CA 92410` **← SHARED with 22166967**
- Physical: `245 Francis Lewis Blvd #9536, Gardena, CA 90248` **← SHARED with 22166967**

### Entity 22166967

**Communications (Phones + Emails): 4 total (ALL SHARED WITH 22138233)**
- Phone 1: `+1-219-313-6370` (Wired) **← SHARED**
- Phone 2: `+1-419-906-3229` (Fax) **← SHARED**
- Email 1: `silvana3.zapoticky@cblmaycfqw.com` (Business) **← SHARED**
- Email 2: `silvana4.zapoticky@cblmaycfqw.com` (Personal) **← SHARED**

**Addresses: 3 total**
- Mailing: `7 Se Bishop Ave #9, San Bernardino, CA 92410` **← SHARED**
- Physical: `245 Francis Lewis Blvd #9536, Gardena, CA 90248` **← SHARED**
- Principal: `7 Se Bishop Ave #9, San Bernardino, CA 92410`

## External ID Format

### Old Model (Master-Detail with NPN suffix)
- Communication External ID: `{phoneNumber|emailAddress}{type}{NPN}`
  - Example: `'+1-219-313-6370Wired22138233'` and `'+1-219-313-6370Wired22166967'` were DIFFERENT records
- Address External ID: `{addressReferences}{type}{NPN}`
  - Example: `'245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Mailing22138233'`

### New Model (Junction with NO NPN suffix)
- Communication External ID: `{phoneNumber|emailAddress}{type}` (NO NPN)
  - Example: `'+1-219-313-6370Wired'` is ONE shared record
- Address External ID: `{addressReferences}{type}` (NO NPN)
  - Example: `'245FrancisLewisBlvd#9536GardenaCA90248U.S.A.Mailing'` is ONE shared record

## Junction Counts (New Model)

### Expected Junction Counts After Import

**Entity 22138233:**
- Communication Junctions: **9** (5 exclusive + 4 shared)
- Address Junctions: **4** (1 exclusive + 3 shared)

**Entity 22166967:**
- Communication Junctions: **4** (0 exclusive, all 4 shared with 22138233)
- Address Junctions: **3** (1 exclusive + 2 shared)

### Total Unique Standalone Records

**After deduplication (External IDs without NPN suffix):**
- Unique Communications: **9** (5 for 22138233 only + 4 shared = 9 total)
- Unique Addresses: **5** (1 for 22138233 only + 1 for 22166967 only + 3 shared = 5 total)

## Test Data Setup for Test 4 (Update Scenario)

`createNIPRPDBAlertTestData()` should create:

1. **5 Entities** (22138233, 22166967, 22166100, 22138253, 22234021)
2. **9 Unique Communications** (deduplicated by External ID without NPN)
3. **5 Unique Addresses** (deduplicated by External ID without NPN)
4. **13 Communication Junctions** (9 for 22138233 + 4 for 22166967 = 13 total)
5. **7 Address Junctions** (4 for 22138233 + 3 for 22166967 = 7 total)
6. **12 Licenses**
7. **36 Lines of Authority**
8. **6 Carrier Appointments**

## Critical Rules

1. **Standalone Objects**: Addresses and Communications are standalone objects with NO parent relationship
2. **No Duplicates**: External IDs do NOT include NPN suffix, so duplicates are prevented via upsert
3. **Junction Creation**: Test setup must create junctions linking entities to addresses/communications
4. **Junction Counts Match Old Model**: Junction counts should equal the old Master-Detail counts per producer
5. **Import Logic**: The import process creates junctions for ALL addresses/communications in the XML for each entity

## Test Assertions

### Test 2 (Insert Scenario - No Setup)
```apex
// After import with NO test setup
System.assertEquals(5, getCount('d4c_Entity__c'));
System.assertEquals(5, getCount('d4c_NIPR_Address__c')); // Deduplicated
System.assertEquals(9, getCount('d4c_NIPR_Communication__c')); // Deduplicated
System.assertEquals(13, getCommunicationJunctionCount()); // 9 + 4
System.assertEquals(7, getAddressJunctionCount()); // 4 + 3
```

### Test 4 (Update Scenario - With Setup)
```apex
// After test setup BEFORE import
System.assertEquals(5, getCount('d4c_Entity__c'));
System.assertEquals(5, getCount('d4c_NIPR_Address__c'));
System.assertEquals(9, getCount('d4c_NIPR_Communication__c'));
System.assertEquals(13, getCommunicationJunctionCount()); // From test setup
System.assertEquals(7, getAddressJunctionCount()); // From test setup

// After import (should remain the same - no new junctions created)
System.assertEquals(9, getCommunicationCountForEntity('22138233')); // Via junctions
System.assertEquals(4, getCommunicationCountForEntity('22166967')); // Via junctions
System.assertEquals(4, getAddressCountForEntity('22138233')); // Via junctions
System.assertEquals(3, getAddressCountForEntity('22166967')); // Via junctions
```

---

**Date Created**: 2026-02-11
**Last Updated**: 2026-02-11
