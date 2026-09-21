# CLMCA ("Có Làm Mới Có Ăn") — EA MetaTrader 5 cho XAUUSD M15

[English](README.md) · **Tiếng Việt**

> ⚠️ **Đọc trước khi dùng.** EA này **chưa qua kiểm định thống kê**. Kết quả backtest là in-sample: quá khứ không đảm
> bảo tương lai. Chuỗi thua 40–65 lệnh liên tiếp và drawdown kéo dài 2,5–4 năm đã từng xảy ra trong dữ liệu lịch sử.
> Có thể mất toàn bộ vốn. Đây không phải lời khuyên đầu tư. **Hãy chạy trên tài khoản demo trước.**

Web (giải thích chi tiết, kết quả backtest, hành trình kiểm định): https://clmca.pandify.io

EA miễn phí, mã nguồn mở của [Pandify](https://pandify.io), làm theo tinh thần nghiên cứu mở: mọi kết quả đều công
khai, kể cả các phép kiểm bị trượt. Cảm ơn cộng đồng Cần Cù Bù Siêng Năng.

## Tải về
- **Bản mới nhất:** https://github.com/pandaluvly/clmca-ea/releases/latest
  - `CLMCA.ex5` — đã compile sẵn, dùng ngay
  - `CLMCA.mq5` — cùng EA đó dạng một file mã nguồn, nếu bạn muốn tự compile
  - `CLMCA_<chiến lược>.set` — cài đặt sẵn cho từng chiến lược
  - `SHA256SUMS` — mã kiểm tra để so file tải về

## 5 chiến lược (`InpMode`)
| Mode | Tên | Điểm vào | Lệnh mở tối đa | Thang dời SL |
|---|---|---|---|---|
| `C_V1` | Nhịp Hồi Chuẩn | Pullback về Dragon EMA34/EMA89, nến xanh xác nhận, lọc ADX · H1/H4 · độ rộng Dragon · slope (ngưỡng × ATR14) | 3 | lời 2R ⇒ SL về hoà vốn, 3R ⇒ +1R, 4R ⇒ +2R… |
| `C_V1_P1b` | Hồi Gần Chạm | như C_V1, pullback nới thêm "gần chạm" (≤ EMA34 high + 0,5·ATR14) | 3 | như C_V1 |
| `C_V1_P2` | Hồi Trong 3 Nến | như C_V1, pullback ở bất kỳ nến nào trong 3 nến trước tín hiệu | 3 | như C_V1 |
| `D_V1` | Bắt Mọi Tín Hiệu | như C_V1, mỗi tín hiệu một lệnh | 20 | lời 1R ⇒ hoà vốn, 3R ⇒ +1R… |
| `L07S` | Mở Cửa London 7h | nến M15 lúc 07:00 UTC (T2–T6), H4 trên EMA34 và EMA89, slope đủ | 3 | như C_V1 |

Chỉ LONG. Mọi lệnh mở đều kèm **Stop-Loss cứng** = EMA89 − 0,956·ATR14. Không TP, không martingale, không grid.
Sau 2 lệnh thua trong một ngày (UTC), EA ngừng vào lệnh mới tới hết ngày.

**Giờ vào lệnh (mục 5):** mặc định **24/24**. Có thể giới hạn khung giờ `Từ`–`Đến` (0–23, tính cả hai đầu, cho vắt qua
nửa đêm) **theo giờ máy tính** hoặc **theo giờ UTC**. Lúc khởi động EA in khung đã chọn ra giờ UTC để tự kiểm. Trong
Strategy Tester phải chọn "Theo giờ UTC". `L07S` luôn vào nến 07:00 UTC nên bỏ qua mục này.

## Cài đặt
**Cách nhanh (một file):** tải `CLMCA.ex5` ở trang phát hành, bỏ vào `MQL5/Experts/` trong thư mục dữ liệu MT5
(`File → Open Data Folder`), khởi động lại MT5 hoặc làm mới Navigator, rồi gắn vào chart **XAUUSD M15** và bật Algo
Trading. Có thể nạp cài đặt sẵn: tab Inputs → **Load** → `CLMCA_<chiến lược>.set`.

**Cách đầy đủ (có self-test):**
1. Copy thư mục `MQL5/Experts/CLMCA/` vào thư mục dữ liệu MT5.
2. MetaEditor: compile `CLMCA_SelfTest.mq5`, kéo vào chart bất kỳ. Tab Experts phải ra `PASS … fail=0`.
3. Compile `CLMCA.mq5`, gắn vào chart **XAUUSD M15** (Exness: `XAUUSDm`), bật Algo Trading.

## Input (đúng như hộp Inputs của MT5)
| Nhóm | Input (nhãn trong MT5) | Biến | Mặc định | Ý nghĩa |
|---|---|---|---|---|
| 1. Chiến lược | Chiến lược · Strategy | `InpMode` | Nhịp Hồi Chuẩn (C_V1) | chọn 1 trong 5 chiến lược |
| 2. Rủi ro | Rủi ro theo · Risk by | `InpRiskMode` | Số tiền $ | rủi ro mỗi lệnh theo $ cố định hay % số dư |
| | Lỗ tối đa $ · Max loss $ | `InpRiskUsd` | 50 | số $ mất nếu chạm cắt lỗ (chế độ $); tối đa 2% số dư |
| | Lỗ tối đa % · Max loss % | `InpRiskPercent` | 0,1 | % số dư mất nếu chạm cắt lỗ (chế độ %), 0,01–2 |
| 3. Sàn | Sàn · Broker | `InpBrokerTime` | Tự động | **Tự động** khi chạy thật; trong Strategy Tester chọn đúng sàn: Vantage/IC Markets… (giờ NY), Exness (GMT+0) hoặc Quỹ/sàn giờ châu Âu |
| 4. Nâng cao | Trượt giá (point) · Slippage (pt) | `InpDeviationPoints` | 50 | trượt giá tối đa khi gửi lệnh; không cần đổi |
| | Magic (0 = tự động · auto) | `InpMagic` | 0 | 0 = mỗi chiến lược một magic; chỉ đổi khi chạy 2 bản cùng chiến lược trên một tài khoản |
| 5. Giờ vào lệnh | Giờ vào lệnh · Hours | `InpHours` | 24/24 | 24/24, theo giờ máy tính, hoặc theo giờ UTC (L07S không dùng) |
| | Từ giờ · From hour | `InpHourFrom` | 7 | giờ đầu được vào lệnh (0–23, tính cả) |
| | Đến giờ · To hour | `InpHourTo` | 19 | giờ cuối được vào lệnh (0–23, tính cả; cho vắt qua nửa đêm) |

## Tài khoản quỹ (prop firm)
- Đọc kỹ luật daily loss, max drawdown (static hay trailing) và giờ reset ngày của quỹ trước khi chạy. Backtest từng có
  drawdown vượt hạn mức của nhiều quỹ.
- **Nhiều quỹ cấm EA dùng đại trà** hoặc cấm nhiều tài khoản có lệnh giống hệt nhau. Mọi người chạy CLMCA cùng chiến
  lược sẽ có lệnh gần như trùng nhau. Bạn có thể bị từ chối payout hoặc bị khoá tài khoản — **bạn tự chịu rủi ro này**.

## Kiểm file tải về
So sha256 của file bạn tải với `SHA256SUMS` (cũng có trên web):
- Windows: `certutil -hashfile CLMCA.ex5 SHA256`
- macOS / Linux: `shasum -a 256 CLMCA.ex5`

Lúc khởi động, tab Experts in `[CLMCA] build <ngày giờ>` — gửi kèm dòng này khi báo lỗi.

## Bản gốc
Chỉ tải từ repo này hoặc https://clmca.pandify.io và so sha256 với trang web. Bản đã sửa không phải bản gốc; nếu bạn
sửa code, hãy đổi tên EA và magic.

## File ghi nhận
EA ghi CSV vào `MQL5/Files/fsr5_<MODE>/`: `trades.csv`, `signals.csv` (mọi nến, kèm lý do không vào lệnh),
`ladder_moves.csv`, `lifecycle.csv`, `incidents.csv`.

## Ủng hộ
CLMCA miễn phí. Nếu thấy hữu ích, bạn có thể ủng hộ qua mục Donate trên web (QR ngân hàng / PayPal):
https://clmca.pandify.io/vi/#contact
Ủng hộ không đổi gì về EA: không có bản trả phí, không có tín hiệu riêng.

## Hỗ trợ
Hỗ trợ khi có thể, không cam kết thời gian trả lời. Báo lỗi qua GitHub Issues, kèm sha256 của file bạn đang chạy và
đoạn log tab Experts.

## Giấy phép
MIT — xem `LICENSE`. Phần mềm được cung cấp "nguyên trạng", không bảo hành.

## Dành cho người sửa mã
Sửa trong `MQL5/Experts/CLMCA/`, **không sửa tay** `release/CLMCA.mq5`. Sau khi sửa, chạy `python3 tools/bundle.py` để
sinh lại file một file. Trước khi phát hành: backtest bản gộp và bản nhiều file trên cùng dải ngày, `trades.csv` phải
trùng từng lệnh.
