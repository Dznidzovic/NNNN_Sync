# LOA to Product Mapping - Research Summary

## What We Have: NIPR LOA Codes

**Source**: NIPR API returns Line of Authority (LOA) data with:
- State Code (e.g., "CA")
- LOA Code (e.g., "11", "16", "6952")
- LOA Description (e.g., "Casualty", "Life", "Variable Life and Variable Annuity")

**PDB State Offerings Excel** (updated monthly): Lists all valid State + LOA Code + Description combinations
- [NIPR PDB State Offerings Documentation](https://nipr.com/producer-database-pdb)
- File location: `/Users/stefannidzovic/Documents/NIPR/PDB State Offerings 01-06-2026.xlsx`
- **Purpose**: Shows what LOA codes exist per state, NOT what products they map to

---

## The 6 Standard LOA Categories

According to NAIC standards, LOAs fall into 6 major categories:

| LOA Code Examples | Category | Products Included |
|------------------|----------|-------------------|
| 16 | **Life** | Term Life, Whole Life, Universal Life, Endowments, Annuities |
| 39, 935 | **Accident & Health** | Health Insurance, Disability Income, Accidental Death |
| 12 | **Property** | Commercial Property, Homeowners, Earthquake |
| 11 | **Casualty** | Workers' Compensation, General Liability, Auto Liability, Theft |
| 6952 | **Variable Life/Annuity** | Variable Life Contracts, Variable Annuities |
| 928 | **Personal Lines** | Homeowners, Renters, Personal Auto, Umbrella |

**Sources**:
- [What Is Covered Under Different Lines Of Authority - AgentSync](https://agentsync.io/blog/insurance-101/what-is-covered-under-different-lines-of-authority)
- [Insurance Lines of Authority: What You Need to Know](https://3hcg.com/blog/insurance-lines-of-authority-what-you-need-to-know)
- [Discover the True Meaning of Lines of Authority](https://www.firstconnectinsurance.com/blog/loa-insurance-meaning/)

---

## NAIC Standard Lines of Business

**NAIC** maintains official regulatory classifications for insurance products:

### Property & Casualty LOBs:
- Fire and Allied Lines
- Homeowners Multiple Peril
- Commercial Multiple Peril (CMP)
- Medical Malpractice
- Workers' Compensation
- Auto Liability / Auto Physical Damage
- Ocean Marine / Inland Marine
- Mortgage Guaranty
- Surety, Fidelity
- Burglary and Theft
- Boiler and Machinery
- Earthquake
- Product Liability
- Aircraft (All Perils)

### Life & Health LOBs:
- Life Insurance
- Variable Life
- Annuities
- Variable Annuities
- Accident and Health Insurance
- Disability Insurance
- Credit Life, Health and Accident

**Sources**:
- [NAIC Lines of Business Matrix](https://content.naic.org/industry/ucaa/lob-matrix)
- [Property & Casualty Product Coding Matrix](https://content.naic.org/sites/default/files/property-casualty-pcm_0.pdf)
- [UCAA Lines of Business Matrix PDF](https://content.naic.org/sites/default/files/inline-files/industry_ucaa_lines_of_business_matrix_1.pdf)

---

## The Mapping Challenge

### The Hierarchy:
```
NIPR LOA Code (e.g., "11 - Casualty")
  ↓ Falls into broad CATEGORY
  ↓ Contains multiple NAIC LOBs
      ↓ Workers' Compensation
      ↓ General Liability
      ↓ Auto Liability
  ↓ Companies create SELLABLE PRODUCTS
      ↓ "California Workers' Comp Premier Plus"
```

### Why Manual Mapping is Required:

1. **State Variations**: Same product category uses different LOA codes per state
2. **Granularity Gap**: One LOA category contains multiple NAIC LOBs
3. **Custom Products**: Company product names are internal, not standardized

**Example**:
- NIPR: `CA - 11 - Casualty` (what API returns)
- NAIC: Could be "Workers' Compensation" OR "General Liability" OR "Auto Liability"
- Company: "California Business Liability Premium Package" (custom name)

---

## Conclusion

**What Exists**:
- ✅ NIPR LOA Codes (from API)
- ✅ 6 Standard LOA Categories (industry knowledge)
- ✅ NAIC Standard LOB Names (regulatory classification)

**What Doesn't Exist**:
- ❌ Official mapping: NIPR LOA Code → NAIC LOB Name
- ❌ Official mapping: NAIC LOB Name → Company Product Name

**Our Solution**: `d4c_LOA_Insurance_Product_Mapping__c` object allows clients to manually map:
```
State + LOA Code + LOA Description → Company's Insurance Product
```

This mapping is **business logic** that each organization must define based on their product offerings.

---

**Date**: January 26, 2026
**Researched By**: Dev4Clouds
