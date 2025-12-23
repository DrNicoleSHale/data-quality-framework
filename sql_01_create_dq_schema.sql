-- ============================================================================
-- DATA QUALITY FRAMEWORK - CORE TABLES
-- ============================================================================
-- PURPOSE: Create the tables that store rules, results, and history.
--
-- TABLE OVERVIEW:
--   dq.rules          - Configuration: what to check
--   dq.results        - Current run: what we found
--   dq.results_history - Historical: trends over time
--   dq.exceptions     - Details: individual bad records
-- ============================================================================

-- ============================================================================
-- RULES TABLE: What to check
-- ============================================================================
-- This is the heart of the framework - metadata-driven validation.
-- Add rows here to configure new checks without writing code.

CREATE TABLE dq.rules (
    rule_id             INT IDENTITY(1,1) PRIMARY KEY,
    rule_name           VARCHAR(100) NOT NULL,
    table_schema        VARCHAR(50) NOT NULL DEFAULT 'dbo',
    table_name          VARCHAR(100) NOT NULL,
    column_name         VARCHAR(100),           -- NULL for table-level checks
    rule_type           VARCHAR(20) NOT NULL,   -- FK to rule_types
    
    -- Threshold configuration
    threshold_pct       DECIMAL(5,2) DEFAULT 95.0,  -- Pass if >= this %
    warning_pct         DECIMAL(5,2) DEFAULT 90.0,  -- Warn if between warning and threshold
    
    -- For range checks
    min_value           VARCHAR(100),
    max_value           VARCHAR(100),
    
    -- For domain checks (comma-separated list or subquery)
    allowed_values      VARCHAR(MAX),
    
    -- For regex checks
    regex_pattern       VARCHAR(500),
    
    -- For FK checks
    reference_table     VARCHAR(100),
    reference_column    VARCHAR(100),
    
    -- For cross-field checks
    related_column      VARCHAR(100),
    comparison_operator VARCHAR(10),            -- '>', '<', '>=', '<=', '=', '<>'
    
    -- Metadata
    severity            VARCHAR(10) DEFAULT 'MEDIUM',
    is_active           BIT DEFAULT 1,
    created_date        DATETIME DEFAULT GETDATE(),
    created_by          VARCHAR(50) DEFAULT SYSTEM_USER,
    
    CONSTRAINT FK_rules_rule_type FOREIGN KEY (rule_type) 
        REFERENCES dq.rule_types(rule_type_code),
    CONSTRAINT FK_rules_severity FOREIGN KEY (severity) 
        REFERENCES dq.severity_levels(severity_code)
);

CREATE INDEX IX_rules_table ON dq.rules(table_schema, table_name);
CREATE INDEX IX_rules_active ON dq.rules(is_active) WHERE is_active = 1;


-- ============================================================================
-- RESULTS TABLE: Current run findings
-- ============================================================================
-- Stores the outcome of each rule check for the most recent run.

CREATE TABLE dq.results (
    result_id           INT IDENTITY(1,1) PRIMARY KEY,
    rule_id             INT NOT NULL,
    run_date            DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    run_timestamp       DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- Measurements
    total_records       INT,
    passed_records      INT,
    failed_records      INT,
    pass_percentage     DECIMAL(5,2),
    
    -- Outcome
    status              VARCHAR(10) NOT NULL,   -- PASS, FAIL, WARN, ERROR
    threshold_used      DECIMAL(5,2),
    
    -- For debugging
    error_message       VARCHAR(MAX),
    execution_time_ms   INT,
    
    CONSTRAINT FK_results_rule FOREIGN KEY (rule_id) REFERENCES dq.rules(rule_id),
    CONSTRAINT FK_results_status FOREIGN KEY (status) REFERENCES dq.status_codes(status_code)
);

CREATE INDEX IX_results_date ON dq.results(run_date);
CREATE INDEX IX_results_rule ON dq.results(rule_id);
CREATE INDEX IX_results_status ON dq.results(status) WHERE status IN ('FAIL', 'WARN');


-- ============================================================================
-- RESULTS HISTORY: Trend tracking
-- ============================================================================
-- Preserves historical results for trend analysis and reporting.

CREATE TABLE dq.results_history (
    history_id          INT IDENTITY(1,1) PRIMARY KEY,
    rule_id             INT NOT NULL,
    run_date            DATE NOT NULL,
    run_timestamp       DATETIME NOT NULL,
    
    total_records       INT,
    passed_records      INT,
    failed_records      INT,
    pass_percentage     DECIMAL(5,2),
    status              VARCHAR(10) NOT NULL,
    
    CONSTRAINT FK_history_rule FOREIGN KEY (rule_id) REFERENCES dq.rules(rule_id)
);

CREATE INDEX IX_history_rule_date ON dq.results_history(rule_id, run_date);


-- ============================================================================
-- EXCEPTIONS TABLE: Individual bad records
-- ============================================================================
-- Stores the actual records that failed validation for remediation.

CREATE TABLE dq.exceptions (
    exception_id        INT IDENTITY(1,1) PRIMARY KEY,
    result_id           INT NOT NULL,
    rule_id             INT NOT NULL,
    run_date            DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    
    -- Identify the bad record
    primary_key_value   VARCHAR(500),           -- PK of the failing record
    column_value        VARCHAR(MAX),           -- The actual bad value
    
    -- Context
    failure_reason      VARCHAR(500),
    
    -- Remediation tracking
    is_resolved         BIT DEFAULT 0,
    resolved_date       DATETIME,
    resolved_by         VARCHAR(50),
    resolution_notes    VARCHAR(MAX),
    
    CONSTRAINT FK_exceptions_result FOREIGN KEY (result_id) REFERENCES dq.results(result_id),
    CONSTRAINT FK_exceptions_rule FOREIGN KEY (rule_id) REFERENCES dq.rules(rule_id)
);

CREATE INDEX IX_exceptions_unresolved ON dq.exceptions(is_resolved) WHERE is_resolved = 0;
CREATE INDEX IX_exceptions_rule ON dq.exceptions(rule_id, run_date);


-- ============================================================================
-- TABLE SCORES: Aggregated quality score per table
-- ============================================================================

CREATE TABLE dq.table_scores (
    score_id            INT IDENTITY(1,1) PRIMARY KEY,
    table_schema        VARCHAR(50) NOT NULL,
    table_name          VARCHAR(100) NOT NULL,
    run_date            DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    
    -- Dimension scores (0-25 each)
    completeness_score  DECIMAL(5,2),
    uniqueness_score    DECIMAL(5,2),
    validity_score      DECIMAL(5,2),
    consistency_score   DECIMAL(5,2),
    
    -- Overall (0-100)
    overall_score       DECIMAL(5,2),
    grade               CHAR(1),                -- A, B, C, D, F
    
    -- Counts
    total_rules         INT,
    passed_rules        INT,
    failed_rules        INT,
    
    run_timestamp       DATETIME DEFAULT GETDATE()
);

CREATE UNIQUE INDEX IX_table_scores_key ON dq.table_scores(table_schema, table_name, run_date);


PRINT 'Data Quality core tables created successfully.';
