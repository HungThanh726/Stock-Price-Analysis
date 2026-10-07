# VN Stock Market Analytics — End-to-End Portfolio Project

Project phân tích thị trường chứng khoán Việt Nam (HOSE/HNX/UPCOM), đi đầy đủ 1 vòng pipeline thực tế của Business Data Analyst: **Crawl dữ liệu → ETL → SQL (star schema + business question) → Power BI dashboard**.

## 1. Overview / Business Problem

Nhà đầu tư cá nhân và bộ phận theo dõi thị trường cần một cái nhìn tổng quan, cập nhật về **thanh khoản, biến động giá và các phiên giao dịch bất thường** trên toàn thị trường, thay vì theo dõi thủ công từng mã. Project này trả lời 3 câu hỏi kinh doanh cốt lõi:

1. Dòng tiền đang tập trung ở nhóm cổ phiếu nào (thanh khoản cao/thấp)?
2. Mã nào tăng/giảm mạnh nhất, biến động (rủi ro) cao nhất trong kỳ?
3. Có phiên giao dịch nào bất thường cần lưu ý (dấu hiệu rủi ro hoặc sự kiện doanh nghiệp) không?

## 2. Dataset Description

| Thuộc tính | Giá trị |
|---|---|
| Nguồn | CafeF (s.cafef.vn) — crawl trực tiếp hoặc dùng file snapshot có sẵn trong `data/` |
| Phạm vi | 403 mã cổ phiếu (HOSE/HNX/UPCOM) |
| Khoảng thời gian | 05/01/2026 – 28/01/2026 (18 phiên giao dịch) |
| Số dòng | 7,224 (403 mã x 18 phiên) |
| Đơn vị giá trị giao dịch | tỷ VNĐ |
| Các cột gốc | Mã, Ngày, Giá đóng cửa, Giá điều chỉnh, Thay đổi, Khối lượng khớp lệnh, Giá trị khớp lệnh, Khối lượng thỏa thuận, Giá trị thỏa thuận, Giá mở cửa, Giá cao nhất, Giá thấp nhất |

## 3. Tech Stack

- **Python**: `requests` (crawl), `pandas` (ETL), chạy trong Jupyter Notebook
- **SQL Server (T-SQL)**: star schema, window functions (`LAG`, `RANK`, `NTILE`, `STDEV`, `FIRST_VALUE/LAST_VALUE`)
- **Power BI Desktop**: DAX measures, dashboard 3 trang

## 4. Project Structure

```
VN_Stock_Market_Analytics/
|README.md                                  <- file này
| data/
| LichSuGia_ALL_01_01_2026_02_01_2026.csv   <- snapshot gốc dùng cho Key Insights bên dưới
|─ 01_crawl/
| crawl_cafef.py                            <- Extract: crawl dữ liệu trực tiếp từ CafeF
| tickers.csv                               <- danh sách 403 mã dùng để crawl
|- 02_etl/
| ETL_Pipeline.ipynb                        <- Transform (rename cột VN->EN, parse, clean) + Load
|- 03_sql/
| 01_star_schema.sql                        <- dựng DimTicker / DimDate / FactStockPrice
| 02_business_questions.sql                 <- 10 Business Question (Q1-Q10) + Bonus
|- 04_powerbi/
```

## 5. Key Insights

- Tổng giá trị giao dịch toàn thị trường trong 18 phiên: **~577,449 tỷ VNĐ**.
- **Top gainer cả giai đoạn**: PLX (+62.3%) · **Top loser**: MCH (-29.0%, xem ghi chú data quality bên dưới).
- **Top 5 mã thanh khoản cao nhất**: VIX, VHM, SHB, HPG, VCB — tập trung ở nhóm ngân hàng/bluechip vốn hoá lớn.
- **Mã biến động (volatility) cao nhất**: PMG (~6.6%/phiên), HID (~5.9%), CMV (~5.5%) — đa phần là nhóm thanh khoản thấp.
- **157 phiên** được gắn cờ bất thường theo Z-score (|Z| > 2.5), phần lớn trùng với các phiên **kịch trần/kịch sàn (±7%)** theo quy tắc biên độ dao động giá của HOSE.
- Thanh khoản trung bình cao nhất vào **Thứ Năm**, thấp nhất vào **Thứ Hai**.
- **Data quality**: mã **MCH** ngày 09/01/2026 giảm ~18.7% theo giá đóng cửa dù cột "Thay đổi" gốc chỉ ghi -0.11% → dấu hiệu giá tham chiếu được điều chỉnh do sự kiện doanh nghiệp (chia cổ tức/tách quyền), không phải giảm sàn thực tế.

## 6. Business Recommendations

- **Watchlist theo Liquidity Tier (Q7)**: ưu tiên theo dõi nhóm Tier 1 (thanh khoản cao) cho chiến lược ngắn hạn — dễ vào/thoát lệnh mà không trượt giá nhiều; nhóm Tier 4 nên tránh giao dịch khối lượng lớn.
- **Cảnh báo rủi ro theo volatility (Q6)**: các mã có độ lệch chuẩn daily return cao (PMG, HID, CMV...) cần mức cắt lỗ chặt hơn trong mô hình quản trị rủi ro danh mục.
- **Luôn dùng Giá điều chỉnh khi tính lợi nhuận**: như trường hợp MCH cho thấy, dùng giá đóng cửa thô để tính % thay đổi có thể cho kết quả sai lệch nghiêm trọng khi có sự kiện doanh nghiệp (chia cổ tức/tách quyền) — nên chuẩn hoá quy trình tính return luôn ưu tiên `AdjClosePrice`.
- **Cảnh báo tự động cho phiên bất thường (Q9)**: 157 phiên Z-score bất thường có thể dùng làm input cho 1 bảng cảnh báo hằng ngày (daily alert) gửi cho đội phân tích, thay vì rà soát thủ công từng mã.
- **Theo dõi nhịp thanh khoản theo tuần**: thanh khoản thấp vào Thứ Hai có thể là điểm vào lệnh tốt hơn (giá chưa phản ánh hết thông tin cuối tuần) — cần thêm dữ liệu dài hạn để kiểm chứng xu hướng này có lặp lại hay không.
