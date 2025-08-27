# Snowflake GDPR Right to be Forgotten - Compliance Demo

This project demonstrates how to implement GDPR Article 17 (Right to be Forgotten) compliance workflows using **Snowflake Data Cloud** native features and capabilities.

## 🎯 Project Overview

This demonstration showcases how organizations can leverage Snowflake's built-in security, governance, and data management features to create a comprehensive GDPR compliance solution without requiring external databases or complex infrastructure.

## 🏗️ Snowflake-Native Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Snowflake Data Cloud                        │
├─────────────────────────────────────────────────────────────────┤
│  🏢 ACCOUNT: GDPR_COMPLIANCE_DEMO                              │
│                                                                 │
│  📊 DATABASES:                                                  │
│  ├── CUSTOMER_DATA_DB (Primary customer data)                  │
│  ├── ANALYTICS_DB (Behavioral and ML data)                     │
│  ├── COMPLIANCE_DB (Audit trails and erasure requests)         │
│  └── REFERENCE_DB (Configuration and metadata)                 │
│                                                                 │
│  🔐 SECURITY FEATURES:                                          │
│  ├── Row Access Policies (Data filtering by user consent)      │
│  ├── Dynamic Data Masking (PII protection)                     │
│  ├── Data Classification (Automatic PII detection)             │
│  └── Secure Views (Controlled data access)                     │
│                                                                 │
│  🕐 TIME TRAVEL & RETENTION:                                    │
│  ├── Data Recovery (Accidental deletion protection)            │
│  ├── Audit Trails (Change tracking)                            │
│  └── Compliance Verification (Proof of deletion)               │
│                                                                 │
│  📈 MONITORING & GOVERNANCE:                                    │
│  ├── Account Usage Views (Access and change monitoring)        │
│  ├── Information Schema (Data discovery and lineage)           │
│  ├── Query History (Audit trail of all operations)             │
│  └── Data Sharing (Secure third-party coordination)            │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Key Snowflake Features Demonstrated

### 1. **Data Discovery & Classification**
- **Information Schema Queries**: Automatically discover personal data across all databases
- **Data Classification**: Use Snowflake's built-in PII detection
- **Column-Level Lineage**: Track data dependencies and relationships
- **Cross-Database Discovery**: Find related data across multiple databases and schemas

### 2. **Secure Data Deletion**
- **Conditional DELETE Operations**: Remove data based on user consent and GDPR grounds
- **Row Access Policies**: Dynamically filter out deleted user data
- **Secure Views**: Present "erasure-compliant" views of data
- **Time Travel Verification**: Prove data has been properly deleted

### 3. **Data Masking & Privacy**
- **Dynamic Data Masking**: Protect PII in non-production environments
- **Column-Level Security**: Fine-grained access control
- **Data Tokenization**: Replace sensitive data with non-sensitive tokens
- **Pseudonymization**: Maintain analytics capability while protecting identity

### 4. **Audit & Compliance**
- **Query History**: Complete audit trail of all data operations
- **Account Usage Views**: Monitor access patterns and data changes
- **Change Tracking**: Track all modifications to customer data
- **Compliance Reporting**: Automated GDPR compliance reports

### 5. **Third-Party Coordination**
- **Data Sharing**: Securely coordinate with external processors
- **External Tables**: Monitor third-party data deletion
- **API Integration**: Snowflake SQL API for external system coordination
- **Data Clean Rooms**: Secure collaboration without data sharing

## 📋 Demo Scenarios

### Scenario 1: Customer Data Discovery
```sql
-- Discover all personal data for a specific customer
CALL SP_DISCOVER_CUSTOMER_DATA('customer@example.com');

-- Results show:
-- - Customer profile in CUSTOMER_DATA_DB.CORE.CUSTOMERS
-- - Purchase history in CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS
-- - Behavioral data in ANALYTICS_DB.EVENTS.USER_ACTIVITIES
-- - Marketing data in ANALYTICS_DB.CAMPAIGNS.INTERACTIONS
-- - Support data in CUSTOMER_DATA_DB.SUPPORT.TICKETS
```

### Scenario 2: Conditional Data Erasure
```sql
-- Submit erasure request with GDPR grounds validation
CALL SP_SUBMIT_ERASURE_REQUEST(
    customer_email => 'customer@example.com',
    erasure_reason => 'WITHDRAWN_CONSENT',
    legal_basis_override => NULL
);

-- Automated workflow:
-- 1. Validates GDPR grounds for erasure
-- 2. Checks for legal retention requirements
-- 3. Creates erasure plan across all systems
-- 4. Executes coordinated deletion
-- 5. Applies row access policies for immediate effect
-- 6. Generates compliance verification report
```

### Scenario 3: Analytics Data Pseudonymization
```sql
-- For analytics retention while protecting privacy
CALL SP_PSEUDONYMIZE_CUSTOMER_DATA('customer@example.com');

-- Results:
-- - Personal identifiers replaced with pseudonyms
-- - Analytics data retained for business intelligence
-- - Irreversible pseudonymization (one-way)
-- - Compliance with data minimization principles
```

### Scenario 4: Third-Party Data Coordination
```sql
-- Coordinate deletion with external systems
CALL SP_COORDINATE_THIRD_PARTY_DELETION('customer@example.com');

-- Automated actions:
-- - Identifies all data sharing agreements
-- - Sends deletion notifications to external processors
-- - Tracks third-party compliance status
-- - Updates shared data sets and clean rooms
```

## 🚀 Quick Start

### Prerequisites
- **Snowflake Account** (Trial account works perfectly)
- **ACCOUNTADMIN or SYSADMIN** privileges for setup
- **SnowSQL CLI** or **Snowflake Web Interface**

### 1. Setup Snowflake Environment
```sql
-- Run the setup script in Snowflake
!source setup/snowflake_setup.sql
```

### 2. Load Demo Data
```sql
-- Create realistic customer data for testing
CALL SP_SETUP_DEMO_DATA();
```

### 3. Test GDPR Workflows
```sql
-- Test data discovery
CALL SP_DISCOVER_CUSTOMER_DATA('demo.customer.1@company.com');

-- Test erasure request
CALL SP_SUBMIT_ERASURE_REQUEST(
    customer_email => 'demo.customer.1@company.com',
    erasure_reason => 'WITHDRAWN_CONSENT'
);

-- Check compliance status
SELECT * FROM VW_GDPR_COMPLIANCE_DASHBOARD;
```

## 📊 Snowflake-Specific GDPR Implementation

### Data Discovery Engine
```sql
-- Comprehensive data discovery using Snowflake metadata
CREATE OR REPLACE PROCEDURE SP_DISCOVER_CUSTOMER_DATA(CUSTOMER_EMAIL STRING)
RETURNS TABLE()
LANGUAGE SQL
AS
$$
DECLARE
    discovery_results RESULTSET;
BEGIN
    -- Query Information Schema for all tables containing customer data
    discovery_results := (
        SELECT 
            table_catalog,
            table_schema,
            table_name,
            column_name,
            data_type,
            is_nullable,
            column_default,
            -- Use Snowflake's built-in functions to identify PII
            CASE 
                WHEN UPPER(column_name) LIKE '%EMAIL%' THEN 'EMAIL_ADDRESS'
                WHEN UPPER(column_name) LIKE '%PHONE%' THEN 'PHONE_NUMBER'
                WHEN UPPER(column_name) LIKE '%ADDRESS%' THEN 'POSTAL_ADDRESS'
                WHEN UPPER(column_name) LIKE '%NAME%' THEN 'PERSONAL_NAME'
                WHEN UPPER(column_name) LIKE '%SSN%' OR UPPER(column_name) LIKE '%SOCIAL%' THEN 'SSN'
                ELSE 'POTENTIAL_PII'
            END AS pii_classification,
            -- Estimate row count with customer data
            (SELECT COUNT(*) 
             FROM IDENTIFIER(table_catalog||'.'||table_schema||'.'||table_name) 
             WHERE column_name ILIKE '%email%' AND column_name = :customer_email) AS records_found
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE table_catalog IN ('CUSTOMER_DATA_DB', 'ANALYTICS_DB', 'COMPLIANCE_DB')
        AND (
            UPPER(column_name) LIKE '%EMAIL%' OR
            UPPER(column_name) LIKE '%CUSTOMER%' OR
            UPPER(column_name) LIKE '%USER%' OR
            UPPER(column_name) LIKE '%PERSON%'
        )
        ORDER BY table_catalog, table_schema, table_name
    );
    
    RETURN TABLE(discovery_results);
END;
$$;
```

### Erasure Request Processing
```sql
-- GDPR-compliant erasure workflow
CREATE OR REPLACE PROCEDURE SP_PROCESS_ERASURE_REQUEST(
    REQUEST_ID STRING,
    CUSTOMER_EMAIL STRING,
    ERASURE_REASON STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    erasure_plan ARRAY;
    deletion_summary STRING;
BEGIN
    -- 1. Validate GDPR grounds
    IF erasure_reason NOT IN ('WITHDRAWN_CONSENT', 'NO_LONGER_NECESSARY', 'UNLAWFUL_PROCESSING', 'OBJECTION') THEN
        RETURN 'ERROR: Invalid GDPR grounds for erasure';
    END IF;
    
    -- 2. Check for legal retention requirements
    LET retention_check STRING := (
        SELECT CASE 
            WHEN COUNT(*) > 0 THEN 'LEGAL_HOLD'
            ELSE 'APPROVED'
        END
        FROM COMPLIANCE_DB.LEGAL.RETENTION_POLICIES rp
        JOIN CUSTOMER_DATA_DB.CORE.CUSTOMERS c ON c.customer_id = rp.customer_id
        WHERE c.email = :customer_email
        AND rp.retention_end_date > CURRENT_DATE()
    );
    
    IF retention_check = 'LEGAL_HOLD' THEN
        RETURN 'ERROR: Customer data under legal retention - cannot delete';
    END IF;
    
    -- 3. Execute coordinated deletion across all databases
    
    -- Delete from customer database
    DELETE FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS WHERE email = :customer_email;
    DELETE FROM CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS WHERE customer_email = :customer_email;
    DELETE FROM CUSTOMER_DATA_DB.SUPPORT.TICKETS WHERE customer_email = :customer_email;
    
    -- Pseudonymize analytics data (retain for business intelligence)
    UPDATE ANALYTICS_DB.EVENTS.USER_ACTIVITIES 
    SET user_email = 'PSEUDONYM_' || SHA2(user_email || RANDOM())
    WHERE user_email = :customer_email;
    
    -- Apply row access policy for immediate effect
    CREATE OR REPLACE ROW ACCESS POLICY RAP_CUSTOMER_ERASURE AS (customer_email STRING) RETURNS BOOLEAN ->
        customer_email != :customer_email;
    
    -- 4. Log erasure operation
    INSERT INTO COMPLIANCE_DB.AUDIT.ERASURE_LOG (
        request_id,
        customer_email,
        erasure_reason,
        deletion_timestamp,
        systems_affected,
        verification_hash
    ) VALUES (
        :request_id,
        :customer_email,
        :erasure_reason,
        CURRENT_TIMESTAMP(),
        ARRAY_CONSTRUCT('CUSTOMER_DATA_DB', 'ANALYTICS_DB'),
        SHA2(:customer_email || CURRENT_TIMESTAMP())
    );
    
    RETURN 'SUCCESS: Customer data erasure completed';
END;
$$;
```

### Compliance Monitoring Dashboard
```sql
-- Real-time GDPR compliance view
CREATE OR REPLACE VIEW VW_GDPR_COMPLIANCE_DASHBOARD AS
SELECT 
    -- Active erasure requests
    COUNT(CASE WHEN status = 'PENDING' THEN 1 END) AS pending_requests,
    COUNT(CASE WHEN status = 'IN_PROGRESS' THEN 1 END) AS in_progress_requests,
    COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) AS completed_requests,
    
    -- SLA compliance (30 days for GDPR)
    COUNT(CASE 
        WHEN status IN ('PENDING', 'IN_PROGRESS') 
        AND DATEDIFF('day', request_date, CURRENT_DATE()) > 30 
        THEN 1 
    END) AS overdue_requests,
    
    -- Processing time metrics
    AVG(CASE 
        WHEN status = 'COMPLETED' 
        THEN DATEDIFF('day', request_date, completion_date) 
    END) AS avg_processing_days,
    
    -- Data discovery metrics
    SUM(records_discovered) AS total_records_discovered,
    COUNT(DISTINCT systems_affected) AS systems_with_customer_data,
    
    -- Compliance status
    CASE 
        WHEN COUNT(CASE WHEN status IN ('PENDING', 'IN_PROGRESS') AND DATEDIFF('day', request_date, CURRENT_DATE()) > 30 THEN 1 END) = 0 
        THEN 'COMPLIANT'
        ELSE 'NON_COMPLIANT'
    END AS overall_compliance_status
    
FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS
WHERE request_date >= DATEADD('month', -12, CURRENT_DATE());
```

## 🔐 Security & Privacy Features

### Row Access Policies for Data Filtering
```sql
-- Automatically filter deleted customers from all queries
CREATE OR REPLACE ROW ACCESS POLICY RAP_GDPR_ERASURE AS (customer_email STRING) RETURNS BOOLEAN ->
    customer_email NOT IN (
        SELECT customer_email 
        FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS 
        WHERE status = 'COMPLETED'
    );

-- Apply to all customer tables
ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
ADD ROW ACCESS POLICY RAP_GDPR_ERASURE ON (email);
```

### Dynamic Data Masking for PII Protection
```sql
-- Mask PII in non-production environments
CREATE OR REPLACE MASKING POLICY MP_EMAIL_MASKING AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('GDPR_ADMIN', 'DATA_PROTECTION_OFFICER') THEN val
        ELSE REGEXP_REPLACE(val, '.{1,}@', '*****@')
    END;

-- Apply masking policy
ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN email SET MASKING POLICY MP_EMAIL_MASKING;
```

### Data Classification and Discovery
```sql
-- Automatic PII detection and classification
CREATE OR REPLACE FUNCTION FN_CLASSIFY_PII_COLUMN(column_name STRING, sample_data STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
    CASE 
        WHEN REGEXP_LIKE(sample_data, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}') THEN 'EMAIL_ADDRESS'
        WHEN REGEXP_LIKE(sample_data, '\\d{3}-\\d{2}-\\d{4}') THEN 'SSN'
        WHEN REGEXP_LIKE(sample_data, '\\+?\\d{10,15}') THEN 'PHONE_NUMBER'
        WHEN UPPER(column_name) LIKE '%NAME%' THEN 'PERSONAL_NAME'
        WHEN UPPER(column_name) LIKE '%ADDRESS%' THEN 'POSTAL_ADDRESS'
        ELSE 'NON_PII'
    END
$$;
```

## 📈 Monitoring & Reporting

### Account Usage for Audit Trails
```sql
-- Track all customer data access
CREATE OR REPLACE VIEW VW_CUSTOMER_DATA_ACCESS_AUDIT AS
SELECT 
    qh.query_id,
    qh.query_text,
    qh.user_name,
    qh.role_name,
    qh.start_time,
    qh.execution_status,
    qh.warehouse_name,
    -- Extract customer emails from queries
    REGEXP_SUBSTR(qh.query_text, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}') AS customer_email_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
WHERE qh.query_text ILIKE '%customer%'
   OR qh.query_text ILIKE '%email%'
   OR qh.query_text ILIKE '%personal%'
ORDER BY qh.start_time DESC;
```

### Time Travel for Deletion Verification
```sql
-- Verify data has been properly deleted
CREATE OR REPLACE PROCEDURE SP_VERIFY_DELETION(CUSTOMER_EMAIL STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    before_count INT;
    after_count INT;
BEGIN
    -- Count records before deletion (using Time Travel)
    before_count := (
        SELECT COUNT(*) 
        FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS AT(OFFSET => -3600) -- 1 hour ago
        WHERE email = :customer_email
    );
    
    -- Count records after deletion (current)
    after_count := (
        SELECT COUNT(*) 
        FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS 
        WHERE email = :customer_email
    );
    
    IF before_count > 0 AND after_count = 0 THEN
        RETURN 'VERIFICATION_SUCCESS: Data properly deleted';
    ELSE
        RETURN 'VERIFICATION_FAILED: Data may not be properly deleted';
    END IF;
END;
$$;
```

## 🌐 Third-Party Integration

### Data Sharing for External Coordination
```sql
-- Share deletion notifications with external processors
CREATE OR REPLACE SHARE SHARE_GDPR_NOTIFICATIONS;

-- Add deletion log to share
GRANT USAGE ON DATABASE COMPLIANCE_DB TO SHARE SHARE_GDPR_NOTIFICATIONS;
GRANT USAGE ON SCHEMA COMPLIANCE_DB.NOTIFICATIONS TO SHARE SHARE_GDPR_NOTIFICATIONS;
GRANT SELECT ON TABLE COMPLIANCE_DB.NOTIFICATIONS.THIRD_PARTY_DELETIONS TO SHARE SHARE_GDPR_NOTIFICATIONS;

-- External processors can query for deletion notifications
CREATE OR REPLACE VIEW COMPLIANCE_DB.NOTIFICATIONS.VW_PENDING_DELETIONS AS
SELECT 
    customer_email,
    deletion_request_date,
    external_system_name,
    notification_status
FROM COMPLIANCE_DB.NOTIFICATIONS.THIRD_PARTY_DELETIONS
WHERE notification_status = 'PENDING';
```

## 📊 Demo Results

After running the complete demo, you'll see:

1. **Data Discovery**: Comprehensive mapping of customer data across all Snowflake databases
2. **Erasure Execution**: Coordinated deletion with immediate effect via row access policies  
3. **Compliance Verification**: Time Travel-based proof of successful deletion
4. **Audit Trail**: Complete history of all GDPR-related operations
5. **Third-Party Coordination**: Automated notification and tracking of external deletions

## 🎯 Business Benefits

### ✅ **Snowflake-Native Compliance**
- Leverage built-in security and governance features
- No external infrastructure required
- Seamless integration with existing Snowflake workflows
- Reduced compliance complexity and cost

### ⚡ **Automated Processing**
- SQL-based automation using stored procedures
- Real-time effect via row access policies
- Background processing with Snowflake tasks
- Minimal manual intervention required

### 🔒 **Enterprise Security**
- Role-based access control
- Column-level and row-level security
- Data masking and pseudonymization
- Comprehensive audit trails

### 📈 **Scalable Architecture**
- Handles enterprise-scale data volumes
- Multi-database coordination
- Time Travel for verification and recovery
- Integration with external systems via data sharing

## 🚀 **Getting Started**

Ready to implement GDPR compliance in Snowflake? 

1. Clone this repository
2. Run the Snowflake setup scripts
3. Load demo data
4. Test erasure workflows
5. Customize for your organization

**This demo proves that comprehensive GDPR compliance can be achieved using Snowflake's native capabilities, without requiring complex external infrastructure or third-party tools.**
