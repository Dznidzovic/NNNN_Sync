# NIPR Integration - Initial Setup Guide

**Version**: 1.0
**Last Updated**: 2026-01-20
**Package Name**: NIPR Integration
**Package Namespace**: `niprsync`

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Install NIPR Package](#step-1-install-nipr-package)
3. [Step 2: Assign Permission Set Groups](#step-2-assign-permission-set-groups)
4. [Step 3: Configure Page Layouts](#step-3-configure-page-layouts)
5. [Step 4: Configure Custom Metadata - Subscription Email](#step-4-configure-custom-metadata---subscription-email)
6. [Step 5: Share NIPR Reports Folder](#step-5-share-nipr-reports-folder)
7. [Step 6: Configure Named Credentials](#step-6-configure-named-credentials)
8. [Step 7: Test NIPR Integration](#step-7-test-nipr-integration)
9. [Step 8: Schedule Automated Jobs](#step-8-schedule-automated-jobs)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before beginning the installation, ensure you have:

- ✅ System Administrator access to the target Salesforce org
- ✅ NIPR API credentials (username and password)
  - **UAT Environment**: Credentials available in LastPass
  - **Production Environment**: Client-specific credentials obtained from NIPR
- ✅ Postman collection from the NIPR repository (for credential testing)
- ✅ Client approval for Production environment configuration

---

## Step 1: Install NIPR Package

### 1.1 Get Latest Package Version from Hipten

To get the latest package version, contact your Hipten representative or run the following command from the Hipten Dev Hub:

```bash
# Authenticate to Hipten Dev Hub
sf org login web --alias "HIPTEN DEV HUB" --set-default-dev-hub

# List all released package versions
sf package version list --packages "NIPR Integration" --target-dev-hub "HIPTEN DEV HUB"
```

Look for the latest version with `Released = true`. The current latest version is:

**Package Version**: 0.7.0-1
**Subscriber Package Version ID**: `04tPB000000At1dYAC`

### 1.2 Install Package in Client Org

Install the package in the client's Salesforce org:

```bash
# Authenticate to client org
sf org login web --alias "Client Org Name"

# Install the package
sf package install \
  --package "04tPB000000At1dYAC" \
  --target-org "Client Org Name" \
  --wait 20 \
  --upgrade-type Mixed
```

**Expected Output**: Installation will take 5-15 minutes. You will see `Install status: SUCCESS` when complete.

### 1.3 Alternative: Install via Salesforce UI

1. Log into the client org as System Administrator
2. Navigate to the package installation URL:
   ```
   https://login.salesforce.com/packaging/installPackage.apexp?p0=04tPB000000At1dYAC
   ```
3. Click **Install for All Users**
4. Click **Install**
5. Wait for installation to complete (you'll receive an email notification)

---

## Step 2: Assign Permission Set Groups

After package installation, assign the appropriate Permission Set Groups to users.

### 2.1 For Standard Users (Read-Only Access)

**Permission Set Group**: `NIPR Read Only User`
**API Name**: `niprsync__ht_NIPR_Read_Only_User`

**Included Permissions**:
- View NIPR data (Producers, Licenses, Appointments, etc.)
- API callout permissions for NIPR integration

**Assignment Steps**:
1. Navigate to **Setup** → **Users** → **Permission Set Groups**
2. Search for **NIPR Read Only User**
3. Click **Manage Assignments**
4. Click **Add Assignments**
5. Select all standard users who need read-only access to NIPR data
6. Click **Assign**

### 2.2 For Admin Users (Full Access)

**Permission Set Group**: `NIPR Admin User`
**API Name**: `niprsync__ht_NIPR_Admin_User`

**Included Permissions**:
- Full administrative access to NIPR objects
- SSN field visibility
- Manage Producer records
- API callout permissions
- Admin-level access to all NIPR features

**Assignment Steps**:
1. Navigate to **Setup** → **Users** → **Permission Set Groups**
2. Search for **NIPR Admin User**
3. Click **Manage Assignments**
4. Click **Add Assignments**
5. Select all admin users who need full NIPR access
6. Click **Assign**

---

## Step 3: Configure Page Layouts

**CRITICAL**: The NIPR package adds custom fields to standard objects (Account, Contact, Lead) but **cannot modify your org's page layouts**. You must manually add NIPR fields to your page layouts for users to see and edit them.

### 3.1 Account Page Layout Configuration

Add the following NIPR fields to your Account page layouts:

**NIPR Section** (create a new section on the layout):
- **NPN** (`niprsync__ht_NPN__c`) - National Producer Number
- **Last NIPR Sync** (`niprsync__ht_LastNIPRSync__c`) - Last sync timestamp
- **NIPR Sync Status** (`niprsync__ht_NIPRSyncStatus__c`) - Current sync status
- **Exclude Carrier Appointments** (`niprsync__ht_ExcludeCarrierAppointments__c`) - Checkbox to exclude large carrier data

**Steps**:
1. Navigate to **Setup** → **Object Manager** → **Account**
2. Click **Page Layouts**
3. Select the page layout(s) used by your users (e.g., "Account Layout")
4. Click **Edit**
5. Create a new section called **NIPR Information**
6. Drag and drop the NIPR fields listed above into the section
7. Click **Save**
8. Repeat for all Account page layouts in use

### 3.2 Contact Page Layout Configuration

Add the following NIPR fields to your Contact page layouts:

**NIPR Section**:
- **NPN** (`niprsync__ht_NPN__c`) - National Producer Number
- **First Name** (`niprsync__ht_FirstName__c`) - Producer first name from NIPR
- **Last Name** (`niprsync__ht_LastName__c`) - Producer last name from NIPR
- **Middle Name** (`niprsync__ht_MiddleName__c`) - Producer middle name from NIPR
- **Last NIPR Sync** (`niprsync__ht_LastNIPRSync__c`) - Last sync timestamp
- **NIPR Sync Status** (`niprsync__ht_NIPRSyncStatus__c`) - Current sync status

**Steps**:
1. Navigate to **Setup** → **Object Manager** → **Contact**
2. Click **Page Layouts**
3. Select the page layout(s) used by your users
4. Click **Edit**
5. Create a new section called **NIPR Information**
6. Drag and drop the NIPR fields listed above into the section
7. Click **Save**
8. Repeat for all Contact page layouts in use

### 3.3 Lead Page Layout Configuration

Add the following NIPR fields to your Lead page layouts:

**NIPR Section**:
- **NPN** (`niprsync__ht_NPN__c`) - National Producer Number
- **Last NIPR Sync** (`niprsync__ht_LastNIPRSync__c`) - Last sync timestamp
- **NIPR Sync Status** (`niprsync__ht_NIPRSyncStatus__c`) - Current sync status

**Steps**:
1. Navigate to **Setup** → **Object Manager** → **Lead**
2. Click **Page Layouts**
3. Select the page layout(s) used by your users
4. Click **Edit**
5. Create a new section called **NIPR Information**
6. Drag and drop the NIPR fields listed above into the section
7. Click **Save**
8. Repeat for all Lead page layouts in use

### 3.4 Field-Level Security

**IMPORTANT**: The Permission Set Groups assigned in Step 2 grant users **field-level access** to NIPR fields. However, users also need:

- **Object-level permissions** (Create/Read/Edit on Account, Contact, Lead) - typically granted by their Profile
- **Page layout visibility** (completed in steps 3.1-3.3 above)

If users cannot see or edit NIPR fields after adding them to layouts, verify:
1. ✅ Permission Set Groups are assigned (Step 2)
2. ✅ User's Profile grants Create/Edit access to Account, Contact, Lead objects
3. ✅ NIPR fields are added to the correct page layouts (steps 3.1-3.3)
4. ✅ User is assigned the correct page layout via their Profile or Record Type

---

## Step 4: Configure Custom Metadata - Subscription Email

Configure the email address where PDB Alert notifications should be sent.

### 3.1 Navigate to Custom Metadata Type

1. Navigate to **Setup** → **Custom Metadata Types**
2. Search for **NIPR Subscription Email**
3. Click **Manage Records**

### 3.2 Create or Edit Email Record

If a record already exists:
1. Click **Edit** next to the existing record
2. Update the **Email** field (`niprsync__ht_Email__c`) with the client's desired email address
3. Click **Save**

If no record exists:
1. Click **New**
2. Enter a **Label** (e.g., "Client PDB Alerts Email")
3. The **NIPR Subscription Email Name** field will auto-populate
4. In the **Email** field (`niprsync__ht_Email__c`), enter the client's email address for PDB alert notifications
5. Click **Save**

**Example**:
- **Label**: Client PDB Alerts Email
- **Email**: `nipr-alerts@clientdomain.com`

---

## Step 4: Share NIPR Reports Folder

The NIPR package includes a **NIPR Reports** folder with pre-built reports. Share this folder with users who need access.

### 4.1 Navigate to Reports

1. Go to the **Reports** tab
2. Search for the folder **NIPR Reports**
3. Click the dropdown arrow next to the folder name
4. Select **Share**

### 4.2 Share with Users or Roles

1. In the **Share with Users or Roles** section, click **Add**
2. Select the users, roles, or public groups that should have access
3. Choose the access level:
   - **Viewer**: Can view and run reports
   - **Editor**: Can view, run, and edit reports
4. Click **Share**

**Recommended**: Share with all users who have the **NIPR Read Only User** or **NIPR Admin User** permission set groups.

---

## Step 5: Configure Named Credentials

Configure the Named Credentials to connect to NIPR's APIs.

### 5.1 Test Credentials with Postman (CRITICAL STEP)

**⚠️ WARNING**: This step is billable by NIPR. Only test the PDB Alerts API endpoint.

Before configuring Named Credentials in Salesforce, test the credentials using the Postman collection found in the NIPR repository:

1. Open the Postman collection from the NIPR repository
2. Configure the NIPR credentials (username and password)
3. **ONLY** test the **PDB Alerts API** endpoint
4. Expected response: Error indicating no subscriptions (confirms credentials are valid)
5. **DO NOT** test other endpoints to avoid unnecessary charges

**For Production Environment**: Obtain explicit client approval before proceeding with credential configuration.

---

### 5.2 UAT Environment Configuration

**For UAT/Sandbox orgs**, use the beta NIPR environment credentials.

#### 5.2.1 Configure External Credential

1. Navigate to **Setup** → **Named Credentials**
2. Click on the **External Credentials** tab
3. Find **NIPR API** (`niprsync__NIPR_API`)
4. Click **Edit** (or click the dropdown arrow → **Edit**)
5. Scroll to **Principals** section
6. Click **Edit** next to **NIPR Basic Auth**
7. Enter the credentials:
   - **Username**: (Found in LastPass - UAT credentials)
   - **Password**: (Found in LastPass - UAT credentials)
8. Click **Save**

#### 5.2.2 Verify Named Credentials URLs (UAT)

For UAT environment, the Named Credentials should already have the correct `.beta` URLs:

**Named Credential: NIPR API**
- **Label**: NIPR API
- **API Name**: `niprsync__NIPR_API`
- **URL**: `https://pdb-alerts-industry-services.api.beta.nipr.com`
- ✅ No changes needed for UAT

**Named Credential: NIPR Entity Info API**
- **Label**: NIPR Entity Info API
- **API Name**: `niprsync__NIPR_EntityInfo_API`
- **URL**: `https://pdb-xml-reports.api.beta.nipr.com/pdb-xml-reports`
- ✅ No changes needed for UAT

---

### 5.3 Production Environment Configuration

**🚨 CRITICAL WARNING**: Production environment configuration should only be done:
- ✅ After successful UAT testing
- ✅ With explicit client approval
- ✅ With production credentials from the client
- ✅ After testing credentials via Postman

**⚠️ All NIPR API calls in production are billable. Configure with high caution.**

#### 5.3.1 Configure External Credential (Production)

1. Navigate to **Setup** → **Named Credentials**
2. Click on the **External Credentials** tab
3. Find **NIPR API** (`niprsync__NIPR_API`)
4. Click **Edit**
5. Scroll to **Principals** section
6. Click **Edit** next to **NIPR Basic Auth**
7. Enter the **production** credentials:
   - **Username**: (Client-specific production username from NIPR)
   - **Password**: (Client-specific production password from NIPR)
8. Click **Save**

#### 5.3.2 Update Named Credential URLs (Production)

**⚠️ CRITICAL**: Remove `.beta` from both Named Credential URLs.

**Step 1: Update NIPR API Named Credential**

1. Navigate to **Setup** → **Named Credentials**
2. Click on the **Named Credentials** tab
3. Find **NIPR API** (`niprsync__NIPR_API`)
4. Click **Edit**
5. In the **URL** field, change:
   - **FROM**: `https://pdb-alerts-industry-services.api.beta.nipr.com`
   - **TO**: `https://pdb-alerts-industry-services.api.nipr.com`
6. Click **Save**

**Step 2: Update NIPR Entity Info API Named Credential**

1. Find **NIPR Entity Info API** (`niprsync__NIPR_EntityInfo_API`)
2. Click **Edit**
3. In the **URL** field, change:
   - **FROM**: `https://pdb-xml-reports.api.beta.nipr.com/pdb-xml-reports`
   - **TO**: `https://pdb-xml-reports.api.nipr.com/pdb-xml-reports`
4. Click **Save**

---

## Step 6: Test NIPR Integration

Test the NIPR integration by manually creating a Producer record.

### 6.1 Create Test Producer Record

**⚠️ Use a valid but failing NPN for testing purposes.**

**Test NPN**: `1234567890` (This will fail the integration, which is expected for testing)

**Steps**:

1. Log in as a **standard user** (any user with the **NIPR Read Only User** or **NIPR Admin User** permission set group)
2. Navigate to the **Producers** tab
3. Click **New**
4. Fill in the following fields:
   - **Producer Name**: Test Producer
   - **NPN** (`niprsync__ht_NPN__c`): `1234567890`
   - **First Name** (`niprsync__ht_FirstName__c`): Test
   - **Last Name** (`niprsync__ht_LastName__c`): Producer
5. Click **Save**

### 6.2 Verify Integration Attempt

After saving, the integration will attempt to retrieve data from NIPR. Since this is a test NPN, the integration should fail (which confirms the integration is working).

**Verification Steps**:

1. Navigate to the **Logger** tab (`niprsync__ht_Logger__c`)
2. Search for recent logs related to the NPN `1234567890`
3. You should see a log entry indicating the NIPR API was called
4. The log should show an error (expected for a test NPN)

**Expected Log Entry**:
- **Log Level**: ERROR or WARNING
- **Message**: Contains reference to NPN `1234567890` and NIPR API call
- **Class Name**: Should reference NIPR callout classes

If you see log entries, the integration is working correctly.

---

## Step 7: Schedule Automated Jobs

Schedule the automated jobs for PDB Alerts and log cleanup.

### 7.1 Schedule PDB Alerts Daily Report

This job retrieves daily PDB alerts from NIPR and updates Producer records.

**Schedule Timing**: Daily at 11 AM Central Time

**Steps**:

1. Navigate to **Setup** → **Apex Classes**
2. Search for **PDBAlertReportSchedulable** (`niprsync__PDBAlertReportSchedulable`)
3. Open the **Developer Console** (Setup → Developer Console)
4. Click **Debug** → **Open Execute Anonymous Window**
5. Paste the following code:
   ```apex
   Id jobId = niprsync.PDBAlertReportSchedulable.scheduleDaily();
   System.debug('Scheduled Job ID: ' + jobId);
   ```
6. Click **Execute**
7. Check the debug log to verify the job was scheduled
8. Navigate to **Setup** → **Scheduled Jobs** to confirm the job appears in the list

**Job Name**: `NIPR PDB Alerts Daily Report - 11 AM CT`

### 7.2 Schedule Log Deletion Job

This job automatically deletes old Logger records to keep the org clean.

**Schedule Timing**: Twice monthly (1st and 15th of each month at 2:00 AM)

**Steps**:

1. Open the **Developer Console**
2. Click **Debug** → **Open Execute Anonymous Window**
3. Paste the following code:
   ```apex
   Id jobId = niprsync.DeleteLogsScheduleable.scheduleTwiceMonthly();
   System.debug('Scheduled Job ID: ' + jobId);
   ```
4. Click **Execute**
5. Check the debug log to verify the job was scheduled
6. Navigate to **Setup** → **Scheduled Jobs** to confirm the job appears in the list

**Job Name**: `DeleteLogsScheduleable_1stAnd15th`

### 7.3 Verify Scheduled Jobs

1. Navigate to **Setup** → **Scheduled Jobs**
2. Confirm both jobs appear in the list:
   - ✅ `NIPR PDB Alerts Daily Report - 11 AM CT`
   - ✅ `DeleteLogsScheduleable_1stAnd15th`
3. Verify the **Next Scheduled Run** dates are correct

---

## Troubleshooting

### Issue: Package Installation Fails

**Symptoms**: Package installation fails with error message

**Solutions**:
- Ensure you have System Administrator access
- Check that the org has sufficient storage space
- Verify the package version ID is correct
- Try installing with `--upgrade-type Mixed` flag

### Issue: Named Credential Authentication Fails

**Symptoms**: NIPR API calls fail with authentication errors

**Solutions**:
1. Verify credentials in LastPass (UAT) or from client (Production)
2. Test credentials using Postman before configuring in Salesforce
3. Ensure the correct environment URLs are configured (beta vs production)
4. Check that the External Credential Principal is configured correctly

### Issue: Users Cannot See NIPR Data

**Symptoms**: Users get "Insufficient Privileges" errors

**Solutions**:
1. Verify the user has been assigned the appropriate Permission Set Group
2. Check that the Permission Set Group is Active
3. Ensure the user's profile has access to the NIPR tabs
4. Log out and log back in to refresh permissions

### Issue: PDB Alerts Not Received

**Symptoms**: Email notifications for PDB alerts are not being received

**Solutions**:
1. Verify the email address in the **NIPR Subscription Email** custom metadata type
2. Check the scheduled job is active (**Setup** → **Scheduled Jobs**)
3. Review **Logger** records for any errors during PDB alert processing
4. Verify NIPR subscriptions exist and are active

### Issue: Logs Not Being Deleted

**Symptoms**: Old Logger records are not being deleted

**Solutions**:
1. Verify the **DeleteLogsScheduleable** job is scheduled (**Setup** → **Scheduled Jobs**)
2. Check the job is not in a failed state
3. Review **Logger** records for any errors during log deletion
4. Manually run the job from Developer Console to test:
   ```apex
   Database.executeBatch(new niprsync.DeleteLogsBatchable(), 2000);
   ```

---

## Support

For technical support or questions:

- **Package Issues**: Contact Hipten Support at support@hipten.com
- **NIPR API Issues**: Contact NIPR Support
- **Installation Questions**: Contact your Salesforce Administrator

---

**Document Version**: 1.0
**Last Updated**: 2026-01-20
**Maintained By**: Hipten Development Team
