/*
    Data Quality Audit Framework
    01_create_dq_schema.sql
    
    Creates the schema and foundational objects for the
    data quality monitoring system.
*/

-- Create schema for data quality objects
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dq')
    EXEC('CREATE SCHEMA dq');
GO

PRINT 'Data quality schema created successfully.';
GO
