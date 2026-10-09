# VN Stock Market Analytics — Crawl → ETL → SQL → Power BI

Project phân tích end-to-end dữ liệu giao dịch **396 mã cổ phiếu Việt Nam trong 20 phiên (09/09 – 06/10/2026)**: tự crawl dữ liệu từ CafeF, làm sạch bằng Python, mô hình hoá star schema và trả lời 10 Business Question bằng T-SQL, trực quan hoá bằng Power BI (3 trang).

Điểm nhấn của project: phát hiện và xử lý lỗi **giá đóng cửa chưa điều chỉnh sự kiện doanh nghiệp** — nếu dùng giá thô, 31 mã (7.8%) bị tính sai biến động (ví dụ TRC hiện −70.9% thay vì +16.6% sau điều chỉnh).

---

## 1. Overview / Business Problem

Một nhà đầu tư hoặc bộ phận theo dõi thị trường cần nhìn nhanh ~400 mã cổ phiếu thay vì kiểm tra thủ công từng mã. Project trả lời 4 câu hỏi:

1. **Dòng tiền** đang mạnh hay yếu, và tập trung ở nhóm mã nào?
2. **Mã nào** tăng/giảm mạnh nhất và biến động (rủi ro) cao nhất?
3. **Phiên nào bất thường** cần rà soát (chạm biên độ, lệch chuẩn thống kê)?
4. **Dữ liệu giá có đáng tin không?** (sự kiện doanh nghiệp làm méo lợi suất)

Quy trình: `CafeF API → crawl (Python) → ETL (Pandas) → SQL Server (star schema + 10 BQ) → Power BI (3 trang)`.

---

## 2. Dataset Description

### 2.1 Tổng quan

| Thuộc tính | Giá trị |
|---|---|
| Nguồn | CafeF — crawl bằng [crawl_cafef.ipynb](./crawl_cafef.ipynb) |
| Khoảng thời gian phân tích | 09/09/2026 – 06/10/2026 (**20 phiên liên tiếp**) |
| Số mã | 396 (crawl được 398, loại 2 mã không đủ phiên) |
| Số dòng | 7,932 raw → **7,920** sau khi làm sạch (396 mã × 20 phiên) |
| Đơn vị giá trị giao dịch | tỷ VNĐ |

Schema sau ETL ([StockPrice_Clean.csv](./StockPrice_Clean.csv)): `Ticker, TradeDate, DayOfWeek, OpenPrice, HighPrice, LowPrice, ClosePrice, AdjClosePrice, MatchedVolume, MatchedValue, DealVolume, DealValue`.
---

## 2. Tech Stack

| Tầng | Công cụ |
|---|---|
| Crawl | Python (`requests`, `pandas`, `logging`) trong Jupyter |
| ETL | Python (`pandas`), Jupyter Notebook |
| Database | SQL Server  |
| BI | Power BI Desktop, DAX |

---

## 3. Project Structure

Các file hiện nằm trực tiếp trong thư mục workspace `Stock_price`:

- [crawl_cafef.ipynb](./crawl_cafef.ipynb) — crawl dữ liệu CafeF.
- [LichSuGia_Crawled.csv](./LichSuGia_Crawled.csv) — dữ liệu crawl thô, 7.932 dòng.
- [ETL_Pipeline.ipynb](./ETL_Pipeline.ipynb) — làm sạch và xuất dữ liệu.
- [StockPrice_Clean.csv](./StockPrice_Clean.csv) — dữ liệu sạch, 7.920 dòng.
- [01_star_schema.sql](./01_star_schema.sql) — dựng DimTicker, DimDate và FactStockPrice.
- [02_business_questions.sql](./02_business_questions.sql) — truy vấn câu hỏi nghiệp vụ.
- [README_StockPrice.md](./README_StockPrice.md) — tài liệu dự án.

---

## 4. Key Insights

> Phạm vi: 396 mã × 20 phiên. Chỉ số lợi suất/biến động tính trên `AdjClosePrice`.

### 4.1 Hoạt động thị trường
- Tổng giá trị khớp lệnh: **259,797 tỷ VNĐ** (10.3 tỷ cổ phiếu); trung bình **12,990 tỷ/phiên**.
- Phiên đỉnh **18/09** (21,876 tỷ, gấp 1.68× trung bình); phiên thấp nhất **05/10** (9,976 tỷ, bằng 0.77×).
- Thanh khoản 10 phiên cuối **thấp hơn 13.4%** so với 10 phiên đầu.
- Độ rộng thị trường lệch giảm: **109 mã tăng / 279 mã giảm / 8 đứng giá**; lợi suất trung vị −3.08%.

### 4.2 Mức độ tập trung thanh khoản
- **99 mã Tier 1 (25% số mã) chiếm 96.6% giá trị giao dịch**; Tier 3 + Tier 4 cộng lại chỉ 0.2%.
- Top 10 chiếm **39.6%**; riêng VIC chiếm **6.7%**.
- 208/396 mã có giá trị giao dịch trung bình dưới 1 tỷ/phiên.

| Hạng | Mã | Tổng giá trị (tỷ) | TB/phiên (tỷ) |
|---|---|---|---|
| 1 | VIC | 17,320 | 866.0 |
| 2 | VHM | 13,798 | 689.9 |
| 3 | VPB | 11,387 | 569.4 |
| 4 | TCB | 10,349 | 517.5 |
| 5 | SHB | 9,278 | 463.9 |
| 6 | SSI | 8,883 | 444.2 |
| 7 | BSR | 8,498 | 424.9 |
| 8 | VIX | 7,838 | 391.9 |
| 9 | FPT | 7,806 | 390.3 |
| 10 | HPG | 7,762 | 388.1 |

### 4.3 Mã tăng/giảm mạnh nhất (cả giai đoạn)
- **Tăng:** VDP +40.5%, PET +34.4%, PVP +32.6%, STG +26.6%, BFC +24.8%.
- **Giảm:** KOS −62.1%, PNJ −46.9%, TNH −29.3%, FIR −28.6%, VPG −26.7%.
- KOS và PNJ là biến động **thật**: mỗi mã có 3 phiên giảm sàn và lợi suất từng phiên khớp hoàn toàn cột "Thay đổi" của CafeF.

### 4.4 Rủi ro & biến động
- Độ lệch chuẩn lợi suất ngày cao nhất: HU1 5.68%, HID 5.57%, PIT 5.54%, VDP 5.22%, TNC 5.04%.
- Biên độ trong phiên trung bình cao nhất: HID 8.21%, SVD 6.93%, PLP 5.64%, SSB 5.56%, HII 5.55%.
- Độ lệch chuẩn trung bình theo nhóm thanh khoản: Tier 1 1.82%, Tier 2 1.80%, Tier 3 1.50%, **Tier 4 2.28%**.

### 4.5 Phiên bất thường
- **153 phiên** (146 mã) có |Z-score| > 2.5, chiếm 2.0% trong 7,524 quan sát lợi suất.
- **45 phiên chạm biên ±7%** (21 tăng trần, 24 giảm sàn) ở 34 mã; không có phiên nào vượt ±7.0% sau điều chỉnh.

### 4.6 Hiệu ứng của sự kiện doanh nghiệp lên lợi suất

| Mã | Lợi suất giá thô | Lợi suất giá điều chỉnh |
|---|---|---|
| TRC | −70.86% | **+16.55%** |
| PHR | −46.50% | −1.41% |
| SZL | −46.98% | −5.16% |
| HTN | −22.78% | +15.77% |
| VPB (top 3 thanh khoản) | −15.33% | +6.72% |

Dùng giá thô còn tạo **165** phiên bất thường (thay vì 153) và **12 phiên "giảm ≥10%"** hoàn toàn là nhiễu.

### 4.7 Giao dịch thỏa thuận & hiệu ứng ngày trong tuần
- Giá trị thỏa thuận bằng **23.2%** giá trị khớp lệnh, tập trung ở 166 mã; 5 mã đầu (HDB, EIB, STB, SSB, SBT) chiếm 29.3%.
- Thứ Sáu có giá trị TB cao nhất (15,679 tỷ) nhưng mỗi thứ chỉ có 4 phiên và Thứ Sáu chứa phiên đỉnh 18/09 (bỏ phiên này còn 13,613 tỷ) — chỉ là giả thuyết, cần thêm dữ liệu.

---

## 6. Business Recommendations

1. **Chuẩn hoá dùng giá điều chỉnh** cho mọi báo cáo lợi suất/rủi ro. Giá thô sẽ phát cảnh báo "sập giá" giả ở 31 mã, kể cả VPB thuộc top 3 thanh khoản.
2. **Tập trung nguồn lực theo thanh khoản:** 99 mã Tier 1 phủ 96.6% dòng tiền. Phần còn lại xếp vào danh sách "thanh khoản thấp" với hạn mức lệnh chặt hơn (208 mã trung bình dưới 1 tỷ/phiên).
3. **Theo dõi rủi ro tập trung:** top 10 chiếm 39.6% và VIC 6.7% giá trị giao dịch — nên đọc tín hiệu thanh khoản cùng với độ rộng thị trường (số mã tăng/giảm) để tránh bị nhóm vốn hoá lớn chi phối.
4. **Cảnh báo hai tầng:** ưu tiên 45 phiên chạm biên trước, sau đó mới tới các phiên Z-score còn lại, để giảm nhiễu cho người rà soát.
5. **Kiểm tra cơ bản/tin tức** cho các mã sụt giảm sâu thật như KOS (−62%) và PNJ (−47%); thêm cờ "drawdown > 40%" vào dashboard.
6. **Tách dòng tiền thỏa thuận** khỏi khớp lệnh khi đo thanh khoản, vì thỏa thuận chiếm 23.2% và tập trung ở vài mã ngân hàng.
7. **Tín hiệu thận trọng toàn thị trường** trong kỳ: thanh khoản giảm 13.4% và 279/396 mã giảm giá — nên theo dõi tiếp thêm vài tuần để xác nhận xu hướng.

---

## 7. How to Run

### Bước 1 — Crawl (tuỳ chọn)
```bash
pip install requests pandas jupyter
jupyter notebook crawl_cafef.ipynb
```
### Bước 2 — ETL
Chạy các cell trong [ETL_Pipeline.ipynb]. Notebook đọc [LichSuGia_Crawled.csv], loại mã có ít phiên hơn mức tối đa, rồi xuất [StockPrice_Clean.csv]. kết quả là 7.920 dòng / 396 mã.

### Bước 3 — SQL Server
1. Nạp `StockPrice_Clean` vào `dbo.StockPrice_Clean` 
2. Chạy [01_star_schema.sql]
3. Chạy [02_business_questions.sql]

| Kiểm tra | Kết quả mong đợi |
|---|---|
| `COUNT(*)` FactStockPrice | 7,920 |
| `COUNT(*)` DimTicker / DimDate | 396 / 20 |
| `SUM(MatchedValue)` | 259,797.25 |
| Q4 top gainer / top loser | VDP +40.48% / KOS −62.11% |
| Q9 số phiên có Z-score tuyệt đối vượt 2.5 | 153 |

### Bước 4 — Visualization
