/*
    Data Quality Audit Framework
    04_sample_rules_config.sql
    
    Example rules configuration for a customers table.
    Demonstrates various rule types and configurations.
*/

-- First, create a sample table to validate
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'demo')
    EXEC('CREATE SCHEMA demo');
GO

-- Sample customers table
CREATE TABLE demo.customers (
    customer_id     INT PRIMARY KEY,
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    email           VARCHAR(100),
    phone           VARCHAR(20),
    address         VARCHAR(200),
    city            VARCHAR(50),
    state           VARCHAR(2),
    zip_code        VARCHAR(10),
    created_date    DATE,
    modified_date   DATE,
    is_active       BIT DEFAULT 1
);
GO

-- ============================================================
-- Configure Quality Rules for Customers Table
-- ============================================================

-- COMPLETENESS Rules
EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'COMPLETENESS',
    @rule_subtype = 'NULL_CHECK',
    @rule_description = 'Email should be populated for all customers',
    @threshold_pct = 95.0,
    @severity = 'WARNING';

EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'first_name',
    @rule_type = 'COMPLETENESS',
    @rule_subtype = 'NULL_CHECK',
    @rule_description = 'First name is required',
    @threshold_pct = 100.0,
    @severity = 'CRITICAL';

EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'last_name',
    @rule_type = 'COMPLETENESS',
    @rule_subtype = 'NULL_CHECK',
    @rule_description = 'Last name is required',
    @threshold_pct = 100.0,
    @severity = 'CRITICAL';

EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'phone',
    @rule_type = 'COMPLETENESS',
    @rule_subtype = 'NULL_CHECK',
    @rule_description = 'Phone should be populated',
    @threshold_pct = 90.0,
    @severity = 'WARNING';

-- UNIQUENESS Rules
EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'customer_id',
    @rule_type = 'UNIQUENESS',
    @rule_subtype = 'DUPLICATE',
    @rule_description = 'Customer ID must be unique',
    @threshold_pct = 100.0,
    @severity = 'CRITICAL';

EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'UNIQUENESS',
    @rule_subtype = 'DUPLICATE',
    @rule_description = 'Email should be unique per customer',
    @threshold_pct = 100.0,
    @severity = 'WARNING';

-- VALIDITY Rules
EXEC dq.usp_add_rule 
    @table_schema = 'demo',
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'VALIDITY',
    @rule_subtype = 'EMAIL_FORMAT',
    @rule_description = 'Email must be in valid format',
    @threshold_pct = 98.0,
    @severity = 'WARNING';

-- View configured rules
SELECT 
    rule_id,
    table_name,
    column_name,
    rule_type,
    rule_subtype,
    threshold_pct,
    severity,
    is_active
FROM dq.quality_rules
ORDER BY table_name, rule_type, column_name;
GO

PRINT 'Sample rules configured successfully.';
PRINT 'Run: EXEC dq.usp_run_quality_audit @table_schema = ''demo'', @table_name = ''customers'';';
GO
