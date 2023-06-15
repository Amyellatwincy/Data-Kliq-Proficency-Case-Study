/* Gross sales 
TO solve for Gross sales = Quantity supplied * Unit price
Quantity supplied is in Transaction able and Unit price is in Products tale we need to join the two tables
 */
--- View the tables to get a glimpse of the columns
SELECT
    *
FROM
    myreturn;

SELECT
    *
FROM
    customer;

SELECT
    *
FROM
    product;

SELECT
    *
FROM
    mytransaction;

SELECT
    *
FROM
    store;

---- Before we join the two tables we need to remove returned tansactions from transaction table
CREATE VIEW CLEAN_TRANSACTIONS AS
SELECT
    b.*
FROM (
    SELECT
        a.*,
        CASE WHEN a."Status" = 'Returns' THEN
            'drop'
        ELSE
            'keep'
        END AS indicators
    FROM (
        SELECT
            t.*,
            r."Status"
        FROM
            mytransaction AS t
        LEFT JOIN myreturn AS r ON t."TransactionID" = R."TransactionID") AS a) AS b
WHERE
    indicators = 'keep';


/* FIRST QUESTION (T1) = GROSS SALES
To find GROSS SALES= Quantity_Supplied * Unit price
To find Discount value = Gross sales * discount rate
TO FIND REVENUE = Gross sales - discount value
to find manufacturing cost = quantity supplied * production price
to find profit before tax = revenue - manufacturing cost
 */
CREATE VIEW SUM_GROSS_SALES AS
SELECT
    SUM(Gross_sales) AS SUM_GROSS_SALES
FROM (
    SELECT
        *,
        "Quantity_Supplied" * "Unit_Price" AS Gross_Sales
    FROM
        CLEAN_TRANSACTIONS AS c
    LEFT JOIN product AS p ON c."ProductID" = p."ProductID") AS D;

----- SECOND QUESTION -  Revenue without Returns
CREATE VIEW Revenue_table AS
SELECT
    E.*,
    E.Gross_sales - E.Discount_value AS Revenue
FROM (
    SELECT
        D.*,
        (Gross_sales * "Discount(%)" / 100) AS Discount_value
    FROM (
        SELECT
            C.*,
            p."Product_Name",
            p."Product_Category",
            p."Stock_Quantity_Left",
            p."Unit_Price",
            p."Production_Price",
            p."Store_Location_Code",
            "Quantity_Supplied" * "Unit_Price" AS Gross_Sales
        FROM
            CLEAN_TRANSACTIONS AS c
        LEFT JOIN product AS p ON c."ProductID" = p."ProductID") AS D) AS E;

-- Question 3 (T2) - Revenue and growth (MTM & YTY)
CREATE VIEW YTY_GROWTHRATE AS
SELECT
    c.*,
    YTY_Difference / Revenue_previous_year * 100 AS Growth_rate
FROM (
    SELECT
        year,
        sum_revenue,
        LAG(sum_revenue) OVER (ORDER BY year) AS Revenue_Previous_Year,
        sum_revenue - LAG(sum_revenue) OVER (ORDER BY year) AS YTY_Difference
    FROM (
        SELECT
            year,
            sum(revenue) AS sum_revenue
        FROM (
            SELECT
                *,
                EXTRACT(year FROM "Order_Date") AS year,
                EXTRACT(month FROM "Order_Date")
            FROM
                revenue_table) AS a
        GROUP BY
            year) AS b) AS c;

CREATE VIEW MTM_GROWTHRATE_CORRECT AS
SELECT
    c.*,
    MTM_Difference / previous_month * 100 AS Growth_rate
FROM (
    SELECT
        month,
        sum_revenue,
        LAG(sum_revenue) OVER (ORDER BY month) AS previous_month,
        sum_revenue - LAG(sum_revenue) OVER (ORDER BY month) AS MTM_Difference
    FROM (
        SELECT
            month,
            sum(revenue) AS sum_revenue
        FROM (
            SELECT
                *,
                EXTRACT(year FROM "Order_Date") AS year,
                EXTRACT(month FROM "Order_Date") AS month
            FROM
                revenue_table) AS a
        GROUP BY
            month) AS b) AS c CREATE VIEW MTM_GROWTHRATE AS
    SELECT
        c.*,
        MTM_Difference / previous_month * 100 AS Growth_rate
    FROM (
        SELECT
            year,
            month,
            sum_revenue,
            LAG(sum_revenue) OVER (ORDER BY year, month) AS previous_month,
            sum_revenue - LAG(sum_revenue) OVER (ORDER BY year, month) AS MTM_Difference
        FROM (
            SELECT
                year,
                month,
                ROUND(sum(revenue)::numeric, 2) AS sum_revenue
            FROM (
                SELECT
                    *,
                    EXTRACT(year FROM "Order_Date") AS year,
                    EXTRACT(month FROM "Order_Date") AS month
                FROM
                    revenue_table) AS a
            GROUP BY
                year,
                month) AS b) AS c;

--- Proft before tax = Revenue - Manufacturing cost
-- Manufacturing cost = Quantity supplied * production price
---- TAX = 5% * Profit_before_tax
---- Profit after tax = Profit before tax - tax
CREATE VIEW Profit_table AS
SELECT
    *,
    profit_before_tax - tax AS profit_after_tax
FROM (
    SELECT
        *,
        0.05 * profit_before_tax AS tax
    FROM (
        SELECT
            *,
            ROUND(Revenue::numeric, 2) - Manufacturing_Cost AS Profit_before_tax
        FROM (
            SELECT
                *,
                ROUND("Quantity_Supplied" * "Production_Price"::numeric, 2) AS Manufacturing_Cost
            FROM
                revenue_table) AS a) AS b) AS c
    --- NOW TO CALCULATE THE TOTAL PROFIT BEFORE TAX, TOTAL TAX AND TOTAL PROFIT_AFTER_TAX
    SELECT
        SUM(profit_before_tax) AS sum_profit_before_tax,
    SUM(profit_after_tax) AS sum_profit_after_tax,
    SUM(tax) AS sum_tax,
    SUM(manufacturing_cost) AS sum_manufacturing_cost,
    SUM(gross_sales) AS sum_gross_sales,
    sum(revenue) AS sum_revenue
FROM
    profit_table
    --- Total returns
    CREATE VIEW returned_transaction AS
    SELECT
        b.*
    FROM (
        SELECT
            a.*,
            CASE WHEN a."Status" = 'Returns' THEN
                'drop'
            ELSE
                'keep'
            END AS indicators
        FROM (
            SELECT
                t.*,
                r."Status"
            FROM
                mytransaction AS t
            LEFT JOIN myreturn AS r ON t."TransactionID" = R."TransactionID") AS a) AS b
WHERE
    indicators = 'drop';

CREATE VIEW TOTAL_COST_RETURN AS
SELECT
    SUM(cost_return) AS total_cost_return,
    month
FROM (
    SELECT
        *,
        EXTRACT(month FROM "Order_Date") AS month
    FROM (
        SELECT
            *,
            "Unit_Price" * "Quantity_Supplied" AS cost_return
        FROM (
            SELECT
                *
            FROM
                returned_transaction AS r
            LEFT JOIN product AS P ON r."ProductID" = p."ProductID") AS a) AS b) AS c
GROUP BY
    month
    ----Quick Analyses Cases
    ---TOP TEN CUSTOMERS BY REVENUE
    CREATE VIEW TOP_TEN_CUSTOMERS AS
    SELECT
        c."Customers_Name",
        ROUND(sum(revenue)::numeric, 2) AS Total_revenue
FROM
    revenue_table AS r
    LEFT JOIN customer AS c ON r."CustomerID" = c."CustomerID"
GROUP BY
    c."Customers_Name"
ORDER BY
    Total_revenue DESC
LIMIT 10
----Revenue and Profit after tax (MTM)
CREATE VIEW REVENUE_PAT_MTM AS
SELECT
    month,
    SUM(profit_after_tax) AS sum_profit_after_tax,
    SUM(revenue) AS sum_revenue
FROM (
    SELECT
        *,
        EXTRACT(year FROM "Order_Date") AS year,
        EXTRACT(month FROM "Order_Date") AS month
    FROM
        profit_table) AS a
GROUP BY
    month
    --- Top ten products by revenue
    CREATE VIEW TOP_TEN_PRODUCT AS
    SELECT
        r."Product_Name",
        ROUND(sum(revenue)::numeric, 2) AS Total_revenue
FROM
    revenue_table AS r
GROUP BY
    r."Product_Name"
ORDER BY
    Total_revenue DESC
LIMIT 10
--- Product category by revenue
CREATE VIEW Product_category_revenue AS
SELECT
    "Product_Category",
    ROUND(sum(revenue)::numeric, 2) AS Total_revenue
FROM
    revenue_table AS r
GROUP BY
    "Product_Category"
ORDER BY
    Total_revenue DESC
	
----Quantity of product supplied against store location
CREATE VIEW Total_Quantity_Location AS
SELECT
	"Location",
	Sum("Quantity_Supplied") AS Total_Quantity
FROM (
    SELECT
        p.*,
        s."Location",
        s."State"
    FROM
        profit_table AS P
    LEFT JOIN store AS s ON p."Store_Location_Code" = s."Store_Location_Code") AS a
GROUP BY
    "Location"
ORDER BY
    Total_Quantity

--- TOP 15 PRODUCTS WITH FREQUENCY OF TRANSACTION AND PROFIT
CREATE VIEW PRODUCT_FREQUENCY_PROFIT AS
SELECT
	p."Product_Name",
	COUNT("Product_Name") AS FREQUENCY_TRANSACTION,
    ROUND(sum(Profit_after_tax)::numeric, 2) AS Total_profit
FROM
    Profit_table AS p
GROUP BY
    p."Product_Name"
ORDER BY
    Total_Profit DESC
LIMIT 15
