# Data Quality Audit Framework

## Overview
An automated SQL-based data quality monitoring system that validates data across four dimensions: Completeness, Uniqueness, Validity, and Consistency. Includes automated scoring, threshold alerting, and historical trending.

## Why This Matters
Data quality is ~80% of a data engineer's job. This framework demonstrates:
- Proactive quality monitoring (catch issues before they reach reports)
- Automated validation at scale
- Quantifiable metrics for data governance
- Exception handling and remediation tracking

## The Four Dimensions of Data Quality

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DATA QUALITY DIMENSIONS                              │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┤
│   COMPLETENESS  │    UNIQUENESS   │    VALIDITY     │   CONSISTENCY   │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ • NULL counts   │ • Duplicate     │ • Format checks │ • Cross-table   │
│ • Required      │   detection     │ • Range checks  │   referential   │
│   fields        │ • Primary key   │ • Domain values │   integrity     │
│ • % populated   │   violations    │ • Data types    │ • Business rule │
│                 │                 │                 │   validation    │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         QUALITY FRAMEWORK                                │
│                                                                          │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐        │
│  │  Quality       │    │  Exception     │    │  Historical    │        │
│  │  Rules Config  │───▶│  Detection     │───▶│  Trending      │        │
│  └────────────────┘    └────────────────┘    └────────────────┘        │
│         │                      │                      │                 │
│         ▼                      ▼                      ▼                 │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐        │
│  │  dq.rules      │    │  dq.results    │    │  dq.trends     │        │
│  │  (metadata)    │    │  (findings)    │    │  (history)     │        │
│  └────────────────┘    └────────────────┘    └────────────────┘        │
│                                │                                        │
│                                ▼                                        │
│                       ┌────────────────┐                               │
│                       │  Quality Score │                               │
│                       │  Dashboard     │                               │
│                       └────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## Quality Checks Implemented

### 1. Completeness Checks
- NULL percentage by column
- Required field validation
- Row completeness scoring

### 2. Uniqueness Checks
- Primary key duplicates
- Natural key duplicates
- Composite key validation

### 3. Validity Checks
- Email format validation
- Phone number formats
- Date range validation
- Domain value checking
- Numeric range validation

### 4. Consistency Checks
- Referential integrity (orphan records)
- Cross-field validation (end_date > start_date)
- Business rule validation

## Quality Scoring

Each table receives a quality score (0-100) based on:
- Completeness: 25 points
- Uniqueness: 25 points
- Validity: 25 points
- Consistency: 25 points

**Threshold Levels:**
| Score | Status | Action |
|-------|--------|--------|
| 95-100 | Excellent | No action |
| 85-94 | Good | Monitor |
| 70-84 | Warning | Investigate |
| <70 | Critical | Immediate review |

## Sample Output

```
TABLE: customers
═══════════════════════════════════════════════════════════════
OVERALL SCORE: 87/100 (Good)

COMPLETENESS (23/25)
├── email: 98.5% populated ✓
├── phone: 92.3% populated ⚠ (threshold: 95%)
└── address: 99.1% populated ✓

UNIQUENESS (25/25)
├── customer_id: 0 duplicates ✓
└── email: 0 duplicates ✓

VALIDITY (22/25)
├── email format: 96.2% valid ⚠
├── phone format: 94.8% valid ⚠
└── state codes: 100% valid ✓

CONSISTENCY (17/25)
├── FK to orders: 12 orphans found ✗
└── created_date <= modified_date: 100% ✓
═══════════════════════════════════════════════════════════════
```

## How to Run

1. **Create the framework:**
```sql
-- Run in order
sql/01_create_dq_schema.sql
sql/02_create_dq_tables.sql
sql/03_create_dq_procedures.sql
sql/04_sample_rules_config.sql
```

2. **Configure rules for your tables:**
```sql
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'COMPLETENESS',
    @threshold = 95.0;
```

3. **Execute quality audit:**
```sql
EXEC dq.usp_run_quality_audit @table_name = 'customers';
```

4. **View results:**
```sql
SELECT * FROM dq.quality_results WHERE run_date = CAST(GETDATE() AS DATE);
SELECT * FROM dq.vw_quality_dashboard;
```

## Files
```
02-data-quality-framework/
├── README.md
├── sql/
│   ├── 01_create_dq_schema.sql
│   ├── 02_create_dq_tables.sql
│   ├── 03_create_dq_procedures.sql
│   └── 04_sample_rules_config.sql
├── data/
│   └── sample_dirty_data.sql
└── docs/
    └── rule_configuration_guide.md
```

## Key Learnings
- Metadata-driven validation scales better than hardcoded checks
- Historical trending catches gradual degradation
- Thresholds should be configurable per business context
- Exception tables enable remediation tracking
