# Customer Retention & Churn Analysis: Where Customers Go and Why They Don't Come Back

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

> 1 in 4 customers never returns. The critical drop-off happens between order 2 and order 3. Fixing it is worth 3.6x more revenue per customer — without acquiring a single new one.

---

## Dashboard Preview

*Screenshots coming soon*

---

## Business Context

A growing e-commerce company is acquiring new customers at scale but has no systematic view of whether those customers stay. Retention, churn timing, and customer lifetime value have been tracked informally at best. Marketing spends on acquisition without knowing which channels bring back loyal customers versus one-time buyers, and no one has identified the exact point in the customer journey where churn risk is highest.

**The business is investing in acquisition while quietly hemorrhaging the customers it already has.**

This analysis answers three questions:
1. **How bad** is the retention problem — and is it getting worse?
2. **Where and when** does churn concentrate in the customer journey?
3. **Who** is churning, and what does fixing it mean in dollars?

---

## Key Findings

**1. One in four customers is a one-time buyer**
24.84% of customers made a single purchase and never returned. This is the anchor number for the entire project — a quarter of all acquisition spend generates no repeat value.

**2. Retention is deteriorating, not stable**
Monthly retention declined from 90.72% in January to 54.17% in August (reliable observation window). This is a structural, worsening trend — not a campaign anomaly or seasonal dip.

**3. The critical intervention window is between order 2 and order 3**
Churn rate jumps 16 points at this exact transition — from 33.33% to 49.57%. Customers who churn at order 2 waited an average of 119 days before their second purchase, versus 86 days for those who continued. Speed of return is the strongest behavioral predictor of loyalty.

**4. Paid Social acquires the least loyal customers**
Paid Social has a 30.33% one-and-done rate — the worst of any channel and 60% higher than Email (19.05%). The business is spending acquisition budget on a channel that systematically produces low-loyalty buyers.

**5. Retained customers are worth 3.6x more**
Retained customers generate $2,794.75 in average LTV versus $766.37 for one-and-done customers. Every additional order adds $827–$1,252 in customer value. The tipping point is order 2 — a customer who buys twice is already worth more than double a one-time buyer.

---

## Recommendations & Estimated Impact

| Priority | Action | Basis | Estimated Impact |
|---|---|---|---|
| 1 | Launch Day-60 to Day-90 re-engagement trigger for customers without a second order | Churned customers wait 33 days longer — the window closes at ~day 119 | ~$24K additional revenue at 10% conversion of 116 one-and-done customers |
| 2 | Audit and reallocate Paid Social acquisition spend toward Email | Paid Social one-and-done rate (30%) is 60% worse than Email (19%) | ~$118K revenue upside closing the loyalty gap at full conversion |
| 3 | Build win-back campaign for 89 At-Risk RFM customers | Previously frequent buyers who have gone quiet — most recoverable segment | ~$90K retained revenue at 50% recovery rate |
| 4 | Design second and third purchase nurture path for 295 Potential customers | Largest addressable pool — 63% of the customer base is undeveloped | ~$240K incremental LTV at 20% conversion to Loyal |
| | **Total addressable opportunity** | | **~$472K** |

*All estimates are assumption-based projections. Assumptions are stated explicitly per row.*

---

## Project Architecture

```
Raw Tables → Staging & Cleaning → Fact Table → Star Schema → Power BI
```

| Layer | Purpose |
|---|---|
| Staging | Cleaned and validated tables — INITCAP standardization, signup date correction, order status normalization |
| Fact Table | Pre-computed customer lifecycle metrics using window functions — order sequencing, cohort month, LTV, days between orders |
| Star Schema | Dimension tables (customers, products, date) + pre-aggregated analysis tables optimized for Power BI |

### Star Schema
```
           dim_date
               │
dim_customers ── fact_customer_orders ── dim_products
                        │
              rfm_segments · cohort_retention
              churn_by_order_number · retention_by_month
              ltv_by_order_bucket · channel_rfm_breakdown
```

---

## Technical Highlights

### Pre-Computed Fact Table
The most important design decision in this project. Rather than rewriting complex window functions in every analysis query, all lifecycle metrics are computed once in the fact table and reused across all 10 questions:

```sql
ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date)     -- order sequence
LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)  -- days between orders
DATE_TRUNC('month', MIN(order_date) OVER (PARTITION BY customer_id)) -- cohort month
SUM(net_revenue) OVER (PARTITION BY customer_id)                     -- customer LTV
NTILE(4) OVER (ORDER BY last_order_date DESC)                        -- RFM recency score
```

This enables clean, readable analysis queries with no repeated subqueries — the fact table does the heavy lifting once.

### RFM Segmentation From Scratch
RFM scoring built entirely in SQL using NTILE quartiles — no plugins, no templates. Customers scored 1–4 on recency, frequency, and monetary dimensions, then classified into Champion / Loyal / At-Risk / Lost / Potential using CASE WHEN logic evaluated from most to least exclusive segment.

### Cohort Elapsed-Time Arithmetic
Cohort retention calculated using AGE-based month arithmetic to handle year boundaries correctly:

```sql
EXTRACT(YEAR FROM AGE(order_date, cohort_month)) * 12 +
EXTRACT(MONTH FROM AGE(order_date, cohort_month)) AS months_elapsed
```

This gives exact month intervals regardless of order date distribution — not approximations.

### Analysis Framework — 10 Questions Across 4 Layers

| Layer | Focus | Techniques |
|---|---|---|
| How Bad? | One-and-done rate, 30/60/90-day retention, monthly trend | FILTER aggregates, DISTINCTCOUNT |
| When? | Days to second purchase, churn spike by order number, cohort retention | ROW_NUMBER, LAG, DATE_TRUNC, AGE |
| Who? | Churn by category, region, RFM segmentation | NTILE, CASE WHEN, DISTINCT ON |
| So What? | LTV gap: retained vs. one-and-done | AVERAGEX, window aggregates |

### Deep Dives
Three targeted investigations beyond the surface questions:

**Order 2-to-3 Behavioral Signal** — comparing avg days to second purchase for customers who churned at order 2 vs. those who continued. Conclusion: 33-day gap (119 vs. 86 days) is the strongest behavioral predictor of churn — slower returners are disproportionately likely to never come back.

**Acquisition Channel Quality** — one-and-done rate by channel. Conclusion: Paid Social produces a 30% one-and-done rate vs. 19% for Email — the channel performing best on acquisition volume is systematically producing the least loyal customers.

**LTV Payoff Curve** — average cumulative LTV at each order bucket using LAG to show incremental value. Conclusion: every additional order adds $827–$1,252 in customer value with a consistent upward curve — the business case for retention compounds with each purchase.

---

## Dashboard Structure

6-page Power BI dashboard built around the analytical narrative:

| Page | Core Finding | Key Visuals |
|---|---|---|
| Executive Summary | 1 in 4 customers never returns — retained customers worth 3.6x more | KPI cards · Channel bar · RFM segment table |
| Retention Overview | Retention declining from 91% to 54% — customers return slowly | Trend line · 30/60/90 cards · Donut · Cohort heatmap |
| Where Churn Happens | Biggest spike at order 2→3 — slow returners churn more | Funnel · Churn rate bar · Speed of return comparison |
| Who Is Churning | Paid Social worst channel — RFM shows 63% undeveloped | Channel bar · Category bar · Channel×RFM matrix · Scatter plot |
| Revenue Impact | 3.6x LTV gap — every order adds $827–$1,252 | LTV cards · Payoff curve · What-If retention calculator |
| Recommendations & Impact | Three actions cover the majority of recoverable value | Priority matrix · Action table with tradeoffs |

---

## Repository Structure

```
/sql
  /01_staging          → cleaning, validation, and staging tables
  /02_fact_table       → fact_customer_orders creation with window functions
  /03_analysis         → all 10 analysis queries + 3 deep dives
  /04_star_schema      → dimension tables and pre-aggregated export tables
/dashboard
  /screenshots         → Power BI dashboard page screenshots
PROJECT_2_DOCUMENTATION.docx
README.md
```

---

## Limitations & Tradeoffs

| Area | Detail |
|---|---|
| Data | Synthetic — patterns are cleaner and more uniform than real transaction data |
| Time range | Single year (2024) — cohorts from September onward are immature and should not be used for retention conclusions |
| Completed orders only | Fact table scoped to completed orders — cancelled and returned orders excluded by design to avoid inflating retention metrics |
| First-order category | Defined as the category of the highest-value item in the first order — 80% of orders are multi-category, making a single label an approximation |
| RFM thresholds | Champion requires top NTILE score on all three dimensions — intentionally strict, producing a small segment of 4 customers |
| Support tickets | Only 90 of 328 ticket records imported successfully due to a boolean formatting issue — ticket data plays no role in the 10 core questions |
| Causality | All findings are correlational — the analysis identifies where and when churn concentrates but cannot prove why a given customer churned |

---

## What I Would Do Next

This analysis successfully diagnoses where and when churn concentrates, and which segments and channels are most affected. To move from diagnosis to true root cause, the following data would be required: customer satisfaction scores or NPS surveys, email engagement data (open rates, click-through rates by segment), ad creative performance data by channel to isolate whether Paid Social underperforms due to targeting or messaging, and session-level behavioral data to understand whether one-and-done customers engage differently during their single visit.

---

## About the Project

This is Project 2 of a three-project e-commerce analytics portfolio built to demonstrate end-to-end analytical thinking — from raw data to prioritized, dollar-quantified business recommendations.

The portfolio is built around a single fictional e-commerce company across all three projects, allowing findings to reference and build on each other. Project 1 covers Revenue Leakage Analysis. Project 3 covers Regional Sales Performance and Growth Diagnosis.

**What this project demonstrates:**
- Customer lifecycle reconstruction using SQL window functions — order sequencing, cohort assignment, RFM scoring
- Connecting retention findings directly to acquisition strategy — tracing churn back to channel quality
- Honest handling of cohort immaturity — distinguishing real churn from data truncation
- Dollar-quantified recommendations with explicit assumptions and stated tradeoffs

---

*Ahmed · Data Analyst Portfolio · SQL · Power BI · Data Modeling*
