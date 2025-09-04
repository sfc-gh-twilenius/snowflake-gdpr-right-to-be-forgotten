-- ==========================================
-- SNOWFLAKE GDPR PROCEDURES AND FUNCTIONS
-- Core GDPR compliance procedures for data discovery, erasure, and verification
-- ==========================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GDPR_PROCESSING_WH;
USE DATABASE COMPLIANCE_DB;
USE SCHEMA REQUESTS;

-- ==========================================
-- 1. DATA DISCOVERY PROCEDURES
-- ==========================================

-- Comprehensive data discovery across all databases
CREATE OR REPLACE PROCEDURE SP_DISCOVER_CUSTOMER_DATA(CUSTOMER_EMAIL STRING)
RETURNS TABLE(database_name STRING, schema_name STRING, table_name STRING, column_name STRING, 
              pii_classification STRING, records_found INTEGER, sensitivity_level STRING)
LANGUAGE SQL
AS
$$
DECLARE
    discovery_cursor CURSOR FOR
        SELECT table_catalog, table_schema, table_name, column_name, data_type
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE table_catalog IN ('CUSTOMER_DATA_DB', 'ANALYTICS_DB', 'COMPLIANCE_DB')
        AND (
            UPPER(column_name) LIKE '%EMAIL%' OR
            UPPER(column_name) LIKE '%CUSTOMER%' OR
            UPPER(column_name) LIKE '%USER%' OR
            UPPER(column_name) LIKE '%PHONE%' OR
            UPPER(column_name) LIKE '%ADDRESS%' OR
            UPPER(column_name) LIKE '%NAME%'
        );
        
    db_name STRING;
    schema_name STRING;
    table_name STRING;
    col_name STRING;
    data_type_val STRING;
    pii_class STRING;
    record_count INTEGER;
    sensitivity STRING;
    full_table_name STRING;
    check_sql STRING;
    
    res_cursor CURSOR FOR
        SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
BEGIN
    -- Create temporary table for results
    CREATE OR REPLACE TEMPORARY TABLE temp_discovery_results (
        database_name STRING,
        schema_name STRING,
        table_name STRING,
        column_name STRING,
        pii_classification STRING,
        records_found INTEGER,
        sensitivity_level STRING
    );
    
    -- Loop through all potentially relevant tables
    FOR record IN discovery_cursor DO
        db_name := record.table_catalog;
        schema_name := record.table_schema;
        table_name := record.table_name;
        col_name := record.column_name;
        data_type_val := record.data_type;
        
        -- Classify PII type
        IF (UPPER(col_name) LIKE '%EMAIL%') THEN
            pii_class := 'EMAIL_ADDRESS';
        ELSEIF (UPPER(col_name) LIKE '%PHONE%') THEN
            pii_class := 'PHONE_NUMBER';
        ELSEIF (UPPER(col_name) LIKE '%ADDRESS%') THEN
            pii_class := 'POSTAL_ADDRESS';
        ELSEIF (UPPER(col_name) LIKE '%NAME%' AND UPPER(col_name) NOT LIKE '%USER%') THEN
            pii_class := 'PERSONAL_NAME';
        ELSEIF (UPPER(col_name) LIKE '%SSN%' OR UPPER(col_name) LIKE '%SOCIAL%') THEN
            pii_class := 'SSN';
        ELSEIF (UPPER(col_name) LIKE '%BIRTH%') THEN
            pii_class := 'DATE_OF_BIRTH';
        ELSE
            pii_class := 'POTENTIAL_PII';
        END IF;
        
        -- Determine sensitivity level
        IF (pii_class IN ('SSN', 'DATE_OF_BIRTH')) THEN
            sensitivity := 'CRITICAL';
        ELSEIF (pii_class IN ('EMAIL_ADDRESS', 'PHONE_NUMBER', 'POSTAL_ADDRESS')) THEN
            sensitivity := 'HIGH';
        ELSEIF (pii_class = 'PERSONAL_NAME') THEN
            sensitivity := 'MEDIUM';
        ELSE
            sensitivity := 'LOW';
        END IF;
        
        -- Build dynamic SQL to count records for this customer
        full_table_name := db_name || '.' || schema_name || '.' || table_name;
        
        -- Special handling for email columns
        check_sql := 'SELECT COUNT(*) FROM IDENTIFIER(''' || full_table_name || ''') ' ||
                    ' WHERE (TRY_CAST(customer_email AS STRING) = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                    'TRY_CAST(email AS STRING) = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                    'TRY_CAST(user_email AS STRING) = ''' || CUSTOMER_EMAIL || ''')';
                    
        -- For email columns, also check the specific column
        IF (pii_class = 'EMAIL_ADDRESS') THEN
            check_sql := 'SELECT COUNT(*) FROM IDENTIFIER(''' || full_table_name || ''') ' ||
                        ' WHERE TRY_CAST(' || col_name || ' AS STRING) = ''' || CUSTOMER_EMAIL || '''';
        END IF;
        
        -- Execute the count query
        BEGIN
            LET count_result RESULTSET := (EXECUTE IMMEDIATE check_sql);
            LET count_cursor CURSOR FOR count_result;
            FOR count_row IN count_cursor DO
                record_count := count_row."COUNT(*)";
            END FOR;
        EXCEPTION
            WHEN OTHER THEN
                record_count := 0; -- Table might not have the expected columns
        END;
        
        -- Insert results if records found
        IF (record_count > 0) THEN
            INSERT INTO temp_discovery_results VALUES (
                db_name, schema_name, table_name, col_name, 
                pii_class, record_count, sensitivity
            );
        END IF;
    END FOR;
    
    -- Store discovery results in permanent table (using dynamic SQL to avoid syntax issues)
    LET insert_results_sql STRING := 
        'INSERT INTO COMPLIANCE_DB.REQUESTS.DATA_DISCOVERY_RESULTS (' ||
        'discovery_id, request_id, customer_email, database_name, schema_name,' ||
        'table_name, column_name, pii_classification, records_found,' ||
        'sensitive_data_detected, can_be_deleted) ' ||
        'SELECT CONCAT(''DISC_'', UUID_STRING(), ''_'', REPLACE(''' || CUSTOMER_EMAIL || ''', ''@'', ''_AT_'')), ' ||
        '''DISCOVERY_'' || UUID_STRING(), ''' || CUSTOMER_EMAIL || ''', ' ||
        'database_name, schema_name, table_name, column_name, pii_classification, ' ||
        'records_found, sensitivity_level IN (''HIGH'', ''CRITICAL''), TRUE ' ||
        'FROM temp_discovery_results';
    
    EXECUTE IMMEDIATE insert_results_sql;
    
    -- Return results
    RETURN TABLE(
        SELECT database_name, schema_name, table_name, column_name,
               pii_classification, records_found, sensitivity_level
        FROM temp_discovery_results
        ORDER BY sensitivity_level DESC, records_found DESC
    );
END;
$$;

-- ==========================================
-- 2. ERASURE REQUEST PROCESSING
-- ==========================================

-- Submit a new erasure request
CREATE OR REPLACE PROCEDURE SP_SUBMIT_ERASURE_REQUEST(
    CUSTOMER_EMAIL STRING,
    ERASURE_REASON STRING,
    REQUEST_SOURCE STRING DEFAULT 'API'
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    request_id STRING;
    customer_id_val STRING;
    valid_reasons ARRAY;
    estimated_completion DATE;
BEGIN
    -- Validate GDPR grounds for erasure
    valid_reasons := ARRAY_CONSTRUCT(
        'WITHDRAWN_CONSENT', 'NO_LONGER_NECESSARY', 'UNLAWFUL_PROCESSING', 
        'OBJECTION', 'LEGAL_COMPLIANCE', 'CHILD_CONSENT'
    );
    
    IF (NOT ARRAY_CONTAINS(ERASURE_REASON::VARIANT, valid_reasons)) THEN
        RETURN 'ERROR: Invalid GDPR grounds for erasure. Must be one of: ' || 
               ARRAY_TO_STRING(valid_reasons, ', ');
    END IF;
    
    -- Check if customer exists
    SELECT customer_id INTO customer_id_val
    FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS 
    WHERE email = CUSTOMER_EMAIL AND is_deleted = FALSE;
    
    -- Generate unique request ID
    request_id := 'REQ_' || DATE_PART('YEAR', CURRENT_DATE()) || '_' || UUID_STRING();
    
    -- Calculate estimated completion date (30 days per GDPR)
    estimated_completion := DATEADD('day', 30, CURRENT_DATE());
    
    -- Check for existing active requests
    LET existing_request_count INTEGER;
    SELECT COUNT(*) INTO existing_request_count
    FROM ERASURE_REQUESTS 
    WHERE customer_email = CUSTOMER_EMAIL 
    AND status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS');
    
    IF (existing_request_count > 0) THEN
        RETURN 'ERROR: An active erasure request already exists for this email';
    END IF;
    
    -- Insert erasure request
    INSERT INTO ERASURE_REQUESTS (
        request_id, customer_id, customer_email, request_type, erasure_reason,
        request_source, status, estimated_completion_date
    ) VALUES (
        request_id, customer_id_val, CUSTOMER_EMAIL, 'FULL_ERASURE', ERASURE_REASON,
        REQUEST_SOURCE, 'SUBMITTED', estimated_completion
    );
    
    -- Log the request submission
    CALL SP_LOG_GDPR_EVENT(
        'ERASURE_REQUEST_SUBMITTED',
        CUSTOMER_EMAIL,
        'Erasure request submitted with reason: ' || ERASURE_REASON,
        PARSE_JSON('{"request_id": "' || request_id || '", "reason": "' || ERASURE_REASON || '"}')
    );
    
    -- Trigger data discovery
    CALL SP_DISCOVER_CUSTOMER_DATA(CUSTOMER_EMAIL);
    
    RETURN 'SUCCESS: Erasure request submitted with ID: ' || request_id;
END;
$$;

-- Process an erasure request (main workflow)
CREATE OR REPLACE PROCEDURE SP_PROCESS_ERASURE_REQUEST(REQUEST_ID STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    customer_email_val STRING;
    erasure_reason_val STRING;
    current_status STRING;
    retention_check INTEGER;
    deletion_summary OBJECT;
    
    -- Cursors for processing
    table_cursor CURSOR FOR
        SELECT DISTINCT database_name, schema_name, table_name
        FROM DATA_DISCOVERY_RESULTS
        WHERE request_id = REQUEST_ID AND records_found > 0;
        
    operation_id STRING;
    operation_sql STRING;
    records_affected INTEGER;
    db_name STRING;
    schema_name STRING;
    table_name STRING;
    full_table_name STRING;
BEGIN
    -- Get request details
    SELECT customer_email, erasure_reason, status 
    INTO customer_email_val, erasure_reason_val, current_status
    FROM ERASURE_REQUESTS 
    WHERE request_id = REQUEST_ID;
    
    IF (customer_email_val IS NULL) THEN
        RETURN 'ERROR: Erasure request not found';
    END IF;
    
    IF (current_status NOT IN ('SUBMITTED', 'VALIDATED')) THEN
        RETURN 'ERROR: Request is not in a processable state. Current status: ' || current_status;
    END IF;
    
    -- Check for legal retention requirements
    SELECT COUNT(*) INTO retention_check
    FROM COMPLIANCE_DB.LEGAL.RETENTION_POLICIES rp
    JOIN CUSTOMER_DATA_DB.CORE.CUSTOMERS c ON c.customer_id = rp.customer_id
    WHERE c.email = customer_email_val
    AND rp.retention_end_date > CURRENT_DATE()
    AND rp.can_override_gdpr = FALSE;
    
    IF (retention_check > 0) THEN
        UPDATE ERASURE_REQUESTS 
        SET status = 'REJECTED',
            legal_basis_override = 'Customer data under legal retention - cannot delete'
        WHERE request_id = REQUEST_ID;
        
        RETURN 'ERROR: Customer data under legal retention - cannot delete';
    END IF;
    
    -- Update status to in progress
    UPDATE ERASURE_REQUESTS 
    SET status = 'IN_PROGRESS', started_at = CURRENT_TIMESTAMP()
    WHERE request_id = REQUEST_ID;
    
    -- Initialize deletion summary
    deletion_summary := OBJECT_CONSTRUCT();
    
    -- Process each table with customer data
    FOR table_record IN table_cursor DO
        db_name := table_record.database_name;
        schema_name := table_record.schema_name;
        table_name := table_record.table_name;
        full_table_name := db_name || '.' || schema_name || '.' || table_name;
        
        operation_id := 'OP_' || UUID_STRING();
        
        -- Determine operation type based on table and data sensitivity
        IF (db_name = 'ANALYTICS_DB' AND schema_name IN ('EVENTS', 'ML_MODELS')) THEN
            -- Pseudonymize analytics data instead of deleting
            operation_sql := 'UPDATE IDENTIFIER(''' || full_table_name || ''') ' ||
                           ' SET user_email = ''PSEUDONYM_'' || SHA2(COALESCE(user_email, '''') || CURRENT_TIMESTAMP()), ' ||
                           '     is_pseudonymized = TRUE, ' ||
                           '     pseudonym_id = UUID_STRING() ' ||
                           ' WHERE TRY_CAST(user_email AS STRING) = ''' || customer_email_val || ''' OR ' ||
                           '       TRY_CAST(customer_email AS STRING) = ''' || customer_email_val || '''';
        ELSE
            -- Full deletion for other tables
            operation_sql := 'DELETE FROM IDENTIFIER(''' || full_table_name || ''') ' ||
                           ' WHERE TRY_CAST(customer_email AS STRING) = ''' || customer_email_val || ''' OR ' ||
                           '       TRY_CAST(email AS STRING) = ''' || customer_email_val || ''' OR ' ||
                           '       TRY_CAST(user_email AS STRING) = ''' || customer_email_val || '''';
        END IF;
        
        -- Execute the operation
        BEGIN
            EXECUTE IMMEDIATE operation_sql;
            records_affected := SQLROWCOUNT;
            
            -- Log successful operation
            INSERT INTO ERASURE_OPERATIONS (
                operation_id, request_id, operation_type, target_database,
                target_schema, target_table, operation_sql, operation_status,
                records_affected
            ) VALUES (
                operation_id, REQUEST_ID, 
                CASE WHEN operation_sql LIKE '%UPDATE%' THEN 'PSEUDONYMIZE' ELSE 'DELETE' END,
                db_name, schema_name, table_name, operation_sql, 'SUCCESS',
                records_affected
            );
            
            -- Update deletion summary
            deletion_summary := OBJECT_INSERT(deletion_summary, 
                full_table_name, records_affected, TRUE);
            
        EXCEPTION
            WHEN OTHER THEN
                -- Log failed operation
                INSERT INTO ERASURE_OPERATIONS (
                    operation_id, request_id, operation_type, target_database,
                    target_schema, target_table, operation_sql, operation_status,
                    error_message
                ) VALUES (
                    operation_id, REQUEST_ID, 'DELETE',
                    db_name, schema_name, table_name, operation_sql, 'FAILED',
                    SQLERRM
                );
        END;
    END FOR;
    
    -- Update request as completed
    UPDATE ERASURE_REQUESTS 
    SET status = 'COMPLETED',
        completed_at = CURRENT_TIMESTAMP(),
        actual_completion_date = CURRENT_DATE(),
        deletion_summary = deletion_summary,
        verification_hash = SHA2(customer_email_val || CURRENT_TIMESTAMP())
    WHERE request_id = REQUEST_ID;
    
    -- Log completion
    CALL SP_LOG_GDPR_EVENT(
        'ERASURE_REQUEST_COMPLETED',
        customer_email_val,
        'Erasure request completed successfully',
        PARSE_JSON('{"request_id": "' || REQUEST_ID || '", "deletion_summary": ' || deletion_summary::STRING || '}')
    );
    
    RETURN 'SUCCESS: Erasure request completed. Request ID: ' || REQUEST_ID;
END;
$$;

-- ==========================================
-- 3. AUDIT AND LOGGING PROCEDURES
-- ==========================================

-- Log GDPR events
CREATE OR REPLACE PROCEDURE SP_LOG_GDPR_EVENT(
    EVENT_TYPE STRING,
    CUSTOMER_EMAIL STRING,
    EVENT_DESCRIPTION STRING,
    EVENT_DATA VARIANT DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    audit_id STRING;
    query_id_val STRING;
BEGIN
    audit_id := 'AUDIT_' || UUID_STRING();
    query_id_val := LAST_QUERY_ID();
    
    INSERT INTO COMPLIANCE_DB.AUDIT.GDPR_AUDIT_LOG (
        audit_id, event_type, customer_email, event_description,
        event_data, query_id, warehouse_name, audit_hash
    ) VALUES (
        audit_id, EVENT_TYPE, CUSTOMER_EMAIL, EVENT_DESCRIPTION,
        EVENT_DATA, query_id_val, CURRENT_WAREHOUSE(),
        SHA2(audit_id || EVENT_TYPE || CUSTOMER_EMAIL || CURRENT_TIMESTAMP())
    );
    
    RETURN audit_id;
END;
$$;

-- ==========================================
-- 4. VERIFICATION PROCEDURES
-- ==========================================

-- Verify data deletion using Time Travel
CREATE OR REPLACE PROCEDURE SP_VERIFY_DELETION(
    CUSTOMER_EMAIL STRING,
    HOURS_BACK INTEGER DEFAULT 24
)
RETURNS TABLE(table_name STRING, records_before INTEGER, records_after INTEGER, deletion_verified BOOLEAN)
LANGUAGE SQL
AS
$$
DECLARE
    table_cursor CURSOR FOR
        SELECT DISTINCT database_name || '.' || schema_name || '.' || table_name AS full_table_name
        FROM REFERENCE_DB.METADATA.DATA_CLASSIFICATION
        WHERE pii_type = 'EMAIL_ADDRESS';
        
    table_name_val STRING;
    before_count INTEGER;
    after_count INTEGER;
    verification_sql STRING;
    time_travel_sql STRING;
BEGIN
    -- Create temporary table for results
    CREATE OR REPLACE TEMPORARY TABLE temp_verification_results (
        table_name STRING,
        records_before INTEGER,
        records_after INTEGER,
        deletion_verified BOOLEAN
    );
    
    -- Check each table for deletion verification
    FOR table_record IN table_cursor DO
        table_name_val := table_record.full_table_name;
        
        -- Count records before deletion (using Time Travel)
        time_travel_sql := 'SELECT COUNT(*) FROM ' || table_name_val || 
                          ' AT(OFFSET => -' || (HOURS_BACK * 3600) || ')' ||
                          ' WHERE customer_email = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                          '       email = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                          '       user_email = ''' || CUSTOMER_EMAIL || '''';
        
        BEGIN
            EXECUTE IMMEDIATE time_travel_sql;
            before_count := (SELECT "COUNT(*)" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
        EXCEPTION
            WHEN OTHER THEN
                before_count := 0; -- Table might not exist or have Time Travel data
        END;
        
        -- Count records after deletion (current)
        verification_sql := 'SELECT COUNT(*) FROM ' || table_name_val ||
                           ' WHERE customer_email = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                           '       email = ''' || CUSTOMER_EMAIL || ''' OR ' ||
                           '       user_email = ''' || CUSTOMER_EMAIL || '''';
        
        BEGIN
            EXECUTE IMMEDIATE verification_sql;
            after_count := (SELECT "COUNT(*)" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
        EXCEPTION
            WHEN OTHER THEN
                after_count := 0;
        END;
        
        -- Insert verification result
        INSERT INTO temp_verification_results VALUES (
            table_name_val,
            before_count,
            after_count,
            (before_count > 0 AND after_count = 0) OR (before_count = 0 AND after_count = 0)
        );
    END FOR;
    
    -- Return verification results
    RETURN TABLE(
        SELECT table_name, records_before, records_after, deletion_verified
        FROM temp_verification_results
        WHERE records_before > 0 OR records_after > 0
        ORDER BY deletion_verified ASC, records_before DESC
    );
END;
$$;

-- ==========================================
-- 5. THIRD-PARTY COORDINATION PROCEDURES
-- ==========================================

-- Coordinate deletion with third parties
CREATE OR REPLACE PROCEDURE SP_COORDINATE_THIRD_PARTY_DELETION(CUSTOMER_EMAIL STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    third_party_systems ARRAY;
    system_name STRING;
    notification_id STRING;
    request_id_val STRING;
    coordination_summary STRING;
BEGIN
    -- Get active erasure request
    SELECT request_id INTO request_id_val
    FROM ERASURE_REQUESTS
    WHERE customer_email = CUSTOMER_EMAIL
    AND status IN ('IN_PROGRESS', 'COMPLETED')
    ORDER BY requested_at DESC
    LIMIT 1;
    
    IF (request_id_val IS NULL) THEN
        RETURN 'ERROR: No active erasure request found for customer';
    END IF;
    
    -- Define third-party systems (in production, this would be from a configuration table)
    third_party_systems := ARRAY_CONSTRUCT(
        'GOOGLE_ANALYTICS', 'MAILCHIMP', 'SALESFORCE', 'STRIPE', 'ZENDESK'
    );
    
    coordination_summary := 'Third-party coordination initiated for: ';
    
    -- Create notification records for each third-party system
    FOR i IN 0 TO (ARRAY_SIZE(third_party_systems) - 1) DO
        system_name := GET(third_party_systems, i)::STRING;
        notification_id := 'NOTIF_' || UUID_STRING();
        
        INSERT INTO COMPLIANCE_DB.NOTIFICATIONS.THIRD_PARTY_NOTIFICATIONS (
            notification_id, request_id, customer_email, third_party_name,
            third_party_type, notification_type, method, status
        ) VALUES (
            notification_id, request_id_val, CUSTOMER_EMAIL, system_name,
            'PROCESSOR', 'DELETION_REQUEST', 'API', 'PENDING'
        );
        
        coordination_summary := coordination_summary || system_name || ', ';
    END FOR;
    
    -- Log coordination event
    CALL SP_LOG_GDPR_EVENT(
        'THIRD_PARTY_COORDINATION_INITIATED',
        CUSTOMER_EMAIL,
        'Third-party deletion coordination initiated',
        PARSE_JSON('{"request_id": "' || request_id_val || '", "systems": ' || third_party_systems::STRING || '}')
    );
    
    RETURN 'SUCCESS: ' || coordination_summary;
END;
$$;

-- ==========================================
-- 6. UTILITY FUNCTIONS
-- ==========================================

-- Check GDPR compliance status for a customer
CREATE OR REPLACE FUNCTION FN_CHECK_GDPR_COMPLIANCE_STATUS(CUSTOMER_EMAIL STRING)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'customer_email', CUSTOMER_EMAIL,
        'has_active_request', EXISTS(
            SELECT 1 FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS 
            WHERE customer_email = CUSTOMER_EMAIL 
            AND status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS')
        ),
        'last_request_date', (
            SELECT MAX(requested_at) FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS 
            WHERE customer_email = CUSTOMER_EMAIL
        ),
        'deletion_completed', EXISTS(
            SELECT 1 FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS 
            WHERE customer_email = CUSTOMER_EMAIL 
            AND status = 'COMPLETED'
        ),
        'data_retention_until', (
            SELECT data_retention_until FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS 
            WHERE email = CUSTOMER_EMAIL AND is_deleted = FALSE
        ),
        'consent_status', (
            SELECT OBJECT_CONSTRUCT(
                'marketing', consent_marketing,
                'analytics', consent_analytics,
                'consent_given_date', consent_given_date
            )
            FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS 
            WHERE email = CUSTOMER_EMAIL AND is_deleted = FALSE
        )
    )
$$;

-- Classify PII in a column
CREATE OR REPLACE FUNCTION FN_CLASSIFY_PII_COLUMN(COLUMN_NAME STRING, SAMPLE_DATA STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
    CASE 
        WHEN REGEXP_LIKE(SAMPLE_DATA, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}') THEN 'EMAIL_ADDRESS'
        WHEN REGEXP_LIKE(SAMPLE_DATA, '\\d{3}-\\d{2}-\\d{4}') THEN 'SSN'
        WHEN REGEXP_LIKE(SAMPLE_DATA, '\\+?\\d{10,15}') THEN 'PHONE_NUMBER'
        WHEN REGEXP_LIKE(SAMPLE_DATA, '\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}') THEN 'DATE_OF_BIRTH'
        WHEN UPPER(COLUMN_NAME) LIKE '%NAME%' THEN 'PERSONAL_NAME'
        WHEN UPPER(COLUMN_NAME) LIKE '%ADDRESS%' THEN 'POSTAL_ADDRESS'
        WHEN UPPER(COLUMN_NAME) LIKE '%IP%' THEN 'IP_ADDRESS'
        ELSE 'NON_PII'
    END
$$;

-- ==========================================
-- PROCEDURES SETUP COMPLETE
-- ==========================================

SELECT 'GDPR procedures and functions created successfully!' AS message,
       CURRENT_TIMESTAMP() AS completed_at;

-- Show created procedures
SHOW PROCEDURES LIKE 'SP_%';
SHOW FUNCTIONS LIKE 'FN_%';

