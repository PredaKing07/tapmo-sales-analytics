USE tapmo;
CREATE OR REPLACE VIEW vw_sales_clean AS
SELECT 
 o.order_id, o.order_date, o.customer_id, o.product_id,o.rep_id,
 o.sales_channel, o.quantity, o.net_revenue, o.cogs,o.shipping_cost,
 o.net_revenue-o.cogs-o.shipping_cost AS profit,
 ROUND((o.net_revenue - o.cogs - o.shipping_cost) / o.net_revenue * 100 , 1) AS margin_pct,
 o.order_status, o.delivery_days, o.courier_partner, o.customer_rating,
 CASE WHEN o.order_status= 'Returned' THEN 1 ELSE 0 END AS is_returned
FROM fact_orders o
WHERE o.order_status <> 'Cancelled';

CREATE OR REPLACE VIEW vw_monthly_kpis AS
WITH monthly AS (
  SELECT
    DATE_FORMAT(order_date, '%Y-%m-01') AS month_start,
    COUNT(*)                    AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(net_revenue)            AS revenue,
    SUM(profit)                 AS profit
  FROM vw_sales_clean
  GROUP BY month_start
)
SELECT
  month_start, orders, customers,
  ROUND(revenue) AS revenue,
  ROUND(profit)  AS profit,
  ROUND(revenue / orders) AS avg_order_value,
  ROUND(LAG(revenue) OVER (ORDER BY month_start)) AS prev_month_revenue,
  ROUND((revenue - LAG(revenue) OVER (ORDER BY month_start))
        / LAG(revenue) OVER (ORDER BY month_start) * 100, 1) AS mom_growth_pct
FROM monthly;

CREATE OR REPLACE VIEW vw_lead_funnel AS
SELECT
  l.lead_source, l.lead_type, l.rep_id,
  DATE_FORMAT(l.lead_date, '%Y-%m-01') AS month_start,
  COUNT(*)                    AS total_leads,
  SUM(l.stage_design_shared)  AS design_shared,
  SUM(l.stage_quote_sent)     AS quote_sent,
  SUM(l.final_stage = 'Won')  AS won,
  SUM(l.final_stage = 'Lost') AS lost,
  ROUND(SUM(l.final_stage = 'Won') * 100.0 / COUNT(*), 1) AS conversion_pct,
  ROUND(AVG(CASE WHEN l.final_stage = 'Won' THEN l.days_to_close END), 1) AS avg_days_to_win
FROM fact_leads l
GROUP BY l.lead_source, l.lead_type, l.rep_id, month_start;

CREATE OR REPLACE VIEW vw_rep_vs_target AS
WITH actuals AS (
  SELECT rep_id, DATE_FORMAT(order_date, '%Y-%m-01') AS month_start,
         SUM(net_revenue) AS actual_revenue, COUNT(*) AS orders
  FROM vw_sales_clean
  WHERE rep_id <> 'ONLINE'
  GROUP BY rep_id, month_start
)
SELECT
  t.month_start, r.rep_id, r.rep_name, r.team,
  t.revenue_target,
  ROUND(COALESCE(a.actual_revenue, 0)) AS actual_revenue,
  COALESCE(a.orders, 0) AS orders,
  ROUND(COALESCE(a.actual_revenue, 0) / t.revenue_target * 100, 1) AS achievement_pct,
  CASE WHEN COALESCE(a.actual_revenue, 0) >= t.revenue_target
       THEN 'Hit' ELSE 'Missed' END AS target_status
FROM fact_targets t
JOIN dim_sales_rep r ON t.rep_id = r.rep_id
LEFT JOIN actuals a ON a.rep_id = t.rep_id AND a.month_start = t.month_start;

CREATE OR REPLACE VIEW vw_customer_cohorts AS
WITH first_orders AS (
  SELECT customer_id, DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
  FROM vw_sales_clean
  GROUP BY customer_id
),
activity AS (
  SELECT DISTINCT s.customer_id, f.cohort_month,
         DATE_FORMAT(s.order_date, '%Y-%m-01') AS order_month
  FROM vw_sales_clean s
  JOIN first_orders f ON s.customer_id = f.customer_id
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS cohort_customers
  FROM first_orders GROUP BY cohort_month
)
SELECT
  a.cohort_month, a.order_month,
  TIMESTAMPDIFF(MONTH, a.cohort_month, a.order_month) AS months_since_first,
  c.cohort_customers,
  COUNT(*) AS active_customers,
  ROUND(COUNT(*) * 100.0 / c.cohort_customers, 1) AS retention_pct
FROM activity a
JOIN cohort_size c ON a.cohort_month = c.cohort_month
GROUP BY a.cohort_month, a.order_month, c.cohort_customers;

CREATE OR REPLACE VIEW vw_rfm_segments AS
WITH base AS (
  SELECT customer_id,
         DATEDIFF('2026-09-30', MAX(order_date)) AS recency_days,
         COUNT(*)         AS frequency,
         SUM(net_revenue) AS monetary
  FROM vw_sales_clean
  GROUP BY customer_id
),
scored AS (
  SELECT *,
    NTILE(5) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,
NTILE(5) OVER (ORDER BY frequency, monetary, customer_id) AS f_score,
NTILE(5) OVER (ORDER BY monetary, customer_id) AS m_score
  FROM base
)
SELECT
  s.customer_id, c.customer_name, c.customer_type, c.industry, c.city,
  s.recency_days, s.frequency, ROUND(s.monetary) AS monetary,
  s.r_score, s.f_score, s.m_score,
  CONCAT(s.r_score, s.f_score, s.m_score) AS rfm_code,
  CASE
    WHEN s.r_score >= 4 AND s.f_score >= 4 AND s.m_score >= 4 THEN 'Champions'
    WHEN s.r_score >= 3 AND s.f_score >= 3                    THEN 'Loyal'
    WHEN s.r_score >= 4 AND s.f_score <= 2                    THEN 'New / Promising'
    WHEN s.r_score <= 2 AND s.m_score >= 4                    THEN 'At Risk (High Value)'
    WHEN s.r_score <= 2                                       THEN 'Hibernating'
    ELSE 'Needs Attention'
  END AS segment
FROM scored s
JOIN dim_customer c ON s.customer_id = c.customer_id;