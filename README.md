# VN Stock Market – Price History Analysis (T-SQL)

Phân tích lịch sử giá giao dịch của **403 mã cổ phiếu** trên thị trường chứng khoán Việt Nam (HOSE/HNX/UPCOM) trong khoảng **05/01/2026 – 28/01/2026** (18 phiên giao dịch), sử dụng T-SQL trên SQL Server.


## 1. Nguồn dữ liệu

| Thuộc tính | Giá trị |
|---|---|
| File gốc | `LichSuGia_ALL_01_01_2026_02_01_2026.csv` |
| Số dòng | 7,224 (403 mã x 18 phiên) |
| Khoảng thời gian | 05/01/2026 → 28/01/2026 |
| Đơn vị giá trị giao dịch | tỷ VNĐ |
| Encoding | UTF-8 with BOM |

Các cột gốc: `Mã, Ngày, Giá đóng cửa, Giá điều chỉnh, Thay đổi, Khối lượng khớp lệnh, Giá trị khớp lệnh, Khối lượng thỏa thuận, Giá trị thỏa thuận, Giá mở cửa, Giá cao nhất, Giá thấp nhất`.

## 2. Kiến trúc dữ liệu

```
Staging_StockPrice (raw, kiểu VARCHAR/TEXT sát với CSV gốc)     
        
-> DimTicker  
-> DimDate    
-> FactStockPrice (grain: 1 mã x 1 ngày)
```

- **DimTicker**: danh mục 403 mã cổ phiếu.
- **DimDate**: lịch giao dịch, có sẵn `DayOfWeek`, `WeekOfYear` phục vụ phân tích theo chu kỳ.
- **FactStockPrice**: bảng fact ở mức Ticker–Date, chứa giá mở/đóng/cao/thấp, khối lượng và giá trị khớp lệnh/thoả thuận.

Xem chi tiết script tạo bảng + nạp dữ liệu (BULK INSERT) + toàn bộ query tại [`VN_Stock_TSQL_Analysis.sql`](./VN_Stock_TSQL_Analysis.sql).

## 3. 10 Business Question:

| # | Câu hỏi | Kỹ thuật T-SQL |
|---|---|---|
| Q1 | Tổng khối lượng & giá trị giao dịch toàn thị trường theo phiên | `GROUP BY`, `SUM` |
| Q2 | Top 10 mã thanh khoản cao nhất | `AVG`, `TOP` |
| Q3 | Biên độ dao động trung bình trong phiên | Tính toán cột, `AVG` |
| Q4 | Lợi nhuận cả giai đoạn mỗi mã (đầu kỳ vs cuối kỳ) | `FIRST_VALUE`, `LAST_VALUE`, `RANK` |
| Q5 | Biến động ngày-qua-ngày (Daily Return) | `LAG` |
| Q6 | Độ biến động (volatility) theo mã | `STDEV` |
| Q7 | Phân khúc thanh khoản (Liquidity Tier) | `NTILE(4)` |
| Q8 | Đường trung bình động 5 phiên (SMA5) | `AVG() OVER (ROWS BETWEEN...)` |
| Q9 | Phát hiện bất thường bằng Z-score | Window function kết hợp CTE |
| Q10 | Top phiên biến động mạnh nhất toàn thị trường | `RANK()` trên toàn tập hợp |

## 4. Kết quả nổi bật (Key Findings)

Số liệu dưới đây được tính trực tiếp trên bộ dữ liệu, dùng để đối chiếu kết quả khi chạy lại các query ở trên.

- **Tổng giá trị giao dịch toàn thị trường** trong 18 phiên: **~577,449 tỷ VNĐ** (~18.4 tỷ cổ phiếu khớp lệnh).
- **Top gainer cả giai đoạn**: **PLX (+62.3%)**, theo sau là MDG (+53.9%), GAS (+52.5%), PNC (+49.1%), GVR (+48.4%).
- **Top loser cả giai đoạn**: **MCH (-29.0%)**, VHM (-21.3%), VDP (-20.7%), VTB (-19.9%), GEE (-19.4%).
- **Top 5 mã thanh khoản cao nhất** (tổng giá trị khớp lệnh): VIX (~24,081 tỷ), VHM (~22,028 tỷ), SHB (~21,466 tỷ), HPG (~20,663 tỷ), VCB (~20,629 tỷ) — đều là nhóm ngân hàng/bluechip vốn hoá lớn.
- **Mã biến động (volatility) cao nhất**: PMG (stdev ~6.6%/phiên), HID (~5.9%), CMV (~5.5%) — nhóm này có thanh khoản thấp nên giá dễ bị "nhảy" mạnh.
- **Biên độ dao động trong phiên (Amplitude) cao nhất**: TDP (~7.7%), PLX (~7.6%), GAS (~6.8%).
- **157 phiên giao dịch** (trên tổng ~6,800 quan sát daily-return) được gắn cờ bất thường theo Z-score (|Z| > 2.5) — đa phần trùng với các phiên **kịch trần/kịch sàn (+-7%)**, đúng với quy tắc biên độ dao động giá của HOSE.
- **Data quality note**: mã **MCH** ngày 09/01/2026 có `DailyReturnPct` tính từ giá đóng cửa giảm ~18.7%, nhưng cột "Thay đổi" gốc chỉ ghi -0.11% → dấu hiệu giá tham chiếu bị điều chỉnh do sự kiện doanh nghiệp (chia cổ tức/tách quyền), không phải giảm sàn thực tế. Khi tính lợi nhuận nên ưu tiên dùng "Giá điều chỉnh" thay vì "Giá đóng cửa" thô.
- **Thanh khoản theo ngày trong tuần**: giá trị giao dịch trung bình cao nhất vào **Thứ Năm** (~86.5 tỷ/mã/phiên), thấp nhất vào **Thứ Hai** (~74.4 tỷ/mã/phiên).

## 5. Cách chạy lại

1. Import `LichSuGia_ALL_01_01_2026_02_01_2026.csv` vào SQL Server (khuyến nghị dùng SSMS Import Wizard). 
2. Đối chiếu kết quả với phần *Key Findings* ở trên.
