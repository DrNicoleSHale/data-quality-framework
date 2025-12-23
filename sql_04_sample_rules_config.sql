-- ============================================================================
-- SAMPLE RULES CONFIGURATION
-- ============================================================================
-- PURPOSE: Example rules demonstrating how to configure the DQ framework.
--          These rules check a sample 'customers' table across all 4 dimensions.
--
-- TO USE: Modify table/column names to match your actual data.
-- ============================================================================

-- ============================================================================
-- SAMPLE TABLE (for testing - create this first)
-- ============================================================================

CREATE TABLE dbo.customers (
    customer_id     INT PRIMARY KEY,
    email           VARCHAR(100),
    phone           VARCHAR(20),
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    state_code      CHAR(2),
    age             INT,
    created_date    DATE,
    modified_date   DATE,
    segment_id      INT              -- FK to segments table
);

CREATE TABLE dbo.segments (
    segment_id      INT PRIMARY KEY,
    segment_name    VARCHAR(50)
);

-- Insert reference data
INSERT INTO dbo.segments VALUES (1, 'Premium'), (2, 'Standard'), (3, 'Basic');

-- ============================================================================
-- COMPLETENESS RULES
-- "Are required fields populated?"
-- ============================================================================

-- Email is required - should be 95%+ populated
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'NULL_CHECK',
    @threshold_pct = 95.0,
    @severity = 'HIGH';

-- Phone is optional but we want to track it - 80% threshold
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'phone',
    @rule_type = 'NULL_CHECK',
    @threshold_pct = 80.0,
    @severity = 'LOW';

-- Names are required
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'first_name',
    @rule_type = 'REQUIRED',
    @threshold_pct = 99.0,
    @severity = 'MEDIUM';

EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'last_name',
    @rule_type = 'REQUIRED',
    @threshold_pct = 99.0,
    @severity = 'MEDIUM';


-- ============================================================================
-- UNIQUENESS RULES
-- "Are there duplicates where there shouldn't be?"
-- ============================================================================

-- Customer ID must be unique (PK)
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'customer_id',
    @rule_type = 'PK_VIOLATION',
    @threshold_pct = 100.0,
    @severity = 'CRITICAL';

-- Email should be unique
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'email',
    @rule_type = 'DUPLICATE',
    @threshold_pct = 100.0,
    @severity = 'HIGH';


-- ============================================================================
-- VALIDITY RULES
-- "Does data match expected formats and ranges?"
-- ============================================================================

-- Age must be between 0 and 120
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'age',
    @rule_type = 'RANGE_CHECK',
    @threshold_pct = 99.0,
    @severity = 'MEDIUM',
    @min_value = '0',
    @max_value = '120';

-- State code must be valid (2 characters)
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'state_code',
    @rule_type = 'DOMAIN_CHECK',
    @threshold_pct = 99.0,
    @severity = 'MEDIUM',
    @allowed_values = 'AL,AK,AZ,AR,CA,CO,CT,DE,FL,GA,HI,ID,IL,IN,IA,KS,KY,LA,ME,MD,MA,MI,MN,MS,MO,MT,NE,NV,NH,NJ,NM,NY,NC,ND,OH,OK,OR,PA,RI,SC,SD,TN,TX,UT,VT,VA,WA,WV,WI,WY,DC';


-- ============================================================================
-- CONSISTENCY RULES  
-- "Do related tables align?"
-- ============================================================================

-- Segment ID must exist in segments table
EXEC dq.usp_add_rule 
    @table_name = 'customers',
    @column_name = 'segment_id',
    @rule_type = 'FK_CHECK',
    @threshold_pct = 100.0,
    @severity = 'HIGH',
    @reference_table = 'segments',
    @reference_column = 'segment_id';


-- ============================================================================
-- VERIFY RULES WERE CREATED
-- ============================================================================

SELECT 
    rule_id,
    rule_name,
    rule_type,
    threshold_pct,
    severity,
    is_active
FROM dq.rules
WHERE table_name = 'customers'
ORDER BY rule_id;


-- ============================================================================
-- RUN THE AUDIT
-- ============================================================================

-- Execute all rules for the customers table
-- EXEC dq.usp_run_quality_audit @table_name = 'customers';

-- View results
-- SELECT * FROM dq.results WHERE run_date = CAST(GETDATE() AS DATE);
-- SELECT * FROM dq.table_scores WHERE table_name = 'customers';
