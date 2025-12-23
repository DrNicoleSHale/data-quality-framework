-- ============================================================================
-- DATA QUALITY FRAMEWORK - SCHEMA SETUP
-- ============================================================================
-- PURPOSE: Create the schema and custom types for the data quality framework.
--
-- DESIGN PHILOSOPHY:
--   - Isolated schema keeps DQ objects separate from business data
--   - Custom types ensure consistency across procedures
--   - Easy to deploy to any database
-- ============================================================================

-- Create dedicated schema for data quality objects
CREATE SCHEMA IF NOT EXISTS dq;
GO

-- ============================================================================
-- CUSTOM TYPES FOR CONSISTENCY
-- ============================================================================

-- Rule types enum (as a reference table since SQL Server lacks true enums)
-- This ensures only valid rule types can be configured
CREATE TABLE dq.rule_types (
    rule_type_code      VARCHAR(20) PRIMARY KEY,
    rule_type_desc      VARCHAR(100) NOT NULL,
    dimension           VARCHAR(20) NOT NULL,   -- Which DQ dimension
    default_weight      INT DEFAULT 25
);

INSERT INTO dq.rule_types (rule_type_code, rule_type_desc, dimension) VALUES
-- Completeness checks
('NULL_CHECK', 'Check for NULL values in column', 'COMPLETENESS'),
('EMPTY_CHECK', 'Check for empty strings', 'COMPLETENESS'),
('REQUIRED', 'Required field validation', 'COMPLETENESS'),

-- Uniqueness checks
('DUPLICATE', 'Check for duplicate values', 'UNIQUENESS'),
('PK_VIOLATION', 'Primary key uniqueness', 'UNIQUENESS'),

-- Validity checks
('FORMAT_EMAIL', 'Email format validation', 'VALIDITY'),
('FORMAT_PHONE', 'Phone number format validation', 'VALIDITY'),
('FORMAT_DATE', 'Date format validation', 'VALIDITY'),
('RANGE_CHECK', 'Value within expected range', 'VALIDITY'),
('DOMAIN_CHECK', 'Value in allowed list', 'VALIDITY'),
('REGEX_MATCH', 'Custom regex pattern match', 'VALIDITY'),

-- Consistency checks
('FK_CHECK', 'Foreign key referential integrity', 'CONSISTENCY'),
('CROSS_FIELD', 'Cross-field validation (e.g., end > start)', 'CONSISTENCY'),
('CROSS_TABLE', 'Cross-table consistency', 'CONSISTENCY');
GO

-- ============================================================================
-- SEVERITY LEVELS
-- ============================================================================

CREATE TABLE dq.severity_levels (
    severity_code       VARCHAR(10) PRIMARY KEY,
    severity_desc       VARCHAR(50) NOT NULL,
    score_impact        INT NOT NULL,           -- Points deducted
    requires_action     BIT DEFAULT 0
);

INSERT INTO dq.severity_levels (severity_code, severity_desc, score_impact, requires_action) VALUES
('CRITICAL', 'Data is unusable', 25, 1),
('HIGH', 'Significant data issues', 15, 1),
('MEDIUM', 'Moderate data issues', 10, 0),
('LOW', 'Minor data issues', 5, 0),
('INFO', 'Informational only', 0, 0);
GO

-- ============================================================================
-- STATUS REFERENCE
-- ============================================================================

CREATE TABLE dq.status_codes (
    status_code         VARCHAR(10) PRIMARY KEY,
    status_desc         VARCHAR(50) NOT NULL
);

INSERT INTO dq.status_codes (status_code, status_desc) VALUES
('PASS', 'Check passed - meets threshold'),
('FAIL', 'Check failed - below threshold'),
('WARN', 'Warning - approaching threshold'),
('ERROR', 'Error executing check'),
('SKIP', 'Check skipped');
GO

PRINT 'Data Quality schema and reference tables created successfully.';
