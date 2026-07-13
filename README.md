# VN Stock Market – Price History EDA (Python / Pandas)

EDA (Exploratory Data Analysis) trên **403 mã cổ phiếu** thị trường chứng khoán Việt Nam (HOSE/HNX/UPCOM), giai đoạn **05/01/2026 – 28/01/2026** (18 phiên giao dịch), sử dụng Python (Pandas, Matplotlib) trong Jupyter Notebook.

Bản này là phiên bản độc lập song song với project T-SQL (`VN_Stock_TSQL_Analysis`), cùng bộ dữ liệu nhưng khai thác theo hướng Python: dùng Pandas thay cho window function, Matplotlib để trực quan hoá trực tiếp trong notebook.

## 1. Nguồn dữ liệu

| Thuộc tính | Giá trị |
|---|---|
| File gốc | `LichSuGia_ALL_01_01_2026_02_01_2026.csv` |
| Số dòng | 7,224 (403 mã x 18 phiên) |
| Khoảng thời gian | 05/01/2026 → 28/01/2026 |
| Đơn vị giá trị giao dịch | tỷ VNĐ |
| Encoding | UTF-8 with BOM |

## 2. Nội dung notebook

File chính: [`VN_Stock_EDA.ipynb`](./VN_Stock_EDA.ipynb) — đã được chạy sẵn (có output/biểu đồ) để xem trực tiếp trên GitHub mà không cần mở Jupyter.

| Mục | Nội dung | Kỹ thuật |
|---|---|---|
| 1 | Nạp & làm sạch dữ liệu | `pd.read_csv`, parse ngày `dd/mm/yyyy` |
| 2 | Tổng quan thanh khoản thị trường | `groupby`, biểu đồ cột theo thời gian |
| 3 | Top gainers / losers cả giai đoạn | `first()/last()`, `pct_change` giai đoạn |
| 4 | Độ biến động (volatility) theo mã | `pct_change`, `std()` |
| 5 | Phân khúc thanh khoản | `pd.qcut` (tương đương `NTILE` trong SQL) |
| 6 | Đường trung bình động SMA5 | `rolling(5).mean()` |
| 7 | Phát hiện bất thường bằng Z-score | `(x - mean) / std`, lọc `\|Z\| > 2.5` |
| 8 | Thanh khoản theo ngày trong tuần | `dt.day_name()`, `groupby` |

## 3. Kết quả nổi bật (Key Findings)

- Tổng giá trị giao dịch toàn thị trường trong 18 phiên: **~577,449 tỷ VNĐ** (~18.4 tỷ cổ phiếu khớp lệnh).
- **Top gainer cả giai đoạn**: PLX (+62.3%), MDG (+53.9%), GAS (+52.5%), PNC (+49.1%), GVR (+48.4%).
- **Top loser cả giai đoạn**: MCH (-29.0%), VHM (-21.3%), VDP (-20.7%), VTB (-19.9%), GEE (-19.4%).
- **Top 5 mã thanh khoản cao nhất**: VIX (~24,081 tỷ), VHM (~22,028 tỷ), SHB (~21,466 tỷ), HPG (~20,663 tỷ), VCB (~20,629 tỷ) — nhóm ngân hàng/bluechip vốn hoá lớn.
- **Mã biến động (volatility) cao nhất**: PMG (~6.6%/phiên), HID (~5.9%), CMV (~5.5%) — thường là nhóm thanh khoản thấp.
- **157 phiên** được gắn cờ bất thường theo Z-score (|Z| > 2.5), phần lớn trùng với các phiên kịch trần/kịch sàn (±7%) theo quy tắc biên độ dao động giá của HOSE.
- **Data quality**: mã **MCH** ngày 09/01/2026 giảm ~18.7% theo giá đóng cửa dù cột "Thay đổi" gốc chỉ ghi -0.11% → dấu hiệu giá tham chiếu được điều chỉnh do sự kiện doanh nghiệp (chia cổ tức/tách quyền), không phải giảm sàn thực tế. Nên dùng "Giá điều chỉnh" khi tính lợi nhuận để tránh nhiễu.
- Thanh khoản trung bình cao nhất vào **Thứ Năm** (~86.5 tỷ/mã/phiên), thấp nhất vào **Thứ Hai** (~74.4 tỷ/mã/phiên).

## 4. Cách chạy lại

```bash
pip install pandas matplotlib jupyter
jupyter notebook VN_Stock_EDA.ipynb
```

File CSV cần đặt cùng thư mục với notebook (hoặc chỉnh lại đường dẫn ở cell đầu tiên).

## 5. Giới hạn & hướng mở rộng

- Dữ liệu chỉ có 18 phiên (1 tháng) nên các chỉ số volatility/SMA mang tính minh hoạ kỹ thuật hơn là kết luận đầu tư dài hạn.
- Chưa có dữ liệu ngành (sector) để so sánh dòng tiền theo nhóm ngành.
- Có thể mở rộng thêm: chỉ báo kỹ thuật (RSI, MACD, Bollinger Bands), so sánh tương quan với VN-Index, hoặc dùng `statsmodels`/`scipy` cho kiểm định thống kê sâu hơn.
