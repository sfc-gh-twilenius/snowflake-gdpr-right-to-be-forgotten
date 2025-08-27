-- ==========================================
-- SNOWFLAKE GDPR RIGHT TO BE FORGOTTEN DEMO
-- Setup Script - Creates all databases, schemas, tables, and procedures
-- ==========================================

-- Use SYSADMIN role for setup
USE ROLE SYSADMIN;

-- ==========================================
-- 1. CREATE DATABASES AND SCHEMAS
-- ==========================================

-- Customer Data Database (Primary customer information)
CREATE DATABASE IF NOT EXISTS CUSTOMER_DATA_DB
    COMMENT = 'Primary customer data for GDPR compliance demo';

CREATE SCHEMA IF NOT EXISTS CUSTOMER_DATA_DB.CORE
    COMMENT = 'Core customer profiles and basic information';

CREATE SCHEMA IF NOT EXISTS CUSTOMER_DATA_DB.TRANSACTIONS
    COMMENT = 'Customer transaction and purchase history';

CREATE SCHEMA IF NOT EXISTS CUSTOMER_DATA_DB.SUPPORT
    COMMENT = 'Customer support interactions and tickets';

CREATE SCHEMA IF NOT EXISTS CUSTOMER_DATA_DB.PREFERENCES
    COMMENT = 'Customer preferences and settings';

-- Analytics Database (Behavioral and ML data)
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB
    COMMENT = 'Customer analytics and behavioral data';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.EVENTS
    COMMENT = 'User activity events and clickstream data';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.CAMPAIGNS
    COMMENT = 'Marketing campaign interactions';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.ML_MODELS
    COMMENT = 'Machine learning features and predictions';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.AGGREGATIONS
    COMMENT = 'Aggregated analytics and reporting data';

-- Compliance Database (GDPR requests and audit trails)
CREATE DATABASE IF NOT EXISTS COMPLIANCE_DB
    COMMENT = 'GDPR compliance, audit trails, and erasure requests';

CREATE SCHEMA IF NOT EXISTS COMPLIANCE_DB.REQUESTS
    COMMENT = 'GDPR erasure and access requests';

CREATE SCHEMA IF NOT EXISTS COMPLIANCE_DB.AUDIT
    COMMENT = 'Comprehensive audit trails for compliance';

CREATE SCHEMA IF NOT EXISTS COMPLIANCE_DB.NOTIFICATIONS
    COMMENT = 'Third-party notifications and coordination';

CREATE SCHEMA IF NOT EXISTS COMPLIANCE_DB.LEGAL
    COMMENT = 'Legal holds and retention policies';

-- Reference Database (Configuration and metadata)
CREATE DATABASE IF NOT EXISTS REFERENCE_DB
    COMMENT = 'Configuration, metadata, and reference data';

CREATE SCHEMA IF NOT EXISTS REFERENCE_DB.CONFIG
    COMMENT = 'GDPR configuration and settings';

CREATE SCHEMA IF NOT EXISTS REFERENCE_DB.METADATA
    COMMENT = 'Data lineage and classification metadata';

-- ==========================================
-- 2. CREATE CORE CUSTOMER DATA TABLES
-- ==========================================

USE SCHEMA CUSTOMER_DATA_DB.CORE;

-- Main customer table
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id STRING PRIMARY KEY,
    email STRING NOT NULL UNIQUE,
    first_name STRING,
    last_name STRING,
    phone_number STRING,
    date_of_birth DATE,
    
    -- Address information
    address_line1 STRING,
    address_line2 STRING,
    city STRING,
    state_province STRING,
    postal_code STRING,
    country_code STRING(2),
    
    -- GDPR compliance fields
    consent_marketing BOOLEAN DEFAULT FALSE,
    consent_analytics BOOLEAN DEFAULT FALSE,
    consent_given_date TIMESTAMP_TZ,
    lawful_basis STRING DEFAULT 'CONSENT',
    data_retention_until DATE,
    
    -- Audit fields
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP_TZ,
    
    -- Metadata for PII classification
    pii_classification VARIANT DEFAULT PARSE_JSON('{"email": "EMAIL_ADDRESS", "phone_number": "PHONE_NUMBER", "address_line1": "POSTAL_ADDRESS"}')
);

-- Customer preferences
USE SCHEMA CUSTOMER_DATA_DB.PREFERENCES;

CREATE OR REPLACE TABLE USER_PREFERENCES (
    preference_id STRING PRIMARY KEY,
    customer_id STRING NOT NULL,
    preference_key STRING NOT NULL,
    preference_value VARIANT,
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER_DATA_DB.CORE.CUSTOMERS(customer_id)
);

-- Transaction data
USE SCHEMA CUSTOMER_DATA_DB.TRANSACTIONS;

CREATE OR REPLACE TABLE ORDERS (
    order_id STRING PRIMARY KEY,
    customer_id STRING NOT NULL,
    customer_email STRING NOT NULL, -- Denormalized for easier discovery
    order_date TIMESTAMP_TZ,
    total_amount NUMBER(10,2),
    currency STRING(3) DEFAULT 'USD',
    payment_method STRING,
    billing_address VARIANT,
    shipping_address VARIANT,
    order_status STRING,
    
    -- Legal retention for financial records
    legal_retention_until DATE,
    can_be_deleted BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER_DATA_DB.CORE.CUSTOMERS(customer_id)
);

CREATE OR REPLACE TABLE ORDER_ITEMS (
    order_item_id STRING PRIMARY KEY,
    order_id STRING NOT NULL,
    product_id STRING,
    product_name STRING,
    quantity INTEGER,
    unit_price NUMBER(10,2),
    total_price NUMBER(10,2),
    
    FOREIGN KEY (order_id) REFERENCES ORDERS(order_id)
);

-- Support data
USE SCHEMA CUSTOMER_DATA_DB.SUPPORT;

CREATE OR REPLACE TABLE SUPPORT_TICKETS (
    ticket_id STRING PRIMARY KEY,
    customer_id STRING NOT NULL,
    customer_email STRING NOT NULL,
    subject STRING,
    description TEXT,
    priority STRING DEFAULT 'MEDIUM',
    status STRING DEFAULT 'OPEN',
    assigned_agent STRING,
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    resolved_at TIMESTAMP_TZ,
    
    -- PII may be in ticket description
    contains_pii BOOLEAN DEFAULT TRUE,
    
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER_DATA_DB.CORE.CUSTOMERS(customer_id)
);

-- ==========================================
-- 3. CREATE ANALYTICS TABLES
-- ==========================================

USE SCHEMA ANALYTICS_DB.EVENTS;

-- User activity events
CREATE OR REPLACE TABLE USER_ACTIVITIES (
    event_id STRING PRIMARY KEY,
    customer_id STRING,
    user_email STRING, -- May exist even if customer record deleted
    session_id STRING,
    event_type STRING,
    event_timestamp TIMESTAMP_TZ,
    page_url STRING,
    user_agent STRING,
    ip_address STRING,
    device_type STRING,
    browser STRING,
    country_code STRING,
    
    -- Event properties
    event_properties VARIANT,
    
    -- GDPR fields
    is_pseudonymized BOOLEAN DEFAULT FALSE,
    pseudonym_id STRING,
    consent_for_analytics BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- Campaign interactions
USE SCHEMA ANALYTICS_DB.CAMPAIGNS;

CREATE OR REPLACE TABLE MARKETING_INTERACTIONS (
    interaction_id STRING PRIMARY KEY,
    customer_id STRING,
    customer_email STRING,
    campaign_id STRING,
    campaign_name STRING,
    interaction_type STRING, -- email_open, click, conversion
    interaction_timestamp TIMESTAMP_TZ,
    channel STRING, -- email, social, web
    content_id STRING,
    conversion_value NUMBER(10,2),
    
    -- Consent tracking
    consent_basis STRING DEFAULT 'MARKETING_CONSENT',
    consent_timestamp TIMESTAMP_TZ,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- ML features and predictions
USE SCHEMA ANALYTICS_DB.ML_MODELS;

CREATE OR REPLACE TABLE CUSTOMER_ML_FEATURES (
    feature_id STRING PRIMARY KEY,
    customer_id STRING,
    feature_set_name STRING,
    features VARIANT, -- JSON object with feature values
    model_version STRING,
    computed_at TIMESTAMP_TZ,
    
    -- Privacy fields
    contains_sensitive_data BOOLEAN DEFAULT TRUE,
    can_be_pseudonymized BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- ==========================================
-- 4. CREATE COMPLIANCE TABLES
-- ==========================================

USE SCHEMA COMPLIANCE_DB.REQUESTS;

-- GDPR erasure requests
CREATE OR REPLACE TABLE ERASURE_REQUESTS (
    request_id STRING PRIMARY KEY,
    customer_id STRING,
    customer_email STRING NOT NULL,
    request_type STRING DEFAULT 'FULL_ERASURE', -- FULL_ERASURE, PARTIAL_ERASURE, DATA_ACCESS
    erasure_reason STRING, -- GDPR Article 17 grounds
    request_source STRING DEFAULT 'WEB_FORM',
    
    -- Request lifecycle
    status STRING DEFAULT 'SUBMITTED', -- SUBMITTED, VALIDATED, IN_PROGRESS, COMPLETED, REJECTED
    requested_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    validated_at TIMESTAMP_TZ,
    started_at TIMESTAMP_TZ,
    completed_at TIMESTAMP_TZ,
    
    -- Legal assessment
    legal_basis_override TEXT,
    retention_exceptions VARIANT,
    
    -- Processing details
    estimated_completion_date DATE,
    actual_completion_date DATE,
    systems_affected VARIANT,
    data_discovered VARIANT,
    deletion_summary VARIANT,
    
    -- Verification
    verification_hash STRING,
    verification_timestamp TIMESTAMP_TZ,
    
    -- Communication
    confirmation_sent_at TIMESTAMP_TZ,
    completion_notification_sent_at TIMESTAMP_TZ
);

-- Data discovery results
CREATE OR REPLACE TABLE DATA_DISCOVERY_RESULTS (
    discovery_id STRING PRIMARY KEY,
    request_id STRING NOT NULL,
    customer_email STRING NOT NULL,
    
    -- Discovery details
    database_name STRING,
    schema_name STRING,
    table_name STRING,
    column_name STRING,
    data_type STRING,
    pii_classification STRING,
    
    -- Data found
    records_found INTEGER,
    sensitive_data_detected BOOLEAN,
    can_be_deleted BOOLEAN,
    deletion_restrictions TEXT,
    
    -- Legal assessment
    retention_requirement STRING,
    legal_basis STRING,
    
    discovered_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (request_id) REFERENCES ERASURE_REQUESTS(request_id)
);

-- Erasure operation log
CREATE OR REPLACE TABLE ERASURE_OPERATIONS (
    operation_id STRING PRIMARY KEY,
    request_id STRING NOT NULL,
    operation_type STRING, -- DELETE, PSEUDONYMIZE, MASK, ANONYMIZE
    target_database STRING,
    target_schema STRING,
    target_table STRING,
    
    -- Operation details
    operation_sql TEXT,
    executed_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    executed_by STRING DEFAULT CURRENT_USER(),
    operation_status STRING DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED
    error_message TEXT,
    
    -- Verification
    records_affected INTEGER,
    before_hash STRING,
    after_hash STRING,
    verification_query TEXT,
    
    FOREIGN KEY (request_id) REFERENCES ERASURE_REQUESTS(request_id)
);

-- Audit trail
USE SCHEMA COMPLIANCE_DB.AUDIT;

CREATE OR REPLACE TABLE GDPR_AUDIT_LOG (
    audit_id STRING PRIMARY KEY,
    event_type STRING NOT NULL,
    event_timestamp TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Subject information
    customer_id STRING,
    customer_email STRING,
    
    -- User information
    user_name STRING DEFAULT CURRENT_USER(),
    role_name STRING DEFAULT CURRENT_ROLE(),
    session_id STRING,
    client_ip STRING,
    
    -- Event details
    event_description TEXT,
    event_data VARIANT,
    
    -- Related entities
    request_id STRING,
    operation_id STRING,
    affected_systems VARIANT,
    data_categories VARIANT,
    
    -- Legal context
    legal_basis STRING,
    consent_status STRING,
    retention_applied BOOLEAN DEFAULT FALSE,
    
    -- Query context
    query_id STRING,
    warehouse_name STRING,
    
    -- Verification
    audit_hash STRING
);

-- Third-party coordination
USE SCHEMA COMPLIANCE_DB.NOTIFICATIONS;

CREATE OR REPLACE TABLE THIRD_PARTY_NOTIFICATIONS (
    notification_id STRING PRIMARY KEY,
    request_id STRING NOT NULL,
    customer_email STRING NOT NULL,
    
    third_party_name STRING,
    third_party_type STRING, -- PROCESSOR, CONTROLLER, PARTNER
    notification_type STRING, -- DELETION_REQUEST, DELETION_CONFIRMATION
    
    -- Notification details
    sent_at TIMESTAMP_TZ,
    method STRING, -- API, EMAIL, MANUAL
    api_endpoint STRING,
    request_payload VARIANT,
    response_payload VARIANT,
    
    -- Status tracking
    status STRING DEFAULT 'PENDING', -- PENDING, SENT, ACKNOWLEDGED, COMPLETED, FAILED
    acknowledged_at TIMESTAMP_TZ,
    completed_at TIMESTAMP_TZ,
    
    -- Verification
    confirmation_token STRING,
    verification_data VARIANT,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (request_id) REFERENCES COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS(request_id)
);

-- Legal holds and retention policies
USE SCHEMA COMPLIANCE_DB.LEGAL;

CREATE OR REPLACE TABLE RETENTION_POLICIES (
    policy_id STRING PRIMARY KEY,
    customer_id STRING,
    data_category STRING,
    retention_reason STRING, -- TAX_COMPLIANCE, LEGAL_HOLD, REGULATORY_REQUIREMENT
    retention_period_months INTEGER,
    retention_start_date DATE,
    retention_end_date DATE,
    jurisdiction STRING,
    legal_reference TEXT,
    
    can_override_gdpr BOOLEAN DEFAULT FALSE,
    override_justification TEXT,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    created_by STRING DEFAULT CURRENT_USER(),
    
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER_DATA_DB.CORE.CUSTOMERS(customer_id)
);

-- ==========================================
-- 5. CREATE REFERENCE TABLES
-- ==========================================

USE SCHEMA REFERENCE_DB.CONFIG;

-- GDPR configuration
CREATE OR REPLACE TABLE GDPR_CONFIG (
    config_key STRING PRIMARY KEY,
    config_value VARIANT,
    description TEXT,
    last_updated TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by STRING DEFAULT CURRENT_USER()
);

-- Insert default configuration
INSERT INTO GDPR_CONFIG VALUES
('MAX_RESPONSE_TIME_DAYS', 30, 'Maximum response time for GDPR requests in days'),
('AUTO_APPROVE_SIMPLE_REQUESTS', TRUE, 'Automatically approve simple erasure requests'),
('REQUIRE_IDENTITY_VERIFICATION', TRUE, 'Require identity verification for erasure requests'),
('DEFAULT_RETENTION_YEARS', 7, 'Default data retention period in years'),
('ENABLE_PSEUDONYMIZATION', TRUE, 'Enable pseudonymization for analytics data'),
('NOTIFICATION_EMAIL', 'gdpr-officer@company.com', 'Email for GDPR notifications'),
('THIRD_PARTY_COORDINATION_ENABLED', TRUE, 'Enable automatic third-party coordination');

-- Data classification metadata
USE SCHEMA REFERENCE_DB.METADATA;

CREATE OR REPLACE TABLE DATA_CLASSIFICATION (
    classification_id STRING PRIMARY KEY,
    database_name STRING,
    schema_name STRING,
    table_name STRING,
    column_name STRING,
    
    -- Classification details
    pii_type STRING, -- EMAIL_ADDRESS, PHONE_NUMBER, SSN, etc.
    sensitivity_level STRING, -- LOW, MEDIUM, HIGH, CRITICAL
    data_category STRING, -- PERSONAL_DATA, SENSITIVE_DATA, SPECIAL_CATEGORY
    
    -- Processing context
    processing_purpose STRING,
    lawful_basis STRING,
    consent_required BOOLEAN DEFAULT TRUE,
    
    -- Retention information
    default_retention_period_months INTEGER,
    can_be_deleted BOOLEAN DEFAULT TRUE,
    deletion_dependencies VARIANT,
    
    -- Discovery metadata
    detection_method STRING, -- MANUAL, AUTOMATIC, PATTERN_MATCHING
    confidence_score NUMBER(3,2),
    last_reviewed TIMESTAMP_TZ,
    reviewed_by STRING,
    
    created_at TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- ==========================================
-- 6. CREATE WAREHOUSES
-- ==========================================

-- Warehouse for GDPR processing
CREATE WAREHOUSE IF NOT EXISTS GDPR_PROCESSING_WH
    WITH WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for GDPR data processing and erasure operations';

-- Warehouse for compliance monitoring
CREATE WAREHOUSE IF NOT EXISTS COMPLIANCE_MONITORING_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for compliance monitoring and reporting';

-- ==========================================
-- 7. SET UP INITIAL CONTEXT
-- ==========================================

-- Set default warehouse
USE WAREHOUSE GDPR_PROCESSING_WH;

-- Set default database for subsequent scripts
USE DATABASE COMPLIANCE_DB;
USE SCHEMA REQUESTS;

-- ==========================================
-- SETUP COMPLETE
-- ==========================================

SELECT 'Snowflake GDPR setup completed successfully!' AS message,
       CURRENT_TIMESTAMP() AS completed_at,
       CURRENT_USER() AS setup_by;

-- Show created databases
SHOW DATABASES LIKE '%DB';

-- Grant basic permissions for demo
-- (In production, implement proper RBAC)
GRANT USAGE ON WAREHOUSE GDPR_PROCESSING_WH TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE COMPLIANCE_MONITORING_WH TO ROLE SYSADMIN;

GRANT ALL ON DATABASE CUSTOMER_DATA_DB TO ROLE SYSADMIN;
GRANT ALL ON DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT ALL ON DATABASE COMPLIANCE_DB TO ROLE SYSADMIN;
GRANT ALL ON DATABASE REFERENCE_DB TO ROLE SYSADMIN;

GRANT ALL ON ALL SCHEMAS IN DATABASE CUSTOMER_DATA_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE COMPLIANCE_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE REFERENCE_DB TO ROLE SYSADMIN;

GRANT ALL ON ALL TABLES IN DATABASE CUSTOMER_DATA_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL TABLES IN DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL TABLES IN DATABASE COMPLIANCE_DB TO ROLE SYSADMIN;
GRANT ALL ON ALL TABLES IN DATABASE REFERENCE_DB TO ROLE SYSADMIN;
