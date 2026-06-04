-- ============================================================
-- E-Commerce Sales Analysis - Online Retail II Dataset
-- Author: Abdelrhman
-- Database: PostgreSQL 18
-- Dataset: UCI Online Retail II (2009-2011)
-- Source: https://archive.ics.uci.edu/dataset/502/online+retail+ii
-- ============================================================


-- ============================================================
-- STEP 1: DATABASE SETUP
-- ============================================================

-- 1. Create a new database called 'online_retail' in pgAdmin
-- 2. Download the dataset from the link above
-- 3. The Excel file contains two sheets:
--    - Sheet 1: Year 2009-2010
--    - Sheet 2: Year 2010-2011
-- 4. Save each sheet as a separate CSV (UTF-8 format) before importing
-- 5. Run the following scripts in order

-- Raw Sales Table
CREATE TABLE raw_sales (
    invoice VARCHAR(20),
    stock_code VARCHAR(20),
    description TEXT,
    quantity INTEGER,
    invoice_date TIMESTAMP,
    price NUMERIC(10,2),
    customer_id VARCHAR(20),
    country VARCHAR(50)
);

-- Import first CSV via pgAdmin: right-click raw_sales > Import/Export Data
-- For the second CSV, create a temp table and merge:
-- CREATE TABLE raw_sales_2009 (same structure as raw_sales);
-- Import second CSV into raw_sales_2009
-- INSERT INTO raw_sales SELECT * FROM raw_sales_2009;


-- ============================================================
-- STEP 2: NORMALIZATION (Flat File → Relational Tables)
-- ============================================================

-- Customers Table
CREATE TABLE customers AS
SELECT 
    customer_id,
    MAX(country) AS country
FROM raw_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id;

-- Products Table
CREATE TABLE products AS
SELECT 
    stock_code,
    MAX(description) AS description,
    MAX(price) AS standard_price
FROM raw_sales
WHERE stock_code IS NOT NULL
GROUP BY stock_code;

-- Transactions Table
-- Note: NULL customer_ids replaced with 'Guest' to represent guest checkouts
CREATE TABLE transactions AS
SELECT 
    invoice,
    stock_code,
    COALESCE(customer_id, 'Guest') AS customer_id,
    quantity,
    invoice_date,
    price
FROM raw_sales;


-- ============================================================
-- STEP 3: SALES ANALYSIS
-- ============================================================

-- Total Revenue (Overall)
SELECT
    SUM(CASE WHEN quantity > 0 THEN quantity * price ELSE 0 END) AS total_gross_sales,
    SUM(CASE WHEN quantity < 0 THEN quantity * price * -1 ELSE 0 END) AS total_cancelations,
    SUM(quantity * price) AS total_net_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description);


-- Monthly Revenue Trend
SELECT
    EXTRACT(YEAR FROM invoice_date) AS year,
    EXTRACT(MONTH FROM invoice_date) AS month,
    SUM(quantity * price) AS total_revenue
FROM transactions
GROUP BY year, month
ORDER BY year, month;


-- Net Sales by Year
CREATE OR REPLACE VIEW view_net_sales AS
SELECT
    EXTRACT(YEAR FROM invoice_date) AS year,
    SUM(CASE WHEN t.quantity > 0 THEN t.quantity * t.price ELSE 0 END) AS gross_sales,
    SUM(CASE WHEN t.quantity < 0 THEN t.quantity * t.price * -1 ELSE 0 END) AS cancelations,
    SUM(t.quantity * t.price) AS net_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY year;


-- Sales by Country
CREATE OR REPLACE VIEW view_sales_by_country AS
SELECT 
    c.country,
    SUM(t.quantity * t.price) AS total_sales,
    COUNT(DISTINCT t.invoice) AS total_orders,
    COUNT(DISTINCT t.customer_id) AS total_customers
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN products p ON t.stock_code = p.stock_code
WHERE t.customer_id IS NOT NULL 
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
    AND t.quantity > 0
GROUP BY c.country
ORDER BY total_sales DESC;


-- ============================================================
-- STEP 4: PRODUCT ANALYSIS
-- ============================================================

-- Top 10 Products by Sales
CREATE OR REPLACE VIEW view_top_10_products_by_sales AS
SELECT
    t.stock_code,
    p.description,
    SUM(t.quantity * t.price) AS total_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
    AND t.quantity > 0
GROUP BY t.stock_code, p.description
ORDER BY total_sales DESC
LIMIT 10;


-- Top Products by Quantity and Sales
CREATE OR REPLACE VIEW view_top_products AS
SELECT 
    p.description AS product_name,
    SUM(t.quantity) AS total_quantity_sold,
    SUM(t.quantity * t.price) AS total_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
JOIN customers c ON t.customer_id = c.customer_id
WHERE t.customer_id IS NOT NULL 
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
    AND t.quantity > 0
GROUP BY p.description
ORDER BY total_sales DESC
LIMIT 10;


-- Net Sales Top 10 Products
CREATE OR REPLACE VIEW view_net_sales_top_10_products AS
SELECT
    t.stock_code,
    p.description,
    SUM(CASE WHEN t.quantity > 0 THEN t.quantity * t.price ELSE 0 END) AS gross_sales,
    SUM(CASE WHEN t.quantity < 0 THEN t.quantity * t.price * -1 ELSE 0 END) AS cancelations,
    SUM(t.quantity * t.price) AS net_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY t.stock_code, p.description
ORDER BY net_sales DESC
LIMIT 10;


-- ============================================================
-- STEP 5: CANCELLATION ANALYSIS
-- ============================================================

-- Cancellation Rate
-- Note: Invoices 581483 and C581484 excluded as statistical outliers
-- Discovery process: original rate was 3.54%, corrected to 2.61% after outlier removal
CREATE OR REPLACE VIEW view_cancellation_rate AS
WITH total_calculations AS (
    SELECT
        t.stock_code,
        p.description,
        SUM(CASE WHEN quantity < 0 THEN quantity * price * -1 ELSE 0 END) AS cancelations,
        SUM(CASE WHEN quantity > 0 THEN quantity * price ELSE 0 END) AS gross_sales
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
    GROUP BY t.stock_code, p.description
)
SELECT
    SUM(cancelations) AS total_cancelations,
    SUM(gross_sales) AS total_gross_sales,
    ROUND((SUM(cancelations) / SUM(gross_sales)) * 100, 2) || '%' AS cancellation_rate_percentage
FROM total_calculations;


-- Cancellations by Product
CREATE OR REPLACE VIEW cancelations_by_product AS
SELECT 
    p.description,
    COUNT(t.invoice) AS return_transactions_count,
    SUM(t.quantity * -1) AS total_returned_quantity,
    SUM(t.quantity * t.price * -1) AS total_lost_amount
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.quantity < 0
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY p.description
ORDER BY total_lost_amount DESC;


-- Cancellations by Customer
CREATE OR REPLACE VIEW cancelations_by_amount_of_transactions AS
SELECT 
    t.customer_id,
    COUNT(DISTINCT t.invoice) AS cancellation_count,
    SUM(t.quantity * t.price * -1) AS total_canceled_amount
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.quantity < 0 
    AND t.customer_id IS NOT NULL
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY t.customer_id
ORDER BY total_canceled_amount DESC;


-- Ceramic Products Returns by Country
-- Insight: MEDIUM CERAMIC TOP STORAGE JAR has the highest return value (~£80K)
-- Possible causes: fragile in shipping, product images don't reflect actual size/quality
-- Recommendation: improve packaging or update product description and images
CREATE OR REPLACE VIEW view_ceramic_returns_by_country AS
SELECT 
    c.country,
    COUNT(DISTINCT t.invoice) AS return_invoices,
    SUM(t.quantity * t.price * -1) AS total_returned_amount
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN products p ON t.stock_code = p.stock_code
WHERE t.quantity < 0
    AND p.description ILIKE '%ceramic%'
    AND t.customer_id != 'Guest'
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
GROUP BY c.country
ORDER BY total_returned_amount DESC;


-- ============================================================
-- STEP 6: CUSTOMER ANALYSIS
-- ============================================================

-- Top 10 Customers by Spending
CREATE OR REPLACE VIEW view_top_10_customers AS
SELECT
    t.customer_id,
    SUM(CASE WHEN t.quantity > 0 THEN t.quantity * t.price ELSE 0 END) AS total_spending
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
WHERE t.customer_id IS NOT NULL
    AND t.customer_id != 'Guest'
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY t.customer_id
ORDER BY total_spending DESC
LIMIT 10;


-- AOV & Purchase Frequency
CREATE OR REPLACE VIEW view_AOV AS
WITH store_totals AS (
    SELECT 
        SUM(t.quantity * t.price) AS total_net_sales,
        COUNT(DISTINCT t.invoice) AS total_unique_orders,
        COUNT(DISTINCT t.customer_id) AS total_unique_customers
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.customer_id IS NOT NULL 
        AND t.customer_id != 'Guest'
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
        AND t.quantity > 0
)
SELECT 
    ROUND(total_net_sales / total_unique_orders, 2) AS average_order_value_AOV,
    ROUND(total_unique_orders::numeric / total_unique_customers, 2) AS purchase_frequency_per_customer
FROM store_totals;


-- Customer Lifetime Value
-- Using median instead of average to eliminate impact of high-spending outliers
CREATE OR REPLACE VIEW view_LTV AS
WITH customer_total_spending AS (
    SELECT 
        t.customer_id,
        SUM(t.quantity * t.price) AS customer_lifetime_spending
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.customer_id IS NOT NULL 
        AND t.customer_id != 'Guest'
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
        AND t.quantity > 0
    GROUP BY t.customer_id
)
SELECT 
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY customer_lifetime_spending)::numeric, 2) AS median_customer_LTV
FROM customer_total_spending;


-- RFM Analysis & Customer Segmentation
CREATE OR REPLACE VIEW view_rfm_analysis AS
WITH customer_rfm AS (
    SELECT
        t.customer_id,
        (SELECT MAX(invoice_date::date) FROM transactions) - MAX(t.invoice_date::date) AS recency_days,
        COUNT(DISTINCT t.invoice) AS frequency,
        SUM(CASE WHEN t.quantity > 0 THEN t.quantity * t.price ELSE 0 END) AS monetary_value
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.customer_id IS NOT NULL 
        AND t.customer_id != 'Guest'
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
    GROUP BY t.customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score
    FROM customer_rfm
),
-- FM score combined to simplify CASE WHEN segmentation logic
rfm_combined AS (
    SELECT
        *,
        ROUND((frequency_score + monetary_score) / 2.0) AS fm_score
    FROM rfm_scores
),
rfm_segments AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,
        CASE
            WHEN recency_score >= 4 AND fm_score >= 4 THEN 'VIP Customers'
            WHEN recency_score >= 3 AND fm_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 4 AND fm_score < 3 THEN 'Promising Customers'
            WHEN recency_score = 3 AND fm_score < 3 THEN 'About to Sleep'
            WHEN recency_score < 3 AND fm_score >= 3 THEN 'At Risk'
            ELSE 'Lost'
        END AS customer_segment
    FROM rfm_combined
)
SELECT
    customer_segment,
    COUNT(customer_id) AS total_customers,
    ROUND(COUNT(customer_id) * 100.0 / (SELECT COUNT(*) FROM rfm_segments), 2) || '%' AS customer_segment_percentage,
    ROUND(SUM(monetary_value), 2) AS total_monetary_value,
    -- Using median instead of average to eliminate outlier impact
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monetary_value)::numeric, 2) AS median_monetary_value
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_monetary_value DESC;


-- Churn Analysis
-- 90-day threshold used as it represents 1 business quarter
CREATE OR REPLACE VIEW view_churn_analysis AS
WITH customer_last_purchase AS (
    SELECT 
        t.customer_id,
        MAX(t.invoice_date::date) AS last_purchase_date,
        (SELECT MAX(invoice_date::date) FROM transactions) AS max_store_date
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.customer_id IS NOT NULL 
        AND t.customer_id != 'Guest'
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
        AND t.quantity > 0
    GROUP BY t.customer_id
),
customer_status AS (
    SELECT 
        customer_id,
        (max_store_date - last_purchase_date) AS days_of_absence,
        CASE 
            WHEN (max_store_date - last_purchase_date) > 90 THEN 1
        END AS is_churned
    FROM customer_last_purchase
)
SELECT 
    COUNT(*) AS total_active_base_customers,
    SUM(is_churned) AS churned_customers,
    COUNT(*) - SUM(is_churned) AS active_customers,
    ROUND((SUM(is_churned) * 100.0 / COUNT(*)), 2) || '%' AS churn_rate_percentage
FROM customer_status;


-- ============================================================
-- STEP 7: COHORT ANALYSIS
-- ============================================================

CREATE OR REPLACE VIEW view_cohort_analysis AS
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(invoice_date::date) AS first_purchase_date,
        DATE_TRUNC('quarter', MIN(invoice_date::date)) AS cohort_quarter
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE customer_id IS NOT NULL
        AND customer_id != 'Guest'
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
    GROUP BY customer_id
),
customer_period AS (
    SELECT
        t.customer_id,
        cohort_quarter,
        DATE_TRUNC('quarter', t.invoice_date::date) AS purchase_quarter,
        (EXTRACT(YEAR FROM t.invoice_date) - EXTRACT(YEAR FROM fp.first_purchase_date)) * 4 +
        (EXTRACT(QUARTER FROM t.invoice_date) - EXTRACT(QUARTER FROM fp.first_purchase_date)) AS period
    FROM transactions t
    JOIN first_purchase fp ON t.customer_id = fp.customer_id
    JOIN products p ON t.stock_code = p.stock_code
    WHERE t.customer_id IS NOT NULL
        AND t.customer_id != 'Guest'
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND description IS NOT NULL
        AND description = UPPER(description)
),
cohort_counts AS (
    SELECT
        cohort_quarter,
        period,
        COUNT(DISTINCT customer_id) AS customers
    FROM customer_period
    GROUP BY cohort_quarter, period
),
cohort_sizes AS (
    SELECT
        cohort_quarter,
        customers AS cohort_size
    FROM cohort_counts
    WHERE period = 0
)
SELECT
    cc.cohort_quarter::date AS cohort_quarter,
    cc.period,
    cc.customers,
    cs.cohort_size,
    ROUND((cc.customers::decimal / cs.cohort_size) * 100, 2) || '%' AS retention_rate
FROM cohort_counts cc
JOIN cohort_sizes cs ON cc.cohort_quarter = cs.cohort_quarter
WHERE cc.period >= 0
ORDER BY cc.cohort_quarter, cc.period;


-- ============================================================
-- STEP 8: SEASONALITY ANALYSIS
-- ============================================================

-- Hourly Seasonality
CREATE OR REPLACE VIEW view_hourly_seasonality AS
SELECT 
    EXTRACT(HOUR FROM invoice_date) AS order_hour,
    COUNT(DISTINCT invoice) AS total_orders,
    SUM(quantity * price) AS gross_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
JOIN customers c ON t.customer_id = c.customer_id
WHERE quantity > 0
    AND t.customer_id IS NOT NULL
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY order_hour
ORDER BY gross_sales DESC;


-- Daily Seasonality
CREATE OR REPLACE VIEW view_daily_seasonality AS
SELECT 
    EXTRACT(DOW FROM invoice_date) AS day_of_week,
    CASE EXTRACT(DOW FROM invoice_date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(DISTINCT invoice) AS total_orders,
    SUM(quantity * price) AS gross_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
JOIN customers c ON t.customer_id = c.customer_id
WHERE quantity > 0
    AND t.customer_id IS NOT NULL
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY day_of_week
ORDER BY gross_sales DESC;


-- Monthly Seasonality
CREATE OR REPLACE VIEW view_monthly_seasonality AS
SELECT 
    EXTRACT(MONTH FROM invoice_date) AS order_month,
    CASE EXTRACT(MONTH FROM invoice_date)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    COUNT(DISTINCT t.invoice) AS total_orders,
    SUM(quantity * price) AS gross_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
JOIN customers c ON t.customer_id = c.customer_id
WHERE quantity > 0
    AND t.customer_id IS NOT NULL
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY order_month
ORDER BY order_month ASC;


-- Seasonality Trend (Year + Month)
CREATE OR REPLACE VIEW view_seasonality_trend AS
SELECT 
    EXTRACT(YEAR FROM invoice_date) AS order_year,
    EXTRACT(MONTH FROM invoice_date) AS order_month,
    CASE EXTRACT(MONTH FROM invoice_date)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    COUNT(DISTINCT t.invoice) AS total_orders,
    SUM(quantity * price) AS gross_sales
FROM transactions t
JOIN products p ON t.stock_code = p.stock_code
JOIN customers c ON t.customer_id = c.customer_id
WHERE quantity > 0
    AND t.customer_id IS NOT NULL
    AND t.stock_code IS NOT NULL
    AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
    AND t.invoice NOT IN ('581483','C581484')
    AND p.description IS NOT NULL
    AND p.description = UPPER(p.description)
GROUP BY order_year, order_month
ORDER BY order_year ASC, order_month ASC;


-- ============================================================
-- STEP 9: PRODUCT INTELLIGENCE
-- ============================================================

-- Pareto Analysis (80/20 Rule)
CREATE OR REPLACE VIEW view_pareto_analysis AS
WITH total_product_sales AS (
    SELECT
        t.stock_code,
        p.description,
        SUM(t.quantity * t.price) AS total_sales
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE quantity > 0
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
    GROUP BY t.stock_code, p.description
),
running_totals AS (
    SELECT
        stock_code,
        description,
        total_sales,
        SUM(total_sales) OVER (ORDER BY total_sales DESC) AS cumulative_sales,
        -- Empty OVER() returns same total for all rows to calculate cumulative percentage
        SUM(total_sales) OVER () AS total_revenue
    FROM total_product_sales
),
pareto_categorization AS (
    SELECT
        stock_code,
        description,
        total_sales,
        ROUND((cumulative_sales / total_revenue) * 100.0, 2) AS cumulative_percentage,
        CASE
            WHEN ROUND((cumulative_sales / total_revenue) * 100.0, 2) <= 80 THEN 'Top 20% (Hero Product)'
            ELSE 'Bottom 80% (Long Tail Product)'
        END AS pareto_category
    FROM running_totals
)
SELECT
    pareto_category,
    COUNT(stock_code) AS segment_products,
    (SELECT COUNT(stock_code) FROM pareto_categorization) AS total_products,
    ROUND(COUNT(stock_code) * 100.0 / (SELECT COUNT(*) FROM pareto_categorization), 2) || '%' AS category_percentage
FROM pareto_categorization
GROUP BY pareto_category
ORDER BY category_percentage DESC;


-- Market Basket Analysis
-- Self-Join to find product pairs bought together in the same invoice
-- stock_code < b.stock_code avoids duplicate pairs (A,B) and (B,A)
CREATE OR REPLACE VIEW view_market_basket_analysis AS
WITH cleaned_product_sales AS (
    SELECT
        t.invoice,
        t.stock_code,
        p.description
    FROM transactions t
    JOIN products p ON t.stock_code = p.stock_code
    WHERE quantity > 0
        AND t.stock_code IS NOT NULL
        AND t.stock_code NOT IN ('DOT', 'M','POST','gift_0001_10','AMAZONFEE','D','S','BANK CHARGES')
        AND t.invoice NOT IN ('581483','C581484')
        AND p.description IS NOT NULL
        AND p.description = UPPER(p.description)
),
product_pairs AS (
    SELECT
        a.invoice,
        a.description AS Product_A,
        b.description AS Product_B
    FROM cleaned_product_sales a
    JOIN cleaned_product_sales b ON a.invoice = b.invoice
    WHERE a.stock_code < b.stock_code
)
SELECT
    Product_A,
    Product_B,
    COUNT(*) AS times_bought_together
FROM product_pairs
GROUP BY Product_A, Product_B
ORDER BY times_bought_together DESC
LIMIT 20;
