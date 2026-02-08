# Package Version Creation Errors

**Date**: 2026-01-15
**Package**: NIPR (0HoPB00000001NV0AY)
**Version**: 0.1.0.1 (04tPB000000ApFlYAK)
**Status**: ✅ **SUCCESS!** Package version created successfully!

---

## Progress Summary

**First Attempt**: 11 errors
**Second Attempt**: 6 errors (**5 fixed!** ✅)
**Third Attempt**: 6 errors (no change - user fixing permission sets)
**Fourth Attempt**: 1 error (ApexTestSuite not supported)
**Fifth Attempt**: ✅ **SUCCESS!** - All errors resolved!

## Package Version Information

- **Package Version ID**: `04tPB000000ApFlYAK`
- **Package Version Creation Request**: `08cPB00000010lxYAA`
- **Installation URL**: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tPB000000ApFlYAK
- **Created**: 2026-01-15

## Installation Command

```bash
sf package install --package "04tPB000000ApFlYAK" --target-org <org-alias> --wait 20
```

### All Errors Fixed ✅
- ~~ERROR 1: Invalid ActionPlan field in LOA Layout~~ **FIXED** (User - removed ActionPlan related lists)
- ~~ERROR 2: Invalid ActionPlan field in Producer Address Layout~~ **FIXED** (User - removed ActionPlan related lists)
- ~~ERROR 3: Missing Custom Links section in LOA Layout~~ **FIXED** (User - removed Custom Links section)
- ~~ERROR 4: Missing Custom Links section in Producer Address Layout~~ **FIXED** (User - removed Custom Links section)
- ~~ERROR 5: Missing test class in Test Suite~~ **FIXED** (User - fixed test class reference)
- ~~ERROR 6: Contact_Full_Access - Invalid Contact.Languages__c field~~ **FIXED** (User - removed invalid field)
- ~~ERROR 7: NIPR_View_NIPR_Data - Invalid Account.FinServ__AUM__c field~~ **FIXED** (User - removed invalid field)
- ~~ERROR 8: ht_NIPR_Admin_Access - Invalid ActionPlan object~~ **FIXED** (User - removed ActionPlan permissions)
- ~~ERROR 9: ht_NIPR_Admin_User - Invalid permission set references~~ **FIXED** (User - fixed permission set group)
- ~~ERROR 10: NIPR_Line_of_Authority_Record_Page_Read_Only - Invalid Record.OwnerId~~ **FIXED** (User - fixed FlexiPage)
- ~~ERROR 11: ht_NIPR_API_Callout - Invalid cross reference~~ **FIXED** (User - removed invalid references)
- ~~ERROR 12: ApexTestSuite not supported in managed packages~~ **FIXED** (Added `**/testSuites/**` to `.forceignore`)

---

## Error Summary (Remaining 6 Errors)

| # | Category | Severity | Component | Issue | Status |
|---|----------|----------|-----------|-------|--------|
| 6 | Permission Set | HIGH | Contact_Full_Access | Invalid field reference | ❌ ACTIVE |
| 7 | Permission Set | HIGH | NIPR_View_NIPR_Data | Invalid field reference | ❌ ACTIVE |
| 8 | Permission Set | HIGH | ht_NIPR_Admin_Access | Invalid object reference | ❌ ACTIVE |
| 9 | Permission Set Group | CRITICAL | ht_NIPR_Admin_User | Invalid permission set references | ❌ ACTIVE |
| 10 | FlexiPage | HIGH | NIPR_Line_of_Authority_Record_Page_Read_Only | Invalid field reference | ❌ ACTIVE |
| 11 | Permission Set | HIGH | ht_NIPR_API_Callout | Invalid cross reference | ❌ ACTIVE |

---

## Detailed Error Breakdown

### ERROR 1: Invalid ActionPlan Field in LOA Layout
**Component**: `ht_LineOfAuthority__c-NIPR Line Of Authority Layout`
**Error Message**: `Invalid field:Name in related list:ActionPlan`
**File Location**: `force-app/main/default/layouts/ht_LineOfAuthority__c-NIPR Line Of Authority Layout.layout-meta.xml`

**Issue**:
- Layout references `ActionPlan` object in a related list
- `ActionPlan` is a Salesforce standard object that may not be available in all orgs
- The related list references `Name` field which doesn't exist on ActionPlan

**Fix Options**:
1. Remove the ActionPlan related list from the layout
2. Verify if ActionPlan object should be included in package dependencies

---

### ERROR 2: Invalid ActionPlan Field in Producer Address Layout
**Component**: `ht_ProducerAddress__c-NIPR Producer Address Layout`
**Error Message**: `Invalid field:Name in related list:ActionPlan`
**File Location**: `force-app/main/default/layouts/ht_ProducerAddress__c-NIPR Producer Address Layout.layout-meta.xml`

**Issue**: Same as Error 1, but for Producer Address layout

**Fix Options**:
1. Remove the ActionPlan related list from the layout
2. Verify if ActionPlan object should be included in package dependencies

---

### ERROR 3: Missing Custom Links Section in LOA Layout
**Component**: `ht_LineOfAuthority__c-en_US`
**Error Message**: `Couldn't locate layout section:Custom Links in layout:NIPR Line Of Authority Layout`
**File Location**: `force-app/main/default/layouts/ht_LineOfAuthority__c-NIPR Line Of Authority Layout.layout-meta.xml`

**Issue**:
- Layout translation references a "Custom Links" section that doesn't exist in the actual layout
- This is likely a translation metadata issue

**Fix Options**:
1. Remove the Custom Links section from the translation file
2. Add the Custom Links section to the layout if it's intended to be there

---

### ERROR 4: Missing Custom Links Section in Producer Address Layout
**Component**: `ht_ProducerAddress__c-en_US`
**Error Message**: `Couldn't locate layout section:Custom Links in layout:NIPR Producer Address Layout`
**File Location**: `force-app/main/default/layouts/ht_ProducerAddress__c-NIPR Producer Address Layout.layout-meta.xml`

**Issue**: Same as Error 3, but for Producer Address layout

**Fix Options**:
1. Remove the Custom Links section from the translation file
2. Add the Custom Links section to the layout if it's intended to be there

---

### ERROR 5: Missing Test Class in Test Suite
**Component**: `NIPRTestSuite`
**Error Message**: `No classes found for AccountProducerAssignmentService_Test.`
**File Location**: `force-app/main/default/testSuites/NIPRTestSuite.testSuite-meta.xml`

**Issue**:
- Test suite references `AccountProducerAssignmentService_Test` class
- The actual class name is `AccountProducerAssignmentService_Test` but it may not be found due to:
  - Wrong class name in test suite
  - Class doesn't exist
  - Class is not marked as @isTest

**Fix Options**:
1. Verify the correct test class name and update test suite
2. Check if test class exists: `force-app/main/default/classes/Test/AccountProducerAssignmentService_Test.cls`
3. Ensure test class is properly annotated with `@isTest`

**File to Check**: `force-app/main/default/testSuites/NIPRTestSuite.testSuite-meta.xml`

---

### ERROR 6: Invalid Field in Contact_Full_Access Permission Set
**Component**: `Contact_Full_Access`
**Error Message**: `In field: field - no CustomField named Contact.Languages__c found`
**File Location**: `force-app/main/default/permissionsets/Contact_Full_Access.permissionset-meta.xml`

**Issue**:
- Permission set grants access to `Contact.Languages__c` field
- This field doesn't exist in the metadata (not part of package)
- This is likely a field from a different package or org-specific customization

**Fix Options**:
1. Remove `Contact.Languages__c` from the permission set
2. Add the field to the package if it should be included

---

### ERROR 7: Invalid Field in NIPR_View_NIPR_Data Permission Set
**Component**: `NIPR_View_NIPR_Data`
**Error Message**: `In field: field - no CustomField named Account.FinServ__AUM__c found`
**File Location**: `force-app/main/default/permissionsets/NIPR_View_NIPR_Data.permissionset-meta.xml`

**Issue**:
- Permission set grants access to `Account.FinServ__AUM__c` field
- `FinServ__` prefix indicates this is from Financial Services Cloud managed package
- This field is from an external managed package not included as dependency

**Fix Options**:
1. Remove `Account.FinServ__AUM__c` from the permission set
2. Add Financial Services Cloud as package dependency (if applicable)

---

### ERROR 8: Invalid Object in ht_NIPR_Admin_Access Permission Set
**Component**: `ht_NIPR_Admin_Access`
**Error Message**: `In field: object - no CustomObject named ActionPlan found`
**File Location**: `force-app/main/default/permissionsets/ht_NIPR_Admin_Access.permissionset-meta.xml`

**Issue**:
- Permission set grants object-level permissions to `ActionPlan` object
- ActionPlan is not part of the package metadata
- This is a Salesforce standard object that may not be available in all orgs

**Fix Options**:
1. Remove ActionPlan object permissions from the permission set
2. Add ActionPlan as package dependency if required

---

### ERROR 9: Invalid Permission Set References in Permission Set Group
**Component**: `ht_NIPR_Admin_User`
**Error Message**: `Cannot create permission set group components since the following permission set names are invalid: HT_Manage_Producer, HT_NIPR_View_Agent_SSN, NIPR_View_NIPR_Data, ht_NIPR_API_Callout, ht_NIPR_Admin_Access`
**File Location**: `force-app/main/default/permissionsetgroups/ht_NIPR_Admin_User.permissionsetgroup-meta.xml`

**Issue**:
- Permission set group references 5 permission sets that have validation errors or don't exist
- This error is cascading from other permission set errors (errors 6, 7, 8, 11)

**Referenced Permission Sets**:
1. `HT_Manage_Producer` - May not exist or has errors
2. `HT_NIPR_View_Agent_SSN` - May not exist or has errors
3. `NIPR_View_NIPR_Data` - Has Error 7 (invalid field reference)
4. `ht_NIPR_API_Callout` - Has Error 11 (invalid cross reference)
5. `ht_NIPR_Admin_Access` - Has Error 8 (invalid object reference)

**Fix Options**:
1. Fix all referenced permission sets first (errors 6, 7, 8, 11)
2. Remove invalid permission set references from the group
3. Verify all permission set names exist in metadata

---

### ERROR 10: Invalid Field Reference in FlexiPage
**Component**: `NIPR_Line_of_Authority_Record_Page_Read_Only`
**Error Message**: `Something went wrong. We couldn't retrieve or load the information on the field: Record.OwnerId.`
**File Location**: `force-app/main/default/flexipages/NIPR_Line_of_Authority_Record_Page_Read_Only.flexipage-meta.xml`

**Issue**:
- FlexiPage component references `Record.OwnerId` field
- This field reference is invalid or malformed in the FlexiPage configuration
- Lightning page may have a component that tries to access OwnerId on an object that doesn't have ownership

**Fix Options**:
1. Open FlexiPage in Lightning App Builder and verify component configuration
2. Remove or fix the component that references `Record.OwnerId`
3. Check if the page is assigned to the correct object type

---

### ERROR 11: Invalid Cross Reference in ht_NIPR_API_Callout Permission Set
**Component**: `ht_NIPR_API_Callout`
**Error Message**: `invalid cross reference id`
**File Location**: `force-app/main/default/permissionsets/ht_NIPR_API_Callout.permissionset-meta.xml`

**Issue**:
- Permission set contains an invalid cross-reference ID
- This typically means the permission set references a metadata component that doesn't exist
- Could be:
  - Custom permission that doesn't exist
  - Apex class that doesn't exist
  - Field or object that doesn't exist
  - External credential or named credential that's not packaged

**Fix Options**:
1. Open the permission set XML file and look for ID references
2. Remove invalid references
3. Check for references to:
   - Custom permissions
   - Apex classes
   - Named credentials
   - External credentials

---

## Recommended Fix Order

Fix in this order to avoid cascading errors:

1. **First**: Fix individual permission sets (Errors 6, 7, 8, 11)
2. **Second**: Fix permission set group (Error 9) - will resolve once permission sets are fixed
3. **Third**: Fix test suite (Error 5)
4. **Fourth**: Fix layouts (Errors 1, 2)
5. **Fifth**: Fix layout translations (Errors 3, 4)
6. **Sixth**: Fix FlexiPage (Error 10)

---

## Files to Check and Fix

### Permission Sets
- `force-app/main/default/permissionsets/Contact_Full_Access.permissionset-meta.xml` (Error 6)
- `force-app/main/default/permissionsets/NIPR_View_NIPR_Data.permissionset-meta.xml` (Error 7)
- `force-app/main/default/permissionsets/ht_NIPR_Admin_Access.permissionset-meta.xml` (Error 8)
- `force-app/main/default/permissionsets/ht_NIPR_API_Callout.permissionset-meta.xml` (Error 11)

### Permission Set Groups
- `force-app/main/default/permissionsetgroups/ht_NIPR_Admin_User.permissionsetgroup-meta.xml` (Error 9)

### Test Suites
- `force-app/main/default/testSuites/NIPRTestSuite.testSuite-meta.xml` (Error 5)

### Layouts
- `force-app/main/default/layouts/ht_LineOfAuthority__c-NIPR Line Of Authority Layout.layout-meta.xml` (Errors 1, 3)
- `force-app/main/default/layouts/ht_ProducerAddress__c-NIPR Producer Address Layout.layout-meta.xml` (Errors 2, 4)

### FlexiPages
- `force-app/main/default/flexipages/NIPR_Line_of_Authority_Record_Page_Read_Only.flexipage-meta.xml` (Error 10)

---

## Next Steps

1. Review each error above
2. Decide on fix strategy for each (fix vs remove)
3. Make changes to metadata files
4. Test deployment to NIPR DEV org
5. Run tests to ensure nothing breaks
6. Retry package version creation

---

## Additional Notes

- Some errors are likely due to metadata pulled from a production org that references managed packages or org-specific customizations
- Permission sets and layouts often accumulate references to fields/objects that aren't actually needed
- Consider creating a "clean" version of permission sets with only NIPR-specific permissions
- Test suites should only reference test classes that exist in the package

