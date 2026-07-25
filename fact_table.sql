CREATE TABLE fact_customer_orders AS

WITH completed_orders AS (
    -- Base: completed orders only, cancelled/returned excluded
    SELECT *
    FROM stg_orders
    WHERE order_status = 'Completed'
),

order_category AS (
    -- Dominant category per order = category of highest-value item
    SELECT DISTINCT ON (oi.order_id)
        oi.order_id,
        p.category AS dominant_category
    FROM stg_order_items oi
    JOIN stg_products p ON oi.product_id = p.product_id
    ORDER BY oi.order_id, oi.total_price DESC
),

first_order_category AS (
    -- First order's dominant category per customer
    SELECT DISTINCT ON (o.customer_id)
        o.customer_id,
        oc.dominant_category AS first_order_category
    FROM completed_orders o
    JOIN order_category oc ON o.order_id = oc.order_id
    ORDER BY o.customer_id, o.order_date ASC
)

SELECT
    -- Keys
    o.order_id,
    o.customer_id,

    -- Dates
    o.order_date,
    c.signup_date,

    -- Customer demographics
    c.segment,
    c.country,
    c.acquisition_channel,
    c.gender,
    c.age_group,

    -- Order context
    o.region,
    o.channel,
    o.order_status,
    o.gross_revenue,
    o.discount_amount,
    o.net_revenue,
    o.shipping_cost,
    o.payment_fee,

    -- Lifecycle metrics (window functions)
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    ) AS order_number,

    COUNT(o.order_id) OVER (
        PARTITION BY o.customer_id
    ) AS customer_total_orders,

    MIN(o.order_date) OVER (
        PARTITION BY o.customer_id
    ) AS first_order_date,

    MAX(o.order_date) OVER (
        PARTITION BY o.customer_id
    ) AS last_order_date,

    SUM(o.net_revenue) OVER (
        PARTITION BY o.customer_id
    ) AS customer_ltv,

    o.order_date - LAG(o.order_date) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    ) AS days_since_prev_order,

    -- Cohort (month of first purchase)
   DATE_TRUNC('month', MIN(o.order_date) OVER (
    PARTITION BY o.customer_id
)) AS cohort_month,

    -- First order category
    foc.first_order_category

FROM completed_orders o
JOIN stg_customers c         ON o.customer_id = c.customer_id
JOIN first_order_category foc ON o.customer_id = foc.customer_id;

SELECT * FROM fact_customer_orders LIMIT 10;