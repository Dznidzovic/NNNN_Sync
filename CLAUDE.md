# CLAUDE.md - NIPR

> **Global rules from `~/.claude/CLAUDE.md` always apply.**
> This file contains project-specific context for NIPR.

---

## ⚠️ CRITICAL: CLAUDE.md MUST BE KEPT UP TO DATE

**Claude AI is MANDATORY to maintain this document after EVERY change to the codebase.**

- After any code change, update, or new feature, Claude MUST review and update this CLAUDE.md file
- Keep all workflow instructions current and accurate
- Update any changed commands, file paths, or procedures
- Add new patterns, learnings, or best practices discovered during development
- This document is the source of truth for development - it must NEVER become outdated

---

## 🚨 MANDATORY DEVELOPMENT WORKFLOW - READ THIS FIRST! 🚨

**ALL NIPR development MUST follow this workflow:**

1. ✅ **DEVELOP IN "NIPR DEV" ORG ONLY**
   - Make ALL code changes in the "NIPR DEV" org (hiptenadmins@hipten.com.d4c_nipr)
   - **NEVER develop locally or in scratch orgs**
   - Scratch orgs are ONLY for testing package installations

2. ✅ **DEPLOY TO NIPR DEV FIRST**
   - Deploy all changes to "NIPR DEV" org
   - Test thoroughly in "NIPR DEV" org
   - Pull changes back to local repository

3. ✅ **ONLY THEN create package versions**
   - After changes are tested in "NIPR DEV", pull metadata locally
   - Create package version from local repository
   - Promote to Released

4. ✅ **TEST IN SCRATCH ORG**
   - Install/upgrade package in scratch org
   - Verify package installation works correctly
   - Test as a subscriber would experience it

5. ✅ **UPDATE RELEASE NOTES** ⚠️ MANDATORY
   - After creating and promoting package version, ALWAYS update release notes
   - File: `NIPR_Release_Notes_v{version}.md` and `.docx`
   - Include latest package version ID in the release notes
   - Claude will automatically remind you if release notes are not updated

**Commands for NIPR DEV workflow:**
```bash
# 1. Deploy to NIPR DEV
sf project deploy start --source-dir force-app --target-org "NIPR DEV"

# 2. Test in NIPR DEV
sf org open --target-org "NIPR DEV"

# 3. Pull changes back
sf project retrieve start --source-dir force-app --target-org "NIPR DEV"

# 4. Create package version (with code coverage)
sf package version create --package "NIPR" --installation-key-bypass --code-coverage --wait 20 --target-dev-hub "HIPTEN DEV HUB"

# 5. Promote to Released
sf package version promote --package "<version-id>" --target-dev-hub "HIPTEN DEV HUB" --no-prompt

# 6. Test in scratch org
sf package install --package "<version-id>" --target-org "NIPR Package Test" --wait 20
```

---

## Repository Overview
This is a Salesforce DX project that integrates with the National Insurance Entity Registry (NIPR) to manage insurance agent licensing and carrier appointments. The codebase follows enterprise architectural patterns with clear separation of concerns across service, repository, and controller layers.

## Key Commands

### Testing
```bash
# Run all Apex tests with coverage
sf apex run test --test-level RunLocalTests --code-coverage --result-format human

# Run specific test suite (recommended - includes all NIPR tests)
sf apex run test --test-level RunSpecifiedTests --suite-names NIPRTestSuite --code-coverage

# Run a single test class
sf apex run test --class-names ProcessPDBAlertReportService_Test --result-format human --wait 10

# Run multiple test classes
sf apex run test --class-names LOAInsProdMappingTriggerHandler_Test --class-names LineOfAuthorityTriggerHandler_Test --result-format human --wait 10

# Run LWC tests (minimal LWC in this project)
npm test
```

### Code Quality
```bash
# Lint and format code before commits
npm run lint          # ESLint for LWC
npm run prettier      # Format all files
npm run prettier:verify  # Check formatting without changes
```

### Deployment
```bash
# Deploy all source to org
sf project deploy start --source-dir force-app/main/default --wait 10

# Deploy specific class
sf project deploy start --source-dir force-app/main/default/classes/Service/ProcessPDBAlertReportService.cls --wait 5

# Deploy multiple files
sf project deploy start --source-dir force-app/main/default/classes/TriggerHandler/LOAInsuranceProductMappingTriggerHandler.cls --source-dir force-app/main/default/classes/Test/LOAInsProdMappingTriggerHandler_Test.cls --wait 5
```

### Data Operations
```bash
# Query data
sf data query -q "SELECT Id, Name, d4c_NPN__c FROM d4c_Entity__c LIMIT 10"

# Delete a record
sf data delete record -s d4c_LOA_Insurance_Product_Mapping__c -i <recordId>

# Run anonymous Apex
sf apex run -f script.apex
```

## Architecture Patterns

### Layer Structure
The codebase follows a strict layered architecture:

1. **Controllers/** - REST API endpoints that handle HTTP requests
2. **Service/** - Business logic layer containing core functionality
3. **Repository/** - Data access layer with Selector classes for SOQL queries
4. **Callout/** - External API integration classes for NIPR SOAP services
5. **TriggerHandler/** - Trigger framework with dispatcher pattern
6. **DTO/** - Data Transfer Objects for API serialization/deserialization
7. **Test/** - Test classes with extensive mocking framework

### Core Architectural Decisions

**Trigger Framework**: All triggers use TriggerDispatcher with BaseTriggerHandler. Triggers delegate to handler classes that extend BaseTriggerHandler. Test-visible flags (`triggerDisabled`) allow trigger simulation in tests without DML.
- **Cross-context data**: Use STATIC variables (not instance) to pass data between trigger contexts (e.g., beforeDelete → afterDelete) since Salesforce creates a new handler instance for each context.

**Repository Pattern**: All SOQL queries are centralized in Selector classes (26 total). This enables easy mocking in tests and query reuse. Selectors use test-visible properties for mock injection.

**Service Layer**: Services contain pure business logic with no UI or data access code. They use dependency injection via Repository pattern for testability.

**Async Processing**:
- Queueable jobs for API callouts with retry logic
- Batch classes with size=1 for entity isolation during processing
- Schedulable jobs for daily PDB Alert processing
- **Important**: When chaining queueables, set `AsyncOptions.MaximumQueueableStackDepth` on the INITIAL enqueue only (default is 5, often need 100). Chained jobs inherit this limit.

**External ID Strategy**: All NIPR objects use external IDs (e.g., d4c_NPN__c) for upserts. This enables idempotent operations and simplifies data synchronization.

---

## 🔄 Data Model Refactoring (Phase 1 - Updated 2026-02-09)

**Status**: Planning Complete | Implementation Pending

### ⚠️ CRITICAL: Repository-Only Refactoring Workflow

**ALL CHANGES HAPPEN EXCLUSIVELY IN THE REPOSITORY - NOT IN SALESFORCE ORG**

**Workflow**:
1. ✅ Make ALL metadata/code changes in local repository
2. ✅ Update all references as we go (step-by-step)
3. ✅ Test locally that all files are consistent
4. ✅ Commit changes incrementally to git
5. ✅ ONLY THEN deploy everything to fresh new org

**Deployment Strategy**:
- Do NOT deploy to NIPR DEV org during refactoring
- Refactor the entire repo first
- Deploy ALL changes at once to a fresh org when complete
- This ensures clean state without dealing with org-level constraints

**Step-by-Step Execution**:
- User directs each change
- Claude performs ONLY what user requests
- After each critical change, we update all references together
- This prevents forgetting to update related files

### Change 1: Many-to-Many Relationships

#### Current State (Before Refactoring)
- `d4c_ProducerAddress__c` - Master-Detail to Entity (non-reparentable)
- `d4c_ProducerCommunication__c` - Master-Detail to Entity (reparentable)
- Each address/communication belongs to exactly ONE entity

#### Target State (After Refactoring)
- `d4c_ProducerAddress__c` - **Standalone object** (no parent relationship)
- `d4c_ProducerCommunication__c` - **Standalone object** (no parent relationship)

**NEW Junction Objects** (2):
1. **`d4c_Entity_Address_Junction__c`**
   - Master-Detail to `d4c_Entity__c`
   - Master-Detail to `d4c_ProducerAddress__c`
   - External ID: `d4c_UniqueIdentifier__c` (Entity NPN + Address UniqueIdentifier)
   - Enables many-to-many: One address shared by multiple entitys

2. **`d4c_Entity_Communication_Junction__c`**
   - Master-Detail to `d4c_Entity__c`
   - Master-Detail to `d4c_ProducerCommunication__c`
   - External ID: `d4c_UniqueIdentifier__c` (Entity NPN + Communication UniqueIdentifier)
   - Enables many-to-many: One communication shared by multiple entitys

**Benefits**:
- ✅ Reduces database clutter (no duplicate addresses/communications)
- ✅ Natural deduplication via External IDs
- ✅ **Future-ready**: Same pattern will be used for Carrier → Address and Carrier → Communication when carrier sync is added

**⚠️ Note**: Carrier junctions will be implemented in future phase when carrier sync code is added.

---

### Change 2: Remove LOA Mapping Objects

The following 4 objects are being **completely removed** from the product:

#### Objects to DELETE
1. ❌ `d4c_LOA_Insurance_Product_Mapping__c` - LOA mapping configuration
2. ❌ `d4c_Insurance_Product_LOA_Mapping__c` - Junction (LOA mapping to products)
3. ❌ `d4c_Insurance_Product__c` - Insurance product reference data
4. ❌ `d4c_License_Insurance_Product__c` - Junction (license to products)

#### Objects to MODIFY
**`d4c_LineOfAuthority__c`** - KEEP this object (it's NIPR data)
- Remove field: `d4c_LOAMapping__c` (Lookup to deleted mapping object)
- Remove field: `d4c_IsProductMatched__c` (Boolean)
- All other fields remain

**`d4c_License__c`** - Remove calculated fields:
- Remove: `d4c_NumberOfProductMatchedLOAs__c`
- Remove: `d4c_NumberOfProductNotMatchedLOAs__c`
- Remove: `d4c_AllLOAsMatchedToProduct__c`
- Remove: `d4c_License_Products__c` (LongTextArea)

#### Permission Sets to Update
- **NIPR_View_NIPR_Data** - Remove read access to 4 deleted objects
- **d4c_NIPR_Admin_Access** - Remove full CRUD access to 4 deleted objects

**Reason for Removal**: Simplifying the product by removing LOA-to-product mapping feature entirely.

---

### Change 3: Consolidate Custom Metadata Types

#### Current State (5 metadata types)
1. `d4c_NIPRLogger__mdt` - Debug logging control
2. `d4c_NIPRTestXMLResponse__mdt` - Test XML for debugging
3. `d4c_NIPR_Subsciption_NPN_Count__mdt` - Max NPNs per subscription
4. `d4c_NIPR_Subscription_Email__mdt` - Subscription email
5. `d4c_Trigger_Dispatcher_Settings__mdt` - Trigger enable/disable (KEEP)

#### Target State (2 metadata types)

**NEW**: `d4c_NIPR_Sync_Settings__mdt` - Single consolidated settings object

Fields:
- `d4c_EnableDebugging__c` (Checkbox) - From NIPRLogger
- `d4c_MaxNPNCountPerSubscription__c` (Number) - From NIPR_Subsciption_NPN_Count
- `d4c_SubscriptionEmail__c` (Email) - From NIPR_Subscription_Email
- `d4c_TestXMLActive__c` (Checkbox) - From NIPRTestXMLResponse
- `d4c_TestXMLData__c` (LongTextArea) - From NIPRTestXMLResponse

**KEEP**: `d4c_Trigger_Dispatcher_Settings__mdt` - Separate (framework-level config)

#### Metadata Types to DELETE
- ❌ `d4c_NIPRLogger__mdt`
- ❌ `d4c_NIPRTestXMLResponse__mdt`
- ❌ `d4c_NIPR_Subsciption_NPN_Count__mdt`
- ❌ `d4c_NIPR_Subscription_Email__mdt`

**Benefits**:
- ✅ Single metadata query instead of 4 separate queries
- ✅ Improved performance
- ✅ Easier configuration management
- ✅ Cleaner UI/UX for admins

---

### Change 4: Object Renaming (Phase 2.5)

**Purpose**: Rename core objects for better clarity and flexibility

**Objects to Rename**:
1. **Entity → Entity**: `d4c_Entity__c` → `d4c_Entity__c` (Label: "NIPR Entity")
2. **ProducerAddress → NIPR_Address**: `d4c_ProducerAddress__c` → `d4c_NIPR_Address__c` (Label: "NIPR Address")
3. **ProducerCommunication → NIPR_Communication**: `d4c_ProducerCommunication__c` → `d4c_NIPR_Communication__c` (Label: "NIPR Communication")
4. **Logger → Log**: `d4c_Logger__c` → `d4c_Log__c` (Label: "NIPR Log")

**Reason**: "Entity" is more flexible for future expansion (carriers, MGAs), and "Log" is clearer than "Logger"

**Impact**:
- 72+ Apex classes need updates
- All layouts, permission sets, tabs, translations
- Test classes
- Triggers

---

### Change 5: Named Credentials Renaming

**Purpose**: Update named credential labels for better clarity

**Named Credential 1**: NIPR Entity Info API
- **API Name**: `NIPR_EntityInfo_API` (NO CHANGE)
- **Label**: "NIPR Entity Info API" ✅ (already correct)
- **External Credential**: `NIPR_API` (NO CHANGE)
- **Used in**: `RetrieveEntityInfoApiData.cls`

**Named Credential 2**: NIPR PDB Alerts API
- **API Name**: `NIPR_API` (NO CHANGE)
- **Current Label**: "NIPR API" ❌
- **New Label**: "NIPR PDB Alerts API" ✅
- **External Credential**: `NIPR_API` (NO CHANGE)
- **Used in**: `CreateSubscription.cls`, `AddNPNToSubscription.cls`, `RetrievePDBSpecificReportData.cls`, `RemoveNPNFromSubscription.cls`

**Important**: Only the **label** changes, not the API name. **No code changes required** since code references the API name which remains `NIPR_API`.

**File to Update**:
- `force-app/main/default/namedCredentials/NIPR_API.namedCredential-meta.xml`
  - Change `<label>` from "NIPR API" to "NIPR PDB Alerts API"

---

### Implementation Status

**Phase 1 - Metadata Changes**:
- [ ] Create junction objects (Entity → Address, Entity → Communication)
- [ ] Remove Master-Detail fields from ProducerAddress/Communication
- [ ] Delete 4 LOA mapping objects
- [ ] Remove fields from LineOfAuthority and License
- [ ] Update 2 permission sets
- [ ] Create consolidated NIPR_Sync_Settings__mdt
- [ ] Delete 4 old metadata types
- [ ] Update layouts and flexipages

**Phase 2 - Naming Conventions** (Next):
- Rename objects to follow consistent conventions
- Rename fields to follow consistent conventions
- Update all metadata references

**Phase 3 - Code Refactoring** (Future):
- Remove code referencing deleted LOA mapping objects
- Update code to use new junction objects
- Update MetadataTypeSelector for consolidated settings
- Update service classes
- Update test classes

**Detailed plan**: See `/Users/stefannidzovic/.claude/plans/logical-mapping-tarjan.md`

---

### Key Business Flows

**Entity Import Flow**:
1. ProcessPDBAlertReportService orchestrates the process
2. RetrieveEntityInfoAPIDetails fetches entity data from NIPR
3. Data is mapped via DTOs and upserted using external IDs
4. Related objects (licenses, appointments) are processed in sequence

**PDB Alert Processing**:
1. ScheduledGetPDBAlert runs daily at 2 AM
2. Fetches alerts for all active subscriptions
3. QueueGetPDBSpecificReportData processes each alert
4. Updates are applied to existing entity records

**Subscription Management**:
1. Auto-subscription for new entitys without subscriptions
2. 500 entity limit per subscription (NIPR constraint)
3. Large entitys get dedicated subscriptions
4. Reassignment logic for capacity management

**LOA Mapping Flow** (Line of Authority → Insurance Product matching):
1. LOA records are matched to `d4c_LOA_Insurance_Product_Mapping__c` by state/code/description via `LOAProductMappingService.matchLoasToMappings()`
2. `d4c_IsProductMatched__c` indicates if LOA has a valid mapping
3. When an LOA Mapping is deleted, `LOAInsuranceProductMappingTriggerHandler.afterDelete` clears the lookup on related LOAs, triggering re-matching which sets `d4c_IsProductMatched__c = false`
4. Lookup fields with `SetNull` delete constraint do NOT fire triggers - manual cleanup required

### Testing Strategy

**Mock-Based Testing**: Uses HttpSoapMultiMockFactory for API mocking. Test classes create realistic data via JSON deserialization without DML.

**Test Data Creation**: TestDataFactory provides builder patterns for all objects. MockHelper creates complex object graphs from JSON.

**Coverage Requirements**: Maintain minimum 75% coverage for all business logic classes. Current org-wide coverage is 88%.

## Important Business Rules

1. **Subscription Limits**: Maximum 500 entitys per NIPR subscription
2. **Batch Processing**: Process entitys individually (batch size=1) to isolate errors
3. **Retry Logic**: Failed API calls retry up to 3 times with exponential backoff
4. **License States**: Only active licenses are synchronized
5. **Carrier Appointments**: Can be excluded via d4c_ExcludeCarrierAppointments__c flag
6. **NPN Field**: Entity NPN (`d4c_NPN__c`) has max length of 10 characters
7. **LastNIPRSync**: `d4c_LastNIPRSync__c` field tracks last successful sync - ONLY set AFTER successful HTTP request, never before

## Common Development Tasks

### Adding a New NIPR API Integration
1. Create callout class in Callout/ folder
2. Add DTO classes for request/response in DTO/
3. Implement service logic in Service/
4. Add mock responses in Test/HttpSoapMultiMockFactory
5. Write comprehensive test class with all scenarios

### Adding a New Trigger
1. Create trigger file using minimal logic pattern
2. Create handler class extending BaseTriggerHandler
3. Register handler in TriggerDispatcher.cls
4. Write test class covering all trigger contexts

### Modifying SOQL Queries
1. Locate the appropriate Selector class in Repository/
2. Modify the query method (maintain test-visible properties)
3. Update any mock implementations in test classes
4. Run affected test classes to ensure compatibility

---

## Development Environment Setup Guide

This section provides step-by-step instructions for team members to set up their development environment for working with the NIPR managed package.

### Prerequisites

1. **Salesforce CLI** installed and updated
   ```bash
   npm install -g @salesforce/cli
   sf version --verbose
   ```

2. **Node.js and npm** (for code quality tools)
   ```bash
   node --version  # Should be v18 or higher
   npm --version
   ```

3. **Git** configured with your credentials
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@hipten.com"
   ```

4. **VS Code** with Salesforce Extensions installed (recommended)
   - Salesforce Extension Pack
   - Salesforce Package Manager (for 2GP package development)

---

### Understanding the Development Orgs

#### 1. HIPTEN DEV HUB (Production Org)
- **Purpose**: Central hub for managing namespaces, packages, and scratch orgs
- **Org Type**: Production org with Dev Hub enabled
- **Namespace**: `niprsync` (registered and linked to this Dev Hub)
- **Username**: `stefan.nidzovic@hipten.com` (or your assigned admin)
- **What it does**:
  - Stores package definitions and versions
  - Creates and manages scratch orgs
  - Manages namespace registration
  - Tracks package subscribers

#### 2. NIPR DEV (Namespaced Developer Org)
- **Purpose**: Primary development and testing org with namespace enabled
- **Org Type**: Developer Edition org with `niprsync` namespace
- **Username**: `hiptenadmins@hipten.com.d4c_nipr`
- **What it does**:
  - All metadata automatically gets `niprsync__` prefix
  - Used for developing and testing package features
  - Can create and pull metadata with namespace
  - Tests run with namespace enabled

#### 3. Scratch Orgs (Temporary Developer Orgs)
- **Purpose**: Short-lived, disposable orgs for isolated development
- **Org Type**: Scratch org (lasts 1-30 days)
- **Created from**: `config/project-scratch-def.json`
- **What they do**:
  - Clean slate for testing package installation
  - Simulate customer org environment
  - Test package upgrades and installations
  - Auto-deleted after expiration

---

### Required Permissions in Dev Hub

To work with packages and scratch orgs, your Dev Hub user needs specific permissions.

#### Option 1: Use the Standard Developer Permission Set
If you have a Developer license, assign the built-in **Developer** permission set:

1. Log into **HIPTEN DEV HUB** org
2. Go to **Setup** → **Users** → **Permission Sets**
3. Click **Developer** permission set
4. Click **Manage Assignments**
5. Add your user

#### Option 2: Create Custom Permission Set (Recommended)
We created the **Hipten_Build_Managed_Packages** permission set with these permissions:

**Object Settings:**
- **Scratch Org Infos**: Read, Create, Edit, Delete
- **Active Scratch Orgs**: Read, Edit, Delete
- **Namespace Registries**: Read

**System Permissions:**
- ✅ Create and Update Second-Generation Packages

**To assign it to yourself:**
1. Log into **HIPTEN DEV HUB** org
2. Go to **Setup** → **Users** → **Permission Sets**
3. Click **Hipten_Build_Managed_Packages**
4. Click **Manage Assignments**
5. Click **Add Assignments**
6. Select your user and click **Assign**

---

### Initial Setup Steps

#### Step 1: Authenticate to Dev Hub
```bash
# Login to Dev Hub (opens browser)
sf org login web --alias "HIPTEN DEV HUB" --set-default-dev-hub

# Verify authentication
sf org list --all
# You should see 🌳 icon next to HIPTEN DEV HUB
```

#### Step 2: Authenticate to NIPR DEV Org
```bash
# Login to namespaced dev org (opens browser)
sf org login web --alias "NIPR DEV" --set-default

# Verify authentication
sf org display --target-org "NIPR DEV"
```

#### Step 3: Clone the Repository
```bash
git clone <repo-url>
cd NIPR
```

#### Step 4: Install Dependencies
```bash
npm install
```

#### Step 5: Verify Package Configuration
```bash
# List packages (should show NIPR package)
sf package list --target-dev-hub "HIPTEN DEV HUB"

# View package details
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB"
```

---

### Working with Scratch Orgs

Scratch orgs are temporary, isolated environments for development and testing.

#### Creating a Scratch Org
```bash
# Create scratch org with namespace (lasts 30 days by default)
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias nipr-scratch \
  --duration-days 30 \
  --set-default \
  --target-dev-hub "HIPTEN DEV HUB"

# Deploy your code to scratch org
sf project deploy start --source-dir force-app

# Open the scratch org
sf org open --target-org nipr-scratch
```

#### Key Points About Scratch Orgs:
- They have the `niprsync` namespace enabled (defined in `config/project-scratch-def.json`)
- All custom metadata gets the namespace prefix automatically
- Your Apex code doesn't need to reference the namespace (it runs inside the namespace)
- Perfect for testing package installation scenarios
- Auto-deleted after expiration (default 7 days, max 30 days)

#### Managing Scratch Orgs
```bash
# List all scratch orgs
sf org list --all

# Delete a scratch org
sf org delete scratch --target-org nipr-scratch --no-prompt

# Get details about active scratch org
sf org display --target-org nipr-scratch
```

---

### Development Workflow

#### Workflow 1: Develop in NIPR DEV Org
**Best for**: Feature development, testing with real data

```bash
# 1. Pull latest code from repo
git pull origin main

# 2. Deploy to NIPR DEV org
sf project deploy start --source-dir force-app --target-org "NIPR DEV"

# 3. Develop in the org (create classes, fields, etc.)
sf org open --target-org "NIPR DEV"

# 4. Pull changes back to local
sf project retrieve start --source-dir force-app --target-org "NIPR DEV"

# 5. Run tests
sf apex run test --test-level RunLocalTests --code-coverage --target-org "NIPR DEV"

# 6. Commit changes
git add .
git commit -m "Add new feature"
git push origin feature-branch
```

#### Workflow 2: Develop in Scratch Org
**Best for**: Isolated feature development, testing clean installations

```bash
# 1. Create scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias my-feature

# 2. Deploy code
sf project deploy start --source-dir force-app --target-org my-feature

# 3. Develop and test
sf org open --target-org my-feature

# 4. Pull changes
sf project retrieve start --source-dir force-app --target-org my-feature

# 5. Run tests
sf apex run test --test-level RunLocalTests --target-org my-feature

# 6. When done, delete scratch org
sf org delete scratch --target-org my-feature --no-prompt
```

---

### Understanding Namespace Behavior

The `niprsync` namespace affects how metadata is referenced:

#### In Your Code (Inside Namespace)
```apex
// ✅ CORRECT - No namespace prefix needed in your code
d4c_Entity__c entity = new d4c_Entity__c();
entity.d4c_NPN__c = '12345';
Account acc = new Account();
acc.d4c_NPN__c = '12345'; // Custom field on standard object
```

#### In the Org (External API View)
- Custom objects: `d4c_Entity__c` → `niprsync__d4c_Entity__c`
- Fields on standard objects: `Account.d4c_NPN__c` → `Account.niprsync__d4c_NPN__c`
- Fields on custom objects: `d4c_Entity__c.d4c_NPN__c` → stays as `d4c_NPN__c` (within namespace)

#### In Source Files
```
force-app/main/default/
├── objects/
│   └── d4c_Entity__c/  ← No namespace prefix in folder name
│       └── fields/
│           └── d4c_NPN__c.field-meta.xml  ← No namespace in filename
```

**Key Point**: The namespace is implicit in your source code and file structure. Salesforce applies the `niprsync__` prefix automatically at runtime.

---

### Package Management

#### Creating a Package Version
```bash
# Create a new package version (this takes 5-15 minutes)
sf package version create \
  --package "NIPR" \
  --installation-key-bypass \
  --wait 20 \
  --target-dev-hub "HIPTEN DEV HUB"

# This returns a package version ID like: 04tXXXXXXXXXXXXXXX
```

#### Promoting a Package Version
```bash
# Promote to make it generally available
sf package version promote \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-dev-hub "HIPTEN DEV HUB"
```

#### Installing a Package Version
```bash
# Install in a test org or customer org
sf package install \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-org <org-alias> \
  --wait 20
```

#### Viewing Package Information
```bash
# List all packages in your Dev Hub
sf package list --target-dev-hub "HIPTEN DEV HUB"

# List all package versions for a specific package
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB"

# List ALL package versions (all packages)
sf package version list --target-dev-hub "HIPTEN DEV HUB"

# Get detailed report of a specific package version
sf package version report --package "04tXXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB"

# List versions with specific filters
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB" --concise
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB" --released-only
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB" --order-by CreatedDate

# Get package details by alias or ID
sf package version report --package "NIPR@1.0.0-1" --target-dev-hub "HIPTEN DEV HUB"

# List package version creation requests (to see in-progress builds)
sf package version create list --target-dev-hub "HIPTEN DEV HUB"

# Get status of a specific package version creation request
sf package version create report --package-create-request-id "08cXXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB"
```

#### Package Version Aliases
Package versions can be referenced by:
- **Package Version ID**: `04tXXXXXXXXXXXXXXX` (full ID)
- **Package Alias + Version**: `NIPR@1.0.0-1` (from sfdx-project.json)
- **Subscriber Package Version ID**: `04tXXXXXXXXXXXXXXX` (for installation)

Example `sfdx-project.json` with version aliases:
```json
{
  "packageAliases": {
    "NIPR": "0HoPB00000001NV0AY",
    "NIPR@1.0.0-1": "04tXXXXXXXXXXXXXXX",
    "NIPR@1.0.0-2": "04tYYYYYYYYYYYYYYY"
  }
}
```

#### Where to Manage Packages in UI
1. Log into **HIPTEN DEV HUB** org
2. Go to **Setup** → Search **"Packaging"**
3. Click **Packages** to see all packages
4. Click **Package Versions** to see all versions
5. View details, promote versions, manage subscribers

---

### Troubleshooting

#### "Not a Dev Hub" Error
**Problem**: CLI says org is not a Dev Hub
**Solution**:
1. Verify your user has the **Hipten_Build_Managed_Packages** permission set
2. Logout and login again to refresh credentials:
   ```bash
   sf org logout --target-org "HIPTEN DEV HUB" --no-prompt
   sf org login web --alias "HIPTEN DEV HUB" --set-default-dev-hub
   ```

#### Test Failures with Namespace
**Problem**: Tests fail with "field not found" errors after namespace enabled
**Solution**: MockHelper uses direct field assignment (not JSON deserialization) to handle namespaced fields correctly. Follow existing mock patterns in test classes.

#### Cannot Create Scratch Org
**Problem**: "This org doesn't have access to creating scratch orgs"
**Solution**: Ensure `config/project-scratch-def.json` has `"namespace": "niprsync"` and your Dev Hub user has proper permissions.

#### Metadata Retrieve Fails
**Problem**: Cannot retrieve metadata from org
**Solution**: Verify the org has the namespace configured and you're authenticated correctly.

---

### Package Listing & Management Commands

#### Quick Package Queries
```bash
# List all packages (shows Package ID, Name, Namespace, Description)
sf package list --target-dev-hub "HIPTEN DEV HUB"

# List all versions of NIPR package (shows Version, Version ID, Installation Key, etc.)
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB"

# List all versions across all packages
sf package version list --target-dev-hub "HIPTEN DEV HUB"

# Check if any package versions are currently being built
sf package version create list --target-dev-hub "HIPTEN DEV HUB"

# View detailed info about a specific package version
sf package version report --package "04tXXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB"
```

#### Package Version Filters
```bash
# Show only released (promoted) versions
sf package version list --packages "NIPR" --released-only --target-dev-hub "HIPTEN DEV HUB"

# Show concise output (less columns)
sf package version list --packages "NIPR" --concise --target-dev-hub "HIPTEN DEV HUB"

# Order by creation date (newest first)
sf package version list --packages "NIPR" --order-by CreatedDate --target-dev-hub "HIPTEN DEV HUB"

# Show versions created in last 30 days
sf package version list --packages "NIPR" --created-last-days 30 --target-dev-hub "HIPTEN DEV HUB"

# Show versions modified in last 7 days
sf package version list --packages "NIPR" --modified-last-days 7 --target-dev-hub "HIPTEN DEV HUB"
```

#### Package Version JSON Output (for scripting)
```bash
# Get JSON output for programmatic parsing
sf package list --target-dev-hub "HIPTEN DEV HUB" --json

# Get JSON for specific package versions
sf package version list --packages "NIPR" --target-dev-hub "HIPTEN DEV HUB" --json

# Get detailed version report as JSON
sf package version report --package "04tXXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB" --json
```

#### Check Package Version Build Status
```bash
# List all in-progress package version builds
sf package version create list --target-dev-hub "HIPTEN DEV HUB"

# Get detailed status of a specific build
sf package version create report --package-create-request-id "08cXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB"

# Monitor build with verbose output
sf package version create report --package-create-request-id "08cXXXXXXXXXXXXXX" --target-dev-hub "HIPTEN DEV HUB" --verbose
```

---

### Quick Reference

#### Essential Commands
```bash
# Authentication
sf org login web --alias <alias> --set-default-dev-hub
sf org list --all

# Scratch Orgs
sf org create scratch -f config/project-scratch-def.json -a <alias>
sf org delete scratch -o <alias> --no-prompt

# Deployment
sf project deploy start --source-dir force-app -o <org-alias>
sf project retrieve start --source-dir force-app -o <org-alias>

# Testing
sf apex run test --test-level RunLocalTests --code-coverage -o <org-alias>

# Packages
sf package list --target-dev-hub "HIPTEN DEV HUB"
sf package version create -p "NIPR" --wait 20 -v "HIPTEN DEV HUB"
sf package version promote -p <version-id> -v "HIPTEN DEV HUB"
```

#### Important Files
- `sfdx-project.json` - Package configuration and namespace
- `config/project-scratch-def.json` - Scratch org definition
- `.forceignore` - Files excluded from deployments
- `package.xml` - Metadata deployment manifest

---

### Getting Help

If you encounter issues:
1. Check this guide first
2. Review the Troubleshooting section above
3. Check global CLAUDE.md for architectural guidelines
4. Ask team lead or DevOps for assistance
5. Salesforce documentation: https://developer.salesforce.com/docs/
---

## 🎯 QUICK COMMAND REFERENCE FOR CLAUDE

> **For Developers**: Ask Claude to run these command sets instead of typing them manually.
> Claude has these workflows memorized and can execute them for you.

### Command Set 1: Pull Metadata from NIPR DEV

**When to ask**: "Pull latest metadata from NIPR DEV"

```bash
sf project retrieve start --source-dir force-app --target-org "NIPR DEV"
git status
git diff
```

### Command Set 2: Create and Release Package Version

**When to ask**: "Create a new package version and promote it"

**Prerequisites**: 
- Update `versionNumber` in `sfdx-project.json` (e.g., `0.X.0.NEXT`)
- All code tested in NIPR DEV

```bash
# Step 1: Create package version with code coverage
sf package version create \
  --package "NIPR Integration" \
  --installation-key-bypass \
  --code-coverage \
  --wait 20 \
  --target-dev-hub "HIPTEN DEV HUB"

# Step 2: Note the version ID (04tXXXXXXXXXXXXXXX)

# Step 3: Promote to Released
sf package version promote \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-dev-hub "HIPTEN DEV HUB" \
  --no-prompt

# Step 4: Update ancestorId in sfdx-project.json
# (Claude will do this automatically)
```

### Command Set 3: Install Package in QA/Test Org

**When to ask**: "Install package version [04tXXX...] in Hipten QA org"

```bash
# Authenticate to QA org (one-time)
sf org login web --alias "Hipten QA"

# Install/upgrade package
sf package install \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-org "Hipten QA" \
  --wait 20 \
  --upgrade-type Mixed

# Run tests
sf apex run test \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --target-org "Hipten QA"
```

### Command Set 4: Deploy Specific Changes to NIPR DEV

**When to ask**: "Deploy [file/directory] to NIPR DEV"

```bash
# Deploy specific class
sf project deploy start \
  --source-dir force-app/main/default/classes/YourClass.cls \
  --target-org "NIPR DEV" \
  --wait 10

# Deploy entire directory
sf project deploy start \
  --source-dir force-app/main/default/flows \
  --target-org "NIPR DEV" \
  --wait 10

# Deploy multiple files/directories
sf project deploy start \
  --source-dir force-app/main/default/classes/Class1.cls \
  --source-dir force-app/main/default/objects/Object1 \
  --target-org "NIPR DEV" \
  --wait 10
```

### Command Set 5: Full Development Cycle (Pull → Package → Install → Test)

**When to ask**: "Run full packaging workflow for version 0.X.0"

**Claude will execute:**
1. Pull metadata from NIPR DEV
2. Update version number in sfdx-project.json
3. Create package version with coverage
4. Promote to Released
5. Update ancestorId
6. Install in scratch org
7. Open scratch org for testing

```bash
# 1. Pull from NIPR DEV
sf project retrieve start --source-dir force-app --target-org "NIPR DEV"

# 2. Update sfdx-project.json (automated)

# 3. Create package version
sf package version create \
  --package "NIPR Integration" \
  --installation-key-bypass \
  --code-coverage \
  --wait 20 \
  --target-dev-hub "HIPTEN DEV HUB"

# 4. Promote
sf package version promote \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-dev-hub "HIPTEN DEV HUB" \
  --no-prompt

# 5. Update ancestorId (automated)

# 6. Install in scratch org
sf package install \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-org "NIPR-Test" \
  --wait 20 \
  --upgrade-type Mixed

# 7. Open scratch org
sf org open --target-org "NIPR-Test"
```

### Command Set 6: List and View Package Versions

**When to ask**: "Show me all package versions" or "What's the latest package version?"

```bash
# List all versions
sf package version list \
  --packages "NIPR Integration" \
  --target-dev-hub "HIPTEN DEV HUB"

# List only Released versions
sf package version list \
  --packages "NIPR Integration" \
  --released-only \
  --target-dev-hub "HIPTEN DEV HUB"

# Get detailed info about a specific version
sf package version report \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-dev-hub "HIPTEN DEV HUB"
```

### Command Set 7: Run Tests in NIPR DEV

**When to ask**: "Run all tests in NIPR DEV" or "Run tests for [TestClass]"

```bash
# Run all tests with coverage
sf apex run test \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --target-org "NIPR DEV"

# Run specific test class
sf apex run test \
  --class-names YourTestClass_Test \
  --result-format human \
  --target-org "NIPR DEV"

# Run test suite
sf apex run test \
  --test-level RunSpecifiedTests \
  --suite-names NIPRTestSuite \
  --code-coverage \
  --target-org "NIPR DEV"
```

### Command Set 8: Deploy to Client Production

**When to ask**: "Install package version [04tXXX...] in [Client Name] production"

**CRITICAL**: Only after UAT approval in client UAT org

```bash
# Authenticate to client org
sf org login web --alias "[Client Name] Prod"

# Install package
sf package install \
  --package "04tXXXXXXXXXXXXXXX" \
  --target-org "[Client Name] Prod" \
  --wait 20 \
  --upgrade-type Mixed

# Post-installation: Assign permission sets manually in UI
# - NIPR_View_NIPR_Data
# - d4c_NIPR_Edit_NPN_Access
```

---

## 📋 Package Information Summary

**Package Name**: NIPR Integration  
**Namespace**: `niprsync`  
**Package ID**: `0HoPB00000001P70AI`  
**Dev Hub**: HIPTEN DEV HUB (`stefan.nidzovic@hipten.com`)  
**Dev Org**: NIPR DEV (`hiptenadmins@hipten.com.d4c_nipr`)  
**GitHub Repo**: [https://github.com/stefan-nidzovic_hipten/NIPR](https://github.com/stefan-nidzovic_hipten/NIPR)  

**Current Version**: Check `sfdx-project.json` → `versionNumber`  
**Latest Released Version**: Ask Claude or run Command Set 6  

---

## 🚀 Common Developer Questions for Claude

### Package Management
- "Pull latest metadata from NIPR DEV"
- "Create package version 0.5.0"
- "Promote package version 04tXXX..."
- "Install latest package in scratch org"
- "Show me all package versions"
- "What's the latest Released version?"

### Deployment
- "Deploy [ClassName] to NIPR DEV"
- "Deploy all flows to NIPR DEV"
- "Install package in Hipten QA org"
- "Deploy to [Client Name] production"

### Testing
- "Run all tests in NIPR DEV"
- "Run tests for ProcessPDBAlertReportService"
- "Check test coverage"

### Full Workflows
- "Run full packaging workflow for version 0.6.0"
- "Pull metadata, create package, and install in scratch org"
- "Deploy changes, run tests, and create package version"

---

## 📝 Release Notes Management

### **CRITICAL REMINDER: Update Release Notes After Every Package Version**

After creating and promoting a new package version, you **MUST** update the release notes:

1. **File Location**: `NIPR_Release_Notes_v{version}.md` and `NIPR_Release_Notes_v{version}.docx`
2. **Required Information**:
   - Package Version (e.g., 0.8.0-1)
   - Package ID (04tXXXXXXXXXXXXXXX)
   - Release Date
   - Installation URL
   - Summary of changes (features, fixes, improvements)

3. **Format**: Use markdown for `.md` file, then convert to `.docx` with pandoc:
   ```bash
   pandoc NIPR_Release_Notes_v{version}.md -o NIPR_Release_Notes_v{version}.docx
   ```

4. **Claude Reminder**: Claude will automatically check if release notes exist for the latest package version and remind you if they're missing.

### Template Structure:
- Major Improvements (System Stability, Performance, Data Integrity)
- New Features (with screenshots/descriptions)
- UI/UX Improvements
- Technical Improvements
- Testing & Validation results
- Installation Notes
- Key Metrics (before/after comparisons)

---

**Last Updated**: 2026-01-26
**Maintained By**: Hipten Development Team
