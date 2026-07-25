--Analysis
--Question 1 : What percentage of customers made only one purchase and never returned?
SELECT
    ROUND(
        COUNT(DISTINCT customer_id) FILTER (WHERE customer_total_orders = 1) * 100.0
        / COUNT(DISTINCT customer_id),
    2) AS customer_pct
FROM fact_customer_orders;

--Question 2: What is the 30 / 60 / 90-day retention rate across all customers?

SELECT
    ROUND(SUM(CASE WHEN days_since_prev_order <= 30 THEN 1 ELSE 0 END) * 100.0 / total_customers, 2) AS retained_30d,
    ROUND(SUM(CASE WHEN days_since_prev_order <= 60 THEN 1 ELSE 0 END) * 100.0 / total_customers, 2) AS retained_60d,
    ROUND(SUM(CASE WHEN days_since_prev_order <= 90 THEN 1 ELSE 0 END) * 100.0 / total_customers, 2) AS retained_90d
FROM (
    SELECT customer_id, days_since_prev_order
    FROM fact_customer_orders
    WHERE order_number = 2
) second_orders
CROSS JOIN (
    SELECT COUNT(DISTINCT customer_id) AS total_customers
    FROM fact_customer_orders
) total
GROUP BY total_customers;


--Question 3: Is retention improving or deteriorating month over month?

SELECT cohort_month,
       ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE customer_total_orders >= 2) * 100.0
	   / COUNT(DISTINCT customer_id), 2)   AS retention_rate
FROM fact_customer_orders
GROUP BY cohort_month;

--Question 4: What is the average time between a customer's first and second purchase, and how does it distribute?       

SELECT CASE WHEN days_since_prev_order BETWEEN 0 AND 30 THEN '0-30'
            WHEN days_since_prev_order BETWEEN 31 AND 60 THEN '31-60'
			WHEN days_since_prev_order BETWEEN 61 AND 90 THEN '61-90'
			WHEN days_since_prev_order > 90 THEN '90+'
			END                                                            AS periods,
	   COUNT(DISTINCT customer_id)                                         AS numb_of_customers,
	   ROUND(AVG(days_since_prev_order), 0)                                AS avg_time
FROM fact_customer_orders
WHERE order_number = 2
GROUP BY periods;

SELECT ROUND(AVG(days_since_prev_order),0)  AS overall_avg_time_to_second_order
FROM fact_customer_orders
WHERE order_number = 2;


--Question 5: At which order number does the biggest churn spike occur?

SELECT order_number,
	   COUNT(DISTINCT customer_id)   AS numb_of_customers,
	   COUNT(DISTINCT customer_id) FILTER(WHERE customer_total_orders = order_number)  AS churned_customers,
	   ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE customer_total_orders = order_number) * 100.0 /
	   COUNT(DISTINCT customer_id), 2) AS churn_rate
FROM fact_customer_orders
GROUP BY order_number
ORDER BY order_number;

--Question 6: For each monthly acquisition cohort, what percentage returned at months 1, 2, 3, and 6?

WITH elapsed AS (
SELECT
    customer_id,
    cohort_month,
    EXTRACT(YEAR FROM AGE(order_date, cohort_month)) * 12 +
    EXTRACT(MONTH FROM AGE(order_date, cohort_month)) AS months_elapsed
FROM fact_customer_orders
)
SELECT TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month,
       ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE months_elapsed = 1) * 100.0/
	   NULLIF(COUNT(DISTINCT customer_id), 0), 2)      AS month_1,
	   ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE months_elapsed = 2) * 100.0/
	   NULLIF(COUNT(DISTINCT customer_id), 0), 2)      AS month_2,
	   ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE months_elapsed = 3) * 100.0/
	   NULLIF(COUNT(DISTINCT customer_id), 0), 2)      AS month_3,
	   ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE months_elapsed = 6) * 100.0/
	   NULLIF(COUNT(DISTINCT customer_id), 0), 2)      AS month_6
FROM elapsed
GROUP BY cohort_month;

--Question 7: Do customers who start in certain product categories churn at higher rates?


SELECT first_order_category,
       ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE customer_total_orders = 1) * 100.0 /
	   COUNT(DISTINCT customer_id), 2) AS churn_rate
FROM fact_customer_orders
GROUP BY first_order_category
ORDER BY churn_rate DESC;


--Question 8: Which regions retain customers best and worst?

SELECT region,
       ROUND(COUNT(DISTINCT customer_id) FILTER(WHERE customer_total_orders >= 2) * 100.0
	   / COUNT(DISTINCT customer_id), 2)   AS retention_rate
FROM fact_customer_orders
GROUP BY region
ORDER BY retention_rate DESC;

--Question 9: Classify customers into Champions, Loyal, At-Risk, and Lost segments using RFM scores.
WITH customer_score AS (
SELECT DISTINCT customer_id,
       NTILE(4)OVER(ORDER BY last_order_date DESC) AS recency,
	   NTILE(4)OVER(ORDER BY customer_total_orders ASC) AS frequency,
	   NTILE(4)OVER(ORDER BY customer_ltv ASC) AS monetary
FROM fact_customer_orders
),
segments AS (
SELECT customer_id,
       CASE 
    WHEN recency = 4
        AND frequency = 4
        AND monetary = 4
        THEN 'Champion'
    WHEN recency BETWEEN 3 AND 4
        AND frequency BETWEEN 3 AND 4
        AND monetary BETWEEN 3 AND 4
        THEN 'Loyal'
    WHEN recency BETWEEN 1 AND 2
        AND frequency BETWEEN 3 AND 4
        THEN 'At Risk'
    WHEN recency = 1
        AND frequency BETWEEN 1 AND 2
        AND monetary BETWEEN 1 AND 2
        THEN 'Lost'
    ELSE 'Potential' 
END AS customer_segment
FROM customer_score
)
SELECT customer_segment, COUNT(*) AS customer_count
FROM segments
GROUP BY customer_segment
ORDER BY customer_count DESC;

--Question 10:  What is the average lifetime value of retained customers vs one-and-done customers?
SELECT
CASE WHEN customer_total_orders = 1 THEN 'one-and-done'
     WHEN customer_total_orders >= 2 THEN 'retained'
	 END AS loyalty_segment,
ROUND(AVG(customer_ltv), 2) AS avg_ltv
FROM (
SELECT customer_id,
MAX(customer_total_orders) AS customer_total_orders,
MAX(customer_ltv) AS customer_ltv
FROM fact_customer_orders
GROUP BY customer_id
)
GROUP BY loyalty_segment;

--Deep Dive Analysis

--Deep dive 1 — Q5: Do customers who churn at order 2 have a significantly longer gap between order 1 and 2 compared to customers who reached order 3 
SELECT ROUND(AVG(days_since_prev_order) FILTER(WHERE customer_total_orders = 2),2)  AS avg_churn_period,
       ROUND(AVG(days_since_prev_order) FILTER(WHERE customer_total_orders >= 3),2)  AS avg_reached_period
FROM fact_customer_orders
WHERE order_number=2;

--Deep dive 2 — Q1: What is the one-and-done rate by acquisition channel?
SELECT acquisition_channel,
    ROUND(
        COUNT(DISTINCT customer_id) FILTER (WHERE customer_total_orders = 1) * 100.0
        / COUNT(DISTINCT customer_id), 2) AS customer_pct
FROM fact_customer_orders
GROUP BY acquisition_channel;

--Deep dive 3 — Q10: What is the average cumulative LTV at each order number?
WITH customer_level AS (
    SELECT DISTINCT
           customer_id,
           customer_total_orders,
           customer_ltv
    FROM fact_customer_orders
),
ltv_by_bucket AS (
SELECT
    CASE
        WHEN customer_total_orders = 1 THEN '1 order'
        WHEN customer_total_orders = 2 THEN '2 orders'
        WHEN customer_total_orders = 3 THEN '3 orders'
        WHEN customer_total_orders = 4 THEN '4 orders'
        ELSE '5+ orders'
    END AS order_bucket,
    ROUND(AVG(customer_ltv),2) AS avg_ltv
FROM customer_level
GROUP BY order_bucket)
SELECT order_bucket,
       avg_ltv,
	   ROUND(avg_ltv - LAG(avg_ltv) OVER(
    ORDER BY CASE order_bucket
        WHEN '1 order'  THEN 1
        WHEN '2 orders' THEN 2
        WHEN '3 orders' THEN 3
        WHEN '4 orders' THEN 4
        ELSE 5
    END
), 0) AS difference
FROM ltv_by_bucket
ORDER BY CASE order_bucket
    WHEN '1 order'  THEN 1
    WHEN '2 orders' THEN 2
    WHEN '3 orders' THEN 3
    WHEN '4 orders' THEN 4
    ELSE 5
END;