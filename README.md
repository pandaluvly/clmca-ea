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

## Cài đặt
1. Copy thư mục `MQL5/Experts/CLMCA/` vào thư mục dữ liệu MT5 (`File → Open Data Folder`).
2. MetaEditor: compile `CLMCA_SelfTest.mq5`, kéo vào chart bất kỳ. Tab Experts phải ra `PASS … fail=0`.
3. Compile `CLMCA.mq5`, gắn vào chart **XAUUSD M15** (Exness: `XAUUSDm`), bật Algo Trading.

## Input quan trọng
| Input | Ý nghĩa |
|---|---|
| `InpMode` | chọn 1 trong 5 chế độ |
| `InpServerGmtWinter/Summer` | giờ server lệch UTC. Vantage `2/3`, Exness `0/0`. Sai là lệch khung giờ; EA tự chặn nếu lệch > 5 phút (chạy thật) |
| `InpRiskMode` / `InpRiskUsd` / `InpRiskPercent` | rủi ro mỗi lệnh: $ cố định hoặc % số dư |
| `InpMagic` | 0 = magic theo chế độ; nhiều chế độ chạy chung tài khoản không lẫn nhau |

Tài khoản quỹ: đọc kỹ luật daily loss / max drawdown (static hay trailing) / giờ reset ngày của quỹ trước khi chạy.
Backtest từng có drawdown vượt hạn mức của nhiều quỹ.

## File ghi nhận
EA ghi CSV vào `MQL5/Files/fsr5_<MODE>/`: `trades.csv`, `signals.csv` (mọi nến, kèm lý do không vào lệnh), `ladder_moves.csv`, `lifecycle.csv`, `incidents.csv`.

## License
MIT, xem `LICENSE`. Phần mềm được cung cấp "nguyên trạng", không bảo hành.
