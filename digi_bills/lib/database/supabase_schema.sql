-- ================================================================
-- DIGI BILLS - SUPABASE DATABASE SCHEMA
-- ================================================================
-- Digital Receipt Organizer with Multi-currency & Tax Management
-- ================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- ================================================================
-- USERS & AUTHENTICATION 
-- ================================================================

-- User profiles (extends Supabase auth.users)
CREATE TABLE user_profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255),
    avatar_url TEXT,
    phone VARCHAR(20),
    default_currency VARCHAR(3) DEFAULT 'USD',
    default_country VARCHAR(2) DEFAULT 'US',
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(5) DEFAULT 'en',
    
    -- India specific fields
    gstin_number VARCHAR(15), -- GST Identification Number
    pan_number VARCHAR(10),   -- Permanent Account Number
    
    -- App preferences  
    notification_settings JSONB DEFAULT '{"warranty_alerts": true, "tax_reminders": true, "ai_insights": true}'::jsonb,
    ocr_preferences JSONB DEFAULT '{"auto_categorize": true, "extract_merchant": true, "confidence_threshold": 0.7}'::jsonb,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_gstin CHECK (gstin_number IS NULL OR gstin_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'),
    CONSTRAINT valid_pan CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$')
);

-- ================================================================
-- CURRENCIES & TAX MANAGEMENT
-- ================================================================

-- Supported currencies
CREATE TABLE currencies (
    code VARCHAR(3) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    decimal_places INTEGER DEFAULT 2,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Exchange rates (for multi-currency support)
CREATE TABLE exchange_rates (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    from_currency VARCHAR(3) REFERENCES currencies(code),
    to_currency VARCHAR(3) REFERENCES currencies(code),
    rate DECIMAL(15,6) NOT NULL,
    date DATE NOT NULL,
    source VARCHAR(50) DEFAULT 'manual', -- api, manual, calculated
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(from_currency, to_currency, date)
);

-- Tax rates by country/region
CREATE TABLE tax_rates (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL,
    region_code VARCHAR(10), -- state/province
    tax_type VARCHAR(50) NOT NULL, -- GST, VAT, Sales Tax, etc.
    rate DECIMAL(5,2) NOT NULL,
    hsn_code VARCHAR(20), -- Harmonized System of Nomenclature (India)
    description TEXT,
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_tax_rates_country (country_code),
    INDEX idx_tax_rates_hsn (hsn_code)
);

-- ================================================================
-- MERCHANTS & VENDORS
-- ================================================================

-- Merchant information
CREATE TABLE merchants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100),
    gstin VARCHAR(15), -- GST number for Indian merchants
    
    -- Contact information
    address JSONB, -- {street, city, state, country, postal_code}
    phone VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    
    -- Customer care information (AI extracted)
    customer_care JSONB, -- {phone, email, address, hours, website_support}
    
    -- OCR matching data
    name_variations TEXT[], -- Different ways the name appears on receipts
    logo_hash VARCHAR(64),   -- For image recognition
    
    -- Metadata
    category VARCHAR(100),
    tags TEXT[],
    is_verified BOOLEAN DEFAULT false,
    verification_source VARCHAR(50), -- manual, ai, official_api
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_merchants_name (name),
    INDEX idx_merchants_gstin (gstin),
    INDEX idx_merchants_category (category)
);

-- ================================================================
-- RECEIPTS & DOCUMENTS
-- ================================================================

-- Digital receipts
CREATE TABLE receipts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    merchant_id UUID REFERENCES merchants(id),
    
    -- Receipt identification
    receipt_number VARCHAR(100),
    receipt_date DATE NOT NULL,
    
    -- Financial details
    subtotal DECIMAL(15,2) NOT NULL,
    tax_amount DECIMAL(15,2) DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) REFERENCES currencies(code) NOT NULL,
    
    -- Tax information
    tax_details JSONB, -- {rate, type, hsn_code, gstin}
    
    -- OCR extracted data
    ocr_text TEXT,
    ocr_confidence DECIMAL(3,2),
    ocr_extracted_data JSONB, -- Raw OCR extraction
    
    -- File storage
    image_url TEXT, -- Supabase storage URL
    pdf_url TEXT,   -- Generated PDF URL
    image_hash VARCHAR(64), -- For duplicate detection
    
    -- Classification
    category VARCHAR(100),
    subcategory VARCHAR(100),
    tags TEXT[],
    notes TEXT,
    
    -- AI analysis
    ai_analysis JSONB, -- Insights from AI processing
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_receipts_user (user_id),
    INDEX idx_receipts_date (receipt_date),
    INDEX idx_receipts_merchant (merchant_id),
    INDEX idx_receipts_category (category),
    INDEX idx_receipts_total (total_amount)
);

-- Receipt line items (for detailed analysis)
CREATE TABLE receipt_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    receipt_id UUID REFERENCES receipts(id) ON DELETE CASCADE NOT NULL,
    
    -- Item details
    item_name VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,2) DEFAULT 1,
    unit_price DECIMAL(15,2) NOT NULL,
    total_price DECIMAL(15,2) NOT NULL,
    
    -- Tax details
    tax_rate DECIMAL(5,2),
    tax_amount DECIMAL(15,2),
    hsn_code VARCHAR(20),
    
    -- Classification
    category VARCHAR(100),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_receipt_items_receipt (receipt_id),
    INDEX idx_receipt_items_category (category)
);

-- ================================================================
-- WARRANTY TRACKING
-- ================================================================

-- Product warranties
CREATE TABLE warranties (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    receipt_id UUID REFERENCES receipts(id) ON DELETE SET NULL,
    
    -- Product information
    product_name VARCHAR(255) NOT NULL,
    brand VARCHAR(100),
    model_number VARCHAR(100),
    serial_number VARCHAR(100),
    category VARCHAR(100),
    
    -- Purchase details
    purchase_date DATE NOT NULL,
    purchase_price DECIMAL(15,2),
    currency VARCHAR(3) REFERENCES currencies(code),
    
    -- Warranty information
    warranty_period_months INTEGER NOT NULL,
    warranty_start_date DATE NOT NULL,
    warranty_end_date DATE NOT NULL,
    warranty_type VARCHAR(50) DEFAULT 'manufacturer', -- manufacturer, extended, insurance
    
    -- Documents
    warranty_document_url TEXT,
    purchase_proof_url TEXT,
    
    -- Status tracking
    is_active BOOLEAN DEFAULT true,
    claim_status VARCHAR(50) DEFAULT 'none', -- none, pending, approved, rejected, completed
    claim_details JSONB,
    
    -- Alerts
    alert_days_before INTEGER[] DEFAULT ARRAY[30, 7, 1], -- Days before expiry to alert
    last_alert_sent TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_warranties_user (user_id),
    INDEX idx_warranties_end_date (warranty_end_date),
    INDEX idx_warranties_product (product_name),
    INDEX idx_warranties_active (is_active)
);

-- ================================================================
-- AI INTERACTIONS & CUSTOMER CARE
-- ================================================================

-- AI interaction logs
CREATE TABLE ai_interactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Interaction details
    interaction_type VARCHAR(50) NOT NULL, -- ocr, customer_care_lookup, tax_calculation, warranty_alert
    query_text TEXT,
    response_data JSONB,
    
    -- AI service details
    ai_service VARCHAR(50) NOT NULL, -- openrouter, firecrawl, google_ml_kit
    model_used VARCHAR(100),
    processing_time_ms INTEGER,
    cost_tokens INTEGER,
    
    -- Quality metrics
    confidence_score DECIMAL(3,2),
    user_feedback INTEGER, -- 1-5 rating
    user_feedback_text TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_ai_interactions_user (user_id),
    INDEX idx_ai_interactions_type (interaction_type),
    INDEX idx_ai_interactions_date (created_at)
);

-- Customer care lookup cache
CREATE TABLE customer_care_lookup_cache (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    website_url VARCHAR(500),
    
    -- Extracted contact information
    contact_info JSONB NOT NULL, -- {phone, email, address, hours, support_url}
    extraction_method VARCHAR(50), -- firecrawl, manual, api
    
    -- Cache metadata
    is_verified BOOLEAN DEFAULT false,
    cache_expires_at TIMESTAMPTZ,
    extraction_confidence DECIMAL(3,2),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_customer_care_merchant (merchant_id),
    INDEX idx_customer_care_website (website_url),
    INDEX idx_customer_care_expires (cache_expires_at)
);

-- ================================================================
-- NOTIFICATIONS & ALERTS
-- ================================================================

-- User notifications
CREATE TABLE notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Notification details
    type VARCHAR(50) NOT NULL, -- warranty_alert, tax_reminder, ai_insight, system_update
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Related entities
    related_entity_type VARCHAR(50), -- receipt, warranty, merchant
    related_entity_id UUID,
    
    -- Delivery
    is_read BOOLEAN DEFAULT false,
    is_sent BOOLEAN DEFAULT false,
    sent_via VARCHAR(20), -- push, email, sms
    
    -- Scheduling
    scheduled_for TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Metadata
    priority INTEGER DEFAULT 3, -- 1=high, 3=normal, 5=low
    action_url TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_notifications_user (user_id),
    INDEX idx_notifications_type (type),
    INDEX idx_notifications_scheduled (scheduled_for),
    INDEX idx_notifications_unread (user_id, is_read)
);

-- ================================================================
-- AUDIT & ANALYTICS
-- ================================================================

-- User activity log
CREATE TABLE user_activity_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    
    -- Activity details
    action VARCHAR(100) NOT NULL, -- receipt_uploaded, warranty_added, ai_query, etc.
    entity_type VARCHAR(50),
    entity_id UUID,
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    
    -- Metadata
    metadata JSONB,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    INDEX idx_activity_log_user (user_id),
    INDEX idx_activity_log_action (action),
    INDEX idx_activity_log_date (created_at)
);

-- ================================================================
-- FUNCTIONS & TRIGGERS
-- ================================================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_merchants_updated_at BEFORE UPDATE ON merchants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_receipts_updated_at BEFORE UPDATE ON receipts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_warranties_updated_at BEFORE UPDATE ON warranties FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customer_care_updated_at BEFORE UPDATE ON customer_care_lookup_cache FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to get warranty alerts
CREATE OR REPLACE FUNCTION get_warranty_alerts(user_uuid UUID, days_ahead INTEGER DEFAULT 30)
RETURNS TABLE(
    warranty_id UUID,
    product_name VARCHAR(255),
    warranty_end_date DATE,
    days_remaining INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.product_name,
        w.warranty_end_date,
        (w.warranty_end_date - CURRENT_DATE) as days_remaining
    FROM warranties w
    WHERE w.user_id = user_uuid 
        AND w.is_active = true
        AND w.warranty_end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + days_ahead);
END;
$$ LANGUAGE plpgsql;

-- Function to get expense summary by category
CREATE OR REPLACE FUNCTION get_expense_summary(
    user_uuid UUID,
    start_date DATE,
    end_date DATE,
    target_currency VARCHAR(3) DEFAULT 'USD'
)
RETURNS TABLE(
    category VARCHAR(100),
    total_amount DECIMAL(15,2),
    currency VARCHAR(3),
    receipt_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.category,
        SUM(r.total_amount) as total_amount,
        target_currency as currency,
        COUNT(*) as receipt_count
    FROM receipts r
    WHERE r.user_id = user_uuid 
        AND r.receipt_date BETWEEN start_date AND end_date
    GROUP BY r.category
    ORDER BY total_amount DESC;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================

-- Enable RLS on all user-specific tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranties ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view own receipts" ON receipts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own receipts" ON receipts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own receipts" ON receipts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own receipts" ON receipts FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own warranties" ON warranties FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own warranties" ON warranties FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own warranties" ON warranties FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own warranties" ON warranties FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own AI interactions" ON ai_interactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own AI interactions" ON ai_interactions FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- ================================================================
-- SAMPLE DATA
-- ================================================================

-- Insert default currencies
INSERT INTO currencies (code, name, symbol) VALUES 
('USD', 'US Dollar', '$'),
('EUR', 'Euro', '€'),
('GBP', 'British Pound', '£'),
('INR', 'Indian Rupee', '₹'),
('CAD', 'Canadian Dollar', 'C$'),
('AUD', 'Australian Dollar', 'A$'),
('JPY', 'Japanese Yen', '¥');

-- Insert common Indian GST rates
INSERT INTO tax_rates (country_code, tax_type, rate, hsn_code, description) VALUES 
('IN', 'GST', 0.00, '0000', 'GST Exempt'),
('IN', 'GST', 5.00, '0401', 'Milk and dairy products'),
('IN', 'GST', 12.00, '1905', 'Bread and bakery products'),
('IN', 'GST', 18.00, '8517', 'Telephones and mobile phones'),
('IN', 'GST', 28.00, '8703', 'Motor cars and vehicles');

-- Insert US sales tax rates (sample)
INSERT INTO tax_rates (country_code, region_code, tax_type, rate, description) VALUES 
('US', 'CA', 'Sales Tax', 7.25, 'California state sales tax'),
('US', 'NY', 'Sales Tax', 8.00, 'New York state sales tax'),
('US', 'TX', 'Sales Tax', 6.25, 'Texas state sales tax'),
('US', 'FL', 'Sales Tax', 6.00, 'Florida state sales tax');

-- ================================================================
-- AI ENHANCED TABLES (Additional AI Features)
-- ================================================================

-- Enhanced AI merchant information cache
CREATE TABLE IF NOT EXISTS ai_merchant_cache (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    merchant_name VARCHAR(255) NOT NULL,
    website TEXT,
    contact_methods JSONB DEFAULT '[]'::jsonb,
    support_hours TEXT,
    warranty_support BOOLEAN DEFAULT false,
    categories TEXT[] DEFAULT ARRAY[]::TEXT[],
    cached_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
    
    -- Ensure unique merchant names (case insensitive)
    CONSTRAINT unique_merchant_name UNIQUE (LOWER(merchant_name))
);

-- Enhanced AI interaction logs for analytics
CREATE TABLE IF NOT EXISTS ai_interactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'extract_merchant', 'find_contacts', 'warranty_lookup', etc.
    merchant_name VARCHAR(255),
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    processing_time_ms INTEGER,
    tokens_used INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Receipt AI insights storage
CREATE TABLE IF NOT EXISTS receipt_ai_insights (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    receipt_id UUID REFERENCES receipts ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE,
    
    -- AI generated insights
    suggested_categories TEXT[] DEFAULT ARRAY[]::TEXT[],
    estimated_warranty_months INTEGER,
    tax_compliance_score DECIMAL(3,2) CHECK (tax_compliance_score >= 0 AND tax_compliance_score <= 1),
    merchant_reliability_score INTEGER CHECK (merchant_reliability_score >= 1 AND merchant_reliability_score <= 10),
    
    -- Specific insights
    savings_opportunities JSONB DEFAULT '[]'::jsonb,
    tax_suggestions JSONB DEFAULT '[]'::jsonb,
    warranty_recommendations JSONB DEFAULT '[]'::jsonb,
    general_insights JSONB DEFAULT '[]'::jsonb,
    
    -- Metadata
    ai_model_used VARCHAR(100),
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_receipt_insights UNIQUE (receipt_id)
);

-- ================================================================
-- INDEXES FOR PERFORMANCE
-- ================================================================

-- Additional indexes for common queries
CREATE INDEX idx_receipts_user_date ON receipts(user_id, receipt_date DESC);
CREATE INDEX idx_receipts_amount_range ON receipts(total_amount) WHERE total_amount > 0;
CREATE INDEX idx_warranties_expiry ON warranties(warranty_end_date) WHERE is_active = true;
CREATE INDEX idx_ai_interactions_recent ON ai_interactions(user_id, created_at DESC);
CREATE INDEX idx_exchange_rates_lookup ON exchange_rates(from_currency, to_currency, date DESC);

-- Full-text search indexes
CREATE INDEX idx_receipts_ocr_text_search ON receipts USING GIN(to_tsvector('english', ocr_text));
CREATE INDEX idx_merchants_name_search ON merchants USING GIN(to_tsvector('english', name));

-- ================================================================
-- END SCHEMA
-- ================================================================