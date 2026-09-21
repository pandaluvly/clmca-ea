# CLMCA ("Có Làm Mới Có Ăn") — MetaTrader 5 EA for XAUUSD M15

**English** · [Tiếng Việt](README.vi.md)

> ⚠️ **Read first.** This EA has **not passed statistical validation**. Backtests are in-sample: the past does not
> guarantee the future. Losing streaks of 40–65 trades and drawdowns lasting 2.5–4 years have happened in historical
> data. You can lose all your capital. This is not investment advice. **Run it on a demo account first.**

Website (detailed explanation, backtest results, validation journey): https://clmca.pandify.io

A free, open-source EA by [Pandify](https://pandify.io), built as open trading research: every result is published,
including the tests that failed. Thanks to the Cần Cù Bù Siêng Năng community.

## Download
- **Latest release:** https://github.com/pandaluvly/clmca-ea/releases/latest
  - `CLMCA.ex5` — pre-compiled, ready to use
  - `CLMCA.mq5` — the same EA as a single source file, if you prefer to compile it yourself
  - `CLMCA_<strategy>.set` — preset inputs for each strategy
  - `SHA256SUMS` — checksums to verify your download

## 5 strategies (`InpMode`)
| Mode | Name | Entry | Max open trades | Stop-loss ladder |
|---|---|---|---|---|
| `C_V1` | Classic Pullback | Pullback to the EMA34/EMA89 "Dragon", bullish confirmation candle, filters on ADX · H1/H4 trend · Dragon width · slope (thresholds × ATR14) | 3 | at +2R ⇒ SL to break-even, +3R ⇒ +1R, +4R ⇒ +2R… |
| `C_V1_P1b` | Near-Touch Pullback | as C_V1, pullback also accepted when "near" (≤ EMA34 high + 0.5·ATR14) | 3 | as C_V1 |
| `C_V1_P2` | 3-Bar Pullback | as C_V1, pullback on any of the 3 candles before the signal | 3 | as C_V1 |
| `D_V1` | Every Signal | as C_V1, one trade per signal | 20 | at +1R ⇒ break-even, +3R ⇒ +1R… |
| `L07S` | London Open 7AM | M15 candle at 07:00 UTC (Mon–Fri), H4 above EMA34 and EMA89, enough slope | 3 | as C_V1 |

LONG only. Every trade has a **hard stop-loss** = EMA89 − 0.956·ATR14. No take-profit, no martingale, no grid.
After 2 losing trades in one day (UTC), the EA stops opening new trades until the day ends.

**Trading hours (group 5):** **24/7** by default. You can limit entries to a `From`–`To` window (0–23, both ends
included, may wrap past midnight) in **your computer's time** or in **UTC**. On start, the EA prints the chosen window
converted to UTC so you can check it. In the Strategy Tester you must pick "UTC time". `L07S` always trades the
07:00 UTC candle and ignores this group.

## Install
**Quick (single file):** download `CLMCA.ex5` from the release page, put it in `MQL5/Experts/` inside the MT5 data
folder (`File → Open Data Folder`), restart MT5 or refresh the Navigator, then attach it to an **XAUUSD M15** chart and
enable Algo Trading. You can load a preset from the Inputs tab → **Load** → `CLMCA_<strategy>.set`.

**Full (with self-test):**
1. Copy the `MQL5/Experts/CLMCA/` folder into the MT5 data folder.
2. In MetaEditor, compile `CLMCA_SelfTest.mq5` and drag it onto any chart. The Experts tab must print `PASS … fail=0`.
3. Compile `CLMCA.mq5` and attach it to an **XAUUSD M15** chart (Exness: `XAUUSDm`), enable Algo Trading.

## Main inputs
| Input | Meaning |
|---|---|
| `InpMode` | pick 1 of the 5 strategies |
| `InpBrokerTime` | Broker: **Auto** when trading live; in the Strategy Tester pick **Vantage/IC Markets… (New York time)**, **Exness (GMT+0)** or **EU-time brokers / prop firms** |
| `InpRiskMode` / `InpRiskUsd` / `InpRiskPercent` | risk per trade: fixed $ or % of balance (capped at 2% of balance) |
| `InpMagic` | 0 = magic per strategy; several strategies can share an account without mixing trades |
| `InpHours` / `InpHourFrom` / `InpHourTo` | trading hours: 24/7 (default), or a From–To window in your computer's time / UTC |

## Prop-firm accounts
- Read your firm's rules first: daily loss, static vs trailing max drawdown, daily reset time. Backtests have had
  drawdowns beyond many firms' limits.
- **Many prop firms ban mass-distributed EAs** or identical trades across accounts. Everyone running the same CLMCA
  strategy gets nearly identical trades; you may be denied a payout or lose the account. **That risk is yours.**

## Verify your download
Compare the sha256 of your file with `SHA256SUMS` (also listed on the website):
- Windows: `certutil -hashfile CLMCA.ex5 SHA256`
- macOS / Linux: `shasum -a 256 CLMCA.ex5`

On start, the Experts tab prints `[CLMCA] build <date time>`; include this line when reporting a bug.

## Official copy
Download only from this repo or https://clmca.pandify.io and check the sha256. A modified copy is not the original;
if you change the code, rename the EA and change the magic.

## Log files
The EA writes CSV files to `MQL5/Files/fsr5_<MODE>/`: `trades.csv`, `signals.csv` (every candle, with the reason when
no trade was opened), `ladder_moves.csv`, `lifecycle.csv`, `incidents.csv`.

## Donate
CLMCA is free. If you find it useful, you can support it via the Donate section of the website (PayPal / bank QR):
https://clmca.pandify.io/en/#contact
Donating unlocks nothing: there is no paid version and no private signals.

## Support
Best-effort, no response time guaranteed. Report bugs via GitHub Issues, with the sha256 of the file you run and the
Experts-tab log.

## License
MIT — see `LICENSE`. The software is provided "as is", without warranty.

## For contributors
Edit files in `MQL5/Experts/CLMCA/`; **do not edit** `release/CLMCA.mq5` by hand. After editing, run
`python3 tools/bundle.py` to regenerate the single-file build. Before a release, backtest the single-file build and the
multi-file build on the same date range: `trades.csv` must match trade by trade.
