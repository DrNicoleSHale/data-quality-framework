/*
    Data Quality Audit Framework
    03_create_dq_procedures.sql
    
    Procedures for running quality checks and generating reports.
*/

-- ============================================================
-- Helper: Add a quality rule
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_add_rule
    @table_schema VARCHAR(50) = 'dbo',
    @table_name VARCHAR(100),
    @column_name VARCHAR(100) = NULL,
    @rule_type VARCHAR(50),
    @rule_subtype VARCHAR(50) = NULL,
    @rule_description VARCHAR(500) = NULL,
    @threshold_pct DECIMAL(5,2) = 95.0,
    @severity VARCHAR(20) = 'WARNING',
    @check_sql NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO dq.quality_rules (
        table_schema, table_name, column_name, rule_type, rule_subtype,
        rule_description, threshold_pct, severity, check_sql
    )
    VALUES (
        @table_schema, @table_name, @column_name, @rule_type, @rule_subtype,
        @rule_description, @threshold_pct, @severity, @check_sql
    );
    
    PRINT 'Rule added successfully. Rule ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END;
GO

-- ============================================================
-- Check: Completeness (NULL check)
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_check_completeness
    @run_id UNIQUEIDENTIFIER,
    @table_schema VARCHAR(50),
    @table_name VARCHAR(100),
    @column_name VARCHAR(100),
    @rule_id INT,
    @threshold_pct DECIMAL(5,2)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @total_rows INT;
    DECLARE @null_rows INT;
    DECLARE @pass_rate DECIMAL(5,2);
    DECLARE @status VARCHAR(20);
    DECLARE @start_time DATETIME = GETDATE();
    
    -- Build dynamic SQL for NULL check
    SET @sql = N'
        SELECT 
            @total = COUNT(*),
            @nulls = SUM(CASE WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN 1 ELSE 0 END)
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name);
    
    EXEC sp_executesql @sql, 
        N'@total INT OUTPUT, @nulls INT OUTPUT',
        @total = @total_rows OUTPUT,
        @nulls = @null_rows OUTPUT;
    
    -- Calculate pass rate
    SET @pass_rate = CASE 
        WHEN @total_rows = 0 THEN 100.0
        ELSE ((@total_rows - @null_rows) * 100.0 / @total_rows)
    END;
    
    SET @status = CASE
        WHEN @pass_rate >= @threshold_pct THEN 'PASS'
        WHEN @pass_rate >= @threshold_pct - 10 THEN 'WARNING'
        ELSE 'FAIL'
    END;
    
    -- Insert result
    INSERT INTO dq.quality_results (
        run_id, run_date, run_timestamp, rule_id,
        table_schema, table_name, column_name, rule_type,
        total_rows, passed_rows, failed_rows, pass_rate,
        threshold_pct, status, execution_ms
    )
    VALUES (
        @run_id, CAST(GETDATE() AS DATE), GETDATE(), @rule_id,
        @table_schema, @table_name, @column_name, 'COMPLETENESS',
        @total_rows, @total_rows - @null_rows, @null_rows, @pass_rate,
        @threshold_pct, @status, DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );
END;
GO

-- ============================================================
-- Check: Uniqueness (Duplicate detection)
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_check_uniqueness
    @run_id UNIQUEIDENTIFIER,
    @table_schema VARCHAR(50),
    @table_name VARCHAR(100),
    @column_name VARCHAR(100),
    @rule_id INT,
    @threshold_pct DECIMAL(5,2)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @total_rows INT;
    DECLARE @duplicate_rows INT;
    DECLARE @pass_rate DECIMAL(5,2);
    DECLARE @status VARCHAR(20);
    DECLARE @start_time DATETIME = GETDATE();
    
    -- Count total rows
    SET @sql = N'SELECT @total = COUNT(*) FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name);
    EXEC sp_executesql @sql, N'@total INT OUTPUT', @total = @total_rows OUTPUT;
    
    -- Count duplicate rows
    SET @sql = N'
        SELECT @dups = SUM(dup_count - 1)
        FROM (
            SELECT ' + QUOTENAME(@column_name) + ', COUNT(*) as dup_count
            FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + '
            WHERE ' + QUOTENAME(@column_name) + ' IS NOT NULL
            GROUP BY ' + QUOTENAME(@column_name) + '
            HAVING COUNT(*) > 1
        ) dupes';
    
    EXEC sp_executesql @sql, N'@dups INT OUTPUT', @dups = @duplicate_rows OUTPUT;
    SET @duplicate_rows = ISNULL(@duplicate_rows, 0);
    
    -- Calculate pass rate (unique rows / total rows)
    SET @pass_rate = CASE 
        WHEN @total_rows = 0 THEN 100.0
        ELSE ((@total_rows - @duplicate_rows) * 100.0 / @total_rows)
    END;
    
    SET @status = CASE
        WHEN @pass_rate >= @threshold_pct THEN 'PASS'
        WHEN @pass_rate >= @threshold_pct - 10 THEN 'WARNING'
        ELSE 'FAIL'
    END;
    
    -- Insert result
    INSERT INTO dq.quality_results (
        run_id, run_date, run_timestamp, rule_id,
        table_schema, table_name, column_name, rule_type,
        total_rows, passed_rows, failed_rows, pass_rate,
        threshold_pct, status, execution_ms
    )
    VALUES (
        @run_id, CAST(GETDATE() AS DATE), GETDATE(), @rule_id,
        @table_schema, @table_name, @column_name, 'UNIQUENESS',
        @total_rows, @total_rows - @duplicate_rows, @duplicate_rows, @pass_rate,
        @threshold_pct, @status, DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );
END;
GO

-- ============================================================
-- Check: Validity - Email Format
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_check_email_format
    @run_id UNIQUEIDENTIFIER,
    @table_schema VARCHAR(50),
    @table_name VARCHAR(100),
    @column_name VARCHAR(100),
    @rule_id INT,
    @threshold_pct DECIMAL(5,2)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @total_rows INT;
    DECLARE @invalid_rows INT;
    DECLARE @pass_rate DECIMAL(5,2);
    DECLARE @status VARCHAR(20);
    DECLARE @start_time DATETIME = GETDATE();
    
    -- Email pattern: basic validation
    SET @sql = N'
        SELECT 
            @total = COUNT(*),
            @invalid = SUM(CASE 
                WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN 0
                WHEN ' + QUOTENAME(@column_name) + ' NOT LIKE ''%_@__%.__%'' THEN 1
                WHEN ' + QUOTENAME(@column_name) + ' LIKE ''%[^a-zA-Z0-9.@_-]%'' THEN 1
                ELSE 0
            END)
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name);
    
    EXEC sp_executesql @sql, 
        N'@total INT OUTPUT, @invalid INT OUTPUT',
        @total = @total_rows OUTPUT,
        @invalid = @invalid_rows OUTPUT;
    
    SET @pass_rate = CASE 
        WHEN @total_rows = 0 THEN 100.0
        ELSE ((@total_rows - @invalid_rows) * 100.0 / @total_rows)
    END;
    
    SET @status = CASE
        WHEN @pass_rate >= @threshold_pct THEN 'PASS'
        WHEN @pass_rate >= @threshold_pct - 10 THEN 'WARNING'
        ELSE 'FAIL'
    END;
    
    INSERT INTO dq.quality_results (
        run_id, run_date, run_timestamp, rule_id,
        table_schema, table_name, column_name, rule_type,
        total_rows, passed_rows, failed_rows, pass_rate,
        threshold_pct, status, execution_ms
    )
    VALUES (
        @run_id, CAST(GETDATE() AS DATE), GETDATE(), @rule_id,
        @table_schema, @table_name, @column_name, 'VALIDITY',
        @total_rows, @total_rows - @invalid_rows, @invalid_rows, @pass_rate,
        @threshold_pct, @status, DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );
END;
GO

-- ============================================================
-- Check: Consistency - Referential Integrity (Orphans)
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_check_referential_integrity
    @run_id UNIQUEIDENTIFIER,
    @child_schema VARCHAR(50),
    @child_table VARCHAR(100),
    @child_column VARCHAR(100),
    @parent_schema VARCHAR(50),
    @parent_table VARCHAR(100),
    @parent_column VARCHAR(100),
    @rule_id INT,
    @threshold_pct DECIMAL(5,2)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @total_rows INT;
    DECLARE @orphan_rows INT;
    DECLARE @pass_rate DECIMAL(5,2);
    DECLARE @status VARCHAR(20);
    DECLARE @start_time DATETIME = GETDATE();
    
    -- Count total non-null FK values
    SET @sql = N'SELECT @total = COUNT(*) FROM ' + QUOTENAME(@child_schema) + '.' + QUOTENAME(@child_table) +
               ' WHERE ' + QUOTENAME(@child_column) + ' IS NOT NULL';
    EXEC sp_executesql @sql, N'@total INT OUTPUT', @total = @total_rows OUTPUT;
    
    -- Count orphan records
    SET @sql = N'
        SELECT @orphans = COUNT(*)
        FROM ' + QUOTENAME(@child_schema) + '.' + QUOTENAME(@child_table) + ' c
        WHERE c.' + QUOTENAME(@child_column) + ' IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 FROM ' + QUOTENAME(@parent_schema) + '.' + QUOTENAME(@parent_table) + ' p
            WHERE p.' + QUOTENAME(@parent_column) + ' = c.' + QUOTENAME(@child_column) + '
        )';
    
    EXEC sp_executesql @sql, N'@orphans INT OUTPUT', @orphans = @orphan_rows OUTPUT;
    
    SET @pass_rate = CASE 
        WHEN @total_rows = 0 THEN 100.0
        ELSE ((@total_rows - @orphan_rows) * 100.0 / @total_rows)
    END;
    
    SET @status = CASE
        WHEN @pass_rate >= @threshold_pct THEN 'PASS'
        WHEN @pass_rate >= @threshold_pct - 10 THEN 'WARNING'
        ELSE 'FAIL'
    END;
    
    INSERT INTO dq.quality_results (
        run_id, run_date, run_timestamp, rule_id,
        table_schema, table_name, column_name, rule_type,
        total_rows, passed_rows, failed_rows, pass_rate,
        threshold_pct, status, execution_ms
    )
    VALUES (
        @run_id, CAST(GETDATE() AS DATE), GETDATE(), @rule_id,
        @child_schema, @child_table, @child_column, 'CONSISTENCY',
        @total_rows, @total_rows - @orphan_rows, @orphan_rows, @pass_rate,
        @threshold_pct, @status, DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );
END;
GO

-- ============================================================
-- Master: Run all quality checks for a table
-- ============================================================
CREATE OR ALTER PROCEDURE dq.usp_run_quality_audit
    @table_schema VARCHAR(50) = 'dbo',
    @table_name VARCHAR(100) = NULL  -- NULL = all tables
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @run_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rule_id INT;
    DECLARE @col_name VARCHAR(100);
    DECLARE @rule_type VARCHAR(50);
    DECLARE @rule_subtype VARCHAR(50);
    DECLARE @threshold DECIMAL(5,2);
    DECLARE @check_sql NVARCHAR(MAX);
    
    PRINT '========================================';
    PRINT 'Starting Data Quality Audit';
    PRINT 'Run ID: ' + CAST(@run_id AS VARCHAR(50));
    PRINT 'Start Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '========================================';
    
    -- Cursor through active rules
    DECLARE rule_cursor CURSOR FOR
        SELECT rule_id, column_name, rule_type, rule_subtype, threshold_pct, check_sql
        FROM dq.quality_rules
        WHERE is_active = 1
        AND table_schema = @table_schema
        AND (@table_name IS NULL OR table_name = @table_name)
        ORDER BY table_name, rule_type;
    
    OPEN rule_cursor;
    FETCH NEXT FROM rule_cursor INTO @rule_id, @col_name, @rule_type, @rule_subtype, @threshold, @check_sql;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Running Rule ID ' + CAST(@rule_id AS VARCHAR) + ': ' + @rule_type + ' - ' + ISNULL(@col_name, 'TABLE');
        
        -- Route to appropriate check procedure
        IF @rule_type = 'COMPLETENESS' AND @rule_subtype = 'NULL_CHECK'
            EXEC dq.usp_check_completeness @run_id, @table_schema, @table_name, @col_name, @rule_id, @threshold;
        
        ELSE IF @rule_type = 'UNIQUENESS' AND @rule_subtype = 'DUPLICATE'
            EXEC dq.usp_check_uniqueness @run_id, @table_schema, @table_name, @col_name, @rule_id, @threshold;
        
        ELSE IF @rule_type = 'VALIDITY' AND @rule_subtype = 'EMAIL_FORMAT'
            EXEC dq.usp_check_email_format @run_id, @table_schema, @table_name, @col_name, @rule_id, @threshold;
        
        FETCH NEXT FROM rule_cursor INTO @rule_id, @col_name, @rule_type, @rule_subtype, @threshold, @check_sql;
    END;
    
    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;
    
    -- Calculate and store table summary
    INSERT INTO dq.table_quality_summary (
        run_id, run_date, table_schema, table_name, total_rows,
        completeness_score, uniqueness_score, validity_score, consistency_score,
        overall_score, status
    )
    SELECT 
        @run_id,
        CAST(GETDATE() AS DATE),
        table_schema,
        table_name,
        MAX(total_rows),
        AVG(CASE WHEN rule_type = 'COMPLETENESS' THEN pass_rate END),
        AVG(CASE WHEN rule_type = 'UNIQUENESS' THEN pass_rate END),
        AVG(CASE WHEN rule_type = 'VALIDITY' THEN pass_rate END),
        AVG(CASE WHEN rule_type = 'CONSISTENCY' THEN pass_rate END),
        AVG(pass_rate),
        CASE 
            WHEN MIN(pass_rate) < 70 THEN 'CRITICAL'
            WHEN MIN(pass_rate) < 85 THEN 'WARNING'
            WHEN MIN(pass_rate) < 95 THEN 'GOOD'
            ELSE 'EXCELLENT'
        END
    FROM dq.quality_results
    WHERE run_id = @run_id
    GROUP BY table_schema, table_name;
    
    PRINT '========================================';
    PRINT 'Data Quality Audit Complete';
    PRINT 'End Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '========================================';
    
    -- Return summary
    SELECT * FROM dq.table_quality_summary WHERE run_id = @run_id;
END;
GO

-- ============================================================
-- View: Quality Dashboard
-- ============================================================
CREATE OR ALTER VIEW dq.vw_quality_dashboard
AS
SELECT 
    s.run_date,
    s.table_schema,
    s.table_name,
    s.total_rows,
    s.completeness_score,
    s.uniqueness_score,
    s.validity_score,
    s.consistency_score,
    s.overall_score,
    s.status,
    (SELECT COUNT(*) FROM dq.quality_results r WHERE r.run_id = s.run_id AND r.status = 'PASS') as passed_checks,
    (SELECT COUNT(*) FROM dq.quality_results r WHERE r.run_id = s.run_id AND r.status = 'FAIL') as failed_checks,
    (SELECT COUNT(*) FROM dq.quality_results r WHERE r.run_id = s.run_id AND r.status = 'WARNING') as warning_checks
FROM dq.table_quality_summary s
WHERE s.run_date = (SELECT MAX(run_date) FROM dq.table_quality_summary);
GO

PRINT 'Data quality procedures created successfully.';
GO
