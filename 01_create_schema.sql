/* =========================================================
   01_create_schema.sql
   Project : Retail Sales Analytics (SQL Server / T-SQL)
   Purpose : Create the database and a small star-style schema
             (3 dimensions + 1 fact table) with keys & constraints.
   ========================================================= */

IF DB_ID('RetailSalesDB') IS NULL
    CREATE DATABASE RetailSalesDB;
GO

USE RetailSalesDB;
GO

-- Drop in dependency order so the script is re-runnable
DROP TABLE IF EXISTS dbo.Sales;
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Stores;
GO

CREATE TABLE dbo.Stores (
    StoreID     INT           NOT NULL PRIMARY KEY,
    StoreName   VARCHAR(50)   NOT NULL,
    City        VARCHAR(50)   NOT NULL,
    State       VARCHAR(50)   NOT NULL
);

CREATE TABLE dbo.Products (
    ProductID   INT            NOT NULL PRIMARY KEY,
    ProductName VARCHAR(100)   NOT NULL,
    Category    VARCHAR(50)    NOT NULL,
    UnitPrice   DECIMAL(10,2)  NOT NULL CHECK (UnitPrice > 0)
);

CREATE TABLE dbo.Customers (
    CustomerID   INT           NOT NULL PRIMARY KEY,
    CustomerName VARCHAR(100)  NOT NULL,
    City         VARCHAR(50)   NOT NULL,
    JoinDate     DATE          NOT NULL
);

CREATE TABLE dbo.Sales (
    SaleID       INT            NOT NULL PRIMARY KEY,
    SaleDate     DATE           NOT NULL,
    StoreID      INT            NOT NULL REFERENCES dbo.Stores(StoreID),
    CustomerID   INT            NOT NULL REFERENCES dbo.Customers(CustomerID),
    ProductID    INT            NOT NULL REFERENCES dbo.Products(ProductID),
    Quantity     INT            NOT NULL CHECK (Quantity > 0),
    UnitPrice    DECIMAL(10,2)  NOT NULL,          -- price at time of sale
    DiscountPct  DECIMAL(5,2)   NOT NULL DEFAULT 0 CHECK (DiscountPct BETWEEN 0 AND 100),
    -- Derived column: revenue after discount
    NetAmount AS CAST(Quantity * UnitPrice * (1 - DiscountPct / 100.0) AS DECIMAL(12,2)) PERSISTED
);
GO

-- Indexes on the foreign keys / date to support the analysis queries
CREATE INDEX IX_Sales_SaleDate   ON dbo.Sales (SaleDate);
CREATE INDEX IX_Sales_StoreID    ON dbo.Sales (StoreID);
CREATE INDEX IX_Sales_ProductID  ON dbo.Sales (ProductID);
CREATE INDEX IX_Sales_CustomerID ON dbo.Sales (CustomerID);
GO
