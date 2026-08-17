/*==============================================================================
  PROJECT   : VN Stock Market – Price History Analysis (T-SQL)
  DATASET   : LichSuGia_ALL_01_01_2026_02_01_2026.csv
              403 mã cổ phiếu (HOSE/HNX/UPCOM) x 18 phiên giao dịch
              (05/01/2026 - 28/01/2026)
  AUTHOR    : BbiGOD
  MỤC ĐÍCH  : Portfolio project minh hoạ kỹ năng T-SQL cho vị trí
              Business Data Analyst - từ mức Junior đến Junior+
              (staging -> star schema -> window functions -> insight)
==============================================================================*/

/*------------------------------------------------------------------------------
  0. TẠO DATABASE (bỏ qua nếu đã có sẵn database làm việc)
------------------------------------------------------------------------------*/
-- CREATE DATABASE VN_Stock_Portfolio;
-- GO
-- USE VN_Stock_Portfolio;
-- GO

/*==============================================================================
  PHẦN 1 - STAGING: NẠP DỮ LIỆU THÔ TỪ CSV
==============================================================================*/

DROP TABLE IF EXISTS dbo.Staging_StockPrice;
GO

CREATE TABLE dbo.Staging_StockPrice (
    Ticker              NVARCHAR(10),
    TradeDateText       VARCHAR(10),      -- dạng dd/mm/yyyy trong file gốc
    ClosePrice          DECIMAL(18,2),
    AdjClosePrice       DECIMAL(18,2),
    ChangeText          NVARCHAR(50),     -- vd: "+0,02 (+0,26%)" -> giữ nguyên text, xử lý ở bước transform nếu cần
    MatchedVolume       BIGINT,
    MatchedValue        DECIMAL(18,2),    -- đơn vị: tỷ VNĐ
    DealVolume          BIGINT,
    DealValue           DECIMAL(18,2),
    OpenPrice           DECIMAL(18,2),
    HighPrice           DECIMAL(18,2),
    LowPrice            DECIMAL(18,2)
);
GO

-- Nạp dữ liệu bằng BULK INSERT (đổi đường dẫn cho đúng máy của bạn)
-- Lưu ý: file gốc có BOM (UTF-8 with BOM) và dùng dấu phẩy Việt Nam trong cột ChangeText
-- nên cột này được giữ dạng NVARCHAR, không convert sang số.
/*
BULK INSERT dbo.Staging_StockPrice
FROM 'C:\Data\LichSuGia_ALL_01_01_2026_02_01_2026.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',   -- UTF-8
    FIELDQUOTE = '"',
    TABLOCK
);
*/

/*==============================================================================
  PHẦN 2 - STAR SCHEMA: DIM & FACT
==============================================================================*/

-- 2.1 DimTicker: danh mục mã cổ phiếu
DROP TABLE IF EXISTS dbo.DimTicker;
GO
CREATE TABLE dbo.DimTicker (
    TickerKey   INT IDENTITY(1,1) PRIMARY KEY,
    Ticker      NVARCHAR(10) NOT NULL UNIQUE
);
GO
INSERT INTO dbo.DimTicker (Ticker)
SELECT DISTINCT Ticker
FROM dbo.Staging_StockPrice;
GO

-- 2.2 DimDate: lịch giao dịch, phục vụ phân tích theo ngày trong tuần / tuần / tháng
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
    CONVERT(INT, FORMAT(TRY_CONVERT(DATE, TradeDateText, 103), 'yyyyMMdd')) AS DateKey,
    TRY_CONVERT(DATE, TradeDateText, 103)                                   AS FullDate,
    DATENAME(WEEKDAY, TRY_CONVERT(DATE, TradeDateText, 103))                AS DayOfWeek,
    DATEPART(ISO_WEEK, TRY_CONVERT(DATE, TradeDateText, 103))               AS WeekOfYear,
    MONTH(TRY_CONVERT(DATE, TradeDateText, 103))                            AS MonthNo,
    YEAR(TRY_CONVERT(DATE, TradeDateText, 103))                             AS Year
FROM dbo.Staging_StockPrice;
GO

-- 2.3 FactStockPrice: bảng fact ở mức Ticker-Date
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
FROM dbo.Staging_StockPrice s
JOIN dbo.DimTicker t ON t.Ticker = s.Ticker
JOIN dbo.DimDate   d ON d.FullDate = TRY_CONVERT(DATE, s.TradeDateText, 103);
GO

CREATE NONCLUSTERED INDEX IX_Fact_Ticker ON dbo.FactStockPrice(TickerKey);
CREATE NONCLUSTERED INDEX IX_Fact_Date   ON dbo.FactStockPrice(DateKey);
GO


/*==============================================================================
  PHẦN 3 - 10 CÂU HỎI NGHIỆP VỤ (Junior -> Junior+)
==============================================================================*/

/*------------------------------------------------------------------------------
  Q1 [Junior] Tổng khối lượng & giá trị giao dịch toàn thị trường theo từng phiên
------------------------------------------------------------------------------*/
SELECT
    d.FullDate,
    SUM(f.MatchedVolume)                       AS TotalVolume,
    SUM(f.MatchedValue)                        AS TotalValue_BillionVND
FROM dbo.FactStockPrice f
JOIN dbo.DimDate d ON d.DateKey = f.DateKey
GROUP BY d.FullDate
ORDER BY d.FullDate;


/*------------------------------------------------------------------------------
  Q2 [Junior] Top 10 mã có giá trị giao dịch trung bình/phiên cao nhất (thanh khoản)
------------------------------------------------------------------------------*/
SELECT TOP 10
    t.Ticker,
    AVG(f.MatchedValue) AS AvgDailyValue_BillionVND,
    SUM(f.MatchedValue) AS TotalValue_BillionVND
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
GROUP BY t.Ticker
ORDER BY AvgDailyValue_BillionVND DESC;


/*------------------------------------------------------------------------------
  Q3 [Junior] Biên độ dao động trung bình trong phiên (Amplitude %)
             Amplitude% = (High - Low) / Open * 100
------------------------------------------------------------------------------*/
SELECT TOP 10
    t.Ticker,
    AVG((f.HighPrice - f.LowPrice) / NULLIF(f.OpenPrice,0) * 100) AS AvgAmplitudePct
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
GROUP BY t.Ticker
ORDER BY AvgAmplitudePct DESC;


/*------------------------------------------------------------------------------
  Q4 [Junior+] Lợi nhuận cả giai đoạn mỗi mã (giá đóng cửa đầu kỳ vs cuối kỳ)
             Dùng FIRST_VALUE / LAST_VALUE (window function)
------------------------------------------------------------------------------*/
WITH PeriodPrice AS (
    SELECT
        t.Ticker,
        d.FullDate,
        f.ClosePrice,
        FIRST_VALUE(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)               AS FirstClose,
        LAST_VALUE(f.ClosePrice)  OVER (PARTITION BY t.Ticker ORDER BY d.FullDate
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)               AS LastClose,
        ROW_NUMBER() OVER (PARTITION BY t.Ticker ORDER BY d.FullDate)               AS rn
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
)
SELECT
    Ticker,
    FirstClose,
    LastClose,
    ROUND((LastClose - FirstClose) / FirstClose * 100, 2) AS PeriodReturnPct,
    RANK() OVER (ORDER BY (LastClose - FirstClose) / FirstClose DESC) AS GainRank
FROM PeriodPrice
WHERE rn = 1                              -- 1 dòng / mã
ORDER BY PeriodReturnPct DESC;            -- đảo ORDER BY DESC/ASC để xem Top gainer / Top loser


/*------------------------------------------------------------------------------
  Q5 [Junior+] Biến động ngày-qua-ngày (Daily Return %) dùng LAG()
------------------------------------------------------------------------------*/
SELECT
    t.Ticker,
    d.FullDate,
    f.ClosePrice,
    LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate) AS PrevClose,
    ROUND(
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
        / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100
    , 2) AS DailyReturnPct
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
ORDER BY t.Ticker, d.FullDate;


/*------------------------------------------------------------------------------
  Q6 [Junior+] Độ biến động (volatility) - STDEV daily return theo mã, rank giảm dần
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker,
        d.FullDate,
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
            / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100 AS DailyReturnPct
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
)
SELECT TOP 10
    Ticker,
    ROUND(STDEV(DailyReturnPct), 2) AS VolatilityStdDev
FROM DailyReturn
WHERE DailyReturnPct IS NOT NULL
GROUP BY Ticker
ORDER BY VolatilityStdDev DESC;


/*------------------------------------------------------------------------------
  Q7 [Junior+] Phân khúc thanh khoản (Liquidity Segmentation) dùng NTILE(4)
             Tier 1 = thanh khoản cao nhất, Tier 4 = thấp nhất
------------------------------------------------------------------------------*/
WITH AvgLiquidity AS (
    SELECT
        t.Ticker,
        AVG(f.MatchedValue) AS AvgDailyValue
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    GROUP BY t.Ticker
)
SELECT
    Ticker,
    AvgDailyValue,
    NTILE(4) OVER (ORDER BY AvgDailyValue DESC) AS LiquidityTier
FROM AvgLiquidity
ORDER BY LiquidityTier, AvgDailyValue DESC;


/*------------------------------------------------------------------------------
  Q8 [Junior+] Đường trung bình động 5 phiên (SMA5) - Moving Average
------------------------------------------------------------------------------*/
SELECT
    t.Ticker,
    d.FullDate,
    f.ClosePrice,
    AVG(f.ClosePrice) OVER (
        PARTITION BY t.Ticker ORDER BY d.FullDate
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ) AS SMA5
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
ORDER BY t.Ticker, d.FullDate;


/*------------------------------------------------------------------------------
  Q9 [Junior+] Phát hiện bất thường (Anomaly Detection) bằng Z-score
             Z = (x - mean) / stdev tính theo từng mã trên daily return
             Lọc |Z| > 2.5 -> phiên giao dịch "lệch chuẩn" so với hành vi thông thường của mã đó
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker,
        d.FullDate,
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
            / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100 AS DailyReturnPct
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
),
Stats AS (
    SELECT
        Ticker,
        FullDate,
        DailyReturnPct,
        AVG(DailyReturnPct)  OVER (PARTITION BY Ticker) AS AvgReturn,
        STDEV(DailyReturnPct) OVER (PARTITION BY Ticker) AS StdReturn
    FROM DailyReturn
    WHERE DailyReturnPct IS NOT NULL
)
SELECT
    Ticker,
    FullDate,
    ROUND(DailyReturnPct, 2) AS DailyReturnPct,
    ROUND((DailyReturnPct - AvgReturn) / NULLIF(StdReturn,0), 2) AS ZScore
FROM Stats
WHERE ABS((DailyReturnPct - AvgReturn) / NULLIF(StdReturn,0)) > 2.5
ORDER BY ZScore;


/*------------------------------------------------------------------------------
  Q10 [Junior+] Top phiên biến động mạnh nhất toàn thị trường (best/worst single-day)
              Dùng RANK() trên toàn bộ tập hợp Ticker x Date
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker,
        d.FullDate,
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
            / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100 AS DailyReturnPct
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
)
SELECT TOP 10 *
FROM (
    SELECT Ticker, FullDate, ROUND(DailyReturnPct,2) AS DailyReturnPct,
           RANK() OVER (ORDER BY DailyReturnPct DESC) AS RankBest,
           RANK() OVER (ORDER BY DailyReturnPct ASC)  AS RankWorst
    FROM DailyReturn
    WHERE DailyReturnPct IS NOT NULL
) x
WHERE RankBest <= 5 OR RankWorst <= 5
ORDER BY DailyReturnPct DESC;


/*==============================================================================
  GHI CHÚ DATA QUALITY
  - Biên độ dao động giá trong 1 phiên tại HOSE/HNX bị giới hạn bởi biên độ
    +/-7% (HOSE) hoặc +/-10% (HNX) so với giá tham chiếu, nên các giá trị
    DailyReturnPct xấp xỉ +-7% ở Q10 là các phiên "kịch trần/kịch sàn" - hợp lý.
  - Riêng mã MCH ngày 09/01/2026 ghi nhận DailyReturnPct ~ -18.7% dù cột
    "Thay đổi" gốc chỉ show -0.11%: đây là dấu hiệu giá tham chiếu được điều
    chỉnh do sự kiện doanh nghiệp (chia cổ tức/tách quyền), KHÔNG phải giá
    giảm sàn thực tế. Khi phân tích lợi nhuận nên cân nhắc dùng "Giá điều
    chỉnh" (AdjClosePrice) thay vì "Giá đóng cửa" để loại trừ nhiễu này.
==============================================================================*/
