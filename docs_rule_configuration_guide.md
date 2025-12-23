# Rule Configuration Guide

## Overview

This guide explains how to configure data quality rules in the framework. Rules are metadata-driven, meaning you add rows to the `dq.rules` table rather than writing code.

---

## Quick Start

Add a rule using the helper procedure:
```sql
EXEC dq.usp_add_rule 
    @table_name = 'your_table',
    @column_name = 'your_column',
    @rule_type = 'NULL_CHECK',
    @threshold_pct = 95.0,
    @severity = 'HIGH';
```

---

## Rule Types Reference

### Completeness Rules

| Rule Type | Purpose | Required Parameters |
|-----------|---------|---------------------|
| `NULL_CHECK` | Check for NULL values | column_name, threshold_pct |
| `EMPTY_CHECK` | Check for empty strings | column_name, threshold_pct |
| `REQUIRED` | Field must be populated | column_name, threshold_pct |

**Example:**
```sql
-- Email must be 95% populated
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'NULL_CHECK',
    @threshold_pct = 95.0;
```

---

### Uniqueness Rules

| Rule Type | Purpose | Required Parameters |
|-----------|---------|---------------------|
| `DUPLICATE` | Find duplicate values | column_name |
| `PK_VIOLATION` | Primary key must be unique | column_name |

**Example:**
```sql
-- Email must be unique
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'DUPLICATE',
    @severity = 'HIGH';
```

---

### Validity Rules

| Rule Type | Purpose | Required Parameters |
|-----------|---------|---------------------|
| `RANGE_CHECK` | Value within min/max | column_name, min_value, max_value |
| `DOMAIN_CHECK` | Value in allowed list | column_name, allowed_values |
| `FORMAT_EMAIL` | Valid email format | column_name |
| `FORMAT_PHONE` | Valid phone format | column_name |
| `REGEX_MATCH` | Matches custom pattern | column_name, regex_pattern |

**Examples:**
```sql
-- Age must be between 0 and 120
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'age',
    @rule_type = 'RANGE_CHECK',
    @min_value = '0',
    @max_value = '120';

-- State must be valid code
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'state_code',
    @rule_type = 'DOMAIN_CHECK',
    @allowed_values = 'AL,AK,AZ,AR,CA,CO,CT,DE,FL,GA,HI,ID,IL,IN,IA,KS,KY,LA,ME,MD,MA,MI,MN,MS,MO,MT,NE,NV,NH,NJ,NM,NY,NC,ND,OH,OK,OR,PA,RI,SC,SD,TN,TX,UT,VT,VA,WA,WV,WI,WY,DC';
```

---

### Consistency Rules

| Rule Type | Purpose | Required Parameters |
|-----------|---------|---------------------|
| `FK_CHECK` | Foreign key exists in parent | column_name, reference_table, reference_column |
| `CROSS_FIELD` | Compare two columns | column_name, related_column, comparison_operator |

**Examples:**
```sql
-- Segment ID must exist in segments table
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'segment_id',
    @rule_type = 'FK_CHECK',
    @reference_table = 'segments',
    @reference_column = 'segment_id';

-- End date must be after start date
EXEC dq.usp_add_rule 
    @table_name = 'projects',
    @column_name = 'end_date',
    @rule_type = 'CROSS_FIELD',
    @related_column = 'start_date',
    @comparison_operator = '>=';
```

---

## Threshold Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `threshold_pct` | 95.0 | Pass if result >= this percentage |
| `warning_pct` | 90.0 | Warn if between warning and threshold |

**Threshold Logic:**
- `>= threshold_pct` → **PASS** ✓
- `>= warning_pct` → **WARN** ⚠
- `< warning_pct` → **FAIL** ✗

---

## Severity Levels

| Severity | Score Impact | Use When |
|----------|--------------|----------|
| `CRITICAL` | -25 points | Data is unusable |
| `HIGH` | -15 points | Significant business impact |
| `MEDIUM` | -10 points | Moderate issues |
| `LOW` | -5 points | Minor issues |
| `INFO` | 0 points | Tracking only |

---

## Running Audits

### Single Table
```sql
EXEC dq.usp_run_quality_audit @table_name = 'customers';
```

### View Results
```sql
-- Today's results
SELECT * FROM dq.results WHERE run_date = CAST(GETDATE() AS DATE);

-- Table scores
SELECT * FROM dq.table_scores WHERE table_name = 'customers';

-- Failed checks only
SELECT r.*, ru.rule_name
FROM dq.results r
JOIN dq.rules ru ON r.rule_id = ru.rule_id
WHERE r.status = 'FAIL' AND r.run_date = CAST(GETDATE() AS DATE);
```

---

## Best Practices

1. **Start simple** - Add NULL_CHECK rules first, then expand
2. **Set realistic thresholds** - 100% is often unrealistic; start at 95%
3. **Use appropriate severity** - Not everything is CRITICAL
4. **Review regularly** - Adjust thresholds based on actual data quality
5. **Document business rules** - Use rule_name to explain WHY a rule exists

---

## Troubleshooting

### Rule not running?
- Check `is_active = 1` in dq.rules
- Verify table_schema matches (default is 'dbo')

### Unexpected results?
- Check threshold_pct setting
- Verify column_name spelling
- Look at error_message in dq.results

### Performance issues?
- Add indexes on columns being checked
- Run audits during off-peak hours
- Consider sampling for very large tables
