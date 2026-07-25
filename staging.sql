-- 1. CUSTOMERS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE customers (
    customer_id         INT          PRIMARY KEY,
    signup_date         DATE         ,
    segment             VARCHAR(50)  ,
    country             VARCHAR(100) ,
    acquisition_channel VARCHAR(50)  ,
    gender              VARCHAR(20)  ,
    age_group           VARCHAR(20)
);

-- 2. PRODUCTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE products (
    product_id   INT           PRIMARY KEY,
    product_name VARCHAR(255)  ,
    category     VARCHAR(100)  ,
    subcategory  VARCHAR(100),
    cogs         DECIMAL(10,2) CHECK (cogs >= 0)
);

-- 3. ORDERS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE orders (
    order_id        INT           PRIMARY KEY,
    customer_id     INT           NOT NULL REFERENCES customers(customer_id),
    order_date      DATE          ,
    region          VARCHAR(100)  ,
    channel         VARCHAR(50)   ,
    gross_revenue   DECIMAL(12,2) NOT NULL CHECK (gross_revenue >= 0),
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    net_revenue     DECIMAL(12,2) NOT NULL CHECK (net_revenue >= 0),
    shipping_cost   DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    payment_fee     DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (payment_fee >= 0),
    order_status    VARCHAR(50)  
);

-- 4. ORDER_ITEMS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE order_items (
    order_item_id   INT           PRIMARY KEY,
    order_id        INT           NOT NULL REFERENCES orders(order_id),
    product_id      INT           NOT NULL REFERENCES products(product_id),
    quantity        INT           CHECK (quantity > 0),
    unit_price      DECIMAL(10,2) CHECK (unit_price >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    total_price     DECIMAL(10,2) CHECK (total_price >= 0)
);

-- 5. REFUNDS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE refunds (
    refund_id     INT           PRIMARY KEY,
    order_id      INT           NOT NULL REFERENCES orders(order_id),
    product_id    INT           NOT NULL REFERENCES products(product_id),
    refund_date   DATE          ,
    refund_amount DECIMAL(10,2) CHECK (refund_amount > 0),
    reason        VARCHAR(255)
);

-- 6. DISCOUNTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE discounts (
    discount_id   INT          PRIMARY KEY,
    order_item_id INT          NOT NULL REFERENCES order_items(order_item_id),
    discount_type VARCHAR(50) ,
    campaign_name VARCHAR(100),
    discount_rate DECIMAL(5,4) NOT NULL CHECK (discount_rate > 0 AND discount_rate <= 1)
);

-- 7. CUSTOMER_SUPPORT_TICKETS
-- ────────────────────────────────────────────────────────────

CREATE TABLE customer_support_tickets (
    ticket_id       INT         PRIMARY KEY,
    customer_id     INT         NOT NULL REFERENCES customers(customer_id),
    ticket_date     DATE,
    ticket_type     TEXT,
    resolved        TEXT    ,
    resolution_days INT        
);

--------------------------------------------------------------
-- Data Validation
-- 1. Orders before signup (breaks cohort and lifecycle queries)
SELECT COUNT(*) AS orders_before_signup
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date < c.signup_date;

-- 2. Orphaned orders (breaks every customer-level aggregation)
SELECT COUNT(*) AS orphaned_orders
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 3. Nulls in critical columns
SELECT
    COUNT(*) FILTER (WHERE order_date IS NULL)   AS null_order_date,
    COUNT(*) FILTER (WHERE customer_id IS NULL)  AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_order_status
FROM orders;

-- 4. Order status distinct values
SELECT order_status, COUNT(*) AS count
FROM orders
GROUP BY order_status
ORDER BY count DESC;

-- 5. Date range sanity
SELECT MIN(order_date) AS earliest, MAX(order_date) AS latest
FROM orders;

-- 6. Duplicate orders same customer same date
SELECT customer_id, order_date, COUNT(*) AS order_count
FROM orders
GROUP BY customer_id, order_date
HAVING COUNT(*) > 1
ORDER BY order_count DESC;

--Fixing
--signup_date where order_date < signup_date
UPDATE customers c
SET signup_date = (
    SELECT MIN(o.order_date)
    FROM orders o
    WHERE o.customer_id = c.customer_id
)
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
    AND o.order_date < c.signup_date
);
--Renaming tables
ALTER TABLE orders RENAME TO raw_orders;
ALTER TABLE order_items RENAME TO raw_order_items;
ALTER TABLE customers RENAME TO raw_customers;
ALTER TABLE products RENAME TO raw_products;
ALTER TABLE discounts RENAME TO raw_discounts;
ALTER TABLE refunds RENAME TO raw_refunds;
ALTER TABLE customer_support_tickets RENAME TO raw_customer_support_tickets;

--Creating staging tables
CREATE TABLE stg_orders AS SELECT * FROM raw_orders;
CREATE TABLE stg_order_items AS SELECT * FROM raw_order_items;
CREATE TABLE stg_customers AS SELECT * FROM raw_customers;
CREATE TABLE stg_products AS SELECT * FROM raw_products;
CREATE TABLE stg_discounts AS SELECT * FROM raw_discounts;
CREATE TABLE stg_refunds AS SELECT * FROM raw_refunds;
CREATE TABLE stg_customer_support_tickets  AS SELECT * FROM raw_customer_support_tickets;

-- Data cleaning
UPDATE stg_orders
SET channel = TRIM(INITCAP(channel)),
    order_status = CASE WHEN order_status = 'cancel' THEN 'Cancelled'
	WHEN order_status = 'Complete' THEN 'Completed'
	ELSE TRIM(INITCAP(order_status)) 
	END;

UPDATE stg_customers
SET acquisition_channel = TRIM(INITCAP(acquisition_channel)),
    gender = TRIM(INITCAP(gender));

UPDATE stg_customers
SET age_group = CASE 
                  WHEN age_group = '18_24' THEN '18-24'
				  WHEN age_group = '45plus' THEN '45+'
				  ELSE age_group END;

UPDATE stg_discounts
SET campaign_name = CASE WHEN campaign_name ISNULL THEN 'No Campaign'
                         ELSE campaign_name END;

UPDATE stg_customer_support_tickets
SET ticket_type = CASE
    WHEN LOWER(ticket_type) IN ('shipping', 'shipping issue') THEN 'Shipping'
    WHEN LOWER(ticket_type) = 'refund'                        THEN 'Refund'
    WHEN LOWER(ticket_type) = 'product query'                 THEN 'Product_query'
    WHEN LOWER(ticket_type) = 'return'                        THEN 'Refund'
    ELSE TRIM(INITCAP(ticket_type))
END;
