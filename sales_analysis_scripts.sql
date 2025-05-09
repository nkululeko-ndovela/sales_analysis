-- DATA CLEANING & FORMATTING SCRIPTS
-- 1. Remove Duplicate Customers

DELETE FROM customers c
USING (
  SELECT customer_id, MIN(ctid) as keep_row
  FROM customers
  GROUP BY customer_id
  HAVING COUNT(*) > 1
) dupes
WHERE c.customer_id = dupes.customer_id AND ctid <> dupes.keep_row;

-- 2. Standardize Gender Field

UPDATE customers
SET gender = CASE 
  WHEN LOWER(gender) IN ('m', 'male') THEN 'Male'
  WHEN LOWER(gender) IN ('f', 'female') THEN 'Female'
  ELSE 'Other'
END;

-- 3. Fix Inconsistent Date Format

ALTER TABLE sales
ALTER COLUMN sale_date TYPE DATE
USING TO_DATE(sale_date, 'YYYY-MM-DD');

-- 4. Add Missing Age Groups

UPDATE customers
SET age_group = CASE
  WHEN age_group IS NULL AND age < 25 THEN 'Youth'
  WHEN age_group IS NULL AND age BETWEEN 25 AND 44 THEN 'Adult'
  WHEN age_group IS NULL AND age >= 45 THEN 'Senior'
  ELSE age_group
END;

-- ANALYTICAL SCRIPTS
-- 5. Top 5 Products by Total Sales

SELECT product_name, SUM(total_sale) AS total_revenue
FROM sales
GROUP BY product_name
ORDER BY total_revenue DESC
LIMIT 5;

-- 6. Top 5 Provinces by Revenue

SELECT province, SUM(total_sale) AS total_revenue
FROM sales
GROUP BY province
ORDER BY total_revenue DESC
LIMIT 5;

-- 7. Monthly Sales Trend

SELECT DATE_TRUNC('month', sale_date) AS month, SUM(total_sale) AS revenue
FROM sales
GROUP BY month
ORDER BY month;

-- 8. Inventory Profit Performance

SELECT product_id, product_name, 
       expected_profit,
       sold_stock, 
       expected_profit * sold_stock AS total_expected_profit
FROM inventory
ORDER BY total_expected_profit DESC
LIMIT 10;

-- 9. Customer Lifetime Value

SELECT c.customer_id, c.city, c.age_group, SUM(s.total_sale) AS lifetime_value
FROM customers c
JOIN sales s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.city, c.age_group
ORDER BY lifetime_value DESC;

-- 10. Discount Impact on Sales

SELECT
  ROUND(discount::numeric, 2) AS discount_rate,
  COUNT(*) AS num_sales,
  SUM(total_sale) AS total_revenue
FROM sales
GROUP BY discount_rate
ORDER BY discount_rate;

-- 11. Products With Low Stock and High Sales

SELECT i.product_id, i.product_name, i.stock_available, s.total_units_sold
FROM inventory i
JOIN (
  SELECT product_id, SUM(quantity) AS total_units_sold
  FROM sales
  GROUP BY product_id
) s ON i.product_id = s.product_id
WHERE stock_available < 50
ORDER BY total_units_sold DESC;

-- 12. Customer Satisfaction by Product

SELECT product_name, 
       ROUND(AVG("Customer Satisfaction"), 2) AS avg_rating,
       COUNT(*) AS rating_count
FROM sales
GROUP BY product_name
HAVING COUNT(*) > 10
ORDER BY avg_rating DESC
LIMIT 5;


-- STORED PROCEDURE: Refresh Cleaned Data Table

CREATE OR REPLACE PROCEDURE refresh_clean_sales_data()
LANGUAGE plpgsql
AS $$
BEGIN
  -- Remove duplicates
  DELETE FROM sales s
  USING (
    SELECT sale_id, MIN(ctid) AS keep_ctid
    FROM sales
    GROUP BY sale_id
    HAVING COUNT(*) > 1
  ) dups
  WHERE s.sale_id = dups.sale_id AND s.ctid <> dups.keep_ctid;

  -- Ensure dates are proper
  UPDATE sales
  SET sale_date = TO_DATE(sale_date::TEXT, 'YYYY-MM-DD')
  WHERE sale_date::TEXT ~ '^\d{4}-\d{2}-\d{2}$' IS FALSE;
  
  RAISE NOTICE 'Sales data cleaned and formatted successfully.';
END;
$$;

--  VIEW: Sales Summary by Product and Region

CREATE OR REPLACE VIEW v_sales_summary_product_region AS
SELECT 
  s.product_id,
  s.product_name,
  s.province,
  SUM(s.total_sale) AS total_sales,
  AVG(s."Customer Satisfaction") AS avg_satisfaction,
  COUNT(*) AS num_sales
FROM sales s
GROUP BY s.product_id, s.product_name, s.province;
