-- ============================================================================
-- SAMPLE DIRTY DATA FOR TESTING
-- ============================================================================
-- PURPOSE: Populate the customers table with intentionally flawed data
--          to demonstrate the DQ framework catching issues.
--
-- ISSUES INCLUDED:
--   - NULL values in required fields
--   - Duplicate emails
--   - Invalid age values
--   - Orphaned foreign keys
--   - Invalid state codes
-- ============================================================================

-- Clear existing test data
TRUNCATE TABLE dbo.customers;

-- ============================================================================
-- INSERT TEST DATA WITH INTENTIONAL ISSUES
-- ============================================================================

INSERT INTO dbo.customers 
(customer_id, email, phone, first_name, last_name, state_code, age, created_date, modified_date, segment_id)
VALUES
-- Good records (baseline)
(1, 'john.smith@email.com', '555-0101', 'John', 'Smith', 'VA', 35, '2024-01-15', '2024-01-15', 1),
(2, 'jane.doe@email.com', '555-0102', 'Jane', 'Doe', 'MD', 28, '2024-01-16', '2024-01-16', 2),
(3, 'bob.jones@email.com', '555-0103', 'Bob', 'Jones', 'DC', 45, '2024-01-17', '2024-01-17', 1),
(4, 'alice.wilson@email.com', '555-0104', 'Alice', 'Wilson', 'VA', 52, '2024-01-18', '2024-01-18', 3),
(5, 'charlie.brown@email.com', '555-0105', 'Charlie', 'Brown', 'NC', 31, '2024-01-19', '2024-01-19', 2),

-- COMPLETENESS ISSUES: NULL emails
(6, NULL, '555-0106', 'David', 'Miller', 'VA', 40, '2024-01-20', '2024-01-20', 1),
(7, NULL, '555-0107', 'Emma', 'Davis', 'MD', 29, '2024-01-21', '2024-01-21', 2),

-- COMPLETENESS ISSUES: NULL names
(8, 'missing.firstname@email.com', '555-0108', NULL, 'Garcia', 'TX', 33, '2024-01-22', '2024-01-22', 1),
(9, 'missing.lastname@email.com', '555-0109', 'Frank', NULL, 'FL', 44, '2024-01-23', '2024-01-23', 2),

-- COMPLETENESS ISSUES: NULL phone (acceptable - low threshold)
(10, 'no.phone@email.com', NULL, 'Grace', 'Lee', 'CA', 27, '2024-01-24', '2024-01-24', 3),
(11, 'also.no.phone@email.com', NULL, 'Henry', 'Kim', 'WA', 38, '2024-01-25', '2024-01-25', 1),

-- UNIQUENESS ISSUES: Duplicate emails
(12, 'duplicate@email.com', '555-0112', 'Ivan', 'Chen', 'NY', 41, '2024-01-26', '2024-01-26', 2),
(13, 'duplicate@email.com', '555-0113', 'Julia', 'Wang', 'NJ', 36, '2024-01-27', '2024-01-27', 1),  -- DUPLICATE!

-- VALIDITY ISSUES: Invalid ages
(14, 'too.old@email.com', '555-0114', 'Karl', 'Schmidt', 'PA', 150, '2024-01-28', '2024-01-28', 3),  -- Too old!
(15, 'negative.age@email.com', '555-0115', 'Laura', 'Martinez', 'AZ', -5, '2024-01-29', '2024-01-29', 2),  -- Negative!

-- VALIDITY ISSUES: Invalid state codes
(16, 'bad.state@email.com', '555-0116', 'Mike', 'Johnson', 'XX', 29, '2024-01-30', '2024-01-30', 1),  -- Invalid!
(17, 'another.bad@email.com', '555-0117', 'Nancy', 'Williams', 'ZZ', 34, '2024-01-31', '2024-01-31', 2),  -- Invalid!

-- CONSISTENCY ISSUES: Orphaned segment_id (FK violation)
(18, 'orphan.fk@email.com', '555-0118', 'Oscar', 'Taylor', 'OH', 47, '2024-02-01', '2024-02-01', 99),  -- Doesn't exist!
(19, 'another.orphan@email.com', '555-0119', 'Patricia', 'Anderson', 'MI', 55, '2024-02-02', '2024-02-02', 100),  -- Doesn't exist!

-- More good records to balance the data
(20, 'good.record1@email.com', '555-0120', 'Quinn', 'Thomas', 'GA', 32, '2024-02-03', '2024-02-03', 1),
(21, 'good.record2@email.com', '555-0121', 'Rachel', 'Jackson', 'TN', 29, '2024-02-04', '2024-02-04', 2),
(22, 'good.record3@email.com', '555-0122', 'Steve', 'White', 'AL', 43, '2024-02-05', '2024-02-05', 3),
(23, 'good.record4@email.com', '555-0123', 'Tina', 'Harris', 'SC', 37, '2024-02-06', '2024-02-06', 1),
(24, 'good.record5@email.com', '555-0124', 'Uma', 'Martin', 'KY', 26, '2024-02-07', '2024-02-07', 2),
(25, 'good.record6@email.com', '555-0125', 'Victor', 'Garcia', 'LA', 51, '2024-02-08', '2024-02-08', 3);


-- ============================================================================
-- EXPECTED ISSUES SUMMARY
-- ============================================================================
/*
After running the DQ audit, you should see:

COMPLETENESS:
- email: 23/25 populated = 92% (FAIL - threshold 95%)
- phone: 23/25 populated = 92% (PASS - threshold 80%)
- first_name: 24/25 populated = 96% (FAIL - threshold 99%)
- last_name: 24/25 populated = 96% (FAIL - threshold 99%)

UNIQUENESS:
- customer_id: 0 duplicates (PASS)
- email: 1 duplicate value (FAIL)

VALIDITY:
- age: 23/25 in range = 92% (FAIL - threshold 99%)
- state_code: 23/25 valid = 92% (FAIL - threshold 99%)

CONSISTENCY:
- segment_id: 2 orphans (FAIL)

Expected Overall Score: ~70-75/100 (Grade: C)
*/


-- ============================================================================
-- VERIFY DATA LOADED
-- ============================================================================
SELECT 
    COUNT(*) AS total_records,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS null_emails,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) AS null_phones,
    SUM(CASE WHEN first_name IS NULL THEN 1 ELSE 0 END) AS null_first_names,
    SUM(CASE WHEN age < 0 OR age > 120 THEN 1 ELSE 0 END) AS invalid_ages
FROM dbo.customers;
