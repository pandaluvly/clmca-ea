# Có Làm Mới Có Ăn (CLMCA): EA MetaTrader 5 cho XAUUSD M15

> ⚠️ **Đọc trước khi dùng.** EA này **chưa qua kiểm định thống kê**. Kết quả backtest là in-sample: quá khứ không đảm bảo
> tương lai. Chuỗi thua 40–65 lệnh liên tiếp và drawdown kéo dài 2,5–4 năm đã từng xảy ra trong dữ liệu lịch sử.
> Có thể mất toàn bộ vốn. Đây không phải lời khuyên đầu tư. **Hãy chạy trên tài khoản demo trước.**
>
> ⚠️ **Read first.** This EA has **not passed statistical validation**. Backtests are in-sample. Losing streaks of 40–65
> trades and 2.5–4-year drawdowns occurred historically. You can lose all your capital. Not investment advice. **Demo first.**

Web (giải thích chi tiết, kết quả backtest, hành trình kiểm định): https://clmca.pandify.io

## 5 chế độ (`InpMode`)
| Mode | Điểm vào | Lệnh mở tối đa | Thang dời SL |
|---|---|---|---|
| `C_V1` | Pullback về Dragon EMA34/EMA89, nến xanh xác nhận, lọc ADX · H1/H4 · độ rộng Dragon · slope (ngưỡng × ATR14) | 3 | lời 2R ⇒ SL về hoà vốn, 3R ⇒ +1R, 4R ⇒ +2R… |
| `C_V1_P1b` | như C_V1, pullback nới thêm "gần chạm" (≤ EMA34 high + 0,5·ATR14) | 3 | như C_V1 |
| `C_V1_P2` | như C_V1, pullback ở bất kỳ nến nào trong 3 nến trước tín hiệu | 3 | như C_V1 |
| `D_V1` | như C_V1, mỗi tín hiệu một lệnh | 20 | lời 1R ⇒ hoà vốn, 3R ⇒ +1R… |
| `L07S` | nến M15 lúc 07:00 UTC (T2–T6), H4 trên EMA34 và EMA89, slope đủ | 3 | như C_V1 |

Chỉ LONG. Mọi lệnh mở đều kèm **Stop-Loss cứng** = EMA89 − 0,956·ATR14. Không TP, không martingale, không grid.
Sau 2 lệnh thua trong một ngày (UTC), EA ngừng vào lệnh mới tới hết ngày.

**Giờ vào lệnh (mục 5):** mặc định **24/24**. Có thể giới hạn khung giờ `Từ`–`Đến` (0–23, tính cả hai đầu, cho vắt qua
nửa đêm) **theo giờ máy tính** hoặc **theo giờ UTC**. Lúc khởi động EA in khung đã chọn ra giờ UTC để tự kiểm. Trong
Strategy Tester phải chọn "Theo giờ UTC". `L07S` luôn vào nến 07:00 UTC nên bỏ qua mục này.

## Cài đặt
**Cách nhanh (một file · single file):** tải `release/CLMCA.mq5`, bỏ vào `MQL5/Experts/` trong thư mục dữ liệu MT5
(`File → Open Data Folder`), compile trong MetaEditor, rồi gắn vào chart **XAUUSD M15** và bật Algo Trading.
File này là `CLMCA.mq5` đã gộp sẵn `CLMCACore.mqh`, logic y hệt bản nhiều file.

**Cách đầy đủ (có self-test):**
1. Copy thư mục `MQL5/Experts/CLMCA/` vào thư mục dữ liệu MT5 (`File → Open Data Folder`).
2. MetaEditor: compile `CLMCA_SelfTest.mq5`, kéo vào chart bất kỳ. Tab Experts phải ra `PASS … fail=0`.
3. Compile `CLMCA.mq5`, gắn vào chart **XAUUSD M15** (Exness: `XAUUSDm`), bật Algo Trading.

## Input quan trọng
| Input | Ý nghĩa |
|---|---|
| `InpMode` | chọn 1 trong 5 chế độ |
| `InpBrokerTime` | Sàn: **Tự động** khi chạy thật; trong Strategy Tester chọn **Vantage/IC Markets… (giờ New York)** hoặc **Exness (GMT+0)** |
| `InpRiskMode` / `InpRiskUsd` / `InpRiskPercent` | rủi ro mỗi lệnh: $ cố định hoặc % số dư |
| `InpMagic` | 0 = magic theo chế độ; nhiều chế độ chạy chung tài khoản không lẫn nhau |
| `InpHours` / `InpHourFrom` / `InpHourTo` | giờ vào lệnh: 24/24 (mặc định), hoặc khung Từ–Đến theo giờ máy tính / giờ UTC |

## Tài khoản quỹ (prop firm) · Prop-firm accounts
- Đọc kỹ luật daily loss, max drawdown (static hay trailing) và giờ reset ngày của quỹ trước khi chạy. Backtest từng có
  drawdown vượt hạn mức của nhiều quỹ.
- **Nhiều quỹ cấm EA dùng đại trà** hoặc cấm nhiều tài khoản có lệnh giống hệt nhau. Mọi người chạy CLMCA cùng chiến
  lược sẽ có lệnh gần như trùng nhau. Bạn có thể bị từ chối payout hoặc bị khoá tài khoản — **bạn tự chịu rủi ro này**.
- Read your firm's rules (daily loss, static vs trailing drawdown, daily reset time) first. **Many prop firms ban
  mass-distributed EAs** or identical trades across accounts. Everyone running the same CLMCA strategy gets nearly
  identical trades; you may be denied a payout or lose the account. **That risk is yours.**

## Ủng hộ · Donate
CLMCA miễn phí. Nếu thấy hữu ích, bạn có thể ủng hộ qua mục Donate trên web (QR ngân hàng / PayPal):
https://clmca.pandify.io/vi/#contact · If you find it useful: https://clmca.pandify.io/en/#contact
Ủng hộ không đổi gì về EA: không có bản "trả phí", không có tín hiệu riêng · Donating unlocks nothing: no paid tier, no private signals.

## Hỗ trợ · Support
Hỗ trợ khi có thể, không cam kết thời gian trả lời. Báo lỗi qua GitHub Issues, kèm sha256 của file bạn đang chạy và
đoạn log tab Experts.
Support on a best-effort basis, no response time guaranteed. Report bugs via GitHub Issues with the sha256 of the file
you run and the Experts-tab log.

## Bản gốc · Official copy
Chỉ tải từ repo này hoặc https://clmca.pandify.io và so sha256 với trang web. Bản đã sửa không phải bản gốc; nếu bạn
sửa code, hãy đổi tên EA và magic.
Download only from this repo or https://clmca.pandify.io and check the sha256. A modified copy is not the original; if
you change the code, rename the EA and change the magic.

## File ghi nhận
EA ghi CSV vào `MQL5/Files/fsr5_<MODE>/`: `trades.csv`, `signals.csv` (mọi nến, kèm lý do không vào lệnh), `ladder_moves.csv`, `lifecycle.csv`, `incidents.csv`.

## License
MIT, xem `LICENSE`. Phần mềm được cung cấp "nguyên trạng", không bảo hành · provided "as is", without warranty.

## Dành cho người sửa mã · For contributors
Sửa trong `MQL5/Experts/CLMCA/`, **không sửa tay** `release/CLMCA.mq5`. Sau khi sửa, chạy `python3 tools/bundle.py` để
sinh lại file một file. Trước khi phát hành: backtest bản gộp và bản nhiều file trên cùng dải ngày, `trades.csv` phải trùng từng lệnh.
