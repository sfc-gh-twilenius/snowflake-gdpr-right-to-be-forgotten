-- ==========================================
-- SNOWFLAKE GDPR SECURITY POLICIES
-- Row access policies, masking policies, and secure views for GDPR compliance
-- ==========================================

USE ROLE SYSADMIN;
USE WAREHOUSE GDPR_PROCESSING_WH;

-- ==========================================
-- 1. ROW ACCESS POLICIES
-- ==========================================

-- Policy to filter out deleted customers from all queries
CREATE OR REPLACE ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS 
AS (customer_email STRING) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'DATA_PROTECTION_OFFICER') THEN TRUE
        ELSE customer_email NOT IN (
            SELECT customer_email 
            FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS 
            WHERE status = 'COMPLETED'
        )
    END;

-- Policy for consent-based data access (marketing)
CREATE OR REPLACE ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_MARKETING_CONSENT
AS (customer_email STRING, consent_marketing BOOLEAN) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN') THEN TRUE
        WHEN CURRENT_ROLE() IN ('MARKETING_TEAM') THEN consent_marketing = TRUE
        ELSE TRUE -- Non-marketing roles see all data
    END;

-- Policy for analytics data access
CREATE OR REPLACE ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_ANALYTICS_CONSENT
AS (customer_email STRING, consent_analytics BOOLEAN) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN') THEN TRUE
        WHEN CURRENT_ROLE() IN ('ANALYTICS_TEAM', 'DATA_SCIENTIST') THEN consent_analytics = TRUE
        ELSE TRUE -- Non-analytics roles see all data
    END;

-- Policy for pseudonymized data (hide personal identifiers but allow analytics)
CREATE OR REPLACE ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_PSEUDONYMIZED_DATA
AS (is_pseudonymized BOOLEAN, user_email STRING) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN') THEN TRUE
        WHEN CURRENT_ROLE() IN ('ANALYTICS_TEAM', 'DATA_SCIENTIST') THEN TRUE -- Can see pseudonymized data
        WHEN is_pseudonymized = TRUE AND CURRENT_ROLE() NOT IN ('CUSTOMER_SERVICE', 'SALES') THEN TRUE
        WHEN is_pseudonymized = FALSE THEN TRUE -- Non-pseudonymized data visible to all authorized roles
        ELSE FALSE
    END;

-- Apply row access policies to customer tables
ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS ON (email);

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_MARKETING_CONSENT ON (email, consent_marketing);

ALTER TABLE CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS ON (customer_email);

ALTER TABLE CUSTOMER_DATA_DB.SUPPORT.SUPPORT_TICKETS 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS ON (customer_email);

ALTER TABLE ANALYTICS_DB.EVENTS.USER_ACTIVITIES 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS ON (user_email);

ALTER TABLE ANALYTICS_DB.EVENTS.USER_ACTIVITIES 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_PSEUDONYMIZED_DATA ON (is_pseudonymized, user_email);

ALTER TABLE ANALYTICS_DB.CAMPAIGNS.MARKETING_INTERACTIONS 
ADD ROW ACCESS POLICY COMPLIANCE_DB.REQUESTS.RAP_GDPR_DELETED_CUSTOMERS ON (customer_email);

-- ==========================================
-- 2. DYNAMIC DATA MASKING POLICIES
-- ==========================================

-- Email masking policy
CREATE OR REPLACE MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE', 'DATA_PROTECTION_OFFICER') THEN val
        WHEN CURRENT_ROLE() IN ('ANALYTICS_TEAM', 'DATA_SCIENTIST') THEN 
            REGEXP_REPLACE(val, '^(.{2}).*(@.*)$', '\\1****\\2')
        WHEN CURRENT_ROLE() IN ('MARKETING_TEAM') THEN
            REGEXP_REPLACE(val, '^(.).*(@.*)$', '\\1****\\2')
        ELSE '*****@*****.***'
    END;

-- Phone number masking policy
CREATE OR REPLACE MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_PHONE_MASKING AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE') THEN val
        WHEN val IS NULL THEN NULL
        WHEN LENGTH(val) >= 10 THEN 
            CONCAT(LEFT(val, 3), '-***-', RIGHT(val, 4))
        ELSE '***-***-****'
    END;

-- Address masking policy
CREATE OR REPLACE MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_ADDRESS_MASKING AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE', 'SHIPPING') THEN val
        WHEN val IS NULL THEN NULL
        ELSE REGEXP_REPLACE(val, '\\d+', '***') -- Replace numbers with ***
    END;

-- Personal name masking policy
CREATE OR REPLACE MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_NAME_MASKING AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE') THEN val
        WHEN val IS NULL THEN NULL
        WHEN LENGTH(val) > 1 THEN 
            CONCAT(LEFT(val, 1), REPEAT('*', LENGTH(val) - 1))
        ELSE '*'
    END;

-- Date of birth masking policy (show only year)
CREATE OR REPLACE MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_DOB_MASKING AS (val DATE) RETURNS DATE ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE') THEN val
        WHEN val IS NULL THEN NULL
        ELSE DATE_FROM_PARTS(YEAR(val), 1, 1) -- Show only year
    END;

-- Apply masking policies to customer data
ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN email SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN phone_number SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_PHONE_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN first_name SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_NAME_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN last_name SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_NAME_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN date_of_birth SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_DOB_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN address_line1 SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_ADDRESS_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.CORE.CUSTOMERS 
MODIFY COLUMN address_line2 SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_ADDRESS_MASKING;

-- Apply email masking to other tables
ALTER TABLE CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS 
MODIFY COLUMN customer_email SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING;

ALTER TABLE CUSTOMER_DATA_DB.SUPPORT.SUPPORT_TICKETS 
MODIFY COLUMN customer_email SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING;

ALTER TABLE ANALYTICS_DB.EVENTS.USER_ACTIVITIES 
MODIFY COLUMN user_email SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING;

ALTER TABLE ANALYTICS_DB.CAMPAIGNS.MARKETING_INTERACTIONS 
MODIFY COLUMN customer_email SET MASKING POLICY COMPLIANCE_DB.REQUESTS.MP_EMAIL_MASKING;

-- ==========================================
-- 3. SECURE VIEWS FOR GDPR COMPLIANCE
-- ==========================================

-- Secure view for customer data with GDPR compliance
USE SCHEMA CUSTOMER_DATA_DB.CORE;

CREATE OR REPLACE SECURE VIEW VW_CUSTOMERS_GDPR_COMPLIANT AS
SELECT 
    c.customer_id,
    c.email,
    c.first_name,
    c.last_name,
    c.phone_number,
    c.date_of_birth,
    c.address_line1,
    c.address_line2,
    c.city,
    c.state_province,
    c.postal_code,
    c.country_code,
    c.consent_marketing,
    c.consent_analytics,
    c.consent_given_date,
    c.lawful_basis,
    c.data_retention_until,
    c.created_at,
    c.updated_at,
    
    -- GDPR status information
    CASE 
        WHEN er.status = 'COMPLETED' THEN 'DELETED'
        WHEN er.status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS') THEN 'DELETION_PENDING'
        ELSE 'ACTIVE'
    END AS gdpr_status,
    
    er.requested_at AS deletion_requested_at,
    er.completed_at AS deletion_completed_at,
    
    -- Data retention compliance
    CASE 
        WHEN c.data_retention_until < CURRENT_DATE() THEN 'OVERDUE_FOR_DELETION'
        WHEN c.data_retention_until <= DATEADD('month', 1, CURRENT_DATE()) THEN 'DUE_FOR_DELETION_SOON'
        ELSE 'WITHIN_RETENTION_PERIOD'
    END AS retention_status,
    
    -- Consent compliance
    CASE 
        WHEN c.consent_given_date IS NULL THEN 'NO_CONSENT_RECORD'
        WHEN c.consent_marketing = FALSE AND c.consent_analytics = FALSE THEN 'ALL_CONSENT_WITHDRAWN'
        WHEN c.consent_marketing = FALSE THEN 'MARKETING_CONSENT_WITHDRAWN'
        WHEN c.consent_analytics = FALSE THEN 'ANALYTICS_CONSENT_WITHDRAWN'
        ELSE 'CONSENTED'
    END AS consent_status

FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS c
LEFT JOIN COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS er 
    ON c.email = er.customer_email 
    AND er.requested_at = (
        SELECT MAX(requested_at) 
        FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS er2 
        WHERE er2.customer_email = c.email
    )
WHERE c.is_deleted = FALSE;

-- Secure view for transaction data with privacy protection
USE SCHEMA CUSTOMER_DATA_DB.TRANSACTIONS;

CREATE OR REPLACE SECURE VIEW VW_ORDERS_PRIVACY_SAFE AS
SELECT 
    o.order_id,
    o.customer_id,
    -- Show masked email for privacy
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE') 
        THEN o.customer_email
        ELSE REGEXP_REPLACE(o.customer_email, '^(.{2}).*(@.*)$', '\\1****\\2')
    END AS customer_email,
    o.order_date,
    o.total_amount,
    o.currency,
    o.payment_method,
    -- Mask address details
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN', 'CUSTOMER_SERVICE', 'SHIPPING') 
        THEN o.billing_address
        ELSE PARSE_JSON('{"masked": "true", "city": "' || o.billing_address:city || '", "country": "' || o.billing_address:country || '"}')
    END AS billing_address,
    o.order_status,
    o.legal_retention_until,
    o.can_be_deleted,
    o.created_at
FROM CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS o
JOIN CUSTOMER_DATA_DB.CORE.VW_CUSTOMERS_GDPR_COMPLIANT c 
    ON o.customer_id = c.customer_id
WHERE c.gdpr_status != 'DELETED' OR CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN');

-- Secure view for analytics data (pseudonymized)
USE SCHEMA ANALYTICS_DB.EVENTS;

CREATE OR REPLACE SECURE VIEW VW_USER_ACTIVITIES_ANALYTICS AS
SELECT 
    ua.event_id,
    -- Use pseudonym_id for deleted users, customer_id for active users
    CASE 
        WHEN ua.is_pseudonymized = TRUE THEN ua.pseudonym_id
        ELSE ua.customer_id
    END AS user_identifier,
    
    -- Hide email for pseudonymized users
    CASE 
        WHEN ua.is_pseudonymized = TRUE THEN 'PSEUDONYMIZED_USER'
        ELSE ua.user_email
    END AS user_email,
    
    ua.session_id,
    ua.event_type,
    ua.event_timestamp,
    ua.page_url,
    -- Anonymize user agent and IP for pseudonymized users
    CASE 
        WHEN ua.is_pseudonymized = TRUE THEN 'ANONYMIZED'
        ELSE ua.user_agent
    END AS user_agent,
    
    CASE 
        WHEN ua.is_pseudonymized = TRUE THEN 'XXX.XXX.XXX.XXX'
        ELSE ua.ip_address
    END AS ip_address,
    
    ua.device_type,
    ua.browser,
    ua.country_code,
    ua.event_properties,
    ua.is_pseudonymized,
    ua.consent_for_analytics,
    ua.created_at
FROM ANALYTICS_DB.EVENTS.USER_ACTIVITIES ua
WHERE 
    -- Only show data where analytics consent is given or data is pseudonymized
    ua.consent_for_analytics = TRUE 
    OR ua.is_pseudonymized = TRUE 
    OR CURRENT_ROLE() IN ('ACCOUNTADMIN', 'GDPR_ADMIN');

-- ==========================================
-- 4. COMPLIANCE MONITORING VIEWS
-- ==========================================

USE SCHEMA COMPLIANCE_DB.REQUESTS;

-- Real-time GDPR compliance dashboard
CREATE OR REPLACE SECURE VIEW VW_GDPR_COMPLIANCE_DASHBOARD AS
SELECT 
    -- Request metrics
    COUNT(CASE WHEN status = 'SUBMITTED' THEN 1 END) AS pending_requests,
    COUNT(CASE WHEN status = 'VALIDATED' THEN 1 END) AS validated_requests,
    COUNT(CASE WHEN status = 'IN_PROGRESS' THEN 1 END) AS in_progress_requests,
    COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) AS completed_requests,
    COUNT(CASE WHEN status = 'REJECTED' THEN 1 END) AS rejected_requests,
    
    -- SLA compliance (30 days for GDPR)
    COUNT(CASE 
        WHEN status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS') 
        AND DATEDIFF('day', requested_at, CURRENT_DATE()) > 30 
        THEN 1 
    END) AS overdue_requests,
    
    COUNT(CASE 
        WHEN status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS') 
        AND DATEDIFF('day', requested_at, CURRENT_DATE()) > 25 
        AND DATEDIFF('day', requested_at, CURRENT_DATE()) <= 30
        THEN 1 
    END) AS due_soon_requests,
    
    -- Processing time metrics
    AVG(CASE 
        WHEN status = 'COMPLETED' 
        THEN DATEDIFF('day', requested_at, completed_at) 
    END) AS avg_processing_days,
    
    MAX(CASE 
        WHEN status = 'COMPLETED' 
        THEN DATEDIFF('day', requested_at, completed_at) 
    END) AS max_processing_days,
    
    -- Recent activity
    COUNT(CASE 
        WHEN requested_at >= DATEADD('day', -7, CURRENT_DATE()) 
        THEN 1 
    END) AS requests_last_7_days,
    
    COUNT(CASE 
        WHEN completed_at >= DATEADD('day', -7, CURRENT_DATE()) 
        THEN 1 
    END) AS completions_last_7_days,
    
    -- Overall compliance status
    CASE 
        WHEN COUNT(CASE 
            WHEN status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS') 
            AND DATEDIFF('day', requested_at, CURRENT_DATE()) > 30 
            THEN 1 
        END) = 0 
        THEN 'COMPLIANT'
        WHEN COUNT(CASE 
            WHEN status IN ('SUBMITTED', 'VALIDATED', 'IN_PROGRESS') 
            AND DATEDIFF('day', requested_at, CURRENT_DATE()) > 30 
            THEN 1 
        END) <= 2
        THEN 'AT_RISK'
        ELSE 'NON_COMPLIANT'
    END AS overall_compliance_status,
    
    CURRENT_TIMESTAMP() AS dashboard_updated_at
    
FROM ERASURE_REQUESTS
WHERE requested_at >= DATEADD('year', -1, CURRENT_DATE());

-- Data retention compliance view
CREATE OR REPLACE SECURE VIEW VW_DATA_RETENTION_COMPLIANCE AS
SELECT 
    'customers' AS data_category,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN data_retention_until < CURRENT_DATE() THEN 1 END) AS overdue_for_deletion,
    COUNT(CASE 
        WHEN data_retention_until BETWEEN CURRENT_DATE() 
        AND DATEADD('month', 1, CURRENT_DATE()) 
        THEN 1 
    END) AS due_soon,
    COUNT(CASE WHEN consent_marketing = FALSE THEN 1 END) AS marketing_consent_withdrawn,
    COUNT(CASE WHEN consent_analytics = FALSE THEN 1 END) AS analytics_consent_withdrawn
FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS
WHERE is_deleted = FALSE

UNION ALL

SELECT 
    'transactions' AS data_category,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN legal_retention_until < CURRENT_DATE() AND can_be_deleted = TRUE THEN 1 END) AS overdue_for_deletion,
    COUNT(CASE 
        WHEN legal_retention_until BETWEEN CURRENT_DATE() 
        AND DATEADD('month', 1, CURRENT_DATE()) 
        AND can_be_deleted = TRUE
        THEN 1 
    END) AS due_soon,
    0 AS marketing_consent_withdrawn,
    0 AS analytics_consent_withdrawn
FROM CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS;

-- Audit trail summary view
CREATE OR REPLACE SECURE VIEW VW_GDPR_AUDIT_SUMMARY AS
SELECT 
    DATE(event_timestamp) AS audit_date,
    event_type,
    COUNT(*) AS event_count,
    COUNT(DISTINCT customer_email) AS unique_customers,
    COUNT(DISTINCT user_name) AS unique_users,
    MIN(event_timestamp) AS first_event,
    MAX(event_timestamp) AS last_event
FROM COMPLIANCE_DB.AUDIT.GDPR_AUDIT_LOG
WHERE event_timestamp >= DATEADD('month', -3, CURRENT_DATE())
GROUP BY DATE(event_timestamp), event_type
ORDER BY audit_date DESC, event_count DESC;

-- ==========================================
-- 5. ROLES AND PERMISSIONS FOR GDPR
-- ==========================================

-- Create GDPR-specific roles (if they don't exist)
CREATE ROLE IF NOT EXISTS GDPR_ADMIN;
CREATE ROLE IF NOT EXISTS DATA_PROTECTION_OFFICER;
CREATE ROLE IF NOT EXISTS CUSTOMER_SERVICE;
CREATE ROLE IF NOT EXISTS ANALYTICS_TEAM;
CREATE ROLE IF NOT EXISTS MARKETING_TEAM;

-- Grant permissions for GDPR roles
GRANT USAGE ON WAREHOUSE GDPR_PROCESSING_WH TO ROLE GDPR_ADMIN;
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE GDPR_ADMIN;

GRANT ALL ON DATABASE COMPLIANCE_DB TO ROLE GDPR_ADMIN;
GRANT ALL ON DATABASE CUSTOMER_DATA_DB TO ROLE GDPR_ADMIN;
GRANT ALL ON DATABASE ANALYTICS_DB TO ROLE GDPR_ADMIN;
GRANT ALL ON DATABASE REFERENCE_DB TO ROLE GDPR_ADMIN;

-- Data Protection Officer permissions
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE DATA_PROTECTION_OFFICER;
GRANT USAGE ON DATABASE COMPLIANCE_DB TO ROLE DATA_PROTECTION_OFFICER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE COMPLIANCE_DB TO ROLE DATA_PROTECTION_OFFICER;
GRANT SELECT ON ALL VIEWS IN DATABASE COMPLIANCE_DB TO ROLE DATA_PROTECTION_OFFICER;

-- Customer Service permissions (limited)
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE CUSTOMER_SERVICE;
GRANT USAGE ON DATABASE CUSTOMER_DATA_DB TO ROLE CUSTOMER_SERVICE;
GRANT USAGE ON SCHEMA CUSTOMER_DATA_DB.CORE TO ROLE CUSTOMER_SERVICE;
GRANT SELECT ON VIEW CUSTOMER_DATA_DB.CORE.VW_CUSTOMERS_GDPR_COMPLIANT TO ROLE CUSTOMER_SERVICE;

-- Analytics Team permissions
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE ANALYTICS_TEAM;
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE ANALYTICS_TEAM;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ANALYTICS_DB TO ROLE ANALYTICS_TEAM;
GRANT SELECT ON VIEW ANALYTICS_DB.EVENTS.VW_USER_ACTIVITIES_ANALYTICS TO ROLE ANALYTICS_TEAM;

-- Marketing Team permissions (consent-based)
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE MARKETING_TEAM;
GRANT USAGE ON DATABASE CUSTOMER_DATA_DB TO ROLE MARKETING_TEAM;
GRANT USAGE ON SCHEMA CUSTOMER_DATA_DB.CORE TO ROLE MARKETING_TEAM;
GRANT SELECT ON VIEW CUSTOMER_DATA_DB.CORE.VW_CUSTOMERS_GDPR_COMPLIANT TO ROLE MARKETING_TEAM;
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE MARKETING_TEAM;
GRANT USAGE ON SCHEMA ANALYTICS_DB.CAMPAIGNS TO ROLE MARKETING_TEAM;

-- ==========================================
-- SECURITY POLICIES SETUP COMPLETE
-- ==========================================

SELECT 'GDPR security policies, masking, and views created successfully!' AS message,
       CURRENT_TIMESTAMP() AS completed_at;

-- Show created policies and views
SHOW ROW ACCESS POLICIES;
SHOW MASKING POLICIES;
SHOW VIEWS LIKE 'VW_%';
