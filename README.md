# Data Quality Audit Framework

## 📋 Overview

An automated SQL-based data quality monitoring system that validates data across four dimensions: **Completeness**, **Uniqueness**, **Validity**, and **Consistency**. Includes automated scoring, threshold alerting, and historical trending.

---

## 🎯 Why This Matters

Data quality is ~80% of a data engineer's job. This framework demonstrates:
- Proactive quality monitoring (catch issues before they reach reports)
- Automated validation at scale
- Quantifiable metrics for data governance
- Exception handling and remediation tracking

---

## 📊 The Four Dimensions of Data Quality
```
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│   COMPLETENESS  │    UNIQUENESS   │    VALIDITY     │   CONSISTENCY   │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ • NULL counts   │ • Duplicate     │ • Format checks │ • Cross-table   │
│ • Required      │   detection     │ • Range checks  │   referential   │
│   fields        │ • Primary key   │ • Domain values │   integrity     │
│ • % populated   │   violations    │ • Data types    │ • Business rule │
│                 │                 │                 │   validation    │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

---

## 🏗️ Architecture
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

---

## 🛠️ Technologies

- SQL Server (easily portable to PostgreSQL, Snowflake, etc.)
- Stored Procedures for automation
- Metadata-driven rule configuration

---

## 📈 Quality Scoring

Each table receives a quality score (0-100) based on weighted dimensions:

| Dimension | Weight | What It Measures |
|-----------|--------|------------------|
| Completeness | 25 pts | Are required fields populated? |
| Uniqueness | 25 pts | Are there duplicates? |
| Validity | 25 pts | Does data match expected formats/ranges? |
| Consistency | 25 pts | Do related tables align? |

**Threshold Levels:**

| Score | Status | Action |
|-------|--------|--------|
| 95-100 | 🟢 Excellent | No action needed |
| 85-94 | 🟡 Good | Monitor |
| 70-84 | 🟠 Warning | Investigate |
| <70 | 🔴 Critical | Immediate review |

---

## 📋 Sample Output
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

---

## 🚀 How to Run

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

---

## 📁 Files

| File | Description |
|------|-------------|
| `sql/01_create_dq_schema.sql` | Schema and types |
| `sql/02_create_dq_tables.sql` | Metadata and results tables |
| `sql/03_create_dq_procedures.sql` | Validation procedures |
| `sql/04_sample_rules_config.sql` | Example rule configurations |
| `data/sample_dirty_data.sql` | Test data with intentional issues |
| `docs/rule_configuration_guide.md` | How to set up rules |

---

## 💡 Key Design Principles

1. **Metadata-driven** - Rules are configured in tables, not hardcoded
2. **Scalable** - Add new tables/rules without code changes
3. **Historical** - Track quality trends over time
4. **Actionable** - Clear thresholds and exception reporting
