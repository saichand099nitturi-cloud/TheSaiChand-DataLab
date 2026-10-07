/* =========================================================
   03_business_queries.sql
   10 business questions answered with T-SQL.
   Concepts covered: aggregations, JOINs, CTEs, window
   functions (RANK, LAG, running totals, NTILE), CASE,
   date functions, and a reusable view.
   ========================================================= */
USE RetailSalesDB;
GO

/* Q1. What is total revenue, orders and units sold for 2025? */
SELECT
    COUNT(*)                 AS TotalOrders,
    SUM(Quantity)            AS UnitsSold,
    SUM(NetAmount)           AS NetRevenue,
    CAST(AVG(NetAmount) AS DECIMAL(10,2)) AS AvgOrderValue
FROM dbo.Sales;
GO

/* Q2. Revenue by store and city, highest first */
SELECT
    st.StoreName,
    st.City,
    COUNT(*)        AS Orders,
    SUM(s.NetAmount) AS NetRevenue
FROM dbo.Sales  s
JOIN dbo.Stores st ON st.StoreID = s.StoreID
GROUP BY st.StoreName, st.City
ORDER BY NetRevenue DESC;
GO

/* Q3. Revenue share (%) by product category */
SELECT
    p.Category,
    SUM(s.NetAmount) AS NetRevenue,
    CAST(100.0 * SUM(s.NetAmount) / SUM(SUM(s.NetAmount)) OVER () AS DECIMAL(5,2)) AS RevenueSharePct
FROM dbo.Sales    s
JOIN dbo.Products p ON p.ProductID = s.ProductID
GROUP BY p.Category
ORDER BY NetRevenue DESC;
GO

/* Q4. Monthly revenue with month-over-month growth % (LAG) */
WITH Monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS MonthStart,
        SUM(NetAmount) AS NetRevenue
    FROM dbo.Sales
    GROUP BY DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)
)
SELECT
    FORMAT(MonthStart, 'yyyy-MM') AS [Month],
    NetRevenue,
    LAG(NetRevenue) OVER (ORDER BY MonthStart) AS PrevMonthRevenue,
    CAST(100.0 * (NetRevenue - LAG(NetRevenue) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(NetRevenue) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,2)) AS MoMGrowthPct
FROM Monthly
ORDER BY MonthStart;
GO

/* Q5. Running (cumulative) revenue through the year */
SELECT
    SaleDate,
    SUM(NetAmount) AS DailyRevenue,
    SUM(SUM(NetAmount)) OVER (ORDER BY SaleDate
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningRevenue
FROM dbo.Sales
GROUP BY SaleDate
ORDER BY SaleDate;
GO

/* Q6. Top 3 products in every category (RANK inside a CTE) */
WITH ProductSales AS (
    SELECT
        p.Category,
        p.ProductName,
        SUM(s.NetAmount) AS NetRevenue,
        RANK() OVER (PARTITION BY p.Category ORDER BY SUM(s.NetAmount) DESC) AS RankInCategory
    FROM dbo.Sales    s
    JOIN dbo.Products p ON p.ProductID = s.ProductID
    GROUP BY p.Category, p.ProductName
)
SELECT Category, ProductName, NetRevenue, RankInCategory
FROM ProductSales
WHERE RankInCategory <= 3
ORDER BY Category, RankInCategory;
GO

/* Q7. Top 10 customers by lifetime spend */
SELECT TOP (10)
    c.CustomerName,
    c.City,
    COUNT(*)         AS Orders,
    SUM(s.NetAmount) AS LifetimeSpend
FROM dbo.Sales     s
JOIN dbo.Customers c ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerName, c.City
ORDER BY LifetimeSpend DESC;
GO

/* Q8. Customer segmentation into 4 spend tiers (NTILE + CASE) */
WITH CustomerSpend AS (
    SELECT CustomerID, SUM(NetAmount) AS Spend
    FROM dbo.Sales
    GROUP BY CustomerID
),
Tiered AS (
    SELECT CustomerID, Spend, NTILE(4) OVER (ORDER BY Spend DESC) AS Quartile
    FROM CustomerSpend
)
SELECT
    CASE Quartile WHEN 1 THEN 'Platinum'
                  WHEN 2 THEN 'Gold'
                  WHEN 3 THEN 'Silver'
                  ELSE 'Bronze' END AS Segment,
    COUNT(*)   AS Customers,
    SUM(Spend) AS SegmentRevenue,
    CAST(AVG(Spend) AS DECIMAL(10,2)) AS AvgSpend
FROM Tiered
GROUP BY Quartile
ORDER BY Quartile;
GO

/* Q9. How much revenue did discounts cost us, by store? */
SELECT
    st.StoreName,
    SUM(s.Quantity * s.UnitPrice)               AS GrossRevenue,
    SUM(s.NetAmount)                            AS NetRevenue,
    SUM(s.Quantity * s.UnitPrice) - SUM(s.NetAmount) AS DiscountGiven,
    SUM(CASE WHEN s.DiscountPct > 0 THEN 1 ELSE 0 END) AS DiscountedOrders
FROM dbo.Sales  s
JOIN dbo.Stores st ON st.StoreID = s.StoreID
GROUP BY st.StoreName
ORDER BY DiscountGiven DESC;
GO

/* Q10. Weekday vs weekend sales pattern */
SELECT
    DATENAME(WEEKDAY, SaleDate) AS DayName,
    CASE WHEN DATENAME(WEEKDAY, SaleDate) IN ('Saturday', 'Sunday')
         THEN 'Weekend' ELSE 'Weekday' END AS DayType,
    COUNT(*)        AS Orders,
    SUM(NetAmount)  AS NetRevenue
FROM dbo.Sales
GROUP BY DATENAME(WEEKDAY, SaleDate)
ORDER BY NetRevenue DESC;
GO

/* Bonus: a reusable reporting view (handy as a Power BI source) */
CREATE OR ALTER VIEW dbo.vw_SalesDetail AS
SELECT
    s.SaleID,
    s.SaleDate,
    st.StoreName,
    st.City       AS StoreCity,
    c.CustomerName,
    p.ProductName,
    p.Category,
    s.Quantity,
    s.UnitPrice,
    s.DiscountPct,
    s.NetAmount
FROM dbo.Sales     s
JOIN dbo.Stores    st ON st.StoreID    = s.StoreID
JOIN dbo.Customers c  ON c.CustomerID  = s.CustomerID
JOIN dbo.Products  p  ON p.ProductID   = s.ProductID;
GO

SELECT TOP (10) * FROM dbo.vw_SalesDetail ORDER BY SaleDate;
GO
