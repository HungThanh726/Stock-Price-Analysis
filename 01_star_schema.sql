/*==============================================================================
  PROJECT   : VN Stock Market Analytics - Star Schema (Bước 3a)
  FILE      : 01_star_schema.sql
  ĐẦU VÀO   : bảng dbo.StockPrice_Clean - do 02_etl/ETL_Pipeline.ipynb tạo ra.
              Tên cột đã là tiếng Anh, kiểu dữ liệu đã chuẩn hoá, KHÔNG còn
              bước rename/clean nào ở đây - file này chỉ dựng star schema.
  OUTPUT    : DimTicker, DimDate, FactStockPrice
  AUTHOR    : BbiGOD
==============================================================================*/

-- CREATE DATABASE VN_Stock_Portfolio;
-- GO
-- USE VN_Stock_Portfolio;
-- GO

/*------------------------------------------------------------------------------
  1. DimTicker - danh mục mã cổ phiếu
------------------------------------------------------------------------------*/
DROP TABLE IF EXISTS dbo.DimTicker;
GO
CREATE TABLE dbo.DimTicker (
    TickerKey   INT IDENTITY(1,1) PRIMARY KEY,
    Ticker      NVARCHAR(10) NOT NULL UNIQUE
);
GO
INSERT INTO dbo.DimTicker (Ticker)
SELECT DISTINCT Ticker
FROM dbo.StockPrice_Clean;
GO

/*------------------------------------------------------------------------------
  2. DimDate - lịch giao dịch (DayOfWeek đã có sẵn từ bước Transform ở Python)
------------------------------------------------------------------------------*/
DROP TABLE IF EXISTS dbo.DimDate;
GO
CREATE TABLE dbo.DimDate (
    DateKey     INT PRIMARY KEY,
    FullDate    DATE NOT NULL UNIQUE,
    DayOfWeek   NVARCHAR(20),
    WeekOfYear  INT,
    MonthNo     INT,
    Year        INT
);
GO
INSERT INTO dbo.DimDate (DateKey, FullDate, DayOfWeek, WeekOfYear, MonthNo, Year)
SELECT DISTINCT
    CONVERT(INT, FORMAT(TradeDate, 'yyyyMMdd')) AS DateKey,
    TradeDate                                   AS FullDate,
    DayOfWeek,
    DATEPART(ISO_WEEK, TradeDate)                AS WeekOfYear,
    MONTH(TradeDate)                             AS MonthNo,
    YEAR(TradeDate)                              AS Year
FROM dbo.StockPrice_Clean;
GO

/*------------------------------------------------------------------------------
  3. FactStockPrice - bảng fact ở mức Ticker-Date
------------------------------------------------------------------------------*/
DROP TABLE IF EXISTS dbo.FactStockPrice;
GO
CREATE TABLE dbo.FactStockPrice (
    TickerKey       INT NOT NULL REFERENCES dbo.DimTicker(TickerKey),
    DateKey         INT NOT NULL REFERENCES dbo.DimDate(DateKey),
    ClosePrice      DECIMAL(18,2),
    AdjClosePrice   DECIMAL(18,2),
    OpenPrice       DECIMAL(18,2),
    HighPrice       DECIMAL(18,2),
    LowPrice        DECIMAL(18,2),
    MatchedVolume   BIGINT,
    MatchedValue    DECIMAL(18,2),
    DealVolume      BIGINT,
    DealValue       DECIMAL(18,2),
    PRIMARY KEY (TickerKey, DateKey)
);
GO
INSERT INTO dbo.FactStockPrice
SELECT
    t.TickerKey,
    d.DateKey,
    s.ClosePrice,
    s.AdjClosePrice,
    s.OpenPrice,
    s.HighPrice,
    s.LowPrice,
    s.MatchedVolume,
    s.MatchedValue,
    s.DealVolume,
    s.DealValue
FROM dbo.StockPrice_Clean s
JOIN dbo.DimTicker t ON t.Ticker = s.Ticker
JOIN dbo.DimDate   d ON d.FullDate = s.TradeDate;
GO

CREATE NONCLUSTERED INDEX IX_Fact_Ticker ON dbo.FactStockPrice(TickerKey);
CREATE NONCLUSTERED INDEX IX_Fact_Date   ON dbo.FactStockPrice(DateKey);
GO

-- Kiểm tra nhanh
SELECT COUNT(*) AS SoDongFact FROM dbo.FactStockPrice;
SELECT COUNT(*) AS SoMa FROM dbo.DimTicker;
SELECT COUNT(*) AS SoPhien FROM dbo.DimDate;
