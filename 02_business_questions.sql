/*==============================================================================
  PROJECT   : VN Stock Market Analytics - 10 Business Questions (Bước 3b)
  FILE      : 02_business_questions.sql
  ĐẦU VÀO   : DimTicker, DimDate, FactStockPrice (tạo ở 01_star_schema.sql)
  AUTHOR    : BbiGOD
==============================================================================*/

/*------------------------------------------------------------------------------
  Q1 - Tổng khối lượng & giá trị giao dịch toàn thị trường theo từng phiên
------------------------------------------------------------------------------*/
SELECT
    d.FullDate,
    SUM(f.MatchedVolume) AS TotalVolume,
    SUM(f.MatchedValue)  AS TotalValue_BillionVND
FROM dbo.FactStockPrice f
JOIN dbo.DimDate d ON d.DateKey = f.DateKey
GROUP BY d.FullDate
ORDER BY d.FullDate;


/*------------------------------------------------------------------------------
  Q2 - Top 10 mã có giá trị giao dịch trung bình/phiên cao nhất (thanh khoản)
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
  Q3 - Biên độ dao động trung bình trong phiên (Amplitude %)
------------------------------------------------------------------------------*/
SELECT TOP 10
    t.Ticker,
    AVG((f.HighPrice - f.LowPrice) / NULLIF(f.OpenPrice,0) * 100) AS AvgAmplitudePct
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
GROUP BY t.Ticker
ORDER BY AvgAmplitudePct DESC;


/*------------------------------------------------------------------------------
  Q4 - Lợi nhuận cả giai đoạn mỗi mã (đầu kỳ vs cuối kỳ)
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
    Ticker, FirstClose, LastClose,
    ROUND((LastClose - FirstClose) / FirstClose * 100, 2) AS PeriodReturnPct,
    RANK() OVER (ORDER BY (LastClose - FirstClose) / FirstClose DESC) AS GainRank
FROM PeriodPrice
WHERE rn = 1
ORDER BY PeriodReturnPct DESC;   -- đảo DESC/ASC để xem Top gainer / Top loser


/*------------------------------------------------------------------------------
  Q5 - Biến động ngày-qua-ngày (Daily Return %) dùng LAG()
------------------------------------------------------------------------------*/
SELECT
    t.Ticker, d.FullDate, f.ClosePrice,
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
  Q6 - Độ biến động (volatility) theo mã - STDEV của Daily Return
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker, d.FullDate,
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
            / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100 AS DailyReturnPct
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
)
SELECT TOP 10
    Ticker, ROUND(STDEV(DailyReturnPct), 2) AS VolatilityStdDev
FROM DailyReturn
WHERE DailyReturnPct IS NOT NULL
GROUP BY Ticker
ORDER BY VolatilityStdDev DESC;


/*------------------------------------------------------------------------------
  Q7 - Phân khúc thanh khoản (Liquidity Segmentation) dùng NTILE(4)
------------------------------------------------------------------------------*/
WITH AvgLiquidity AS (
    SELECT t.Ticker, AVG(f.MatchedValue) AS AvgDailyValue
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    GROUP BY t.Ticker
)
SELECT
    Ticker, AvgDailyValue,
    NTILE(4) OVER (ORDER BY AvgDailyValue DESC) AS LiquidityTier
FROM AvgLiquidity
ORDER BY LiquidityTier, AvgDailyValue DESC;


/*------------------------------------------------------------------------------
  Q8 - Đường trung bình động 5 phiên (SMA5)
------------------------------------------------------------------------------*/
SELECT
    t.Ticker, d.FullDate, f.ClosePrice,
    AVG(f.ClosePrice) OVER (
        PARTITION BY t.Ticker ORDER BY d.FullDate
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ) AS SMA5
FROM dbo.FactStockPrice f
JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
ORDER BY t.Ticker, d.FullDate;


/*------------------------------------------------------------------------------
  Q9 - Phát hiện bất thường (Anomaly Detection) bằng Z-score
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker, d.FullDate,
        (f.ClosePrice - LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate))
            / NULLIF(LAG(f.ClosePrice) OVER (PARTITION BY t.Ticker ORDER BY d.FullDate),0) * 100 AS DailyReturnPct
    FROM dbo.FactStockPrice f
    JOIN dbo.DimTicker t ON t.TickerKey = f.TickerKey
    JOIN dbo.DimDate   d ON d.DateKey   = f.DateKey
),
Stats AS (
    SELECT
        Ticker, FullDate, DailyReturnPct,
        AVG(DailyReturnPct)  OVER (PARTITION BY Ticker) AS AvgReturn,
        STDEV(DailyReturnPct) OVER (PARTITION BY Ticker) AS StdReturn
    FROM DailyReturn
    WHERE DailyReturnPct IS NOT NULL
)
SELECT
    Ticker, FullDate,
    ROUND(DailyReturnPct, 2) AS DailyReturnPct,
    ROUND((DailyReturnPct - AvgReturn) / NULLIF(StdReturn,0), 2) AS ZScore
FROM Stats
WHERE ABS((DailyReturnPct - AvgReturn) / NULLIF(StdReturn,0)) > 2.5
ORDER BY ZScore;


/*------------------------------------------------------------------------------
  Q10 - Top phiên biến động mạnh nhất toàn thị trường (best/worst single-day)
------------------------------------------------------------------------------*/
WITH DailyReturn AS (
    SELECT
        t.Ticker, d.FullDate,
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


/*------------------------------------------------------------------------------
  Bonus - Thanh khoản trung bình theo ngày trong tuần
------------------------------------------------------------------------------*/
SELECT
    d.DayOfWeek,
    AVG(f.MatchedValue) AS AvgValue_BillionVND
FROM dbo.FactStockPrice f
JOIN dbo.DimDate d ON d.DateKey = f.DateKey
GROUP BY d.DayOfWeek
ORDER BY AvgValue_BillionVND DESC;


/*==============================================================================
  GHI CHÚ DATA QUALITY
  Mã MCH ngày 09/01/2026 ghi nhận DailyReturnPct ~ -18.7% dù cột "Thay đổi"
  gốc chỉ show -0.11% -> dấu hiệu giá tham chiếu được điều chỉnh do sự kiện
  doanh nghiệp (chia cổ tức/tách quyền), KHÔNG phải giá giảm sàn thực tế.
  Khi tính lợi nhuận nên cân nhắc dùng AdjClosePrice thay vì ClosePrice.
==============================================================================*/
