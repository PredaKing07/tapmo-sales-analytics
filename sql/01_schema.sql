-- TapMo Sales Analytics: schema (MySQL 8)
DROP DATABASE IF EXISTS tapmo;
CREATE DATABASE tapmo;
USE tapmo;

CREATE TABLE dim_date (
  date DATE PRIMARY KEY, year SMALLINT, month_no TINYINT, month_name CHAR(3), yr_month CHAR(7),
  quarter CHAR(2), fiscal_year CHAR(4), fiscal_quarter CHAR(3), weekday_name CHAR(3), is_weekend TINYINT(1)
);
CREATE TABLE dim_product (
  product_id VARCHAR(10) PRIMARY KEY, product_name VARCHAR(100), category VARCHAR(40),
  list_price DECIMAL(10,2), selling_price DECIMAL(10,2), unit_cost DECIMAL(10,2),
  material VARCHAR(20), launch_date DATE
);
CREATE TABLE dim_sales_rep (
  rep_id VARCHAR(10) PRIMARY KEY, rep_name VARCHAR(60), team VARCHAR(30), base_city VARCHAR(40), join_date DATE
);
CREATE TABLE dim_customer (
  customer_id VARCHAR(10) PRIMARY KEY, customer_name VARCHAR(100), customer_type VARCHAR(20),
  industry VARCHAR(40), profession VARCHAR(40), company_size VARCHAR(20), city VARCHAR(40),
  state VARCHAR(40), region VARCHAR(20), country VARCHAR(30), acquisition_channel VARCHAR(20),
  first_order_date DATE NULL
);
CREATE TABLE fact_orders (
  order_id VARCHAR(12) PRIMARY KEY, order_date DATE NOT NULL, customer_id VARCHAR(10) NOT NULL,
  product_id VARCHAR(10) NOT NULL, rep_id VARCHAR(10) NOT NULL, sales_channel VARCHAR(20),
  quantity INT, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2), gross_amount DECIMAL(12,2),
  discount_amount DECIMAL(12,2), net_revenue DECIMAL(12,2), gst_amount DECIMAL(12,2),
  invoice_total DECIMAL(12,2), cogs DECIMAL(12,2), shipping_cost DECIMAL(10,2), payment_mode VARCHAR(20),
  order_status VARCHAR(15), ship_date DATE NULL, delivery_date DATE NULL, delivery_days INT NULL,
  courier_partner VARCHAR(20) NULL, customer_rating TINYINT NULL,
  FOREIGN KEY (order_date) REFERENCES dim_date(date),
  FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
  FOREIGN KEY (rep_id) REFERENCES dim_sales_rep(rep_id)
);
CREATE TABLE fact_leads (
  lead_id VARCHAR(10) PRIMARY KEY, lead_date DATE NOT NULL, lead_source VARCHAR(20), lead_type VARCHAR(20),
  industry VARCHAR(40), city VARCHAR(40), region VARCHAR(20), rep_id VARCHAR(10),
  stage_new TINYINT(1), stage_design_shared TINYINT(1), stage_quote_sent TINYINT(1),
  final_stage VARCHAR(20), est_quantity INT, days_to_close INT NULL, close_date DATE NULL, lost_reason VARCHAR(40) NULL,
  FOREIGN KEY (lead_date) REFERENCES dim_date(date),
  FOREIGN KEY (rep_id) REFERENCES dim_sales_rep(rep_id)
);
CREATE TABLE fact_profile_engagement (
  month_start DATE, customer_id VARCHAR(10), profile_views INT, nfc_taps INT, qr_link_views INT,
  contacts_saved INT, leads_captured INT,
  PRIMARY KEY (month_start, customer_id),
  FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id)
);
CREATE TABLE fact_targets (
  month_start DATE, rep_id VARCHAR(10), revenue_target DECIMAL(12,2),
  PRIMARY KEY (month_start, rep_id),
  FOREIGN KEY (rep_id) REFERENCES dim_sales_rep(rep_id)
);
