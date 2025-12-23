/*
    Data Quality Audit Framework
    02_create_dq_tables.sql
    
    Creates tables for storing quality rules, results,
    exceptions, and historical trends.
*/

-- Quality Rules Configuration
CREATE TABLE dq.quality_rules (
    rule_id             INT IDENTITY(1,1) PRIMARY KEY,
    table_schema        VARCHAR(50) NOT NULL,
    table_name          VARCHAR(100) NOT NULL,
    column_name         VARCHAR(100),               -- NULL for table-level rules
    rule_type           VARCHAR(50) NOT NULL,       -- COMPLETENESS, UNIQUENESS, VALIDITY, CONSISTENCY
    rule_subtype        VARCHAR(50),                -- NULL_CHECK, DUPLICATE, FORMAT, RANGE, FK, etc.
    rule_description    VARCHAR(500),
    threshold_pct       DECIMAL(5,2) DEFAULT 95.0,  -- Expected pass rate
    severity            VARCHAR(20) DEFAULT 'WARNING', -- CRITICAL, WARNING, INFO
    is_active           BIT DEFAULT 1,
    check_sql           NVARCHAR(MAX),              -- Optional custom SQL
    created_date        DATETIME DEFAULT GETDATE(),
    modified_date       DATETIME DEFAULT GETDATE()
);

-- Quality Results (current run)
CREATE TABLE dq.quality_results (
    result_id           INT IDENTITY(1,1) PRIMARY KEY,
    run_id              UNIQUEIDENTIFIER NOT NULL,
    run_date            DATE NOT NULL,
    run_timestamp       DATETIME NOT NULL,
    rule_id             INT NOT NULL,
    table_schema        VARCHAR(50),
    table_name          VARCHAR(100),
    column_name         VARCHAR(100),
    rule_type           VARCHAR(50),
    total_rows          INT,
    passed_rows         INT,
    failed_rows         INT,
    pass_rate           DECIMAL(5,2),
    threshold_pct       DECIMAL(5,2),
    status              VARCHAR(20),                -- PASS, FAIL, WARNING
    execution_ms        INT,
    CONSTRAINT FK_results_rule FOREIGN KEY (rule_id) REFERENCES dq.quality_rules(rule_id)
);

-- Quality Exceptions (failed records)
CREATE TABLE dq.quality_exceptions (
    exception_id        INT IDENTITY(1,1) PRIMARY KEY,
    run_id              UNIQUEIDENTIFIER NOT NULL,
    rule_id             INT NOT NULL,
    table_name          VARCHAR(100),
    primary_key_value   VARCHAR(500),               -- Concatenated PK for failed record
    column_name         VARCHAR(100),
    actual_value        VARCHAR(500),
    expected_value      VARCHAR(500),
    exception_reason    VARCHAR(500),
    created_date        DATETIME DEFAULT GETDATE(),
    remediated_flag     BIT DEFAULT 0,
    remediated_date     DATETIME,
    remediated_by       VARCHAR(100)
);

-- Historical Trends (daily snapshots)
CREATE TABLE dq.quality_trends (
    trend_id            INT IDENTITY(1,1) PRIMARY KEY,
    snapshot_date       DATE NOT NULL,
    table_schema        VARCHAR(50),
    table_name          VARCHAR(100),
    completeness_score  DECIMAL(5,2),
    uniqueness_score    DECIMAL(5,2),
    validity_score      DECIMAL(5,2),
    consistency_score   DECIMAL(5,2),
    overall_score       DECIMAL(5,2),
    total_rules         INT,
    passed_rules        INT,
    failed_rules        INT,
    warning_rules       INT
);

-- Table Quality Summary (aggregated view)
CREATE TABLE dq.table_quality_summary (
    summary_id          INT IDENTITY(1,1) PRIMARY KEY,
    run_id              UNIQUEIDENTIFIER NOT NULL,
    run_date            DATE NOT NULL,
    table_schema        VARCHAR(50),
    table_name          VARCHAR(100),
    total_rows          INT,
    completeness_score  DECIMAL(5,2),
    uniqueness_score    DECIMAL(5,2),
    validity_score      DECIMAL(5,2),
    consistency_score   DECIMAL(5,2),
    overall_score       DECIMAL(5,2),
    status              VARCHAR(20)
);

-- Create indexes
CREATE INDEX IX_results_run ON dq.quality_results(run_id, run_date);
CREATE INDEX IX_results_table ON dq.quality_results(table_name, rule_type);
CREATE INDEX IX_exceptions_run ON dq.quality_exceptions(run_id);
CREATE INDEX IX_trends_table ON dq.quality_trends(table_name, snapshot_date);

PRINT 'Data quality tables created successfully.';
GO
