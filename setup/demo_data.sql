-- ==========================================
-- SNOWFLAKE GDPR DEMO DATA SETUP
-- Creates realistic customer data for testing GDPR workflows
-- ==========================================

USE ROLE SYSADMIN;
USE WAREHOUSE GDPR_PROCESSING_WH;

-- ==========================================
-- 1. CREATE DEMO CUSTOMERS
-- ==========================================

USE SCHEMA CUSTOMER_DATA_DB.CORE;

-- Insert demo customers with various consent and retention scenarios
INSERT INTO CUSTOMERS (
    customer_id, email, first_name, last_name, phone_number, date_of_birth,
    address_line1, city, state_province, postal_code, country_code,
    consent_marketing, consent_analytics, consent_given_date, lawful_basis, data_retention_until
) VALUES
-- EU customers (GDPR applies)
('CUST_001', 'anna.mueller@email.de', 'Anna', 'Mueller', '+49-30-12345678', '1985-03-15',
 '123 Hauptstrasse', 'Berlin', 'Berlin', '10115', 'DE',
 TRUE, TRUE, '2024-01-15 10:30:00', 'CONSENT', '2031-01-15'),

('CUST_002', 'jean.dupont@email.fr', 'Jean', 'Dupont', '+33-1-23456789', '1990-07-22',
 '456 Rue de la Paix', 'Paris', 'Île-de-France', '75001', 'FR',
 FALSE, TRUE, '2024-02-20 14:15:00', 'LEGITIMATE_INTEREST', '2029-02-20'),

('CUST_003', 'maria.garcia@email.es', 'Maria', 'Garcia', '+34-91-1234567', '1988-11-08',
 '789 Calle Mayor', 'Madrid', 'Madrid', '28001', 'ES',
 TRUE, FALSE, '2024-03-10 09:45:00', 'CONSENT', '2030-03-10'),

('CUST_004', 'giovanni.rossi@email.it', 'Giovanni', 'Rossi', '+39-06-12345678', '1992-05-03',
 '321 Via Roma', 'Rome', 'Lazio', '00100', 'IT',
 TRUE, TRUE, '2024-01-05 16:20:00', 'CONTRACT', '2031-01-05'),

('CUST_005', 'lars.andersson@email.se', 'Lars', 'Andersson', '+46-8-1234567', '1987-09-18',
 '654 Drottninggatan', 'Stockholm', 'Stockholm', '11151', 'SE',
 FALSE, FALSE, NULL, 'LEGITIMATE_INTEREST', '2028-09-18'),

-- Non-EU customers (for comparison)
('CUST_006', 'john.smith@email.com', 'John', 'Smith', '+1-555-123-4567', '1984-12-12',
 '123 Main Street', 'New York', 'NY', '10001', 'US',
 TRUE, TRUE, '2024-02-01 11:00:00', 'CONSENT', '2032-02-01'),

('CUST_007', 'sarah.wilson@email.com', 'Sarah', 'Wilson', '+1-555-987-6543', '1991-04-25',
 '456 Oak Avenue', 'Los Angeles', 'CA', '90210', 'US',
 TRUE, FALSE, '2024-01-20 13:30:00', 'CONSENT', '2031-01-20'),

('CUST_008', 'hiroshi.tanaka@email.jp', 'Hiroshi', 'Tanaka', '+81-3-1234-5678', '1989-08-14',
 '789 Shibuya Street', 'Tokyo', 'Tokyo', '150-0002', 'JP',
 FALSE, TRUE, '2024-03-05 08:15:00', 'LEGITIMATE_INTEREST', '2029-03-05'),

-- Customers with special scenarios
('CUST_009', 'consent.withdrawn@email.de', 'Klaus', 'Weber', '+49-89-1234567', '1986-06-30',
 '111 Marienplatz', 'Munich', 'Bavaria', '80331', 'DE',
 FALSE, FALSE, '2023-12-01 10:00:00', 'CONSENT', '2025-12-01'), -- Consent withdrawn

('CUST_010', 'data.retention.expired@email.fr', 'Pierre', 'Martin', '+33-4-12345678', '1983-02-14',
 '222 Boulevard Saint-Germain', 'Lyon', 'Auvergne-Rhône-Alpes', '69001', 'FR',
 TRUE, TRUE, '2022-01-01 12:00:00', 'CONSENT', '2024-01-01'), -- Retention expired

-- Minor's data (special GDPR consideration)
('CUST_011', 'teen.user@email.de', 'Max', 'Schmidt', '+49-40-1234567', '2008-03-20',
 '333 Reeperbahn', 'Hamburg', 'Hamburg', '20359', 'DE',
 FALSE, FALSE, NULL, 'PARENTAL_CONSENT', '2026-03-20'),

-- B2B customer with complex data
('CUST_012', 'business.contact@company.com', 'Emma', 'Johnson', '+44-20-12345678', '1982-10-05',
 '444 Business Park', 'London', 'England', 'SW1A 1AA', 'GB',
 TRUE, TRUE, '2024-01-10 15:45:00', 'CONTRACT', '2034-01-10');

-- ==========================================
-- 2. CREATE USER PREFERENCES
-- ==========================================

USE SCHEMA CUSTOMER_DATA_DB.PREFERENCES;

INSERT INTO USER_PREFERENCES (preference_id, customer_id, preference_key, preference_value) VALUES
-- Preferences for CUST_001 (Anna Mueller)
('PREF_001_01', 'CUST_001', 'language', '"de"'),
('PREF_001_02', 'CUST_001', 'timezone', '"Europe/Berlin"'),
('PREF_001_03', 'CUST_001', 'email_frequency', '"weekly"'),
('PREF_001_04', 'CUST_001', 'data_sharing_level', '"minimal"'),

-- Preferences for CUST_002 (Jean Dupont)
('PREF_002_01', 'CUST_002', 'language', '"fr"'),
('PREF_002_02', 'CUST_002', 'timezone', '"Europe/Paris"'),
('PREF_002_03', 'CUST_002', 'email_frequency', '"never"'),

-- Preferences for other customers
('PREF_003_01', 'CUST_003', 'language', '"es"'),
('PREF_003_02', 'CUST_003', 'newsletter_subscription', 'false'),
('PREF_004_01', 'CUST_004', 'language', '"it"'),
('PREF_004_02', 'CUST_004', 'data_export_format', '"json"'),
('PREF_006_01', 'CUST_006', 'language', '"en"'),
('PREF_006_02', 'CUST_006', 'marketing_preferences', '{"email": true, "sms": false, "phone": false}');

-- ==========================================
-- 3. CREATE TRANSACTION DATA
-- ==========================================

USE SCHEMA CUSTOMER_DATA_DB.TRANSACTIONS;

INSERT INTO ORDERS (
    order_id, customer_id, customer_email, order_date, total_amount, currency,
    payment_method, billing_address, shipping_address, order_status, legal_retention_until, can_be_deleted
) VALUES
-- Orders for EU customers
('ORD_001_001', 'CUST_001', 'anna.mueller@email.de', '2024-01-20 14:30:00', 299.99, 'EUR',
 'CREDIT_CARD', 
 PARSE_JSON('{"street": "123 Hauptstrasse", "city": "Berlin", "postal_code": "10115", "country": "DE"}'),
 PARSE_JSON('{"street": "123 Hauptstrasse", "city": "Berlin", "postal_code": "10115", "country": "DE"}'),
 'DELIVERED', '2031-01-20', TRUE),

('ORD_001_002', 'CUST_001', 'anna.mueller@email.de', '2024-03-15 10:15:00', 149.50, 'EUR',
 'PAYPAL',
 PARSE_JSON('{"street": "123 Hauptstrasse", "city": "Berlin", "postal_code": "10115", "country": "DE"}'),
 PARSE_JSON('{"street": "123 Hauptstrasse", "city": "Berlin", "postal_code": "10115", "country": "DE"}'),
 'PROCESSING', '2031-03-15', TRUE),

('ORD_002_001', 'CUST_002', 'jean.dupont@email.fr', '2024-02-25 16:45:00', 89.99, 'EUR',
 'BANK_TRANSFER',
 PARSE_JSON('{"street": "456 Rue de la Paix", "city": "Paris", "postal_code": "75001", "country": "FR"}'),
 PARSE_JSON('{"street": "456 Rue de la Paix", "city": "Paris", "postal_code": "75001", "country": "FR"}'),
 'DELIVERED', '2031-02-25', FALSE), -- Cannot be deleted due to legal hold

('ORD_003_001', 'CUST_003', 'maria.garcia@email.es', '2024-03-01 12:20:00', 199.99, 'EUR',
 'CREDIT_CARD',
 PARSE_JSON('{"street": "789 Calle Mayor", "city": "Madrid", "postal_code": "28001", "country": "ES"}'),
 PARSE_JSON('{"street": "789 Calle Mayor", "city": "Madrid", "postal_code": "28001", "country": "ES"}'),
 'DELIVERED', '2031-03-01', TRUE),

-- Orders for non-EU customers
('ORD_006_001', 'CUST_006', 'john.smith@email.com', '2024-02-10 09:30:00', 399.99, 'USD',
 'CREDIT_CARD',
 PARSE_JSON('{"street": "123 Main Street", "city": "New York", "state": "NY", "postal_code": "10001", "country": "US"}'),
 PARSE_JSON('{"street": "123 Main Street", "city": "New York", "state": "NY", "postal_code": "10001", "country": "US"}'),
 'DELIVERED', '2031-02-10', TRUE),

-- High-value order with extended retention
('ORD_012_001', 'CUST_012', 'business.contact@company.com', '2024-01-15 11:00:00', 9999.99, 'GBP',
 'WIRE_TRANSFER',
 PARSE_JSON('{"street": "444 Business Park", "city": "London", "postal_code": "SW1A 1AA", "country": "GB"}'),
 PARSE_JSON('{"street": "444 Business Park", "city": "London", "postal_code": "SW1A 1AA", "country": "GB"}'),
 'DELIVERED', '2034-01-15', FALSE); -- B2B contract retention

-- Order items
INSERT INTO ORDER_ITEMS (order_item_id, order_id, product_id, product_name, quantity, unit_price, total_price) VALUES
('ITEM_001_001_01', 'ORD_001_001', 'PROD_LAPTOP_001', 'Business Laptop Pro', 1, 299.99, 299.99),
('ITEM_001_002_01', 'ORD_001_002', 'PROD_MOUSE_001', 'Wireless Mouse', 1, 49.50, 49.50),
('ITEM_001_002_02', 'ORD_001_002', 'PROD_KEYBOARD_001', 'Mechanical Keyboard', 1, 100.00, 100.00),
('ITEM_002_001_01', 'ORD_002_001', 'PROD_HEADPHONES_001', 'Noise-Canceling Headphones', 1, 89.99, 89.99),
('ITEM_003_001_01', 'ORD_003_001', 'PROD_TABLET_001', 'Tablet 10-inch', 1, 199.99, 199.99),
('ITEM_006_001_01', 'ORD_006_001', 'PROD_SMARTPHONE_001', 'Latest Smartphone', 1, 399.99, 399.99),
('ITEM_012_001_01', 'ORD_012_001', 'PROD_SERVER_001', 'Enterprise Server', 1, 9999.99, 9999.99);

-- ==========================================
-- 4. CREATE SUPPORT TICKET DATA
-- ==========================================

USE SCHEMA CUSTOMER_DATA_DB.SUPPORT;

INSERT INTO SUPPORT_TICKETS (
    ticket_id, customer_id, customer_email, subject, description, priority, status, assigned_agent, resolved_at
) VALUES
('TICK_001_001', 'CUST_001', 'anna.mueller@email.de', 
 'Laptop delivery delay', 'My laptop order is delayed. Can you provide an update?', 
 'MEDIUM', 'RESOLVED', 'agent_sarah', '2024-01-25 15:30:00'),

('TICK_002_001', 'CUST_002', 'jean.dupont@email.fr',
 'Request for data deletion', 'I want to delete my account and all personal data per GDPR Article 17.',
 'HIGH', 'OPEN', 'agent_marie', NULL),

('TICK_003_001', 'CUST_003', 'maria.garcia@email.es',
 'Billing question', 'I have a question about my recent invoice.',
 'LOW', 'RESOLVED', 'agent_carlos', '2024-03-05 14:20:00'),

('TICK_009_001', 'CUST_009', 'consent.withdrawn@email.de',
 'Withdraw marketing consent', 'Please remove me from all marketing communications.',
 'MEDIUM', 'RESOLVED', 'agent_klaus', '2023-12-02 10:30:00'),

('TICK_011_001', 'CUST_011', 'teen.user@email.de',
 'Account access issue', 'Cannot access my account after turning 16.',
 'MEDIUM', 'OPEN', 'agent_anna', NULL);

-- ==========================================
-- 5. CREATE ANALYTICS DATA
-- ==========================================

USE SCHEMA ANALYTICS_DB.EVENTS;

-- Generate user activity events for the past 3 months
INSERT INTO USER_ACTIVITIES (
    event_id, customer_id, user_email, session_id, event_type, event_timestamp,
    page_url, user_agent, ip_address, device_type, browser, country_code,
    event_properties, consent_for_analytics
) VALUES
-- Events for CUST_001 (Anna Mueller)
('EVT_001_001', 'CUST_001', 'anna.mueller@email.de', 'SESS_001_001', 'page_view', '2024-01-15 09:30:00',
 '/products/laptops', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.101', 'desktop', 'Chrome', 'DE',
 PARSE_JSON('{"page_category": "products", "time_on_page": 45}'), TRUE),

('EVT_001_002', 'CUST_001', 'anna.mueller@email.de', 'SESS_001_001', 'add_to_cart', '2024-01-15 09:32:00',
 '/products/laptops/business-pro', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.101', 'desktop', 'Chrome', 'DE',
 PARSE_JSON('{"product_id": "PROD_LAPTOP_001", "price": 299.99}'), TRUE),

('EVT_001_003', 'CUST_001', 'anna.mueller@email.de', 'SESS_001_002', 'purchase', '2024-01-20 14:30:00',
 '/checkout/complete', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.101', 'desktop', 'Chrome', 'DE',
 PARSE_JSON('{"order_id": "ORD_001_001", "total": 299.99, "payment_method": "CREDIT_CARD"}'), TRUE),

-- Events for CUST_002 (Jean Dupont) - analytics consent withdrawn
('EVT_002_001', 'CUST_002', 'jean.dupont@email.fr', 'SESS_002_001', 'page_view', '2024-02-20 14:15:00',
 '/products/headphones', 'Mozilla/5.0 (Macintosh; Intel Mac OS X)', '10.0.1.101', 'desktop', 'Safari', 'FR',
 PARSE_JSON('{"page_category": "products", "time_on_page": 30}'), FALSE),

-- Events for CUST_003 (Maria Garcia) - marketing consent withdrawn, but analytics OK
('EVT_003_001', 'CUST_003', 'maria.garcia@email.es', 'SESS_003_001', 'page_view', '2024-02-28 16:45:00',
 '/products/tablets', 'Mozilla/5.0 (iPhone; CPU iPhone OS)', '172.16.1.101', 'mobile', 'Safari', 'ES',
 PARSE_JSON('{"page_category": "products", "time_on_page": 60}'), TRUE),

('EVT_003_002', 'CUST_003', 'maria.garcia@email.es', 'SESS_003_001', 'purchase', '2024-03-01 12:20:00',
 '/checkout/complete', 'Mozilla/5.0 (iPhone; CPU iPhone OS)', '172.16.1.101', 'mobile', 'Safari', 'ES',
 PARSE_JSON('{"order_id": "ORD_003_001", "total": 199.99}'), TRUE),

-- Events for customers who will have data deleted (for testing pseudonymization)
('EVT_009_001', 'CUST_009', 'consent.withdrawn@email.de', 'SESS_009_001', 'page_view', '2023-11-15 10:30:00',
 '/account/settings', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.2.101', 'desktop', 'Firefox', 'DE',
 PARSE_JSON('{"page_category": "account", "action": "consent_withdrawal"}'), FALSE);

-- ==========================================
-- 6. CREATE MARKETING CAMPAIGN DATA
-- ==========================================

USE SCHEMA ANALYTICS_DB.CAMPAIGNS;

INSERT INTO MARKETING_INTERACTIONS (
    interaction_id, customer_id, customer_email, campaign_id, campaign_name,
    interaction_type, interaction_timestamp, channel, content_id, conversion_value,
    consent_basis, consent_timestamp
) VALUES
-- Marketing interactions for customers with marketing consent
('MKTG_001_001', 'CUST_001', 'anna.mueller@email.de', 'CAMP_SPRING_2024', 'Spring Sale 2024',
 'email_open', '2024-03-01 08:00:00', 'email', 'EMAIL_SPRING_LAPTOPS', NULL,
 'MARKETING_CONSENT', '2024-01-15 10:30:00'),

('MKTG_001_002', 'CUST_001', 'anna.mueller@email.de', 'CAMP_SPRING_2024', 'Spring Sale 2024',
 'click', '2024-03-01 08:05:00', 'email', 'EMAIL_SPRING_LAPTOPS', NULL,
 'MARKETING_CONSENT', '2024-01-15 10:30:00'),

('MKTG_004_001', 'CUST_004', 'giovanni.rossi@email.it', 'CAMP_NEWSLETTER_Q1', 'Q1 Newsletter',
 'email_open', '2024-02-15 09:30:00', 'email', 'EMAIL_NEWSLETTER_Q1', NULL,
 'MARKETING_CONSENT', '2024-01-05 16:20:00'),

('MKTG_006_001', 'CUST_006', 'john.smith@email.com', 'CAMP_US_PROMOTION', 'US Special Promotion',
 'conversion', '2024-02-10 09:30:00', 'web', 'PROMO_US_TECH', 399.99,
 'MARKETING_CONSENT', '2024-02-01 11:00:00'),

-- Marketing interactions that should be filtered out (no consent)
('MKTG_002_001', 'CUST_002', 'jean.dupont@email.fr', 'CAMP_SPRING_2024', 'Spring Sale 2024',
 'email_sent', '2024-03-01 08:00:00', 'email', 'EMAIL_SPRING_LAPTOPS', NULL,
 'SENT_BEFORE_WITHDRAWAL', '2024-02-20 14:15:00');

-- ==========================================
-- 7. CREATE ML MODEL DATA
-- ==========================================

USE SCHEMA ANALYTICS_DB.ML_MODELS;

INSERT INTO CUSTOMER_ML_FEATURES (
    feature_id, customer_id, feature_set_name, features, model_version, computed_at
) VALUES
('ML_001_001', 'CUST_001', 'customer_ltv_model', 
 PARSE_JSON('{"ltv_score": 0.85, "purchase_frequency": 0.3, "avg_order_value": 299.99, "churn_probability": 0.1}'),
 'v2.1', '2024-03-01 02:00:00'),

('ML_003_001', 'CUST_003', 'recommendation_features',
 PARSE_JSON('{"category_preference": "electronics", "price_sensitivity": 0.6, "brand_loyalty": 0.4}'),
 'v1.5', '2024-03-02 02:00:00'),

('ML_006_001', 'CUST_006', 'customer_ltv_model',
 PARSE_JSON('{"ltv_score": 0.92, "purchase_frequency": 0.2, "avg_order_value": 399.99, "churn_probability": 0.05}'),
 'v2.1', '2024-03-01 02:00:00');

-- ==========================================
-- 8. CREATE COMPLIANCE DATA
-- ==========================================

USE SCHEMA COMPLIANCE_DB.REQUESTS;

-- Sample erasure requests in different states
INSERT INTO ERASURE_REQUESTS (
    request_id, customer_id, customer_email, request_type, erasure_reason, request_source,
    status, requested_at, validated_at, started_at, completed_at, estimated_completion_date,
    actual_completion_date, verification_hash
) VALUES
-- Completed erasure request
('REQ_2024_001', 'CUST_009', 'consent.withdrawn@email.de', 'FULL_ERASURE', 'WITHDRAWN_CONSENT', 'WEB_FORM',
 'COMPLETED', '2023-12-01 10:00:00', '2023-12-01 10:30:00', '2023-12-02 09:00:00', '2023-12-05 15:30:00',
 '2023-12-31', '2023-12-05', 'abc123def456789'),

-- In-progress erasure request
('REQ_2024_002', 'CUST_002', 'jean.dupont@email.fr', 'FULL_ERASURE', 'OBJECTION', 'SUPPORT_TICKET',
 'IN_PROGRESS', '2024-03-01 14:00:00', '2024-03-01 14:30:00', '2024-03-02 09:00:00', NULL,
 '2024-03-31', NULL, NULL),

-- Recently submitted request
('REQ_2024_003', 'CUST_010', 'data.retention.expired@email.fr', 'FULL_ERASURE', 'NO_LONGER_NECESSARY', 'API',
 'SUBMITTED', '2024-03-15 16:30:00', NULL, NULL, NULL,
 '2024-04-14', NULL, NULL);

-- ==========================================
-- 9. CREATE LEGAL RETENTION POLICIES
-- ==========================================

USE SCHEMA COMPLIANCE_DB.LEGAL;

INSERT INTO RETENTION_POLICIES (
    policy_id, customer_id, data_category, retention_reason, retention_period_months,
    retention_start_date, retention_end_date, jurisdiction, legal_reference, can_override_gdpr
) VALUES
-- Tax compliance retention (cannot override GDPR erasure)
('POL_001', 'CUST_002', 'FINANCIAL_TRANSACTIONS', 'TAX_COMPLIANCE', 84, 
 '2024-02-25', '2031-02-25', 'FR', 'French Tax Code Article 102', FALSE),

-- Legal investigation hold
('POL_002', 'CUST_012', 'ALL_DATA', 'LEGAL_INVESTIGATION', 36,
 '2024-01-15', '2027-01-15', 'GB', 'Data Protection Act 2018', TRUE),

-- Regulatory compliance
('POL_003', 'CUST_006', 'FINANCIAL_TRANSACTIONS', 'REGULATORY_REQUIREMENT', 60,
 '2024-02-10', '2029-02-10', 'US', 'SOX Compliance Requirements', FALSE);

-- ==========================================
-- 10. CREATE AUDIT LOG ENTRIES
-- ==========================================

USE SCHEMA COMPLIANCE_DB.AUDIT;

INSERT INTO GDPR_AUDIT_LOG (
    audit_id, event_type, event_timestamp, customer_email, user_name, role_name,
    event_description, event_data, request_id, legal_basis, consent_status
) VALUES
('AUDIT_001', 'ERASURE_REQUEST_SUBMITTED', '2023-12-01 10:00:00', 'consent.withdrawn@email.de', 'SYSTEM', 'GDPR_PROCESSOR',
 'Customer submitted erasure request due to withdrawn consent',
 PARSE_JSON('{"request_type": "FULL_ERASURE", "reason": "WITHDRAWN_CONSENT", "source": "WEB_FORM"}'),
 'REQ_2024_001', 'CONSENT', 'WITHDRAWN'),

('AUDIT_002', 'DATA_DELETION_COMPLETED', '2023-12-05 15:30:00', 'consent.withdrawn@email.de', 'GDPR_PROCESSOR', 'SYSTEM',
 'Personal data deletion completed across all systems',
 PARSE_JSON('{"systems_affected": ["CUSTOMER_DATA_DB", "ANALYTICS_DB"], "records_deleted": 15}'),
 'REQ_2024_001', 'CONSENT', 'WITHDRAWN'),

('AUDIT_003', 'CONSENT_WITHDRAWAL', '2024-02-20 14:15:00', 'jean.dupont@email.fr', 'jean.dupont@email.fr', 'CUSTOMER',
 'Customer withdrew analytics consent',
 PARSE_JSON('{"consent_type": "analytics", "withdrawal_method": "account_settings"}'),
 NULL, 'LEGITIMATE_INTEREST', 'WITHDRAWN'),

('AUDIT_004', 'ERASURE_REQUEST_SUBMITTED', '2024-03-01 14:00:00', 'jean.dupont@email.fr', 'SUPPORT_AGENT', 'CUSTOMER_SERVICE',
 'Erasure request submitted via support ticket',
 PARSE_JSON('{"request_type": "FULL_ERASURE", "reason": "OBJECTION", "source": "SUPPORT_TICKET"}'),
 'REQ_2024_002', 'LEGITIMATE_INTEREST', 'OBJECTION'),

('AUDIT_005', 'DATA_ACCESS_REQUEST', '2024-03-10 11:20:00', 'maria.garcia@email.es', 'maria.garcia@email.es', 'CUSTOMER',
 'Customer requested data export',
 PARSE_JSON('{"export_format": "JSON", "data_categories": ["personal_data", "transaction_history"]}'),
 NULL, 'CONSENT', 'GRANTED');

-- ==========================================
-- 11. CREATE THIRD-PARTY NOTIFICATION RECORDS
-- ==========================================

USE SCHEMA COMPLIANCE_DB.NOTIFICATIONS;

INSERT INTO THIRD_PARTY_NOTIFICATIONS (
    notification_id, request_id, customer_email, third_party_name, third_party_type,
    notification_type, sent_at, method, status, acknowledged_at, completed_at
) VALUES
-- Notifications for completed erasure request
('NOTIF_001', 'REQ_2024_001', 'consent.withdrawn@email.de', 'GOOGLE_ANALYTICS', 'PROCESSOR',
 'DELETION_REQUEST', '2023-12-02 10:00:00', 'API', 'COMPLETED', '2023-12-02 10:05:00', '2023-12-02 16:30:00'),

('NOTIF_002', 'REQ_2024_001', 'consent.withdrawn@email.de', 'MAILCHIMP', 'PROCESSOR',
 'DELETION_REQUEST', '2023-12-02 10:01:00', 'API', 'COMPLETED', '2023-12-02 10:10:00', '2023-12-03 09:15:00'),

-- Pending notifications for in-progress request
('NOTIF_003', 'REQ_2024_002', 'jean.dupont@email.fr', 'GOOGLE_ANALYTICS', 'PROCESSOR',
 'DELETION_REQUEST', '2024-03-02 09:30:00', 'API', 'SENT', '2024-03-02 09:35:00', NULL),

('NOTIF_004', 'REQ_2024_002', 'jean.dupont@email.fr', 'SALESFORCE', 'PROCESSOR',
 'DELETION_REQUEST', '2024-03-02 09:32:00', 'EMAIL', 'PENDING', NULL, NULL);

-- ==========================================
-- 12. UPDATE DATA CLASSIFICATION METADATA
-- ==========================================

USE SCHEMA REFERENCE_DB.METADATA;

INSERT INTO DATA_CLASSIFICATION (
    classification_id, database_name, schema_name, table_name, column_name,
    pii_type, sensitivity_level, data_category, processing_purpose, lawful_basis,
    consent_required, default_retention_period_months, can_be_deleted,
    detection_method, confidence_score, last_reviewed, reviewed_by
) VALUES
-- Customer table classifications
('CLASS_001', 'CUSTOMER_DATA_DB', 'CORE', 'CUSTOMERS', 'email', 
 'EMAIL_ADDRESS', 'HIGH', 'PERSONAL_DATA', 'CUSTOMER_IDENTIFICATION', 'CONSENT', 
 TRUE, 84, TRUE, 'MANUAL', 1.00, CURRENT_TIMESTAMP(), 'DATA_PROTECTION_OFFICER'),

('CLASS_002', 'CUSTOMER_DATA_DB', 'CORE', 'CUSTOMERS', 'phone_number',
 'PHONE_NUMBER', 'HIGH', 'PERSONAL_DATA', 'CUSTOMER_CONTACT', 'CONSENT',
 TRUE, 84, TRUE, 'MANUAL', 1.00, CURRENT_TIMESTAMP(), 'DATA_PROTECTION_OFFICER'),

('CLASS_003', 'CUSTOMER_DATA_DB', 'CORE', 'CUSTOMERS', 'date_of_birth',
 'DATE_OF_BIRTH', 'CRITICAL', 'SENSITIVE_DATA', 'AGE_VERIFICATION', 'CONSENT',
 TRUE, 84, TRUE, 'MANUAL', 1.00, CURRENT_TIMESTAMP(), 'DATA_PROTECTION_OFFICER'),

-- Transaction table classifications
('CLASS_004', 'CUSTOMER_DATA_DB', 'TRANSACTIONS', 'ORDERS', 'customer_email',
 'EMAIL_ADDRESS', 'HIGH', 'PERSONAL_DATA', 'ORDER_PROCESSING', 'CONTRACT',
 FALSE, 84, FALSE, 'MANUAL', 1.00, CURRENT_TIMESTAMP(), 'DATA_PROTECTION_OFFICER'),

-- Analytics table classifications
('CLASS_005', 'ANALYTICS_DB', 'EVENTS', 'USER_ACTIVITIES', 'user_email',
 'EMAIL_ADDRESS', 'MEDIUM', 'PERSONAL_DATA', 'ANALYTICS', 'CONSENT',
 TRUE, 36, TRUE, 'AUTOMATIC', 0.95, CURRENT_TIMESTAMP(), 'SYSTEM'),

('CLASS_006', 'ANALYTICS_DB', 'EVENTS', 'USER_ACTIVITIES', 'ip_address',
 'IP_ADDRESS', 'MEDIUM', 'PERSONAL_DATA', 'ANALYTICS', 'LEGITIMATE_INTEREST',
 FALSE, 12, TRUE, 'AUTOMATIC', 0.90, CURRENT_TIMESTAMP(), 'SYSTEM');

-- ==========================================
-- DEMO DATA SETUP COMPLETE
-- ==========================================

SELECT 'Demo data setup completed successfully!' AS message,
       CURRENT_TIMESTAMP() AS completed_at,
       (SELECT COUNT(*) FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS) AS customers_created,
       (SELECT COUNT(*) FROM CUSTOMER_DATA_DB.TRANSACTIONS.ORDERS) AS orders_created,
       (SELECT COUNT(*) FROM ANALYTICS_DB.EVENTS.USER_ACTIVITIES) AS events_created,
       (SELECT COUNT(*) FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS) AS erasure_requests_created;

-- Show some sample data
SELECT 'Sample Customers:' AS info;
SELECT customer_id, email, first_name, last_name, country_code, consent_marketing, consent_analytics
FROM CUSTOMER_DATA_DB.CORE.CUSTOMERS 
LIMIT 5;

SELECT 'Sample Erasure Requests:' AS info;
SELECT request_id, customer_email, status, requested_at, estimated_completion_date
FROM COMPLIANCE_DB.REQUESTS.ERASURE_REQUESTS;

SELECT 'GDPR Compliance Dashboard:' AS info;
SELECT * FROM COMPLIANCE_DB.REQUESTS.VW_GDPR_COMPLIANCE_DASHBOARD;
