-- ============================================================================
-- DATA QUALITY FRAMEWORK - STORED PROCEDURES
-- ============================================================================
-- PURPOSE: Procedures that execute data quality checks and record results.
--
-- KEY PROCEDURES:
--   usp_run_quality_audit    - Main entry point, runs all checks for a table
--   usp_check_completeness   - NULL and empty checks
--   usp_check_uniqueness     - Duplicate detection
--   usp_check_validity       - Format and range validation
--   usp_check_consistency    - Referential integrity
--   usp_calculate_score      - Compute overall quality score
-- ============================================================================

-- ============================================================================
-- HELPER: Add a new rule
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_add_rule
    @table_name         VARCHAR(100),
    @column_name        VARCHAR(100) = NULL,
    @rule_type          VARCHAR(20),
    @threshold_pct      DECIMAL(5,2) = 95.0,
    @severity           VARCHAR(10) = 'MEDIUM',
    @table_schema       VARCHAR(50) = 'dbo',
    @min_value          VARCHAR(100) = NULL,
    @max_value          VARCHAR(100) = NULL,
    @allowed_values     VARCHAR(MAX) = NULL,
    @reference_table    VARCHAR(100) = NULL,
    @reference_column   VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @rule_name VARCHAR(100);
    SET @rule_name = CONCAT(@table_name, '.', COALESCE(@column_name, '*'), ' - ', @rule_type);
    
    INSERT INTO dq.rules (
        rule_name, table_schema, table_name, column_name, rule_type,
        threshold_pct, severity, min_value, max_value, allowed_values,
        reference_table, reference_column
    ) VALUES (
        @rule_name, @table_schema, @table_name, @column_name, @rule_type,
        @threshold_pct, @severity, @min_value, @max_value, @allowed_values,
        @reference_table, @reference_column
    );
    
    PRINT CONCAT('Rule added: ', @rule_name);
END;
GO


-- ============================================================================
-- CHECK: Completeness (NULL and empty values)
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_check_completeness
    @rule_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @table_schema VARCHAR(50), @table_name VARCHAR(100), @column_name VARCHAR(100);
    DECLARE @threshold DECIMAL(5,2), @warning DECIMAL(5,2);
    DECLARE @total INT, @passed INT, @failed INT, @pass_pct DECIMAL(5,2);
    DECLARE @status VARCHAR(10);
    DECLARE @start_time DATETIME = GETDATE();
    
    -- Get rule configuration
    SELECT 
        @table_schema = table_schema,
        @table_name = table_name,
        @column_name = column_name,
        @threshold = threshold_pct,
        @warning = warning_pct
    FROM dq.rules WHERE rule_id = @rule_id;
    
    -- Build and execute dynamic SQL
    SET @sql = N'
        SELECT 
            @total_out = COUNT(*),
            @passed_out = SUM(CASE WHEN ' + QUOTENAME(@column_name) + ' IS NOT NULL 
                                    AND LTRIM(RTRIM(' + QUOTENAME(@column_name) + ')) <> '''' 
                               THEN 1 ELSE 0 END)
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name);
    
    EXEC sp_executesql @sql,
        N'@total_out INT OUTPUT, @passed_out INT OUTPUT',
        @total_out = @total OUTPUT, @passed_out = @passed OUTPUT;
    
    -- Calculate results
    SET @failed = @total - @passed;
    SET @pass_pct = CASE WHEN @total > 0 THEN CAST(@passed AS DECIMAL(10,2)) / @total * 100 ELSE 100 END;
    SET @status = CASE 
        WHEN @pass_pct >= @threshold THEN 'PASS'
        WHEN @pass_pct >= @warning THEN 'WARN'
        ELSE 'FAIL'
    END;
    
    -- Record result
    INSERT INTO dq.results (rule_id, total_records, passed_records, failed_records, 
                            pass_percentage, status, threshold_used, execution_time_ms)
    VALUES (@rule_id, @total, @passed, @failed, @pass_pct, @status, @threshold,
            DATEDIFF(MILLISECOND, @start_time, GETDATE()));
END;
GO


-- ============================================================================
-- CHECK: Uniqueness (duplicates)
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_check_uniqueness
    @rule_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @table_schema VARCHAR(50), @table_name VARCHAR(100), @column_name VARCHAR(100);
    DECLARE @threshold DECIMAL(5,2);
    DECLARE @total INT, @duplicates INT, @pass_pct DECIMAL(5,2);
    DECLARE @status VARCHAR(10);
    DECLARE @start_time DATETIME = GETDATE();
    
    SELECT 
        @table_schema = table_schema,
        @table_name = table_name,
        @column_name = column_name,
        @threshold = threshold_pct
    FROM dq.rules WHERE rule_id = @rule_id;
    
    -- Count total and duplicates
    SET @sql = N'
        SELECT @total_out = COUNT(*) FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + ';
        
        SELECT @dup_out = COUNT(*) FROM (
            SELECT ' + QUOTENAME(@column_name) + '
            FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + '
            WHERE ' + QUOTENAME(@column_name) + ' IS NOT NULL
            GROUP BY ' + QUOTENAME(@column_name) + '
            HAVING COUNT(*) > 1
        ) dups;';
    
    EXEC sp_executesql @sql,
        N'@total_out INT OUTPUT, @dup_out INT OUTPUT',
        @total_out = @total OUTPUT, @dup_out = @duplicates OUTPUT;
    
    SET @pass_pct = CASE WHEN @total > 0 THEN CAST(@total - @duplicates AS DECIMAL(10,2)) / @total * 100 ELSE 100 END;
    SET @status = CASE WHEN @duplicates = 0 THEN 'PASS' ELSE 'FAIL' END;
    
    INSERT INTO dq.results (rule_id, total_records, passed_records, failed_records,
                            pass_percentage, status, threshold_used, execution_time_ms)
    VALUES (@rule_id, @total, @total - @duplicates, @duplicates, @pass_pct, @status, @threshold,
            DATEDIFF(MILLISECOND, @start_time, GETDATE()));
END;
GO


-- ============================================================================
-- CHECK: Validity - Range
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_check_range
    @rule_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @table_schema VARCHAR(50), @table_name VARCHAR(100), @column_name VARCHAR(100);
    DECLARE @min_val VARCHAR(100), @max_val VARCHAR(100), @threshold DECIMAL(5,2);
    DECLARE @total INT, @passed INT, @pass_pct DECIMAL(5,2);
    DECLARE @status VARCHAR(10);
    DECLARE @start_time DATETIME = GETDATE();
    
    SELECT 
        @table_schema = table_schema,
        @table_name = table_name,
        @column_name = column_name,
        @min_val = min_value,
        @max_val = max_value,
        @threshold = threshold_pct
    FROM dq.rules WHERE rule_id = @rule_id;
    
    SET @sql = N'
        SELECT 
            @total_out = COUNT(*),
            @passed_out = SUM(CASE 
                WHEN ' + QUOTENAME(@column_name) + ' >= ' + @min_val + ' 
                 AND ' + QUOTENAME(@column_name) + ' <= ' + @max_val + ' 
                THEN 1 ELSE 0 END)
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + '
        WHERE ' + QUOTENAME(@column_name) + ' IS NOT NULL';
    
    EXEC sp_executesql @sql,
        N'@total_out INT OUTPUT, @passed_out INT OUTPUT',
        @total_out = @total OUTPUT, @passed_out = @passed OUTPUT;
    
    SET @pass_pct = CASE WHEN @total > 0 THEN CAST(@passed AS DECIMAL(10,2)) / @total * 100 ELSE 100 END;
    SET @status = CASE WHEN @pass_pct >= @threshold THEN 'PASS' ELSE 'FAIL' END;
    
    INSERT INTO dq.results (rule_id, total_records, passed_records, failed_records,
                            pass_percentage, status, threshold_used, execution_time_ms)
    VALUES (@rule_id, @total, @passed, @total - @passed, @pass_pct, @status, @threshold,
            DATEDIFF(MILLISECOND, @start_time, GETDATE()));
END;
GO


-- ============================================================================
-- CHECK: Consistency - Foreign Key
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_check_fk
    @rule_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @table_schema VARCHAR(50), @table_name VARCHAR(100), @column_name VARCHAR(100);
    DECLARE @ref_table VARCHAR(100), @ref_column VARCHAR(100), @threshold DECIMAL(5,2);
    DECLARE @total INT, @orphans INT, @pass_pct DECIMAL(5,2);
    DECLARE @status VARCHAR(10);
    DECLARE @start_time DATETIME = GETDATE();
    
    SELECT 
        @table_schema = table_schema,
        @table_name = table_name,
        @column_name = column_name,
        @ref_table = reference_table,
        @ref_column = reference_column,
        @threshold = threshold_pct
    FROM dq.rules WHERE rule_id = @rule_id;
    
    SET @sql = N'
        SELECT @total_out = COUNT(*) 
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + '
        WHERE ' + QUOTENAME(@column_name) + ' IS NOT NULL;
        
        SELECT @orphans_out = COUNT(*)
        FROM ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name) + ' src
        LEFT JOIN ' + QUOTENAME(@table_schema) + '.' + QUOTENAME(@ref_table) + ' ref
            ON src.' + QUOTENAME(@column_name) + ' = ref.' + QUOTENAME(@ref_column) + '
        WHERE src.' + QUOTENAME(@column_name) + ' IS NOT NULL
          AND ref.' + QUOTENAME(@ref_column) + ' IS NULL;';
    
    EXEC sp_executesql @sql,
        N'@total_out INT OUTPUT, @orphans_out INT OUTPUT',
        @total_out = @total OUTPUT, @orphans_out = @orphans OUTPUT;
    
    SET @pass_pct = CASE WHEN @total > 0 THEN CAST(@total - @orphans AS DECIMAL(10,2)) / @total * 100 ELSE 100 END;
    SET @status = CASE WHEN @orphans = 0 THEN 'PASS' ELSE 'FAIL' END;
    
    INSERT INTO dq.results (rule_id, total_records, passed_records, failed_records,
                            pass_percentage, status, threshold_used, execution_time_ms)
    VALUES (@rule_id, @total, @total - @orphans, @orphans, @pass_pct, @status, @threshold,
            DATEDIFF(MILLISECOND, @start_time, GETDATE()));
END;
GO


-- ============================================================================
-- MAIN: Run all checks for a table
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_run_quality_audit
    @table_name VARCHAR(100),
    @table_schema VARCHAR(50) = 'dbo'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @rule_id INT, @rule_type VARCHAR(20);
    DECLARE @rules_processed INT = 0;
    
    PRINT CONCAT('Starting quality audit for ', @table_schema, '.', @table_name);
    PRINT CONCAT('Run time: ', GETDATE());
    PRINT '----------------------------------------';
    
    -- Cursor through active rules for this table
    DECLARE rule_cursor CURSOR FOR
        SELECT rule_id, rule_type 
        FROM dq.rules 
        WHERE table_schema = @table_schema 
          AND table_name = @table_name
          AND is_active = 1;
    
    OPEN rule_cursor;
    FETCH NEXT FROM rule_cursor INTO @rule_id, @rule_type;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT CONCAT('Running rule #', @rule_id, ': ', @rule_type);
        
        -- Route to appropriate check procedure
        IF @rule_type IN ('NULL_CHECK', 'EMPTY_CHECK', 'REQUIRED')
            EXEC dq.usp_check_completeness @rule_id;
        ELSE IF @rule_type IN ('DUPLICATE', 'PK_VIOLATION')
            EXEC dq.usp_check_uniqueness @rule_id;
        ELSE IF @rule_type = 'RANGE_CHECK'
            EXEC dq.usp_check_range @rule_id;
        ELSE IF @rule_type = 'FK_CHECK'
            EXEC dq.usp_check_fk @rule_id;
        
        SET @rules_processed = @rules_processed + 1;
        FETCH NEXT FROM rule_cursor INTO @rule_id, @rule_type;
    END;
    
    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;
    
    -- Calculate overall score
    EXEC dq.usp_calculate_table_score @table_name, @table_schema;
    
    PRINT '----------------------------------------';
    PRINT CONCAT('Audit complete. ', @rules_processed, ' rules processed.');
END;
GO


-- ============================================================================
-- SCORING: Calculate table quality score
-- ============================================================================
CREATE OR ALTER PROCEDURE dq.usp_calculate_table_score
    @table_name VARCHAR(100),
    @table_schema VARCHAR(50) = 'dbo'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @completeness DECIMAL(5,2), @uniqueness DECIMAL(5,2);
    DECLARE @validity DECIMAL(5,2), @consistency DECIMAL(5,2);
    DECLARE @overall DECIMAL(5,2), @grade CHAR(1);
    DECLARE @total_rules INT, @passed_rules INT;
    
    -- Get today's results by dimension
    SELECT 
        @completeness = AVG(CASE WHEN rt.dimension = 'COMPLETENESS' THEN r.pass_percentage END),
        @uniqueness = AVG(CASE WHEN rt.dimension = 'UNIQUENESS' THEN r.pass_percentage END),
        @validity = AVG(CASE WHEN rt.dimension = 'VALIDITY' THEN r.pass_percentage END),
        @consistency = AVG(CASE WHEN rt.dimension = 'CONSISTENCY' THEN r.pass_percentage END),
        @total_rules = COUNT(*),
        @passed_rules = SUM(CASE WHEN r.status = 'PASS' THEN 1 ELSE 0 END)
    FROM dq.results r
    JOIN dq.rules ru ON r.rule_id = ru.rule_id
    JOIN dq.rule_types rt ON ru.rule_type = rt.rule_type_code
    WHERE ru.table_schema = @table_schema
      AND ru.table_name = @table_name
      AND r.run_date = CAST(GETDATE() AS DATE);
    
    -- Convert to 0-25 scale and calculate overall
    SET @completeness = COALESCE(@completeness / 4, 25);
    SET @uniqueness = COALESCE(@uniqueness / 4, 25);
    SET @validity = COALESCE(@validity / 4, 25);
    SET @consistency = COALESCE(@consistency / 4, 25);
    SET @overall = @completeness + @uniqueness + @validity + @consistency;
    
    -- Assign grade
    SET @grade = CASE 
        WHEN @overall >= 95 THEN 'A'
        WHEN @overall >= 85 THEN 'B'
        WHEN @overall >= 70 THEN 'C'
        WHEN @overall >= 60 THEN 'D'
        ELSE 'F'
    END;
    
    -- Save score
    INSERT INTO dq.table_scores (table_schema, table_name, completeness_score, uniqueness_score,
                                  validity_score, consistency_score, overall_score, grade,
                                  total_rules, passed_rules)
    VALUES (@table_schema, @table_name, @completeness, @uniqueness, @validity, @consistency,
            @overall, @grade, @total_rules, @passed_rules);
    
    PRINT CONCAT('Quality Score: ', @overall, '/100 (Grade: ', @grade, ')');
END;
GO


PRINT 'Data Quality procedures created successfully.';
