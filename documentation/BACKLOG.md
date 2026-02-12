# NIPR Integration - Technical Backlog

## High Priority Items

### 1. State-Aware Address & Communication Deletion Logic
**Status:** Deferred (Interim Solution Implemented)
**Priority:** Low (interim solution is acceptable)
**Effort:** High (2-3 days)
**Created:** 2026-02-12
**Interim Solution Implemented:** 2026-02-12

#### Interim Solution Implemented (2026-02-12)

✅ **Merge ALL Communication Data from ALL Person Nodes**
- Modified `RetrievePDBSpecificReportData.mergeSameNPNPersonRecords()` to collect PersonCommunication and BusinessCommunication from ALL state-specific Person nodes
- Added `mergePersonCommunications()` helper method to aggregate all phone/email/address data
- Added `mergeBusinessCommunications()` helper method to aggregate all phone/email/address data
- **Result**: All unique communication data (phones, emails, addresses) is now captured from all 27+ Person nodes (previously lost data from 26 nodes)

✅ **Removed Deletion Logic for Address/Communication Junctions**
- Deleted `getJunctionIdsForDeletion()` method from ProcessPDBAlertReportService.cls
- Removed all calls to deletion logic
- Removed DMLExecutor delete operations for address/communication junctions
- **Result**: Accept data accumulation - outdated addresses/communications may remain but no data loss occurs

✅ **Relies on Existing Deduplication**
- `ListUtils.deduplicateByField()` handles duplicate records via `d4c_UniqueIdentifier__c` External ID
- Same address appearing in multiple states → 1 record in database
- Same phone appearing in multiple states → 1 record in database
- **Result**: Natural deduplication prevents bloat while capturing all unique data

✅ **Comprehensive Test Coverage**
- Updated test mocks to include 5+ Person nodes with communication data spread across them
- Added assertions for EVERY unique communication (phones, emails, addresses)
- Verified counts STAY THE SAME even when delta shows changes (no deletion)
- **Result**: Tests verify all data is preserved, no unexpected deletions

#### Original Problem Statement
NIPR returns demographic data (addresses, phones, emails) grouped by STATE. When they say "brings back all demographic and contact data for that state", they mean ALL data for THAT SPECIFIC STATE.

Current implementation:
- ❌ We merge all state-specific data into one pool (no state tracking for deletion)
- ❌ If Illinois demographics change, we get IL data - but we might incorrectly delete NY data
- ❌ If PersonCommunication node is absent, we can't distinguish "no changes for IL" vs "delete IL data"

#### Example Scenario
Producer has licenses in 3 states: KY, VA, WV
- NIPR sends alert: "KY demographics changed"
- Returns `<Person key="PersonKY123">` with KY addresses
- **Expected behavior:** Update KY data only, leave VA and WV data alone
- **Current behavior:** We merge all into one pool, can't do state-specific deletion

#### Impact
- **Entity Info API:** Returns state-grouped addresses/communications
- **PDB Alerts API:** Returns state-grouped Person nodes
- **Both APIs affected** - need consistent state-aware approach

#### Proposed Solution (Full Implementation)
1. Add `d4c_State__c` field to:
   - `d4c_NIPR_Communication__c`
   - `d4c_NIPR_Address__c` (already has state in address data)

2. **Entity Info API changes:**
   - Extract state from `<STATE name="KY">` wrapper
   - Store state on each phone/email/address record
   - Track which states were included in the response
   - Only delete data for states that were present in the response

3. **PDB Alerts API changes:**
   - Extract state from Person key (e.g., `PersonIL13076346` → `IL`)
   - Merge PersonCommunication/BusinessCommunication PER STATE
   - Track which states had PersonCommunication/BusinessCommunication nodes
   - Only delete data for states where nodes were present
   - If node is empty (`<PersonCommunication/>`), delete that state's data
   - If node is absent, don't touch that state's data

4. **Deletion logic:**
   ```apex
   // Pseudo-code
   Set<String> statesInResponse = extractStatesFromResponse();

   for (String state : statesInResponse) {
       // Only delete data for THIS state
       List<Communication> newCommsForState = getNewCommunicationsForState(state);
       List<Id> junctionsToDelete = compareWithExistingForState(state, newCommsForState);
       delete junctions where state = :state AND id IN :junctionsToDelete;
   }

   // States NOT in response are left untouched
   ```

5. **Data model changes:**
   - Add state field to junction objects OR
   - Add state field to main Communication/Address objects
   - Update UniqueIdentifier formula to include state (if needed)

#### Current Workaround (Interim Solution - Implemented 2026-02-12)
- ✅ No deletion logic for addresses/communications (accept data accumulation)
- ✅ Store state field for future state-aware processing
- ✅ Merge all Person nodes together (accept potential multi-state data merging)
- ✅ Let UniqueIdentifier handle deduplication
- ⚠️ Accept that outdated addresses/phones/emails may remain in database

#### Why Deferred (Full State-Aware Solution)
1. **Interim solution is acceptable:** Merge all data + no deletion prevents data loss effectively
2. **Complexity vs benefit:** Full state-aware implementation requires significant effort (2-3 days) for minimal gain
3. **Testing burden:** Need comprehensive test coverage for complex state-specific scenarios
4. **Data model changes:** May require schema changes (junction objects with state field + migration)
5. **Customer priority:** Licensing data (state-aware) is more critical than demographics
6. **Rare occurrence:** Multi-state demographic updates with actual removals are uncommon
7. **Data accumulation acceptable:** Customers can tolerate outdated contacts remaining in database vs risk of data loss

#### Dependencies
- Refactor Entity Info API processing
- Refactor PDB Alerts processing
- Update test mocks to include multi-state scenarios
- Update data model (potentially)
- Migration script for existing data (add state field)

#### Acceptance Criteria
- [ ] State field stored on all Communication and Address records
- [ ] Entity Info API only deletes data for states present in response
- [ ] PDB Alerts only deletes data for states with PersonCommunication nodes
- [ ] Empty PersonCommunication node deletes that state's data
- [ ] Absent PersonCommunication node leaves that state's data untouched
- [ ] Licensing data unaffected (continues using PersonPRI references)
- [ ] All existing tests pass
- [ ] New tests cover multi-state scenarios

#### Notes
- Licensing is NOT affected by this issue (uses JurisdictionReportItems and PersonPRI references)
- Current merge logic preserves ALL Person keys (PersonPRI, PersonIL, PersonNY) - licensing matching works correctly
- We only lose PersonCommunication/BusinessCommunication data from non-primary nodes
- For most customers, producers are only licensed in 1-2 states, making this edge case rare

---

## Medium Priority Items

### 2. [Placeholder for future items]

---

## Low Priority Items

### 3. [Placeholder for future items]

---

**Last Updated:** 2026-02-12
**Maintained By:** NIPR Development Team
