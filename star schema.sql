-- DIMENSION TABLES
-- ─────────────────────────────────────────────────────

-- dim_customers
CREATE TABLE dim_customers AS
SELECT DISTINCT
    customer_id,
    signup_date,
    segment,
    country,
    acquisition_channel,
    gender,
    age_group
FROM stg_customers;

-- dim_products
CREATE TABLE dim_products AS
SELECT DISTINCT
    product_id,
    product_name,
    category,
    subcategory,
    cogs
FROM stg_products;

-- dim_date
CREATE TABLE dim_date AS
SELECT
    d::DATE                  AS date,
    EXTRACT(YEAR FROM d)     AS year,
    EXTRACT(QUARTER FROM d)  AS quarter,
    EXTRACT(MONTH FROM d)    AS month,
    TO_CHAR(d, 'Month')      AS month_name,
    TO_CHAR(d, 'YYYY-MM')    AS year_month,
    EXTRACT(DAY FROM d)      AS day,
    EXTRACT(DOW FROM d)      AS day_of_week
FROM GENERATE_SERIES('2024-01-01'::DATE, '2024-12-31'::DATE, '1 day'::INTERVAL) d;

-- ─────────────────────────────────────────────────────
-- PRE-AGGREGATED TABLES FOR POWER BI
-- ─────────────────────────────────────────────────────

-- Q3: retention_by_month
CREATE TABLE retention_by_month AS
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month,
    ROUND(
        COUNT(DISTINCT customer_id) FILTER (WHERE customer_total_orders >= 2) * 100.0
        / COUNT(DISTINCT customer_id),
    2) AS retention_rate
FROM fact_customer_orders
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q5: churn_by_order_number
CREATE TABLE churn_by_order_number AS
SELECT
    order_number,
    COUNT(DISTINCT customer_id) AS customers_reached,
    COUNT(DISTINCT customer_id) FILTER (WHERE customer_total_orders = order_number) AS customers_churned,
    ROUND(
        COUNT(DISTINCT customer_id) FILTER (WHERE customer_total_orders = order_number) * 100.0
        / COUNT(DISTINCT customer_id),
    2) AS churn_rate
FROM fact_customer_orders
GROUP BY order_number
ORDER BY order_number;

-- Q6: cohort_retention
CREATE TABLE cohort_retention AS
WITH elapsed AS (
    SELECT
        customer_id,
        cohort_month,
        EXTRACT(YEAR FROM AGE(order_date, cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(order_date, cohort_month)) AS months_elapsed
    FROM fact_customer_orders
)
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(COUNT(DISTINCT customer_id) FILTER (WHERE months_elapsed = 1) * 100.0 / NULLIF(COUNT(DISTINCT customer_id), 0), 2) AS month_1,
    ROUND(COUNT(DISTINCT customer_id) FILTER (WHERE months_elapsed = 2) * 100.0 / NULLIF(COUNT(DISTINCT customer_id), 0), 2) AS month_2,
    ROUND(COUNT(DISTINCT customer_id) FILTER (WHERE months_elapsed = 3) * 100.0 / NULLIF(COUNT(DISTINCT customer_id), 0), 2) AS month_3,
    ROUND(COUNT(DISTINCT customer_id) FILTER (WHERE months_elapsed = 6) * 100.0 / NULLIF(COUNT(DISTINCT customer_id), 0), 2) AS month_6
FROM elapsed
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q9: rfm_segments
CREATE TABLE rfm_segments AS
WITH customer_score AS (
    SELECT DISTINCT customer_id,
        NTILE(4) OVER (ORDER BY last_order_date DESC)      AS recency,
        NTILE(4) OVER (ORDER BY customer_total_orders ASC) AS frequency,
        NTILE(4) OVER (ORDER BY customer_ltv ASC)          AS monetary
    FROM fact_customer_orders
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    CASE
        WHEN recency = 4 AND frequency = 4 AND monetary = 4                                      THEN 'Champion'
        WHEN recency BETWEEN 3 AND 4 AND frequency BETWEEN 3 AND 4 AND monetary BETWEEN 3 AND 4 THEN 'Loyal'
        WHEN recency BETWEEN 1 AND 2 AND frequency BETWEEN 3 AND 4                              THEN 'At Risk'
        WHEN recency = 1 AND frequency BETWEEN 1 AND 2 AND monetary BETWEEN 1 AND 2             THEN 'Lost'
        ELSE 'Potential'
    END AS customer_segment
FROM customer_score;

-- Deep Dive 3: ltv_by_order_bucket
CREATE TABLE ltv_by_order_bucket AS
WITH customer_level AS (
    SELECT DISTINCT
        customer_id,
        customer_total_orders,
        customer_ltv,
        CASE
            WHEN customer_total_orders = 1 THEN '1 order'
            WHEN customer_total_orders = 2 THEN '2 orders'
            WHEN customer_total_orders = 3 THEN '3 orders'
            WHEN customer_total_orders = 4 THEN '4 orders'
            ELSE '5+ orders'
        END AS order_bucket,
        LEAST(customer_total_orders, 5) AS sort_order
    FROM fact_customer_orders
)
SELECT
    order_bucket,
    ROUND(AVG(customer_ltv), 2) AS avg_ltv
FROM customer_level
GROUP BY order_bucket, sort_order
ORDER BY sort_order;

-- Channel x RFM breakdown (Page 4 matrix)
CREATE TABLE channel_rfm_breakdown AS
SELECT
    c.acquisition_channel,
    r.customer_segment,
    COUNT(*) AS customer_count
FROM rfm_segments r
JOIN stg_customers c ON r.customer_id = c.customer_id
GROUP BY c.acquisition_channel, r.customer_segment
ORDER BY c.acquisition_channel, r.customer_segment;