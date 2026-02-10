# LOA Product Categorization System - Technical Specification

**Document Version:** 1.0
**Last Updated:** November 12, 2025
**Status:** Prototype Deployed - Automation Pending

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Context](#2-business-context)
3. [Problem Statement](#3-problem-statement)
4. [Solution Overview](#4-solution-overview)
5. [Data Model & Architecture](#5-data-model--architecture)
6. [Object Specifications](#6-object-specifications)
7. [Key Architectural Decisions](#7-key-architectural-decisions)
8. [User Interface Components](#8-user-interface-components)
9. [Security Model](#9-security-model)
10. [Current Implementation Status](#10-current-implementation-status)
11. [Future Automation Requirements](#11-future-automation-requirements)
12. [Sample Data & Use Cases](#12-sample-data--use-cases)
13. [Glossary](#13-glossary)

---

## 1. Executive Summary

### Business Problem
Insurance agents have Lines of Authority (LOAs) that vary by state in code and description, but represent the same underlying product types. Carriers need to determine if an agent is eligible for appointments based on unified product categories (e.g., HEALTH, LIFE, PROPERTY, CASUALTY, MEDICARE) rather than state-specific LOA codes.

### Solution
A custom object-based categorization system that maps state-specific LOA codes to unified product categories using a many-to-many relationship model. This enables clients to define their own mappings and automatically categorize licenses based on their LOAs.

### Key Benefits
- **Carrier Appointment Eligibility**: Quickly determine if an agent can sell specific product types
- **Unified Product View**: Roll up state-specific LOAs to standardized categories
- **Client Configurability**: Clients can bulk upload and maintain their own LOA mappings
- **Scalability**: Supports 15,000+ LOA mappings without complex deployments

---

## 2. Business Context

### Original Requirement (from Lok)
> "So, we have seen a pattern emerge from clients' requests, yeah. We have, um, a lot of clients or some clients who are approaching us for a specific feature, okay. So, let me explain the business, um, first. So, we have seen an agent in a specific state. Okay. They have licenses in multiple states and each license has multiple LOAs, okay. And the client wants to categorize those LOAs into specific products.
>
> For example, um, in the state of California, an LOA code could be 935, and the description could be "Accident & Health or Sickness," okay. And in the state of Florida, it could be 770, and the description could be "Health Insurance," okay. But both of them are health products, okay.
>
> So what we want to build is some kind of mapping table or metadata where the client can map LOA codes and descriptions to specific products like HEALTH, LIFE, PROPERTY, CASUALTY, MEDICARE, and so on. The client will determine this mapping. We will give them a way to upload data or build this through some configuration, okay.
>
> Then we'll have some kind of automation (might be a trigger) that, whenever an agent has a license, that license has LOAs, and we have to map those LOAs to our mapping table and then determine which products this agent can sell."

### Business Use Case
1. Agent has License in California with LOA Code 935 ("Accident & Health or Sickness")
2. Agent has License in Florida with LOA Code 770 ("Health Insurance")
3. Client configures mapping: CA-935 → HEALTH, FL-770 → HEALTH
4. System automatically categorizes both licenses as "HEALTH" products
5. Carrier can now determine agent is eligible for Health insurance appointments

---

## 3. Problem Statement

### Current State Challenges
1. **State Variation**: LOA codes and descriptions are state-specific and inconsistent
2. **Manual Categorization**: No automated way to group LOAs by product type
3. **Carrier Requirements**: Carriers need to know product eligibility, not LOA details
4. **Scalability**: Potential for 15,000+ unique LOA combinations across all states
5. **Client Control**: Clients need ability to define and maintain their own mappings

### Key Questions Answered
- **Which object to map from?**
  - Answer: Line of Authority (LOA) is the correct level, not License
  - Reason: License Class Description is just a naming convention; LOAs represent actual product authorizations

- **One LOA to multiple products?**
  - Answer: Yes, one LOA combination (State + Code + Description) can map to multiple product categories
  - Example: "Life & Health" LOA could map to both LIFE and HEALTH categories

---

## 4. Solution Overview

### High-Level Architecture
```
NIPR Data (Existing)           Categorization System (New)              Output (New)
─────────────────────          ───────────────────────────────          ────────────────
┌─────────────────┐            ┌──────────────────────────┐            ┌──────────────┐
│  d4c_Entity__c │            │  Product_Category__c     │            │ d4c_License__c│
│                 │            │  (CA-HEALTH, CA-LIFE)    │◄───────────│ .d4c_License_ │
└────────┬────────┘            └────────────┬─────────────┘            │  Products__c │
         │                                  │                          │ (Multi-select)│
         │                                  │                          └──────────────┘
         │                                  │                                  ▲
┌────────▼────────┐            ┌────────────▼─────────────┐                  │
│ d4c_License__c   │            │ License_Product_         │                  │
│                 │◄───────────│ Category__c (Junction)   │──────────────────┘
└────────┬────────┘            └──────────────────────────┘
         │                                  ▲
         │                                  │
┌────────▼────────┐            ┌────────────┴─────────────┐
│d4c_LineOf        │            │ Mapping_Product_         │
│Authority__c     │◄───────────│ Category__c (Junction)   │
│                 │            └────────────┬─────────────┘
└─────────────────┘                         │
         ▲                                  │
         │                      ┌───────────▼──────────────┐
         │                      │ LOA_Product_Category_    │
         └──────────────────────│ Mapping__c               │
                                │ (CA-935-"Acc & Health")  │
                                └──────────────────────────┘
```

### Data Flow
1. **Configuration**: Client uploads LOA mappings to `LOA_Product_Category_Mapping__c`
2. **Junction Creation**: Client creates `Mapping_Product_Category__c` records linking LOA mappings to product categories
3. **Automation (Future)**: Trigger on `d4c_LineOfAuthority__c` matches LOAs to mappings
4. **License Categorization**: System creates `License_Product_Category__c` junction records
5. **Rollup**: Multi-picklist field on License shows all product categories

---

## 5. Data Model & Architecture

### Entity Relationship Diagram (Text Format)

```
┌─────────────────────────────────────────┐
│  d4c_Insurance_Product__c                │
│  ─────────────────────────────────────  │
│  Name (Text 80) *Required               │
│  d4c_StateOrProvince__c (Text 10) *Req   │
│  d4c_ProductName__c (Text) *Required     │
│  d4c_UniqueIdentifier__c (Text 255)      │
│    External ID, Unique                  │
│    Populated by automation              │
└───────────┬─────────────────────────────┘
            │
            │ ┌─ Master-Detail (Many)
            │ │
┌───────────▼──────────────────────────────┐
│  d4c_Insurance_Product_LOA_Mapping__c     │
│  ──────────────────────────────────────  │
│  Name (AutoNumber) IPLM-0000             │
│  d4c_InsuranceProduct__c (MD) *Required   │
│  d4c_LOAMapping__c (MD) *Required         │
└───────────┬──────────────────────────────┘
            │
            │ Master-Detail (Many) ─┐
            │                       │
┌───────────▼───────────────────────▼──────┐
│  d4c_LOA_Insurance_Product_Mapping__c     │
│  ──────────────────────────────────────  │
│  Name (AutoNumber) LOAIPM-0000           │
│  d4c_StateOrProvinceCode__c (Text 10)     │
│  d4c_LineOfAuthorityCode__c (Text 50)     │
│  d4c_LineOfAuthorityDescription__c (Text) │
│  d4c_UniqueIdentifier__c (Text 255)       │
│    External ID, Unique                   │
│    Populated by automation               │
└──────────────────────────────────────────┘
            ▲
            │ Lookup
            │
┌───────────┴──────────────────────────────┐
│  d4c_LineOfAuthority__c (Existing)        │
│  ──────────────────────────────────────  │
│  d4c_LineOfAuthorityCode__c               │
│  d4c_LineOfAuthorityDescription__c        │
│  d4c_LOAMapping__c (New Lookup Field)     │
└───────────┬──────────────────────────────┘
            │
            │ Master-Detail (to License)
            │
┌───────────▼──────────────────────────────┐
│  d4c_License__c (Existing)                │
│  ──────────────────────────────────────  │
│  d4c_LicenseNumber__c                     │
│  d4c_InsuranceProducts__c                 │
│    (New Multi-select Picklist)           │
│    No initial values                     │
└───────────┬──────────────────────────────┘
            │
            │ ┌─ Master-Detail (Many)
            │ │
┌───────────▼──────────────────────────────┐
│  d4c_License_Insurance_Product__c         │
│  ──────────────────────────────────────  │
│  Name (AutoNumber) LIP-0000              │
│  d4c_License__c (MD) *Required            │
│  d4c_InsuranceProduct__c (MD) *Required   │
└──────────────────────────────────────────┘
```

### Relationship Summary
- **Insurance Product ↔ LOA Mapping**: Many-to-Many via `d4c_Insurance_Product_LOA_Mapping__c`
- **License ↔ Insurance Product**: Many-to-Many via `d4c_License_Insurance_Product__c`
- **LOA ↔ LOA Mapping**: Lookup relationship (LOA looks up to its mapping)
- **License ↔ LOA**: Master-Detail (existing NIPR structure)

---

## 6. Object Specifications

### 6.1 d4c_Insurance_Product__c

**Purpose**: Represents unified insurance products per state/province (e.g., "CA-HEALTH", "FL-LIFE", "ON-HEALTH")

**API Name**: `d4c_Insurance_Product__c`
**Label**: NIPR Insurance Product
**Plural Label**: NIPR Insurance Products
**Name Field**: Standard Name field (Text, Required)
**Sharing Model**: Read/Write

#### Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| Name | Text(80) | Insurance Product Name | Yes | Standard Name field (required) |
| d4c_StateOrProvince__c | Text(10) | State or Province | Yes | US states (CA, NY, TX) or Canadian provinces (ON, BC, QC) |
| d4c_ProductName__c | Text(255) | Product Name | Yes | HEALTH, LIFE, PROPERTY, CASUALTY, MEDICARE, etc. |
| d4c_UniqueIdentifier__c | Text(255), External ID, Unique | Unique Identifier | Yes | Populated by automation: State-ProductName |

#### Relationships
- **Parent in**: `d4c_Insurance_Product_LOA_Mapping__c.d4c_InsuranceProduct__c` (Master-Detail)
- **Parent in**: `d4c_License_Insurance_Product__c.d4c_InsuranceProduct__c` (Master-Detail)

#### Related Lists
- Mapping Product Categories
- License Product Categories

---

### 6.2 d4c_LOA_Insurance_Product_Mapping__c

**Purpose**: Client-defined mappings of state-specific LOA codes/descriptions to insurance products

**API Name**: `d4c_LOA_Insurance_Product_Mapping__c`
**Label**: NIPR LOA Insurance Product Mapping
**Name Field**: AutoNumber (LOAIPM-{0000})
**Sharing Model**: Read/Write

#### Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| Name | AutoNumber | LOA Insurance Product Mapping Name | System | LOAIPM-0000 format |
| d4c_StateOrProvinceCode__c | Text(10) | State or Province Code | Yes | US state or Canadian province code (e.g., CA, FL, ON, BC) |
| d4c_LineOfAuthorityCode__c | Text(50) | Line of Authority Code | Yes | NIPR LOA code (e.g., 935, 770) |
| d4c_LineOfAuthorityDescription__c | Text(255) | Line of Authority Description | Yes | NIPR LOA description (e.g., "Accident & Health or Sickness") |
| d4c_UniqueIdentifier__c | Text(255), External ID, Unique | Unique Identifier | Yes | Populated by automation: State-Code-Description |

#### Relationships
- **Child of**: `d4c_LineOfAuthority__c.d4c_LOAMapping__c` (Lookup - reverse)
- **Parent in**: `d4c_Insurance_Product_LOA_Mapping__c.d4c_LOAMapping__c` (Master-Detail)

#### Related Lists
- Insurance Product LOA Mappings (junction to Insurance Products)
- Lines of Authority (LOAs that reference this mapping)

#### Notes
- External ID field enables upsert operations via CSV bulk upload
- Client configures these mappings based on their business rules
- One LOA mapping can connect to multiple insurance products via junction object

---

### 6.3 d4c_Insurance_Product_LOA_Mapping__c (Junction)

**Purpose**: Many-to-many junction enabling one LOA mapping to associate with multiple insurance products

**API Name**: `d4c_Insurance_Product_LOA_Mapping__c`
**Label**: NIPR Insurance Product LOA Mapping
**Name Field**: AutoNumber (IPLM-{0000})
**Sharing Model**: Controlled by Parent

#### Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| Name | AutoNumber | Insurance Product LOA Mapping Name | System | IPLM-0000 format |
| d4c_LOAMapping__c | Master-Detail | LOA Mapping | Yes | Links to LOA Insurance Product Mapping |
| d4c_InsuranceProduct__c | Master-Detail | Insurance Product | Yes | Links to Insurance Product |
| d4c_UniqueIdentifier__c | Text(255), External ID, Unique | Unique Identifier | Yes | Populated by automation |

#### Relationships
- **Child of**: `d4c_LOA_Insurance_Product_Mapping__c` (Master-Detail)
- **Child of**: `d4c_Insurance_Product__c` (Master-Detail)

#### Notes
- Master-Detail fields are auto-required (cannot mark as required in metadata)
- UniqueIdentifier prevents duplicate junction records
- Enables scenarios like: CA-935-"Life & Health" → both LIFE and HEALTH products

---

### 6.4 d4c_License_Insurance_Product__c (Junction)

**Purpose**: Many-to-many junction showing which insurance products a license is authorized for

**API Name**: `d4c_License_Insurance_Product__c`
**Label**: License Insurance Product
**Name Field**: AutoNumber (LIP-{0000})
**Sharing Model**: Controlled by Parent

#### Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| Name | AutoNumber | License Insurance Product Name | System | LIP-0000 format |
| d4c_License__c | Master-Detail | License | Yes | Links to License |
| d4c_InsuranceProduct__c | Master-Detail | Insurance Product | Yes | Links to Insurance Product |
| d4c_UniqueIdentifier__c | Text(255), External ID, Unique | Unique Identifier | Yes | Populated by automation |

#### Relationships
- **Child of**: `d4c_License__c` (Master-Detail)
- **Child of**: `d4c_Insurance_Product__c` (Master-Detail)

#### Notes
- Created by batch job automation
- UniqueIdentifier prevents duplicate junction records
- Rolled up to `d4c_License__c.d4c_InsuranceProducts__c` multi-select picklist

---

### 6.5 d4c_License__c (Enhanced)

**Existing Object with New Field**

#### New Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| d4c_InsuranceProducts__c | Multi-select Picklist (Non-restricted) | Insurance Products | No | Aggregated product categories for quick visibility. No initial picklist values - populated by automation. |

#### New Relationships
- **Parent in**: `License_Product_Category__c.d4c_License__c` (Master-Detail)

---

### 6.6 d4c_LineOfAuthority__c (Enhanced)

**Existing Object with New Field**

#### New Fields

| Field API Name | Type | Label | Required | Description |
|---|---|---|---|---|
| d4c_LOAProductCategoryMapping__c | Lookup | LOA Product Category Mapping | No | Links LOA to its categorization mapping |

#### New Relationships
- **Lookup to**: `LOA_Product_Category_Mapping__c`

#### Notes
- Lookup populated by trigger (future implementation)
- Matches based on: State + LOA Code + LOA Description
- Delete constraint: Set Null (preserves LOA if mapping is deleted)

---

## 7. Key Architectural Decisions

### 7.1 Custom Objects vs Custom Metadata

**Decision**: Use Custom Objects
**Rationale**:
- **Scale**: 15,000+ LOA mappings would require 15,000 metadata deployments
- **Client Control**: Clients can bulk upload via Data Loader without deployments
- **Incremental Adoption**: Can add mappings progressively without full deployment cycles
- **Audit Trail**: Field history tracking and full auditing
- **Flexibility**: Easier to modify structure and add fields over time

**Rejected Approach**: Custom Metadata Types
**Reasons**: Deployment overhead, no bulk upload capability, requires Salesforce admin for all changes

---

### 7.2 External ID Strategy

**Decision**: Use Formula Fields for External IDs
**Pattern**: Concatenate unique identifiers (State + Code + Description)

**Example**:
```
d4c_UniqueIdentifier__c = TEXT(d4c_State__c) & "-" & d4c_LOACode__c & "-" & d4c_LOADescription__c
```

**Benefits**:
- Enables upsert operations in bulk data loads
- No complex SOQL queries needed in triggers
- Exact matching for LOA to mapping lookup

**Important Constraint**: Formula fields cannot be marked as `unique` or `externalId` in Salesforce metadata (API limitation)

---

### 7.3 Many-to-Many Junction Pattern

**Decision**: Use two junction objects with Master-Detail relationships
**Rationale**:
- One LOA combination (e.g., CA-935-"Life & Health") can map to multiple product categories (LIFE, HEALTH)
- One Product Category (e.g., CA-HEALTH) can be associated with multiple LOA mappings
- Provides flexibility for complex business scenarios

**Alternative Considered**: Direct lookup from LOA Mapping to Product Category
**Rejected**: Too restrictive; couldn't handle one LOA mapping to multiple products

---

### 7.4 Trigger vs Flow vs Batch

**Decision**: Apex Trigger (Future Implementation)
**Trigger Object**: `d4c_LineOfAuthority__c`
**Trigger Events**: After Insert, After Update

**Rationale**:
- Real-time categorization when LOAs are synced from NIPR
- Follows existing NIPR architecture patterns (TriggerDispatcher + BaseTriggerHandler)
- Better performance than Flow for bulk operations
- More testable with existing mock framework

**Process Flow**:
1. LOA inserted/updated → Trigger fires
2. Match LOA to `LOA_Product_Category_Mapping__c` via External ID formula
3. Find related Product Categories via `Mapping_Product_Category__c` junction
4. Create/update `License_Product_Category__c` junction records
5. Roll up categories to `d4c_License__c.d4c_License_Products__c` multi-picklist

---

## 8. User Interface Components

### 8.1 Custom Tabs

| Tab Label | API Name | Icon | Visibility |
|---|---|---|---|
| Product Categories | Product_Category__c | Custom48: Laptop | Visible in NIPR Console |
| LOA Product Category Mappings | LOA_Product_Category_Mapping__c | Custom85: Atom | Visible in NIPR Console |

**Note**: No tabs for junction objects (best practice)

---

### 8.2 Lightning Record Pages

All pages follow naming convention: `NCC_[Object]_Record_Page_Read_Only`

#### 8.2.1 NCC Product Category Record Page - Read Only
- **Object**: Product_Category__c
- **Layout**: Two-column field section + related lists
- **Sections**:
  - Product Category Information (State, Category Name, Unique Identifier)
  - System Information (Created By, Last Modified By, Owner)
  - Related Lists (Mapping Product Categories, License Product Categories)

#### 8.2.2 NCC LOA Product Category Mapping Record Page - Read Only
- **Object**: LOA_Product_Category_Mapping__c
- **Layout**: Two-column field section + related lists
- **Sections**:
  - LOA Mapping Information (State, LOA Code, LOA Description, Unique Identifier)
  - System Information
  - Related Lists (Mapping Product Categories, Lines of Authority)

#### 8.2.3 NCC License Product Category Record Page - Read Only
- **Object**: License_Product_Category__c
- **Layout**: Two-column field section + related lists
- **Fields**: Name, License (lookup), Product Category (lookup)

#### 8.2.4 NCC Mapping Product Category Record Page - Read Only
- **Object**: Mapping_Product_Category__c
- **Layout**: Two-column field section + related lists
- **Fields**: Name, LOA Product Category Mapping (lookup), Product Category (lookup)

---

### 8.3 NIPR Console Application

**API Name**: `NIPR_Console`
**Type**: Lightning Console
**Navigation**: Standard

#### Tabs (in order)
1. Accounts
2. Contacts
3. Leads
4. Entitys
5. Licenses
6. Lines of Authority
7. Carrier Appointments
8. Entity Addresses
9. Entity Communications
10. Carriers
11. Subscriptions
12. **Product Categories** ← New
13. **LOA Product Category Mappings** ← New

#### Action Overrides (View Action)
- `Product_Category__c` → NCC_Product_Category_Record_Page_Read_Only
- `LOA_Product_Category_Mapping__c` → NCC_LOA_Product_Category_Mapping_Record_Page_Read_Only
- `License_Product_Category__c` → NCC_License_Product_Category_Record_Page_Read_Only
- `Mapping_Product_Category__c` → NCC_Mapping_Product_Category_Record_Page_Read_Only

---

## 9. Security Model

### 9.1 Permission Set: NIPR_View_NIPR_Data

#### Object Permissions

| Object | Create | Read | Edit | Delete |
|---|---|---|---|---|
| Product_Category__c | ✓ | ✓ | ✓ | ✓ |
| LOA_Product_Category_Mapping__c | ✓ | ✓ | ✓ | ✓ |
| Mapping_Product_Category__c | ✓ | ✓ | ✓ | ✓ |
| License_Product_Category__c | ✓ | ✓ | ✓ | ✓ |

#### Field Permissions
- **Read Access**: All fields (required fields excluded per Salesforce requirements)
- **Edit Access**: Non-formula, non-required fields
- **Formula Fields**: Read-only by nature
- **Required Fields**: Not included in permission set (Salesforce auto-grants)

#### Tab Visibility
- Product_Category__c: **Visible**
- LOA_Product_Category_Mapping__c: **Visible**

---

## 10. Current Implementation Status

### ✅ Completed (Prototype Phase)

#### Metadata
- [x] 4 new custom objects created
- [x] 13 new custom fields created
- [x] 2 junction objects with Master-Detail relationships
- [x] 2 enhanced existing objects (License, LOA)
- [x] Formula fields for External ID matching

#### User Interface
- [x] 2 custom tabs created
- [x] 4 Lightning record pages created
- [x] NIPR Console app updated with tabs and action overrides

#### Security
- [x] NIPR_View_NIPR_Data permission set updated
- [x] Object permissions (CRUD) assigned
- [x] Field permissions assigned
- [x] Tab visibility configured

#### Sample Data
- [x] 4 Product Category records (CA-HEALTH, CA-LIFE, CA-PROPERTY, CA-CASUALTY)
- [x] 4 License Product Category junction records for License LIC-2867
- [x] License multi-picklist populated with sample values

### ⏳ Pending (Automation Phase)

#### Automation Logic
- [ ] Apex trigger on d4c_LineOfAuthority__c
- [ ] Trigger handler class (extends BaseTriggerHandler)
- [ ] Service class for categorization logic
- [ ] Selector class for querying mappings
- [ ] Test classes with mock data

#### Data Population
- [ ] LOA_Product_Category_Mapping__c records (client to provide)
- [ ] Mapping_Product_Category__c junction records
- [ ] Bulk processing of existing LOAs

#### Documentation
- [ ] User guide for LOA mapping configuration
- [ ] Admin guide for bulk upload process
- [ ] Deployment guide for production rollout

---

## 11. Future Automation Requirements

### 11.1 Trigger: LineOfAuthorityTriggerHandler

**Trigger Object**: `d4c_LineOfAuthority__c`
**Events**: After Insert, After Update
**Handler Class**: `LineOfAuthorityTriggerHandler` (extends `BaseTriggerHandler`)

#### Trigger Logic Pseudocode

```apex
// After Insert/Update context
for each d4c_LineOfAuthority__c loa in Trigger.new {

    // Step 1: Build external ID for matching
    String externalId = loa.State + '-' + loa.d4c_LineOfAuthorityCode__c + '-' + loa.d4c_LineOfAuthorityDescription__c;

    // Step 2: Query LOA_Product_Category_Mapping__c by External ID
    LOA_Product_Category_Mapping__c mapping =
        [SELECT Id FROM LOA_Product_Category_Mapping__c
         WHERE d4c_UniqueIdentifier__c = :externalId LIMIT 1];

    // Step 3: Update LOA with mapping lookup
    if (mapping != null) {
        loa.d4c_LOAProductCategoryMapping__c = mapping.Id;
    }

    // Step 4: Query related Product Categories via junction
    List<Mapping_Product_Category__c> junctions =
        [SELECT d4c_ProductCategory__c FROM Mapping_Product_Category__c
         WHERE d4c_LOAProductCategoryMapping__c = :mapping.Id];

    // Step 5: Create License_Product_Category__c records
    List<License_Product_Category__c> licenseCategoryRecords = new List<>();
    for (Mapping_Product_Category__c junction : junctions) {
        licenseCategoryRecords.add(new License_Product_Category__c(
            d4c_License__c = loa.d4c_License__c,
            d4c_ProductCategory__c = junction.d4c_ProductCategory__c
        ));
    }
    upsert licenseCategoryRecords; // Use upsert to avoid duplicates

    // Step 6: Roll up to License multi-picklist
    // Query all License_Product_Category__c for this License
    // Aggregate unique d4c_CategoryName__c values
    // Update d4c_License__c.d4c_License_Products__c with semicolon-separated string
}
```

#### Key Considerations
- **Bulkification**: Process all LOAs in trigger context together
- **Duplicate Prevention**: Use upsert or check existing License_Product_Category__c records
- **Error Handling**: Log failures without blocking entire batch
- **Performance**: Query mappings once and cache in memory
- **Test Coverage**: Mock LOA_Product_Category_Mapping__c data in tests

---

### 11.2 Service Class: LOACategorizationService

**Purpose**: Encapsulate business logic for LOA categorization
**Methods**:
- `categorizeLOAs(List<d4c_LineOfAuthority__c> loas)` - Main entry point
- `matchLOAToMapping(d4c_LineOfAuthority__c loa)` - External ID matching
- `getProductCategoriesForMapping(Id mappingId)` - Query junction records
- `createLicenseCategoryJunctions(Map<Id, Set<Id>> licenseToCategories)` - Bulk create junctions
- `rollupCategoryToLicense(Set<Id> licenseIds)` - Update multi-picklist

---

### 11.3 Selector Class: LOAProductCategoryMappingSelector

**Purpose**: Centralize SOQL queries for LOA mappings
**Methods**:
- `selectByExternalId(Set<String> externalIds)` - Bulk query by formula field
- `selectByIdWithCategories(Set<Id> mappingIds)` - Include junction relationships
- `selectAllActive()` - Get all active mappings for admin UI

---

## 12. Sample Data & Use Cases

### 12.1 Prototype Data Created

#### License Example: LIC-2867
**License Number**: 675353522
**Entity**: (Sample from org)

#### Lines of Authority (4 LOAs)

| LOA Code | LOA Description | Product Mapping |
|---|---|---|
| 11 | Casualty | → CA-CASUALTY |
| 12 | Property | → CA-PROPERTY |
| 16 | Life | → CA-LIFE |
| 935 | Accident & Health or Sickness | → CA-HEALTH |

#### Product Categories Created

| Name | State | Category Name | Unique Identifier |
|---|---|---|---|
| PC-0000 | CA | HEALTH | CA-HEALTH |
| PC-0001 | CA | LIFE | CA-LIFE |
| PC-0002 | CA | PROPERTY | CA-PROPERTY |
| PC-0003 | CA | CASUALTY | CA-CASUALTY |

#### License Product Category Junctions (4 records)
- LIC-2867 → CA-HEALTH
- LIC-2867 → CA-LIFE
- LIC-2867 → CA-PROPERTY
- LIC-2867 → CA-CASUALTY

#### License Multi-Picklist Value
```
d4c_License_Products__c = "HEALTH;LIFE;PROPERTY;CASUALTY"
```

---

### 12.2 Use Case Scenarios

#### Scenario 1: Single Product LOA
**Input**: CA LOA Code 935 - "Accident & Health or Sickness"
**Mapping**: CA-935-"Accident & Health or Sickness" → CA-HEALTH
**Output**: License categorized as HEALTH

#### Scenario 2: Multi-Product LOA
**Input**: CA LOA Code 123 - "Life and Health Insurance"
**Mapping**: CA-123-"Life and Health Insurance" → CA-LIFE, CA-HEALTH
**Output**: License categorized as both LIFE and HEALTH

#### Scenario 3: State Variation
**Input**:
- CA LOA 935 - "Accident & Health or Sickness"
- FL LOA 770 - "Health Insurance"

**Mappings**:
- CA-935-"Accident & Health or Sickness" → CA-HEALTH
- FL-770-"Health Insurance" → FL-HEALTH

**Output**: Both licenses show HEALTH product eligibility

---

## 13. Glossary

### Key Terms

**Line of Authority (LOA)**
A specific product authorization granted by a state insurance department, represented by a code and description. LOAs are the actual legal authorizations that determine what products an agent can sell.

**Product Category**
A unified, standardized product type (e.g., HEALTH, LIFE, PROPERTY) that aggregates state-specific LOAs. Defined at the state level (e.g., CA-HEALTH vs FL-HEALTH) to allow for state-specific business rules.

**LOA Product Category Mapping**
Client-defined configuration that maps state-specific LOA combinations (State + Code + Description) to one or more Product Categories.

**External ID Formula**
A formula field that concatenates unique identifiers (e.g., State + Code + Description) to enable exact matching and upsert operations without complex SOQL.

**Junction Object**
A Salesforce object with two Master-Detail relationships that enables many-to-many relationships between two parent objects.

**Master-Detail Relationship**
A Salesforce relationship where the child record's lifecycle is controlled by the parent. Deleting the parent deletes all children. Used for junction objects.

**Lookup Relationship**
A Salesforce relationship that creates a link between two objects but doesn't control lifecycle. Used for `d4c_LineOfAuthority__c.d4c_LOAProductCategoryMapping__c`.

**Multi-Select Picklist**
A Salesforce field type that allows multiple values to be selected from a predefined list. Used for `d4c_License__c.d4c_License_Products__c` to show aggregated categories.

**Trigger Dispatcher Pattern**
A design pattern where all triggers delegate to handler classes via a central dispatcher (`TriggerDispatcher.cls`). Enables better testing and separation of concerns.

**BaseTriggerHandler**
An abstract class in the NIPR codebase that all trigger handlers extend. Provides lifecycle methods (beforeInsert, afterUpdate, etc.) and test-visible flags.

**Repository Pattern**
A design pattern where all SOQL queries are centralized in Selector classes. Enables easy mocking in tests and query reuse across services.

**NIPR (National Insurance Entity Registry)**
External system that provides insurance agent licensing data via SOAP APIs. Source of truth for Entity, License, and LOA data.

**Carrier Appointment**
A relationship between an insurance agent and an insurance carrier that authorizes the agent to sell the carrier's products. Eligibility is determined by Product Categories.

---

## Appendix A: File Locations

### Metadata Files

#### Objects
- `/force-app/main/default/objects/Product_Category__c/`
- `/force-app/main/default/objects/LOA_Product_Category_Mapping__c/`
- `/force-app/main/default/objects/Mapping_Product_Category__c/`
- `/force-app/main/default/objects/License_Product_Category__c/`

#### Fields
- `/force-app/main/default/objects/d4c_License__c/fields/d4c_License_Products__c.field-meta.xml`
- `/force-app/main/default/objects/d4c_LineOfAuthority__c/fields/d4c_LOAProductCategoryMapping__c.field-meta.xml`

#### Tabs
- `/force-app/main/default/tabs/Product_Category__c.tab-meta.xml`
- `/force-app/main/default/tabs/LOA_Product_Category_Mapping__c.tab-meta.xml`

#### Lightning Pages
- `/force-app/main/default/flexipages/NCC_Product_Category_Record_Page_Read_Only.flexipage-meta.xml`
- `/force-app/main/default/flexipages/NCC_LOA_Product_Category_Mapping_Record_Page_Read_Only.flexipage-meta.xml`
- `/force-app/main/default/flexipages/NCC_License_Product_Category_Record_Page_Read_Only.flexipage-meta.xml`
- `/force-app/main/default/flexipages/NCC_Mapping_Product_Category_Record_Page_Read_Only.flexipage-meta.xml`

#### Applications
- `/force-app/main/default/applications/NIPR_Console.app-meta.xml`

#### Permission Sets
- `/force-app/main/default/permissionsets/NIPR_View_NIPR_Data.permissionset-meta.xml`

---

## Appendix B: Deployment Commands

### Deploy All LOA Categorization Metadata
```bash
# Deploy objects
sf project deploy start -d force-app/main/default/objects/Product_Category__c \
  -d force-app/main/default/objects/LOA_Product_Category_Mapping__c \
  -d force-app/main/default/objects/Mapping_Product_Category__c \
  -d force-app/main/default/objects/License_Product_Category__c

# Deploy enhanced fields
sf project deploy start \
  -m CustomField:d4c_LineOfAuthority__c.d4c_LOAProductCategoryMapping__c \
  -m CustomField:d4c_License__c.d4c_License_Products__c

# Deploy UI components
sf project deploy start \
  -d force-app/main/default/tabs/Product_Category__c.tab-meta.xml \
  -d force-app/main/default/tabs/LOA_Product_Category_Mapping__c.tab-meta.xml \
  -d force-app/main/default/flexipages/ \
  -d force-app/main/default/applications/NIPR_Console.app-meta.xml

# Deploy security
sf project deploy start \
  -d force-app/main/default/permissionsets/NIPR_View_NIPR_Data.permissionset-meta.xml
```

### Query Sample Data
```bash
# View Product Categories
sf data query --query "SELECT Id, Name, d4c_State__c, d4c_CategoryName__c, d4c_UniqueIdentifier__c FROM Product_Category__c"

# View License with Products
sf data query --query "SELECT Id, Name, d4c_License_Products__c FROM d4c_License__c WHERE Name = 'LIC-2867'"

# View License Product Category junctions
sf data query --query "SELECT Id, d4c_License__r.Name, d4c_ProductCategory__r.d4c_CategoryName__c FROM License_Product_Category__c"
```

---

**Document End**

*This specification serves as the single source of truth for the LOA Product Categorization System. All development work should reference and update this document to maintain accuracy.*
