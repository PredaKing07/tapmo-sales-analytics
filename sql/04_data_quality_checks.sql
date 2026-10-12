
USE tapmo;

SELECT 'Duplicate order IDs' AS check_name,
       COUNT(*) - COUNT(DISTINCT order_id) AS issues
FROM fact_orders
UNION ALL
SELECT 'Orders missing customer/product/rep',
       SUM(customer_id IS NULL OR product_id IS NULL OR rep_id IS NULL)
FROM fact_orders
UNION ALL
SELECT 'Zero or negative quantity',
       SUM(quantity <= 0)
FROM fact_orders
UNION ALL
SELECT 'Negative revenue or cost',
       SUM(net_revenue < 0 OR cogs < 0 OR shipping_cost < 0)
FROM fact_orders
UNION ALL
SELECT 'Shipped before ordered',
       SUM(ship_date < order_date)
FROM fact_orders
UNION ALL
SELECT 'Delivered before shipped',
       SUM(delivery_date < ship_date)
FROM fact_orders
UNION ALL
SELECT 'Rating outside 1-5',
       SUM(customer_rating NOT BETWEEN 1 AND 5)
FROM fact_orders
UNION ALL
SELECT 'Delivered orders with no delivery date',
       SUM(order_status = 'Delivered' AND delivery_date IS NULL)
FROM fact_orders;