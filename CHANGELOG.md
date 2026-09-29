# Changelog · Nhật ký phiên bản

## v1.0.2 — 2026-09-29

**Fix — cent & non-USD accounts.** Lot size is now computed from the broker's real money value per lot
(tick value) whenever 1 oz does not equal 1 unit of account currency per $1 of price — e.g. **cent accounts
(XAUUSDc)** or accounts in EUR/other currencies. Before this fix, on a cent account the EA could open a lot
many times larger than the risk you set. **Regular USD accounts: no change** — regression backtests match
the previous version trade-for-trade.
On a cent account, prefer *Risk by = %*; if you use *$*, the amount is in cents (your account currency).

**Sửa lỗi — tài khoản cent và tài khoản không dùng USD.** Khối lượng lệnh nay tính theo giá trị tiền thật mỗi lot
do sàn báo (tick value) khi 1 oz không bằng 1 đơn vị tiền tài khoản mỗi $1 giá — ví dụ **tài khoản cent (XAUUSDc)**
hoặc tài khoản EUR/tiền khác. Bản cũ trên tài khoản cent có thể vào lot lớn gấp nhiều lần mức rủi ro đã đặt.
**Tài khoản USD thường: không đổi gì** — backtest hồi quy trùng từng lệnh với bản trước.
Trên tài khoản cent nên chọn *Rủi ro theo = %*; nếu chọn *$* thì con số tính bằng cent (đơn vị tiền tài khoản).

## v1.0.1 — 2026-09-21

Common tab shows bulleted text, easier to read. · Tab Common trong MT5 có gạch đầu dòng cho dễ đọc.

## v1.0.0 — 2026-09-21

First release: 5 strategies for XAUUSD M15, every trade has a hard stop-loss; no take-profit, no martingale, no grid.
· Phát hành đầu tiên: 5 chiến lược XAUUSD M15, mọi lệnh có stop-loss cứng; không TP, không martingale, không lưới.
