// BẢN PHÁT HÀNH MỘT FILE · SINGLE-FILE RELEASE — sinh bởi tools/bundle.py từ CLMCA.mq5 (sha256 fd66a604d37c).
// Sửa mã ở MQL5/Experts/CLMCA/, rồi chạy lại tools/bundle.py.
//+------------------------------------------------------------------------------------+
//| CLMCA — "Có Làm Mới Có Ăn" · Pandify · XAUUSD M15 · 5 chiến lược · 5 strategies     |
//| Bản gốc · Official source: https://clmca.pandify.io · github.com/pandaluvly/clmca-ea |
//| Cảm ơn cộng đồng Cần Cù Bù Siêng Năng · Thanks to the Cần Cù Bù Siêng Năng community. |
//| MIT License — xem LICENSE · see LICENSE.                                            |
//|                                                                                    |
//| ⚠️ CHƯA ĐỦ CĂN CỨ ĐỂ CHẠY TIỀN THẬT. Không bảo hành. Hãy chạy demo trước.            |
//|    NOT PROVEN FOR REAL MONEY. No warranty. Run it on a demo account first.         |
//| Mọi lệnh có cắt lỗ cứng. Không TP, không martingale, không grid.                     |
//| Every trade has a hard stop-loss. No take-profit, no martingale, no grid.          |
//|                                                                                    |
//| Nếu bạn nhận file này từ người khác hoặc nó đã bị sửa: đó KHÔNG phải bản gốc.         |
//| Chỉ tải từ hai địa chỉ ở trên, và so sha256 với trang web.                           |
//| If you got this file elsewhere or it was modified, it is NOT the original.         |
//| Download only from the two addresses above and check its sha256 on the website.    |
//| Đã sửa code thì đổi tên EA và magic, đừng dùng tên CLMCA.                            |
//| If you modify the code, rename the EA and change the magic; do not call it CLMCA.  |
//+------------------------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property copyright   "Có Làm Mới Có Ăn · Pandify"
#property link        "https://clmca.pandify.io"
#property description "Mã nguồn · Source: github.com/pandaluvly/clmca-ea"
#property description "EA miễn phí cho XAUUSD khung M15 · Free EA for XAUUSD M15."
#property description "5 chiến lược, lệnh nào cũng có cắt lỗ · 5 strategies, every trade has a stop-loss."
#property description "Chưa đủ căn cứ để chạy tiền thật. Hãy chạy demo trước · Not proven for real money. Demo first."
#property description "Chỉ dùng số tiền bạn chấp nhận mất · Only risk money you can afford to lose."
#property description "Cảm ơn cộng đồng Cần Cù Bù Siêng Năng · Thanks to the Cần Cù Bù Siêng Năng community."

#include <Trade\Trade.mqh>
// ===== BEGIN CLMCACore.mqh (sha256 2c8fd999f3e3) — sinh tự động, đừng sửa tay =====
//+------------------------------------------------------------------------------------+
//| CLMCACore.mqh — hàm thuần (chỉ báo, tín hiệu, thang SL) cho CLMCA · Pandify           |
//| Không I/O, không đặt lệnh. MIT License. Bản gốc: github.com/pandaluvly/clmca-ea      |
//| Pure functions (indicators, signals, SL ladder). No I/O, no orders. MIT License.   |
//| Bản đã sửa không phải bản gốc · A modified copy is not the original.               |
//+------------------------------------------------------------------------------------+
#ifndef FORWARD_STEP_R_CORE_MQH
#define FORWARD_STEP_R_CORE_MQH

#define FSR_VARIANT_C 1
#define FSR_VARIANT_D 2

#define FSR_EMA_DRAGON      34
#define FSR_EMA_TREND       89
#define FSR_ADX_PERIOD      14
#define FSR_HTF_READY_BARS  89
#define FSR_SLOPE_LAG       3
#define FSR_MIN_ADX         22.0
#define FSR_MIN_DRAGON      1.2
#define FSR_MIN_SLOPE       0.25
#define FSR_STOP_BUFFER     1.5
#define FSR_HOUR_FIRST      7
#define FSR_HOUR_LAST       19
#define FSR_MAX_LOSSES_DAY  2
#define FSR_MAX_OPEN_C      3
#define FSR_MAX_OPEN_D      20
// floor(mfe + 1e-9): đúng như ladder_level bên research (tránh 1.9999999 do sai số float).
#define FSR_FLOOR_EPS       1e-9
#define FSR_DI_EPS          1e-9
// Trần oz hợp lý (R quá nhỏ ⇒ oz khổng lồ). 50$/0.01$ = 5000 oz = 50 lot.
#define FSR_MAX_OZ          5000

// Lý do bỏ tín hiệu — bitmask, 0 = vào lệnh.
#define FSR_R_HOUR          1
#define FSR_R_ADX           2
#define FSR_R_DRAGON        4
#define FSR_R_HTF           8
#define FSR_R_PULLBACK      16
#define FSR_R_CONFIRM       32
#define FSR_R_SLOPE         64
#define FSR_R_NOT_READY     128
#define FSR_R_LOSS_CAP      256
#define FSR_R_MAX_OPEN      512
#define FSR_R_ATR_INVALID   1024   // v1: ATR14 tại c1 ≤ 0 / NaN ⇒ bỏ (không chia, không đoán)

// v1: ngưỡng $ gốc ÷ ATR14 M15 trung vị exness 2016–2023 (1,5694002200688544).
// CHỐT — không dò, không đổi trong EA.
#define FSR_ATR_PERIOD      14
#define FSR_K_WIDTH         0.7646233157450126
#define FSR_K_SLOPE         0.1592965241135443
#define FSR_K_BUF           0.9557791446812658

// 4 chế độ: C/D × v0 ($ tuyệt đối) / v1 (× ATR14).
#define FSR_MODE_C_V0 1
#define FSR_MODE_D_V0 2
#define FSR_MODE_C_V1 3
#define FSR_MODE_D_V1 4

//--- EMA đệ quy alpha = 2/(n+1), khởi tạo bằng giá trị đầu (ewm adjust=False).
void Fsr_Ema(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   if(n <= 0 || period <= 0)
      return;
   double alpha = 2.0 / (period + 1.0);
   out[0] = src[0];
   for(int i = 1; i < n; i++)
      out[i] = alpha * src[i] + (1.0 - alpha) * out[i - 1];
  }

//--- ADX kiểu EMA (§2), KHÁC ADX Wilder của MT5 — KHÔNG dùng iADX.
//    Nến đầu: TR = high−low, ±DM = 0 (prev null). n < period+2 ⇒ toàn 0 (như research).
void Fsr_AdxEma(const double &h[], const double &l[], const double &c[], const int n,
                const int period, double &out[])
  {
   ArrayResize(out, n);
   if(n <= 0)
      return;
   if(n < period + 2)
     {
      for(int k = 0; k < n; k++)
         out[k] = 0.0;
      return;
     }
   double tr[], pdm[], mdm[];
   ArrayResize(tr, n);
   ArrayResize(pdm, n);
   ArrayResize(mdm, n);
   tr[0] = h[0] - l[0];
   pdm[0] = 0.0;
   mdm[0] = 0.0;
   for(int i = 1; i < n; i++)
     {
      double up = h[i] - h[i - 1];
      double dn = l[i - 1] - l[i];
      pdm[i] = (up > dn && up > 0.0) ? up : 0.0;
      mdm[i] = (dn > up && dn > 0.0) ? dn : 0.0;
      double a = h[i] - l[i];
      double b = MathAbs(h[i] - c[i - 1]);
      double d = MathAbs(l[i] - c[i - 1]);
      tr[i] = MathMax(a, MathMax(b, d));
     }
   double str[], spdm[], smdm[], dx[];
   Fsr_Ema(tr, n, period, str);
   Fsr_Ema(pdm, n, period, spdm);
   Fsr_Ema(mdm, n, period, smdm);
   ArrayResize(dx, n);
   for(int i = 0; i < n; i++)
     {
      double pdi = 100.0 * spdm[i] / (str[i] + FSR_DI_EPS);
      double mdi = 100.0 * smdm[i] / (str[i] + FSR_DI_EPS);
      dx[i] = 100.0 * MathAbs(pdi - mdi) / (pdi + mdi + FSR_DI_EPS);
     }
   Fsr_Ema(dx, n, period, out);
  }

//--- US DST (NY-close broker: server = UTC+3 hè / UTC+2 đông). utc_time tính bằng giây epoch.
//    Hè: từ Chủ nhật thứ 2 tháng 3 07:00 UTC tới Chủ nhật thứ 1 tháng 11 06:00 UTC.
//    Trả số ngày trong tuần 0=CN của ngày (y,m,d) — thuật toán Sakamoto.
int Fsr_DayOfWeek(int y, const int m, const int d)
  {
   int t[12] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
   if(m < 3)
      y -= 1;
   return (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7;
  }

// Số giây epoch của 00:00 UTC ngày (y,m,d) — thuật toán days_from_civil.
long Fsr_DaysFromCivil(int y, const int m, const int d)
  {
   y -= (m <= 2) ? 1 : 0;
   long era = (y >= 0 ? y : y - 399) / 400;
   long yoe = y - era * 400;
   long mp = (m + 9) % 12;
   long doy = (153 * mp + 2) / 5 + d - 1;
   long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
   return era * 146097 + doe - 719468;
  }

int Fsr_NthSunday(const int y, const int m, const int nth)
  {
   int first = Fsr_DayOfWeek(y, m, 1);
   int first_sun = 1 + (7 - first) % 7;
   return first_sun + 7 * (nth - 1);
  }

bool Fsr_IsUsDst(const long utc_time, const int year)
  {
   long start = Fsr_DaysFromCivil(year, 3, Fsr_NthSunday(year, 3, 2)) * 86400 + 7 * 3600;
   long stop = Fsr_DaysFromCivil(year, 11, Fsr_NthSunday(year, 11, 1)) * 86400 + 6 * 3600;
   return utc_time >= start && utc_time < stop;
  }

// Năm UTC của một epoch (đủ dùng cho DST): civil_from_days.
int Fsr_YearOf(const long t)
  {
   long z = (t >= 0 ? t / 86400 : (t - 86399) / 86400) + 719468;
   long era = (z >= 0 ? z : z - 146096) / 146097;
   long doe = z - era * 146097;
   long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
   long y = yoe + era * 400;
   long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
   long mp = (5 * doy + 2) / 153;
   long m = mp < 10 ? mp + 3 : mp - 9;
   return (int)(y + (m <= 2 ? 1 : 0));
  }

// Giờ hè châu Âu: từ Chủ nhật cuối tháng 3 01:00 UTC tới Chủ nhật cuối tháng 10 01:00 UTC.
int Fsr_LastSunday(const int y, const int m)
  {
   int dim[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
   int last = dim[m - 1] + ((m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) ? 1 : 0);
   return last - Fsr_DayOfWeek(y, m, last);
  }

bool Fsr_IsEuDst(const long utc_time, const int year)
  {
   long start = Fsr_DaysFromCivil(year, 3, Fsr_LastSunday(year, 3)) * 86400 + 3600;
   long stop = Fsr_DaysFromCivil(year, 10, Fsr_LastSunday(year, 10)) * 86400 + 3600;
   return utc_time >= start && utc_time < stop;
  }

// Server time → UTC cho sàn đổi giờ theo châu Âu (GMT+2 đông / GMT+3 hè).
long Fsr_ServerToUtcEu(const long server_time, const int winter_h, const int summer_h)
  {
   long guess = server_time - (long)summer_h * 3600;
   bool dst = Fsr_IsEuDst(guess, Fsr_YearOf(guess));
   return server_time - (long)(dst ? summer_h : winter_h) * 3600;
  }

// Server time → UTC cho broker NY-close. winter_h/summer_h = độ lệch giờ (vd 2/3).
// Lấy DST theo mốc UTC ước lượng bằng offset hè (sai lệch chỉ trong cửa sổ cuối tuần đổi giờ).
long Fsr_ServerToUtc(const long server_time, const int winter_h, const int summer_h)
  {
   long guess = server_time - (long)summer_h * 3600;
   bool dst = Fsr_IsUsDst(guess, Fsr_YearOf(guess));
   return server_time - (long)(dst ? summer_h : winter_h) * 3600;
  }

int Fsr_HourOf(const long utc_time)
  {
   long s = utc_time % 86400;
   if(s < 0)
      s += 86400;
   return (int)(s / 3600);
  }

long Fsr_DayOf(const long utc_time)
  {
   return utc_time >= 0 ? utc_time / 86400 : (utc_time - 86399) / 86400;
  }

//--- Gộp nến M15 (UTC, tăng dần) thành khung lớn theo biên UTC tuyệt đối (bucket_sec = 3600 / 14400).
//    Trả số nến. open = open nến M15 đầu bucket, close = close nến cuối, high/low = max/min.
int Fsr_Aggregate(const long &t[], const double &o[], const double &h[], const double &l[],
                  const double &c[], const int n, const long bucket_sec,
                  long &bt[], double &bo[], double &bh[], double &bl[], double &bc[])
  {
   ArrayResize(bt, 0);
   ArrayResize(bo, 0);
   ArrayResize(bh, 0);
   ArrayResize(bl, 0);
   ArrayResize(bc, 0);
   int m = 0;
   long cur = 0;
   for(int i = 0; i < n; i++)
     {
      long b = (t[i] >= 0 ? t[i] / bucket_sec : (t[i] - bucket_sec + 1) / bucket_sec) * bucket_sec;
      if(m == 0 || b != cur)
        {
         m++;
         ArrayResize(bt, m);
         ArrayResize(bo, m);
         ArrayResize(bh, m);
         ArrayResize(bl, m);
         ArrayResize(bc, m);
         cur = b;
         bt[m - 1] = b;
         bo[m - 1] = o[i];
         bh[m - 1] = h[i];
         bl[m - 1] = l[i];
         bc[m - 1] = c[i];
        }
      else
        {
         bh[m - 1] = MathMax(bh[m - 1], h[i]);
         bl[m - 1] = MathMin(bl[m - 1], l[i]);
         bc[m - 1] = c[i];
        }
     }
   return m;
  }

//--- As-of: chỉ số nến khung lớn ĐÃ ĐÓNG gần nhất tại decision_time (= giờ đóng nến M15).
//    Đóng ⇔ open + dur <= decision_time. −1 nếu chưa có. Bucket cuối có thể chưa đủ nến M15
//    nhưng đã qua giờ đóng thì vẫn là "đã đóng" (như join_asof theo close_time của research).
int Fsr_AsOfIndex(const long &bt[], const int m, const long dur, const long decision_time)
  {
   int idx = -1;
   for(int i = 0; i < m; i++)
     {
      if(bt[i] + dur <= decision_time)
         idx = i;
      else
         break;
     }
   return idx;
  }

//--- ATR14 Wilder: TR[0] = high−low; TR[t] = max(h−l, |h−c[t−1]|, |l−c[t−1]|);
//    ATR[0] = TR[0]; ATR[t] = ATR[t−1] + (TR[t] − ATR[t−1]) / period. KHÁC iADX/iATR của MT5 (khởi tạo SMA).
void Fsr_AtrWilder(const double &h[], const double &l[], const double &c[], const int n, const int period,
                   double &out[])
  {
   ArrayResize(out, n);
   if(n <= 0 || period <= 0)
      return;
   out[0] = h[0] - l[0];
   for(int i = 1; i < n; i++)
     {
      double tr = MathMax(h[i] - l[i], MathMax(MathAbs(h[i] - c[i - 1]), MathAbs(l[i] - c[i - 1])));
      out[i] = out[i - 1] + (tr - out[i - 1]) / period;
     }
  }

int Fsr_ModeVariant(const int mode)
  {
   return (mode == FSR_MODE_C_V0 || mode == FSR_MODE_C_V1) ? FSR_VARIANT_C : FSR_VARIANT_D;
  }

bool Fsr_ModeIsV1(const int mode)
  {
   return mode == FSR_MODE_C_V1 || mode == FSR_MODE_D_V1;
  }

bool Fsr_ModeValid(const int mode)
  {
   return mode >= FSR_MODE_C_V0 && mode <= FSR_MODE_D_V1;
  }

string Fsr_ModeName(const int mode)
  {
   if(mode == FSR_MODE_C_V0) return "C_V0";
   if(mode == FSR_MODE_D_V0) return "D_V0";
   if(mode == FSR_MODE_C_V1) return "C_V1";
   if(mode == FSR_MODE_D_V1) return "D_V1";
   return "INVALID";
  }

string Fsr_ModeVersion(const int mode)
  {
   if(mode == FSR_MODE_C_V0) return "cand_c_step_r_v0";
   if(mode == FSR_MODE_D_V0) return "cand_d_step_r_v0";
   if(mode == FSR_MODE_C_V1) return "cand_c_step_r_v1";
   if(mode == FSR_MODE_D_V1) return "cand_d_step_r_v1";
   return "invalid";
  }

//--- Ba ngưỡng theo mode. v0 = $ gốc (đúng hằng cũ). v1 = K × ATR14(c1); ATR ≤ 0/NaN ⇒ false (bỏ tín hiệu).
bool Fsr_ModeThresholds(const int mode, const double atr_c1, double &min_dragon, double &min_slope, double &stop_buf)
  {
   if(!Fsr_ModeIsV1(mode))
     {
      min_dragon = FSR_MIN_DRAGON;
      min_slope = FSR_MIN_SLOPE;
      stop_buf = FSR_STOP_BUFFER;
      return Fsr_ModeValid(mode);
     }
   if(!MathIsValidNumber(atr_c1) || !(atr_c1 > 0.0))
     {
      min_dragon = 0.0;
      min_slope = 0.0;
      stop_buf = 0.0;
      return false;
     }
   min_dragon = FSR_K_WIDTH * atr_c1;
   min_slope = FSR_K_SLOPE * atr_c1;
   stop_buf = FSR_K_BUF * atr_c1;
   return true;
  }

//--- Khung giờ UTC [first..last] tính cả hai đầu; first > last = vắt qua nửa đêm (vd 22..5).
//    Ngoài 0..23 ⇒ false (fail-closed). Mặc định: 7..19.
bool Fsr_HourInWindow(const int hour, const int first, const int last)
  {
   if(hour < 0 || hour > 23 || first < 0 || first > 23 || last < 0 || last > 23)
      return false;
   if(first <= last)
      return hour >= first && hour <= last;
   return hour >= first || hour <= last;
  }

//--- Tín hiệu LONG §3 trên nến c1 (i) với c2 (i−1). Trả bitmask lý do bỏ (0 = vào).
//    htf_ok_ready: cả H1 và H4 đã ≥ 89 nến tại as-of. htf_trend: 4 điều kiện close > ema.
int Fsr_SignalReasons(const int hour_utc_c1_open,
                      const double adx_c1, const double dragon_c1, const double slope_c1,
                      const bool htf_ready, const bool htf_trend,
                      const double c2_low, const double c2_ema34h, const double c2_ema89,
                      const double c1_open, const double c1_close,
                      const double c1_ema34h, const double c1_ema89,
                      const int hour_first = FSR_HOUR_FIRST, const int hour_last = FSR_HOUR_LAST,
                      const double min_dragon = FSR_MIN_DRAGON, const double min_slope = FSR_MIN_SLOPE)
  {
   int r = 0;
   if(!htf_ready)
      r |= FSR_R_NOT_READY;
   if(!Fsr_HourInWindow(hour_utc_c1_open, hour_first, hour_last))
      r |= FSR_R_HOUR;
   if(!(adx_c1 >= FSR_MIN_ADX))
      r |= FSR_R_ADX;
   if(!(dragon_c1 >= min_dragon))
      r |= FSR_R_DRAGON;
   if(!htf_trend)
      r |= FSR_R_HTF;
   if(!(c2_low <= c2_ema34h || c2_low <= c2_ema89))
      r |= FSR_R_PULLBACK;
   if(!(c1_close > c1_open && c1_close > c1_ema34h && c1_close > c1_ema89))
      r |= FSR_R_CONFIRM;
   if(!(slope_c1 >= min_slope))
      r |= FSR_R_SLOPE;
   return r;
  }

bool Fsr_HtfTrend(const double h4c, const double h4e34, const double h4e89,
                  const double h1c, const double h1e34, const double h1e89)
  {
   return h4c > h4e34 && h4c > h4e89 && h1c > h1e34 && h1c > h1e89;
  }

//--- SL ban đầu = ema89(c1) − 1.5. Hợp lệ khi SL < giá vào (entry = ASK lúc khớp). false ⇒ bỏ tín hiệu.
bool Fsr_InitialStop(const double ema89_c1, const double entry, double &stop)
  {
   stop = ema89_c1 - FSR_STOP_BUFFER;
   return MathIsValidNumber(stop) && MathIsValidNumber(entry) && stop < entry;
  }

//--- SL ban đầu với buffer tuỳ mode (v0: 1.5 — cùng phép tính với Fsr_InitialStop; v1: K_BUF × ATR14(c1)).
bool Fsr_InitialStopBuf(const double ema89_c1, const double stop_buf, const double entry, double &stop)
  {
   stop = ema89_c1 - stop_buf;
   return MathIsValidNumber(stop) && MathIsValidNumber(entry) && stop < entry;
  }

//--- oz = floor(risk_usd / R), 1 oz = 0.01 lot. <1 ⇒ 0 (bỏ lệnh). Chặn R ≤ 0/NaN và trần oz.
int Fsr_Oz(const double risk_usd, const double r_price)
  {
   if(!MathIsValidNumber(r_price) || !MathIsValidNumber(risk_usd) || r_price <= 0.0 || risk_usd <= 0.0)
      return 0;
   double q = MathFloor(risk_usd / r_price);
   if(q < 1.0)
      return 0;
   if(q > FSR_MAX_OZ)
      return FSR_MAX_OZ;
   return (int)q;
  }

//--- Thang SL. Trả true + target nếu có mục tiêu. C: f≥2 ⇒ entry+(f−2)R. D: 1≤f<3 ⇒ entry; f≥3 ⇒ entry+(f−2)R.
bool Fsr_LadderTarget(const int variant, const double entry, const double r_price,
                      const double best, double &target)
  {
   target = 0.0;
   if(!(r_price > 0.0) || !MathIsValidNumber(best) || !MathIsValidNumber(entry))
      return false;
   double mfe = (best - entry) / r_price;
   double ff = MathFloor(mfe + FSR_FLOOR_EPS);
   if(ff > 1000000.0)
      ff = 1000000.0;
   int f = (int)ff;
   if(variant == FSR_VARIANT_C)
     {
      if(f < 2)
         return false;
      target = entry + (f - 2) * r_price;
      return true;
     }
   if(variant == FSR_VARIANT_D)
     {
      if(f < 1)
         return false;
      target = (f < 3) ? entry : entry + (f - 2) * r_price;
      return true;
     }
   return false;
  }

//--- Chỉ siết: dời khi target > SL hiện tại.
bool Fsr_ShouldTighten(const double target, const double current_sl)
  {
   return MathIsValidNumber(target) && target > current_sl;
  }

//--- Hành động thang khi có SL mục tiêu mới (đã qua Fsr_ShouldTighten).
//    target ≥ bid ⇒ SL "sai phía"/chạm đúng ⇒ backtest kích hoạt ngay ⇒ ĐÓNG market.
//    bid − stops_gap < target < bid ⇒ broker không nhận (stops_level) ⇒ GIỮ SL cũ, thử lại nến sau.
//    còn lại ⇒ dời SL.
#define FSR_LA_MODIFY      0
#define FSR_LA_CLOSE       1
#define FSR_LA_STOPS_WAIT  2
int Fsr_LadderAction(const double target, const double bid, const double stops_gap)
  {
   if(!MathIsValidNumber(target) || !MathIsValidNumber(bid))
      return FSR_LA_STOPS_WAIT;
   if(target >= bid)
      return FSR_LA_CLOSE;
   double gap = (MathIsValidNumber(stops_gap) && stops_gap > 0.0) ? stops_gap : 0.0;
   if(target > bid - gap)
      return FSR_LA_STOPS_WAIT;
   return FSR_LA_MODIFY;
  }

//--- Vị thế mồ côi: chỉ chạy thang khi có SL ban đầu thật (comment đọc được) và SL > 0 và R > 0.
bool Fsr_OrphanUsable(const bool comment_ok, const double sl0, const double entry)
  {
   return comment_ok && MathIsValidNumber(sl0) && sl0 > 0.0 && MathIsValidNumber(entry) && entry - sl0 > 0.0;
  }

//--- Lịch sử thiếu: bỏ khỏi state sau N nến (96 = 24h M15).
#define FSR_HISTORY_MISSING_DROP_BARS 96
bool Fsr_ShouldDropMissing(const int missing_bars)
  {
   return missing_bars >= FSR_HISTORY_MISSING_DROP_BARS;
  }

//--- Giới hạn thua ngày: đếm lệnh ĐÃ ĐÓNG net ≤ 0 có ngày UTC đóng == day. Đủ 2 ⇒ chặn.
int Fsr_LossesOnDay(const long &exit_utc[], const double &net[], const int n, const long day)
  {
   int k = 0;
   for(int i = 0; i < n; i++)
      if(Fsr_DayOf(exit_utc[i]) == day && net[i] <= 0.0)
         k++;
   return k;
  }

bool Fsr_LossCapHit(const int losses_today)
  {
   return losses_today >= FSR_MAX_LOSSES_DAY;
  }

int Fsr_MaxOpen(const int variant)
  {
   return variant == FSR_VARIANT_C ? FSR_MAX_OPEN_C : FSR_MAX_OPEN_D;
  }

bool Fsr_SlotFree(const int variant, const int open_now)
  {
   return open_now >= 0 && open_now < Fsr_MaxOpen(variant);
  }

string Fsr_StrategyVersion(const int variant)
  {
   return variant == FSR_VARIANT_C ? "cand_c_step_r_v0" : "cand_d_step_r_v0";
  }

//+------------------------------------------------------------------+
//| 5 chế độ v1 (2026-09-19).                                         |
//| CHỈ THÊM — không đổi hàm nào ở trên (EA v0 + EA 4 chế độ giữ y).  |
//+------------------------------------------------------------------+
#define FSR_MODE_C_V1_P1B   5
#define FSR_MODE_C_V1_P2    6
#define FSR_MODE_L07S       7
// §2a P1b: "gần chạm" = c2.low ≤ ema34_high(c2) + 0.5·ATR14(c2). CHỐT, không dò.
#define FSR_P1B_NEAR_K      0.5
// §2b P2: pullback ở ít nhất một trong c2, c3, c4.
#define FSR_P2_LOOKBACK     3
// §3 L07S: nến M15 MỞ lúc 07:00 UTC, thứ Hai–Sáu.
#define FSR_L07S_HOUR       7
#define FSR_R_WEEKEND       2048   // L07S: ngày c1 là thứ Bảy/Chủ nhật

bool Fsr5_ModeValid(const int mode)
  {
   return mode == FSR_MODE_C_V1 || mode == FSR_MODE_D_V1 || mode == FSR_MODE_C_V1_P1B
          || mode == FSR_MODE_C_V1_P2 || mode == FSR_MODE_L07S;
  }

// Mọi mode trừ D_V1 dùng thang C + trần 3 lệnh.
int Fsr5_ModeVariant(const int mode)
  {
   return mode == FSR_MODE_D_V1 ? FSR_VARIANT_D : FSR_VARIANT_C;
  }

string Fsr5_ModeName(const int mode)
  {
   if(mode == FSR_MODE_C_V1) return "C_V1";
   if(mode == FSR_MODE_D_V1) return "D_V1";
   if(mode == FSR_MODE_C_V1_P1B) return "C_V1_P1b";
   if(mode == FSR_MODE_C_V1_P2) return "C_V1_P2";
   if(mode == FSR_MODE_L07S) return "L07S";
   return "INVALID";
  }

string Fsr5_ModeVersion(const int mode)
  {
   if(mode == FSR_MODE_C_V1) return "cand_c_step_r_v1";
   if(mode == FSR_MODE_D_V1) return "cand_d_step_r_v1";
   if(mode == FSR_MODE_C_V1_P1B) return "cand_c_step_r_v1_p1b";
   if(mode == FSR_MODE_C_V1_P2) return "cand_c_step_r_v1_p2";
   if(mode == FSR_MODE_L07S) return "l07s_v1";
   return "invalid";
  }

// Cả 5 mode đều là v1: ngưỡng = K × ATR14(c1), đúng phép tính của C_V1 (L07S chỉ dùng min_slope + stop_buf).
bool Fsr5_ModeThresholds(const int mode, const double atr_c1, double &min_dragon, double &min_slope, double &stop_buf)
  {
   if(!Fsr5_ModeValid(mode))
     {
      min_dragon = 0.0;
      min_slope = 0.0;
      stop_buf = 0.0;
      return false;
     }
   return Fsr_ModeThresholds(mode == FSR_MODE_D_V1 ? FSR_MODE_D_V1 : FSR_MODE_C_V1, atr_c1,
                             min_dragon, min_slope, stop_buf);
  }

//--- Trần lệnh mở theo mode (C 3, D 20).
int Fsr5_MaxOpen(const int mode)
  {
   return Fsr_MaxOpen(Fsr5_ModeVariant(mode));
  }

//--- Điều kiện pullback gốc (bản gốc) trên MỘT nến, so với EMA của chính nó.
bool Fsr_PullbackBar(const double low, const double ema34h, const double ema89)
  {
   return low <= ema34h || low <= ema89;
  }

//--- §2a P1b: gốc HOẶC low ≤ ema34_high + 0.5·ATR14 (ATR tại c2). ATR hỏng ⇒ chỉ còn nhánh gốc.
bool Fsr_PullbackP1b(const double c2_low, const double c2_ema34h, const double c2_ema89, const double c2_atr)
  {
   if(Fsr_PullbackBar(c2_low, c2_ema34h, c2_ema89))
      return true;
   if(!MathIsValidNumber(c2_atr) || !(c2_atr > 0.0))
      return false;
   return c2_low <= c2_ema34h + FSR_P1B_NEAR_K * c2_atr;
  }

//--- Pullback theo mode tại c1 = i (c2 = i−1, c3 = i−2, c4 = i−3). Chỉ số < 0 ⇒ nến đó không tính.
bool Fsr5_Pullback(const int mode, const double &l[], const double &e34h[], const double &e89[],
                   const double &atr[], const int i)
  {
   if(i - 1 < 0)
      return false;
   if(mode == FSR_MODE_C_V1_P1B)
      return Fsr_PullbackP1b(l[i - 1], e34h[i - 1], e89[i - 1], atr[i - 1]);
   if(mode == FSR_MODE_C_V1_P2)
     {
      for(int k = 1; k <= FSR_P2_LOOKBACK && i - k >= 0; k++)
         if(Fsr_PullbackBar(l[i - k], e34h[i - k], e89[i - k]))
            return true;
      return false;
     }
   return Fsr_PullbackBar(l[i - 1], e34h[i - 1], e89[i - 1]);
  }

//--- Thay bit PULLBACK của bitmask Fsr_SignalReasons bằng kết quả pullback theo mode.
int Fsr_ApplyPullback(const int reasons, const bool pullback_ok)
  {
   return (reasons & ~FSR_R_PULLBACK) | (pullback_ok ? 0 : FSR_R_PULLBACK);
  }

//--- Thứ trong tuần của ngày UTC (0 = Chủ nhật). 1970-01-01 là thứ Năm.
int Fsr_WeekdayOf(const long utc_time)
  {
   long d = Fsr_DayOf(utc_time);
   long w = (d + 4) % 7;
   if(w < 0)
      w += 7;
   return (int)w;
  }

//--- §3 L07S trên c1. c1_open_utc = giờ MỞ nến tín hiệu. Trả bitmask (0 = vào).
//    h4_ready: nến H4 đã đóng gần nhất có ≥ 89 nến. Không ADX/H1/dragon/pullback/nến xanh.
int Fsr_L07sReasons(const long c1_open_utc, const bool h4_ready, const double h4c, const double h4e34,
                    const double h4e89, const double slope_c1, const double atr_c1)
  {
   int r = 0;
   if(!h4_ready)
      r |= FSR_R_NOT_READY;
   long s = c1_open_utc % 86400;
   if(s < 0)
      s += 86400;
   if(s != FSR_L07S_HOUR * 3600)
      r |= FSR_R_HOUR;
   int w = Fsr_WeekdayOf(c1_open_utc);
   if(w == 0 || w == 6)
      r |= FSR_R_WEEKEND;
   if(!(h4c > h4e34 && h4c > h4e89))
      r |= FSR_R_HTF;
   if(!MathIsValidNumber(atr_c1) || !(atr_c1 > 0.0))
      r |= FSR_R_ATR_INVALID;
   else if(!(slope_c1 >= FSR_K_SLOPE * atr_c1))
      r |= FSR_R_SLOPE;
   return r;
  }

#endif
// ===== END CLMCACore.mqh =====

// Giá trị enum = mã mode trong ForwardStepRCore.mqh (FSR_MODE_*).
// Chữ sau "//" là mô tả hiện trong bảng Inputs của MT5. Tên biến giữ nguyên để file .set cũ vẫn dùng được.
enum ENUM_FSR5_MODE
  {
   C_V1 = 3,      // Nhịp Hồi Chuẩn · Classic Pullback (C_V1)
   C_V1_P1b = 5,  // Hồi Gần Chạm · Near-Touch Pullback (C_V1_P1b)
   C_V1_P2 = 6,   // Hồi Trong 3 Nến · 3-Bar Pullback (C_V1_P2)
   D_V1 = 4,      // Bắt Mọi Tín Hiệu · Every Signal (D_V1)
   L07S = 7       // Mở Cửa London 7h · London Open 7AM (L07S)
  };
enum ENUM_FSR_RISK_MODE
  {
   FSR_RISK_USD = 0,      // Số tiền $ · Fixed $
   FSR_RISK_PERCENT = 1   // % số dư · % balance
  };

#define FSR_MAX_RISK_PCT     2.0     // trần rủi ro mỗi lệnh: 2% số dư (áp cho cả chế độ $ và %)
#define FSR_MAX_ENTRY_DELAY_SEC 60   // vào trễ quá 60 giây sau khi nến mở ⇒ bỏ lệnh (giá đã khác backtest)
#define FSR_HISTORY_M15_BARS 12000   // số nến M15 nạp để tính chỉ báo (như backtest), không cho đổi

// Giờ server của sàn. Tự động: EA tự dò khi chạy thật. Strategy Tester không có giờ thật ⇒ phải chọn sàn.
enum ENUM_FSR_BROKER_TIME
  {
   BT_AUTO = 0,     // Tự động · Auto
   BT_NY_CLOSE = 1, // Vantage, IC Markets, Pepperstone… (giờ NY · NY time)
   BT_GMT0 = 2,     // Exness (GMT+0)
   BT_EU_CLOSE = 3  // Quỹ/sàn giờ châu Âu · EU-time brokers / prop firms
  };
input group "1. Chiến lược · Strategy"
input ENUM_FSR5_MODE   InpMode           = C_V1;    // Chiến lược · Strategy
input group "2. Rủi ro · Risk"
input ENUM_FSR_RISK_MODE InpRiskMode    = FSR_RISK_USD; // Rủi ro theo · Risk by
input double           InpRiskUsd        = 50.0;    // Lỗ tối đa $ · Max loss $
input double           InpRiskPercent    = 0.1;     // Lỗ tối đa % · Max loss %
input group "3. Sàn · Broker"
input ENUM_FSR_BROKER_TIME InpBrokerTime = BT_AUTO; // Sàn · Broker
input group "4. Nâng cao · Advanced"
input int              InpDeviationPoints = 50;     // Trượt giá (point) · Slippage (pt)
input long             InpMagic          = 0;       // Magic (0 = tự động · auto)
enum ENUM_CLMCA_HOURS
  {
   HOURS_24 = 0,     // 24/24 (mặc định · default)
   HOURS_LOCAL = 1,  // Theo giờ máy tính · My computer's time
   HOURS_UTC = 2     // Theo giờ UTC · UTC time
  };
input group "5. Giờ vào lệnh · Trading hours (không áp dụng cho Mở Cửa London 7h · not for L07S)"
input ENUM_CLMCA_HOURS InpHours          = HOURS_24; // Giờ vào lệnh · Hours
input int              InpHourFrom       = 7;       // Từ giờ (0–23, tính cả) · From hour (incl.)
input int              InpHourTo         = 19;      // Đến giờ (0–23, tính cả) · To hour (incl.)


CTrade   g_trade;
int      g_variant = FSR_VARIANT_C;
string   g_version = "";

//--- strategy_version ghi vào CSV: 24/24 ⇒ hậu tố _24h (như research); 7–19 UTC ⇒ tên gốc (khớp backtest cũ);
//    khung khác ⇒ _h<từ>-<đến><utc|local>. L07S không có lọc giờ ⇒ luôn tên gốc.
string BuildVersion()
  {
   string v = Fsr5_ModeVersion(g_mode);
   if(g_mode == FSR_MODE_L07S)
      return v;
   if(InpHours == HOURS_24)
      return v + "_24h";
   if(InpHours == HOURS_UTC && InpHourFrom == FSR_HOUR_FIRST && InpHourTo == FSR_HOUR_LAST)
      return v;
   return v + StringFormat("_h%d-%d%s", InpHourFrom, InpHourTo, InpHours == HOURS_UTC ? "utc" : "local");
  }

//--- Giờ của nến c1 theo khung người dùng chọn. Giờ máy: lệch = TimeLocal() − TimeGMT() đo MỖI nến
//    (máy đổi giờ mùa thì theo luôn), làm tròn tới phút rồi cộng vào giờ UTC của nến.
int HourForFilter(const long c1_open_utc)
  {
   if(InpHours != HOURS_LOCAL)
      return Fsr_HourOf(c1_open_utc);
   long off = (long)TimeLocal() - (long)TimeGMT();
   off = (long)MathRound(off / 60.0) * 60;
   return Fsr_HourOf(c1_open_utc + off);
  }
int      g_mode = FSR_MODE_C_V1;
long     g_magic = 0;
string   g_dir = "";
datetime g_last_bar = 0;
bool     g_ready = false;

// Trạng thái từng lệnh — ghi lại toàn bộ vào state.csv mỗi khi đổi.
struct FsrPos
  {
   long     pos_id;
   long     signal_utc;       // giờ MỞ nến tín hiệu c1 (UTC)
   long     send_utc;         // lúc gửi lệnh (UTC)
   long     fill_utc;
   double   ask_open_next;    // bid open nến kế + spread nến (giá backtest khớp)
   double   ask_at_send;
   double   fill_price;
   double   sl0;
   double   r_price;
   double   cur_sl;
   double   lots;
   int      oz;
   int      open_at_entry;
   int      losses_at_entry;
   double   spread_entry;
   long     latency_ms;
   int      moves;
   int      excluded;         // 1 = parity_excluded (mồ côi không dựng được SL ban đầu) — KHÔNG chạy thang
   int      miss_bars;        // số nến liên tiếp không đọc được history khi đối soát đóng
   double   atr_sig;          // ATR14 tại c1 (mọi mode, để so)
   double   dragon_sig;
   double   slope_sig;
   double   h4c_sig;          // L07S: close/EMA34/EMA89 nến H4 đã đóng gần nhất tại c1 (mode khác: ô trống)
   double   h4e34_sig;
   double   h4e89_sig;
  };
FsrPos g_pos[];

//+------------------------------------------------------------------+
//| Tiện ích                                                          |
//+------------------------------------------------------------------+
int g_gmt_winter = 2, g_gmt_summer = 3;   // lệch UTC (giờ) mùa đông/hè — đặt trong ResolveBrokerTime()
bool g_eu_dst = false;                    // true ⇒ đổi giờ theo lịch châu Âu thay vì Mỹ

long ToUtc(const datetime server_t)
  {
   if(g_eu_dst)
      return Fsr_ServerToUtcEu((long)server_t, g_gmt_winter, g_gmt_summer);
   return Fsr_ServerToUtc((long)server_t, g_gmt_winter, g_gmt_summer);
  }

string Iso(const long utc)
  {
   string s = TimeToString((datetime)utc, TIME_DATE | TIME_SECONDS);
   StringReplace(s, ".", "-");
   StringReplace(s, " ", "T");
   return s + "Z";
  }

string D(const double v, const int digits = 5)
  {
   if(!MathIsValidNumber(v) || v == EMPTY_VALUE)   // EMPTY_VALUE = DBL_MAX ⇒ ô trống, không in số khổng lồ
      return "";
   return DoubleToString(v, digits);
  }

void AppendLine(const string file, const string header, const string line)
  {
   string path = g_dir + "\\" + file;
   int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[FSR] ❌ không mở được · cannot open %s err=%d", path, GetLastError());
      return;
     }
   if(FileSize(h) == 0)
      FileWriteString(h, header + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
  }

void Incident(const string kind, const string detail)
  {
   long now = ToUtc(TimeTradeServer());
   PrintFormat("[FSR] incident %s %s", kind, detail);
   AppendLine("incidents.csv", "time_utc,strategy_version,kind,detail",
              Iso(now) + "," + g_version + "," + kind + ",\"" + detail + "\"");
  }

//+------------------------------------------------------------------+
//| state.csv                                                         |
//+------------------------------------------------------------------+
int FindPos(const long pos_id)
  {
   for(int i = 0; i < ArraySize(g_pos); i++)
      if(g_pos[i].pos_id == pos_id)
         return i;
   return -1;
  }

void SaveState()
  {
   string path = g_dir + "\\state.csv";
   int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[FSR] ❌ không ghi được state · cannot write state err=%d", GetLastError());
      return;
     }
   for(int i = 0; i < ArraySize(g_pos); i++)
     {
      FsrPos p = g_pos[i];
      FileWriteString(h, StringFormat("%I64d;%I64d;%I64d;%I64d;%s;%s;%s;%s;%s;%s;%s;%d;%d;%d;%s;%I64d;%d;%d;%d;%s;%s;%s;%s;%s;%s\r\n",
                                      p.pos_id, p.signal_utc, p.send_utc, p.fill_utc,
                                      D(p.ask_open_next), D(p.ask_at_send), D(p.fill_price), D(p.sl0),
                                      D(p.r_price), D(p.cur_sl), D(p.lots, 2), p.oz, p.open_at_entry,
                                      p.losses_at_entry, D(p.spread_entry), p.latency_ms, p.moves, p.excluded,
                                      p.miss_bars, D(p.atr_sig, 6), D(p.dragon_sig, 6), D(p.slope_sig, 6),
                                      D(p.h4c_sig), D(p.h4e34_sig), D(p.h4e89_sig)));
     }
   FileClose(h);
  }

void LoadState()
  {
   ArrayResize(g_pos, 0);
   string path = g_dir + "\\state.csv";
   if(!FileIsExist(path))
      return;
   int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      string f[];
      if(StringSplit(line, ';', f) < 17)
         continue;
      FsrPos p;
      ZeroMemory(p);
      p.pos_id = StringToInteger(f[0]);
      p.signal_utc = StringToInteger(f[1]);
      p.send_utc = StringToInteger(f[2]);
      p.fill_utc = StringToInteger(f[3]);
      p.ask_open_next = StringToDouble(f[4]);
      p.ask_at_send = StringToDouble(f[5]);
      p.fill_price = StringToDouble(f[6]);
      p.sl0 = StringToDouble(f[7]);
      p.r_price = StringToDouble(f[8]);
      p.cur_sl = StringToDouble(f[9]);
      p.lots = StringToDouble(f[10]);
      p.oz = (int)StringToInteger(f[11]);
      p.open_at_entry = (int)StringToInteger(f[12]);
      p.losses_at_entry = (int)StringToInteger(f[13]);
      p.spread_entry = StringToDouble(f[14]);
      p.latency_ms = StringToInteger(f[15]);
      p.moves = (int)StringToInteger(f[16]);
      int nf = ArraySize(f);
      p.excluded = nf > 17 ? (int)StringToInteger(f[17]) : 0;
      p.miss_bars = nf > 18 ? (int)StringToInteger(f[18]) : 0;
      p.atr_sig = (nf > 19 && StringLen(f[19]) > 0) ? StringToDouble(f[19]) : EMPTY_VALUE;   // ô trống ≠ 0
      p.dragon_sig = (nf > 20 && StringLen(f[20]) > 0) ? StringToDouble(f[20]) : EMPTY_VALUE;   // ô trống ≠ 0
      p.slope_sig = (nf > 21 && StringLen(f[21]) > 0) ? StringToDouble(f[21]) : EMPTY_VALUE;   // ô trống ≠ 0
      p.h4c_sig = (nf > 22 && StringLen(f[22]) > 0) ? StringToDouble(f[22]) : EMPTY_VALUE;
      p.h4e34_sig = (nf > 23 && StringLen(f[23]) > 0) ? StringToDouble(f[23]) : EMPTY_VALUE;
      p.h4e89_sig = (nf > 24 && StringLen(f[24]) > 0) ? StringToDouble(f[24]) : EMPTY_VALUE;
      int n = ArraySize(g_pos);
      ArrayResize(g_pos, n + 1);
      g_pos[n] = p;
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Vị thế của EA này (magic + symbol)                                |
//+------------------------------------------------------------------+
int CountMyOpen()
  {
   int k = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == g_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         k++;
     }
   return k;
  }

// Vị thế đang mở mà state không có (EA sập giữa khớp lệnh và ghi state) ⇒ dựng từ comment.
// Comment: "FSR<C|D> <signal_utc> <sl0>".
void AdoptOrphans()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || PositionGetInteger(POSITION_MAGIC) != g_magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long pid = PositionGetInteger(POSITION_IDENTIFIER);
      if(FindPos(pid) >= 0)
         continue;
      FsrPos p;
      ZeroMemory(p);
      p.pos_id = pid;
      p.atr_sig = EMPTY_VALUE;      // mồ côi: không biết chỉ báo tại c1
      p.dragon_sig = EMPTY_VALUE;
      p.slope_sig = EMPTY_VALUE;
      p.h4c_sig = EMPTY_VALUE;
      p.h4e34_sig = EMPTY_VALUE;
      p.h4e89_sig = EMPTY_VALUE;
      p.fill_price = PositionGetDouble(POSITION_PRICE_OPEN);
      p.cur_sl = PositionGetDouble(POSITION_SL);
      p.lots = PositionGetDouble(POSITION_VOLUME);
      p.fill_utc = ToUtc((datetime)PositionGetInteger(POSITION_TIME));
      string parts[];
      string cm = PositionGetString(POSITION_COMMENT);
      bool comment_ok = StringSplit(cm, ' ', parts) >= 3 && StringFind(parts[0], "FSR") == 0;
      if(comment_ok)
        {
         p.signal_utc = StringToInteger(parts[1]);
         p.sl0 = StringToDouble(parts[2]);
        }
      if(Fsr_OrphanUsable(comment_ok, p.sl0, p.fill_price))
        {
         p.r_price = p.fill_price - p.sl0;
         Incident("orphan_adopted", StringFormat("pos=%I64d comment=%s R=%s", pid, cm, D(p.r_price)));
        }
      else
        {
         // KHÔNG đoán SL ban đầu, KHÔNG chia R, KHÔNG chạy thang. Giữ nguyên SL đang có trên server.
         p.excluded = 1;
         p.r_price = 0.0;
         if(!(p.cur_sl > 0.0))
            Incident("NO_SL_ORPHAN", StringFormat("🔴 pos=%I64d KHÔNG có SL trên server, EA KHÔNG tự đặt — xử lý tay", pid));
         Incident("orphan_parity_excluded", StringFormat("pos=%I64d comment=%s sl=%s", pid, cm, D(p.cur_sl)));
        }
      int n = ArraySize(g_pos);
      ArrayResize(g_pos, n + 1);
      g_pos[n] = p;
     }
   SaveState();
  }

//+------------------------------------------------------------------+
//| Lịch sử lệnh đã đóng của EA — cho luật thua ngày                  |
//+------------------------------------------------------------------+
int LossesOnUtcDay(const long day)
  {
   datetime now = TimeTradeServer();
   if(!HistorySelect(now - 5 * 86400, now + 86400))
      return 0;
   int total = HistoryDealsTotal();
   long ids[];
   // pass 1: position có deal IN mang magic của EA (deal đóng tay/SL có thể mang magic 0).
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(d, DEAL_MAGIC) == g_magic)
        {
         int n = ArraySize(ids);
         ArrayResize(ids, n + 1);
         ids[n] = HistoryDealGetInteger(d, DEAL_POSITION_ID);
        }
     }
   long ex[];
   double net[];
   for(int k = 0; k < ArraySize(ids); k++)
     {
      double sum = 0.0, vin = 0.0, vout = 0.0;
      long last_out = 0;
      for(int i = 0; i < total; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_POSITION_ID) != ids[k])
            continue;
         sum += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION)
                + HistoryDealGetDouble(d, DEAL_SWAP);
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e == DEAL_ENTRY_IN)
            vin += HistoryDealGetDouble(d, DEAL_VOLUME);
         else
           {
            vout += HistoryDealGetDouble(d, DEAL_VOLUME);
            last_out = MathMax(last_out, (long)HistoryDealGetInteger(d, DEAL_TIME));
           }
        }
      if(vin > 0.0 && vout >= vin - 1e-9 && last_out > 0)
        {
         int n = ArraySize(ex);
         ArrayResize(ex, n + 1);
         ArrayResize(net, n + 1);
         ex[n] = ToUtc((datetime)last_out);
         net[n] = sum;
        }
     }
   return Fsr_LossesOnDay(ex, net, ArraySize(ex), day);
  }

//+------------------------------------------------------------------+
//| Nến + chỉ báo                                                     |
//+------------------------------------------------------------------+
// Nạp nến M15 ĐÃ ĐÓNG (bỏ nến đang chạy), cũ → mới, thời gian UTC.
int LoadM15(long &t[], double &o[], double &h[], double &l[], double &c[], int &spread_pts[])
  {
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, PERIOD_M15, 1, FSR_HISTORY_M15_BARS, r);
   if(n <= 0)
      return n;
   ArrayResize(t, n);
   ArrayResize(o, n);
   ArrayResize(h, n);
   ArrayResize(l, n);
   ArrayResize(c, n);
   ArrayResize(spread_pts, n);
   for(int i = 0; i < n; i++)
     {
      t[i] = ToUtc(r[i].time);
      o[i] = r[i].open;
      h[i] = r[i].high;
      l[i] = r[i].low;
      c[i] = r[i].close;
      spread_pts[i] = r[i].spread;
     }
   return n;
  }

//+------------------------------------------------------------------+
//| Thang SL                                                          |
//+------------------------------------------------------------------+
void ManageLadder(const long &t[], const double &h[], const int n)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stops_lvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetInteger(POSITION_MAGIC) != g_magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long pid = PositionGetInteger(POSITION_IDENTIFIER);
      int k = FindPos(pid);
      if(k < 0 || g_pos[k].excluded != 0 || !(g_pos[k].r_price > 0.0))
         continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      long entry_bar = (ToUtc((datetime)PositionGetInteger(POSITION_TIME)) / 900) * 900;
      // best = max(giá vào, high các nến ĐÃ ĐÓNG từ nến chứa lệnh vào) — dựng lại từ nến nên sống qua restart.
      double best = entry;
      for(int j = n - 1; j >= 0 && t[j] >= entry_bar; j--)
         best = MathMax(best, h[j]);
      double target;
      if(!Fsr_LadderTarget(g_variant, entry, g_pos[k].r_price, best, target))
         continue;
      target = NormalizeDouble(target, _Digits);
      if(!Fsr_ShouldTighten(target, sl))
         continue;
      double mfe = (best - entry) / g_pos[k].r_price;
      long now = ToUtc(TimeTradeServer());
      int act = Fsr_LadderAction(target, bid, stops_lvl * pt);
      if(act == FSR_LA_CLOSE)
        {
         // Research: SL "sai phía"/chạm đúng kích hoạt ngay ⇒ đóng market (gap). Ghi rõ để so parity.
         bool okc = g_trade.PositionClose(ticket, InpDeviationPoints);
         Incident("CLOSE_SL_ABOVE_BID", StringFormat("pos=%I64d target=%s bid=%s ok=%d ret=%d",
                  pid, D(target), D(bid), okc, g_trade.ResultRetcode()));
         continue;
        }
      if(act == FSR_LA_STOPS_WAIT)
        {
         // Backtest chỉ dời SL; broker không nhận vì stops_level ⇒ GIỮ SL cũ, thử lại nến sau. KHÔNG đóng.
         Incident("LADDER_STOPS_LEVEL_WAIT", StringFormat("pos=%I64d target=%s bid=%s stops_gap=%s — giữ SL %s, thử lại nến sau",
                  pid, D(target), D(bid), D(stops_lvl * pt), D(sl)));
         continue;
        }
      bool ok = g_trade.PositionModify(ticket, target, 0.0);
      AppendLine("ladder_moves.csv",
                 "time_utc,strategy_version,forward_trade_id,old_sl,new_sl,mfe_R,best_bid_high,ok,retcode",
                 Iso(now) + "," + g_version + "," + IntegerToString(pid) + "," +
                 D(sl) + "," + D(target) + "," + D(mfe, 4) + "," + D(best) + "," + IntegerToString(ok) + "," +
                 IntegerToString(g_trade.ResultRetcode()));
      if(ok)
        {
         g_pos[k].cur_sl = target;
         g_pos[k].moves++;
         SaveState();
        }
      else
         Incident("modify_failed", StringFormat("pos=%I64d target=%s ret=%d", pid, D(target), g_trade.ResultRetcode()));
     }
  }

//+------------------------------------------------------------------+
//| Tín hiệu + vào lệnh                                               |
//+------------------------------------------------------------------+
void EvaluateAndEnter(const long &t[], const double &o[], const double &h[], const double &l[],
                      const double &c[], const int n, const datetime cur_bar_server)
  {
   if(n < 200)
     {
      Incident("history_short", StringFormat("m15=%d", n));
      return;
     }
   double e34h[], e34l[], e34c[], e89[], adx[];
   Fsr_Ema(h, n, FSR_EMA_DRAGON, e34h);
   Fsr_Ema(l, n, FSR_EMA_DRAGON, e34l);
   Fsr_Ema(c, n, FSR_EMA_DRAGON, e34c);
   Fsr_Ema(c, n, FSR_EMA_TREND, e89);
   Fsr_AdxEma(h, l, c, n, FSR_ADX_PERIOD, adx);
   double atr[];
   Fsr_AtrWilder(h, l, c, n, FSR_ATR_PERIOD, atr);
   long t1[], t4[];
   double o1[], h1[], l1[], c1s[], o4[], h4[], l4[], c4[];
   int m1 = Fsr_Aggregate(t, o, h, l, c, n, 3600, t1, o1, h1, l1, c1s);
   int m4 = Fsr_Aggregate(t, o, h, l, c, n, 14400, t4, o4, h4, l4, c4);
   double h1e34[], h1e89[], h4e34[], h4e89[];
   Fsr_Ema(c1s, m1, 34, h1e34);
   Fsr_Ema(c1s, m1, 89, h1e89);
   Fsr_Ema(c4, m4, 34, h4e34);
   Fsr_Ema(c4, m4, 89, h4e89);

   int i = n - 1;          // c1 = nến vừa đóng
   long dec = t[i] + 900;
   int j1 = Fsr_AsOfIndex(t1, m1, 3600, dec);
   int j4 = Fsr_AsOfIndex(t4, m4, 14400, dec);
   bool h4_ready = (j4 + 1 >= FSR_HTF_READY_BARS);
   bool ready = (j1 + 1 >= FSR_HTF_READY_BARS) && h4_ready;
   bool trend = ready && Fsr_HtfTrend(c4[j4], h4e34[j4], h4e89[j4], c1s[j1], h1e34[j1], h1e89[j1]);
   double slope = e34c[i] - e34c[i - FSR_SLOPE_LAG];
   double dragon = e34h[i] - e34l[i];
   double h4c_v = h4_ready ? c4[j4] : EMPTY_VALUE;
   double h4e34_v = h4_ready ? h4e34[j4] : EMPTY_VALUE;
   double h4e89_v = h4_ready ? h4e89[j4] : EMPTY_VALUE;
   double min_dragon, min_slope, stop_buf;
   bool thr_ok = Fsr5_ModeThresholds(g_mode, atr[i], min_dragon, min_slope, stop_buf);
   int reasons;
   if(g_mode == FSR_MODE_L07S)
     {
      // §3: chỉ lịch 07:00 UTC T2–T6 + H4 trend + slope. Không ADX/H1/dragon/pullback/nến xanh, không lọc phiên.
      reasons = Fsr_L07sReasons(t[i], h4_ready, h4c_v, h4e34_v, h4e89_v, slope, atr[i]);
     }
   else
     {
      // 24/24 ⇒ khung 0..23 (mọi giờ đều qua). Còn lại: giờ UTC hoặc giờ máy của nến c1, so với [Từ..Đến].
      bool h24 = (InpHours == HOURS_24);
      reasons = Fsr_SignalReasons(HourForFilter(t[i]), adx[i], dragon, slope, ready, trend,
                                  l[i - 1], e34h[i - 1], e89[i - 1], o[i], c[i], e34h[i], e89[i],
                                  h24 ? 0 : InpHourFrom, h24 ? 23 : InpHourTo,
                                  min_dragon, min_slope);
      // C_V1/D_V1: Fsr5_Pullback = đúng nhánh gốc ⇒ bitmask y như EA 4 chế độ. P1b/P2: nới theo §2.
      reasons = Fsr_ApplyPullback(reasons, Fsr5_Pullback(g_mode, l, e34h, e89, atr, i));
     }
   if(!thr_ok)
      reasons |= FSR_R_ATR_INVALID;

   string action = "";
   int open_now = CountMyOpen();
   int losses = -1;
   double stop = 0.0;
   if(reasons == 0)
     {
      losses = LossesOnUtcDay(Fsr_DayOf(t[i]));
      if(Fsr_LossCapHit(losses))
         reasons |= FSR_R_LOSS_CAP;
      if(!(open_now >= 0 && open_now < Fsr5_MaxOpen(g_mode)))
        {
         reasons |= FSR_R_MAX_OPEN;
         if(g_variant == FSR_VARIANT_D)
            Incident("max_open_hit", StringFormat("open=%d cap=%d", open_now, Fsr5_MaxOpen(g_mode)));
        }
     }
   if(reasons == 0)
      action = TryEnter(t[i], e89[i], stop_buf, atr[i], dragon, slope, h4c_v, h4e34_v, h4e89_v, open_now, losses,
                        cur_bar_server);

   AppendLine("signals.csv",
              "c1_open_utc,strategy_version,reasons,adx14,dragon_width,ema34_slope,ema34_high,ema89,h1_ready_bars,h4_ready_bars,htf_trend,open_positions,losses_today,action,atr14,min_dragon,min_slope,stop_buf,h4_close,h4_ema34,h4_ema89",
              Iso(t[i]) + "," + g_version + "," + IntegerToString(reasons) + "," +
              D(adx[i], 4) + "," + D(dragon, 4) + "," + D(slope, 4) + "," + D(e34h[i]) + "," + D(e89[i]) + "," +
              IntegerToString(j1 + 1) + "," + IntegerToString(j4 + 1) + "," + IntegerToString(trend) + "," +
              IntegerToString(open_now) + "," + IntegerToString(losses) + "," + action + "," +
              D(atr[i], 6) + "," + D(min_dragon, 6) + "," + D(min_slope, 6) + "," + D(stop_buf, 6) + "," +
              D(h4c_v) + "," + D(h4e34_v) + "," + D(h4e89_v));
  }

//--- Risk $ cho lệnh sắp mở: $ cố định hoặc % SỐ DƯ (balance, không phải equity) tại lúc vào.
double RiskUsdNow()
  {
   if(InpRiskMode == FSR_RISK_PERCENT)
      return AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double cap = AccountInfoDouble(ACCOUNT_BALANCE) * FSR_MAX_RISK_PCT / 100.0;
   if(InpRiskUsd > cap)
     {
      Incident("risk_capped_2pct", StringFormat("risk_usd=%s cap=%s", D(InpRiskUsd, 2), D(cap, 2)));
      return cap;
     }
   return InpRiskUsd;
  }

string TryEnter(const long signal_utc, const double ema89_c1, const double stop_buf, const double atr_c1,
                const double dragon_c1, const double slope_c1, const double h4c, const double h4e34,
                const double h4e89, const int open_now, const int losses,
                const datetime cur_bar_server)
  {
   long delay = (long)(TimeTradeServer() - cur_bar_server);
   if(delay > FSR_MAX_ENTRY_DELAY_SEC)
     {
      Incident("entry_late_skipped", StringFormat("delay_s=%I64d", delay));
      return "skip_late";
     }
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
     {
      Incident("no_tick", "");
      return "skip_no_tick";
     }
   double stop;
   if(!Fsr_InitialStopBuf(ema89_c1, stop_buf, tk.ask, stop))
      return "skip_stop_not_below_entry";
   stop = NormalizeDouble(stop, _Digits);
   double r_price = tk.ask - stop;
   int oz = Fsr_Oz(RiskUsdNow(), r_price);
   if(oz < 1)
      return "skip_oz_lt_1";
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(!(contract > 0.0) || !(step > 0.0))
     {
      Incident("symbol_spec_invalid", StringFormat("contract=%s step=%s", D(contract), D(step)));
      return "skip_symbol_spec";
     }
   double lots = MathFloor((oz / contract) / step + 1e-9) * step;
   lots = NormalizeDouble(lots, 2);
   if(lots < vmin)
      return "skip_lots_lt_min";
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stops_lvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop > tk.bid - stops_lvl * pt)
     {
      Incident("stop_inside_stops_level", StringFormat("stop=%s bid=%s lvl=%I64d", D(stop), D(tk.bid), stops_lvl));
      return "skip_stops_level";
     }
   MqlRates cur[];
   double ask_open_next = 0.0;
   if(CopyRates(_Symbol, PERIOD_M15, 0, 1, cur) == 1)
      ask_open_next = cur[0].open + cur[0].spread * pt;

   string comment = StringFormat("FSR%s %I64d %s", Fsr5_ModeName(g_mode), signal_utc,
                                 DoubleToString(stop, _Digits));
   long send_utc = ToUtc(TimeTradeServer());
   ulong t0 = GetTickCount64();
   bool ok = g_trade.Buy(lots, _Symbol, 0.0, stop, 0.0, comment);   // 🔴 SL cứng ngay khi mở
   ulong t1 = GetTickCount64();
   uint ret = g_trade.ResultRetcode();
   if(!ok || (ret != TRADE_RETCODE_DONE && ret != TRADE_RETCODE_PLACED))
     {
      Incident("order_failed", StringFormat("ret=%u lots=%s stop=%s", ret, D(lots, 2), D(stop)));
      return "order_failed";
     }
   ulong deal = g_trade.ResultDeal();
   long pid = 0;
   double fill = g_trade.ResultPrice();
   if(deal > 0 && HistoryDealSelect(deal))
     {
      pid = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      fill = HistoryDealGetDouble(deal, DEAL_PRICE);
     }
   if(pid == 0)
     {
      Incident("fill_unknown_position", StringFormat("deal=%I64u — AdoptOrphans sẽ nhận ở nhịp sau", deal));
      return "filled_pid_unknown";
     }
   FsrPos p;
   ZeroMemory(p);
   p.pos_id = pid;
   p.signal_utc = signal_utc;
   p.send_utc = send_utc;
   p.fill_utc = ToUtc(TimeTradeServer());
   p.ask_open_next = ask_open_next;
   p.ask_at_send = tk.ask;
   p.fill_price = fill;
   p.sl0 = stop;
   p.r_price = fill - stop;          // R theo giá khớp thật (như engine research: entry_price = fill)
   p.cur_sl = stop;
   p.lots = lots;
   p.oz = oz;
   p.open_at_entry = open_now;
   p.losses_at_entry = losses;
   p.spread_entry = tk.ask - tk.bid;
   p.latency_ms = (long)(t1 - t0);
   p.moves = 0;
   p.atr_sig = atr_c1;
   p.dragon_sig = dragon_c1;
   p.slope_sig = slope_c1;
   p.h4c_sig = h4c;
   p.h4e34_sig = h4e34;
   p.h4e89_sig = h4e89;
   int n = ArraySize(g_pos);
   ArrayResize(g_pos, n + 1);
   g_pos[n] = p;
   SaveState();
   return "entered";
  }

//+------------------------------------------------------------------+
//| Ghi lệnh đã đóng                                                  |
//+------------------------------------------------------------------+
double CheckpointR(const FsrPos &p, const long minutes, const long &t[], const double &c[], const int n)
  {
   long target = (p.fill_utc / 900) * 900 + minutes * 60 - 900; // nến M15 kết thúc đúng mốc
   for(int i = n - 1; i >= 0; i--)
      if(t[i] == target)
         return (c[i] - p.fill_price) / p.r_price;
   return EMPTY_VALUE;
  }

// Trả false khi chưa đọc được history (đối soát sẽ thử lại nến sau).
bool LogClosed(const int k)
  {
   FsrPos p = g_pos[k];
   if(!HistorySelectByPosition(p.pos_id))
      return false;
   double net = 0.0, commission = 0.0, swap = 0.0, vout = 0.0, exit_px_w = 0.0;
   long exit_t = 0, reason = -1;
   ulong exit_deal = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      double pr = HistoryDealGetDouble(d, DEAL_PROFIT);
      double cm = HistoryDealGetDouble(d, DEAL_COMMISSION);
      double sw = HistoryDealGetDouble(d, DEAL_SWAP);
      net += pr + cm + sw;
      commission += cm;
      swap += sw;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
        {
         double v = HistoryDealGetDouble(d, DEAL_VOLUME);
         vout += v;
         exit_px_w += v * HistoryDealGetDouble(d, DEAL_PRICE);
         long tt = HistoryDealGetInteger(d, DEAL_TIME);
         if(tt >= exit_t)
           {
            exit_t = tt;
            reason = HistoryDealGetInteger(d, DEAL_REASON);
            exit_deal = d;
           }
        }
     }
   if(vout <= 0.0)
      return false; // chưa đóng hẳn / history chưa về
   double exit_px = exit_px_w / vout;
   long exit_utc = ToUtc((datetime)exit_t);
   string why = reason == DEAL_REASON_SL ? "stop_loss" : reason == DEAL_REASON_CLIENT ? "manual_external" :
                reason == DEAL_REASON_EXPERT ? "expert_close" : reason == DEAL_REASON_SO ? "stop_out" : "other";
   double spread_exit = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // MFE + checkpoint từ nến.
   long t[];
   double o[], h[], l[], c[];
   int sp[];
   int n = LoadM15(t, o, h, l, c, sp);
   double best = p.fill_price, worst = p.fill_price;
   long entry_bar = (p.fill_utc / 900) * 900;
   for(int i = 0; i < n; i++)
      if(t[i] >= entry_bar && t[i] < exit_utc)
        {
         best = MathMax(best, h[i]);
         worst = MathMin(worst, l[i]);
        }
   double mfe_r = p.r_price > 0.0 ? (best - p.fill_price) / p.r_price : EMPTY_VALUE;
   double mae_r = p.r_price > 0.0 ? (p.fill_price - worst) / p.r_price : EMPTY_VALUE;
   int lvl = 0;
   int levels[4] = {1, 2, 3, 5};
   for(int q = 0; q < 4; q++)
      if(mfe_r >= levels[q])
         lvl = levels[q];
   bool has_r = p.excluded == 0 && p.r_price > 0.0;
   if(!has_r)
     {
      mfe_r = EMPTY_VALUE;
      mae_r = EMPTY_VALUE;
      lvl = 0;
     }
   double pnl_r_price = has_r ? (exit_px - p.fill_price) / p.r_price : EMPTY_VALUE;
   double pnl_r_usd = (has_r && p.oz > 0) ? net / (p.oz * p.r_price) : EMPTY_VALUE;
   string sv = g_version;
   string id = IntegerToString(p.pos_id);

   AppendLine("trades.csv",
              "forward_trade_id,strategy_version,account_ref,direction,signal_time,signal_bar_open_time_utc,"
              "requested_entry_price,ask_open_next_bar,ask_at_send,actual_entry_price,fill_time,slippage_price,slippage_r,slippage_vs_backtest_price,"
              "signal_to_fill_latency_ms,spread_at_entry,stop_loss_price,stop_loss_initial,initial_stop_distance_price,R_price,"
              "lots,oz,open_positions_at_entry,losses_today_at_entry,ladder_moves_count,sl_at_exit,exit_time,exit_reason,"
              "exit_price,exit_fill_price,exit_slippage_vs_sl,spread_at_exit,commission_usd,swap_usd,net_pnl,realized_r,"
              "pnl_R_usd,mfe_r,mae_r,max_r_level_reached,holding_duration_minutes,order_ref,parity_excluded,"
              "atr14_at_signal,dragon_width,ema34_slope,k_width,k_slope,k_buf,h4_close,h4_ema34,h4_ema89",
              id + "," + sv + "," + "" + ",long," + Iso(p.signal_utc + 900) + "," + Iso(p.signal_utc) + "," +
              D(p.ask_at_send) + "," + D(p.ask_open_next) + "," + D(p.ask_at_send) + "," + D(p.fill_price) + "," +
              Iso(p.fill_utc) + "," + D(p.fill_price - p.ask_at_send) + "," + D((p.fill_price - p.ask_at_send) / p.r_price, 4) + "," +
              D(p.fill_price - p.ask_open_next) + "," +
              IntegerToString(p.latency_ms) + "," + D(p.spread_entry) + "," + D(p.sl0) + "," + D(p.sl0) + "," +
              D(p.r_price) + "," + D(p.r_price) + "," + D(p.lots, 2) + "," + IntegerToString(p.oz) + "," +
              IntegerToString(p.open_at_entry) + "," + IntegerToString(p.losses_at_entry) + "," + IntegerToString(p.moves) + "," +
              D(p.cur_sl) + "," + Iso(exit_utc) + "," + why + "," + D(exit_px) + "," + D(exit_px) + "," +
              D(exit_px - p.cur_sl) + "," + D(spread_exit) + "," + D(commission, 2) + "," + D(swap, 2) + "," + D(net, 2) + "," +
              D(pnl_r_price, 4) + "," + D(pnl_r_usd, 4) + "," + D(mfe_r, 4) + "," + D(mae_r, 4) + "," + IntegerToString(lvl) + "," +
              IntegerToString((exit_utc - (p.signal_utc + 900)) / 60) + "," + IntegerToString((long)exit_deal) + "," +
              IntegerToString(p.excluded) + "," + D(p.atr_sig, 6) + "," + D(p.dragon_sig, 6) + "," + D(p.slope_sig, 6) + "," +
              D(FSR_K_WIDTH, 16) + "," + D(FSR_K_SLOPE, 16) + "," + D(FSR_K_BUF, 16) + "," +
              D(p.h4c_sig) + "," + D(p.h4e34_sig) + "," + D(p.h4e89_sig));

   long cps[4] = {15, 30, 60, 120};
   for(int q = 0; q < 4; q++)
     {
      double ur = has_r ? CheckpointR(p, cps[q], t, c, n) : EMPTY_VALUE;
      AppendLine("lifecycle.csv", "forward_trade_id,strategy_version,checkpoint_minutes,unrealized_r_at_checkpoint,closed_before_checkpoint",
                 id + "," + sv + "," + IntegerToString(cps[q]) + "," + (ur == EMPTY_VALUE ? "" : D(ur, 4)) + "," +
                 IntegerToString(exit_utc <= p.fill_utc + cps[q] * 60));
     }

   // Bỏ khỏi state SAU khi ghi (sập giữa hai bước ⇒ ghi trùng một dòng, research khử trùng theo forward_trade_id).
   for(int i = k; i < ArraySize(g_pos) - 1; i++)
      g_pos[i] = g_pos[i + 1];
   ArrayResize(g_pos, ArraySize(g_pos) - 1);
   SaveState();
   return true;
  }

void RemovePos(const int k)
  {
   for(int i = k; i < ArraySize(g_pos) - 1; i++)
      g_pos[i] = g_pos[i + 1];
   ArrayResize(g_pos, ArraySize(g_pos) - 1);
   SaveState();
  }

// Mọi lệnh trong state mà không còn mở ⇒ ghi đóng (bắt cả lệnh đóng lúc EA tắt).
void ReconcileClosed()
  {
   for(int k = ArraySize(g_pos) - 1; k >= 0; k--)
     {
      bool open = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t != 0 && PositionGetInteger(POSITION_IDENTIFIER) == g_pos[k].pos_id)
           {
            open = true;
            break;
           }
        }
      if(open || LogClosed(k))
         continue;
      // Không đọc được history: log MỘT lần, đếm nến, quá 96 nến (24h) thì bỏ khỏi state.
      if(g_pos[k].miss_bars == 0)
         Incident("history_missing", StringFormat("pos=%I64d — thử lại mỗi nến, bỏ sau %d nến", g_pos[k].pos_id,
                  FSR_HISTORY_MISSING_DROP_BARS));
      g_pos[k].miss_bars++;
      if(Fsr_ShouldDropMissing(g_pos[k].miss_bars))
        {
         Incident("history_missing_dropped", StringFormat("pos=%I64d sau %d nến — KHÔNG có dòng trades.csv, research loại khỏi parity",
                  g_pos[k].pos_id, g_pos[k].miss_bars));
         RemovePos(k);
        }
      else
         SaveState();
     }
  }

//+------------------------------------------------------------------+
//| Xuất nến tuần + sha256                                            |
//+------------------------------------------------------------------+
string Sha256File(const string path)
  {
   int h = FileOpen(path, FILE_READ | FILE_BIN);
   if(h == INVALID_HANDLE)
      return "";
   uchar data[];
   FileReadArray(h, data);
   FileClose(h);
   uchar key[], out[];
   if(CryptEncode(CRYPT_HASH_SHA256, data, key, out) <= 0)
      return "";
   string s = "";
   for(int i = 0; i < ArraySize(out); i++)
      s += StringFormat("%02x", out[i]);
   return s;
  }

void ExportWeek(const long week_start_utc)
  {
   long t[];
   double o[], h[], l[], c[];
   int sp[];
   int n = LoadM15(t, o, h, l, c, sp);
   if(n <= 0)
      return;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   string tag = TimeToString((datetime)week_start_utc, TIME_DATE);
   StringReplace(tag, ".", "-");
   string path = g_dir + "\\candles\\m15_" + tag + ".csv";
   int f = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(f == INVALID_HANDLE)
     {
      Incident("export_failed", path);
      return;
     }
   FileWriteString(f, "timestamp_utc,open,high,low,close,spread_points,ask_open_approx,point\r\n");
   int rows = 0;
   for(int i = 0; i < n; i++)
      if(t[i] >= week_start_utc && t[i] < week_start_utc + 7 * 86400)
        {
         FileWriteString(f, Iso(t[i]) + "," + D(o[i]) + "," + D(h[i]) + "," + D(l[i]) + "," + D(c[i]) + "," +
                         IntegerToString(sp[i]) + "," + D(o[i] + sp[i] * pt) + "," + D(pt, 8) + "\r\n");
         rows++;
        }
   FileClose(f);
   string sha = Sha256File(path);
   int g = FileOpen(path + ".sha256", FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(g != INVALID_HANDLE)
     {
      FileWriteString(g, sha + "  m15_" + tag + ".csv\r\n");
      FileClose(g);
     }
   PrintFormat("[FSR] xuất nến tuần · weekly candle export %s: %d M15 (bid) sha256=%s", tag, rows, sha);
  }

// Thứ Hai 00:00 UTC của tuần chứa utc.
long WeekStart(const long utc)
  {
   long day = Fsr_DayOf(utc);
   long dow = (day + 4) % 7;             // 1970-01-01 là thứ Năm ⇒ 0 = Chủ nhật
   long since_mon = (dow + 6) % 7;
   return (day - since_mon) * 86400;
  }

void MaybeExportPreviousWeek(const long now_utc)
  {
   long prev = WeekStart(now_utc) - 7 * 86400;
   string marker = g_dir + "\\candles\\last_export.txt";
   long last = 0;
   int h = FileOpen(marker, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h != INVALID_HANDLE)
     {
      last = StringToInteger(FileReadString(h));
      FileClose(h);
     }
   if(last >= prev)
      return;
   ExportWeek(prev);
   h = FileOpen(marker, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h, IntegerToString(prev));
      FileClose(h);
     }
  }

//+------------------------------------------------------------------+
//| Vòng chính                                                        |
//+------------------------------------------------------------------+
void OnNewBar(const datetime cur_bar_server, const bool allow_entry)
  {
   long t[];
   double o[], h[], l[], c[];
   int sp[];
   int n = LoadM15(t, o, h, l, c, sp);
   if(n <= 0)
     {
      Incident("copyrates_failed", StringFormat("err=%d", GetLastError()));
      return;
     }
   ReconcileClosed();
   AdoptOrphans();
   ManageLadder(t, h, n);
   if(allow_entry)
      EvaluateAndEnter(t, o, h, l, c, n, cur_bar_server);
   MaybeExportPreviousWeek(ToUtc(cur_bar_server));
  }

void Pump()
  {
   if(!g_ready)
      return;
   datetime cur = iTime(_Symbol, PERIOD_M15, 0);
   if(cur == 0 || cur == g_last_bar)
      return;
   g_last_bar = cur;
   OnNewBar(cur, true);
  }

// Đặt g_gmt_winter/summer theo lựa chọn sàn. Tự động: đo lệch hiện tại (giờ server − giờ GMT, làm tròn giờ)
// rồi suy ra kiểu giờ: 0 ⇒ GMT+0 cả năm; 2 lúc Mỹ chưa đổi giờ hoặc 3 lúc đã đổi ⇒ kiểu New York (2/3);
// khác ⇒ kiểu giờ lạ, EA không chạy (khung giờ 7–19 UTC và nến H1/H4 sẽ sai).
bool ResolveBrokerTime(const bool in_tester)
  {
   if(InpBrokerTime == BT_NY_CLOSE) { g_gmt_winter = 2; g_gmt_summer = 3; return true; }
   if(InpBrokerTime == BT_GMT0)     { g_gmt_winter = 0; g_gmt_summer = 0; return true; }
   if(InpBrokerTime == BT_EU_CLOSE) { g_gmt_winter = 2; g_gmt_summer = 3; g_eu_dst = true; return true; }
   if(in_tester)
     {
      Print("[FSR] ⛔ Strategy Tester không có giờ thật để tự dò — hãy chọn sàn ở mục 3 · In the Strategy Tester, pick your broker in group 3.");
      return false;
     }
   long diff = (long)TimeTradeServer() - (long)TimeGMT();
   int off = (int)MathRound(diff / 3600.0);
   bool dst = Fsr_IsUsDst((long)TimeGMT(), Fsr_YearOf((long)TimeGMT()));
   if(off == 0)                       { g_gmt_winter = 0; g_gmt_summer = 0; }
   else if((dst && off == 3) || (!dst && off == 2)) { g_gmt_winter = 2; g_gmt_summer = 3; }
   else
     {
      PrintFormat("[FSR] ⛔ giờ server lệch GMT %+d giờ — kiểu giờ lạ, EA KHÔNG chạy. Nếu là quỹ/sàn đổi giờ theo châu Âu, "
                  "chọn mục đó ở ô Sàn · unsupported server time (GMT%+d); for EU-DST brokers pick that option.", off, off);
      return false;
     }
   PrintFormat("[FSR] giờ server: lệch GMT mùa đông %+d, mùa hè %+d · server GMT offset winter/summer", g_gmt_winter, g_gmt_summer);
   return true;
  }

int OnInit()
  {
   g_mode = (int)InpMode;
   if(!Fsr5_ModeValid(g_mode))
     {
      PrintFormat("[FSR] ⛔ InpMode không hợp lệ · invalid InpMode (%d).", g_mode);
      return INIT_FAILED;
     }
   g_variant = Fsr5_ModeVariant(g_mode);
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
      Print("[FSR] ⚠️ tài khoản KHÔNG phải DEMO — EA sẽ đặt lệnh TIỀN THẬT, chưa qua kiểm định (xem README) · NOT a demo account — REAL-money orders; strategy not validated (see README).");
   if(_Period != PERIOD_M15 || StringFind(_Symbol, "XAUUSD") != 0)
     {
      PrintFormat("[FSR] ⛔ phải gắn chart XAUUSD M15 · attach to an XAUUSD M15 chart (now %s %s).", _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period));
      return INIT_FAILED;
     }
   // Magic RIÊNG của EA 5 chế độ (khác EA 4 chế độ 881803xx) ⇒ chạy cạnh nhau trên cùng demo không lẫn lệnh.
   long mode_magic[8] = {0, 0, 0, 88180511, 88180512, 88180513, 88180514, 88180515};
   g_magic = InpMagic != 0 ? InpMagic : mode_magic[g_mode];
   if((InpRiskMode == FSR_RISK_USD && !(InpRiskUsd > 0.0))
      || (InpRiskMode == FSR_RISK_PERCENT && !(InpRiskPercent > 0.0 && InpRiskPercent <= FSR_MAX_RISK_PCT)))
     {
      Print("[FSR] ⛔ Rủi ro mỗi lệnh: $ phải > 0, % phải trong (0; 2] · Risk per trade: $ > 0, % in (0; 2].");
      return INIT_FAILED;
     }
   // Kiểm quy đổi giờ server → UTC khớp đồng hồ terminal (sai ⇒ lệch khung giờ 7–19 và biên H4).
   // Strategy Tester: TimeGMT() = giờ server giả lập (không có đồng hồ thật) ⇒ bỏ kiểm này.
   bool in_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   if(InpHours != HOURS_24 && g_mode != FSR_MODE_L07S && (InpHourFrom < 0 || InpHourFrom > 23 || InpHourTo < 0 || InpHourTo > 23))
     {
      Print("[FSR] ⛔ Giờ vào lệnh: Từ/Đến phải trong 0–23 · Trading hours: From/To must be 0–23.");
      return INIT_FAILED;
     }
   // Strategy Tester: TimeLocal() là giờ giả lập, không phải giờ máy thật ⇒ lọc theo giờ máy sẽ sai.
   if(in_tester && InpHours == HOURS_LOCAL && g_mode != FSR_MODE_L07S)
     {
      Print("[FSR] ⛔ Strategy Tester không có giờ máy thật — chọn \"Theo giờ UTC\" ở mục 5 · "
            "In the Strategy Tester, pick \"UTC time\" in group 5.");
      return INIT_FAILED;
     }
   g_version = BuildVersion();
   PrintFormat("[CLMCA] build %s · %s · magic %I64d — bản gốc · official: github.com/pandaluvly/clmca-ea",
               TimeToString(__DATETIME__, TIME_DATE | TIME_MINUTES), g_version, g_magic);
   if(g_mode == FSR_MODE_L07S)
     {
      if(InpHours != HOURS_24)
         Print("[FSR] Mở Cửa London 7h luôn vào nến 07:00 UTC — bỏ qua mục 5 · London Open 7AM always trades the 07:00 UTC bar — group 5 ignored.");
     }
   else if(InpHours == HOURS_24)
      Print("[FSR] Giờ vào lệnh: 24/24 · Trading hours: 24/7.");
   else
     {
      long off = (long)TimeLocal() - (long)TimeGMT();
      off = (long)MathRound(off / 60.0) * 60;
      // Quy khung ra UTC theo PHÚT (máy lệch lẻ như UTC+5:30 ⇒ 07:00 giờ máy = 01:30 UTC). Giờ UTC ⇒ lệch 0.
      long shift = (InpHours == HOURS_UTC) ? 0 : off;
      long f_utc = ((InpHourFrom * 3600 - shift) % 86400 + 86400) % 86400;
      long t_utc = ((InpHourTo * 3600 + 59 * 60 - shift) % 86400 + 86400) % 86400;   // mốc cuối khung = HH:59
      PrintFormat("[FSR] Giờ vào lệnh · Trading hours: %02d:00–%02d:59 %s (máy · PC %s, UTC %s, lệch · offset %+.2fh) = %02d:%02d–%02d:%02d UTC",
                  InpHourFrom, InpHourTo, InpHours == HOURS_UTC ? "UTC" : "giờ máy · PC time",
                  TimeToString(TimeLocal(), TIME_MINUTES), TimeToString(TimeGMT(), TIME_MINUTES), off / 3600.0,
                  (int)(f_utc / 3600), (int)(f_utc % 3600 / 60), (int)(t_utc / 3600), (int)(t_utc % 3600 / 60));
     }
   if(!ResolveBrokerTime(in_tester))
      return INIT_FAILED;
   long est = ToUtc(TimeTradeServer());
   long gmt = (long)TimeGMT();
   if(!in_tester && MathAbs(est - gmt) > 300)
     {
      PrintFormat("[FSR] ⛔ quy đổi giờ server→UTC lệch %I64d s (server=%s gmt=%s). Hãy chọn đúng sàn ở mục 3 · Pick your broker in group 3.",
                  est - gmt, TimeToString(TimeTradeServer()), TimeToString(TimeGMT()));
      return INIT_FAILED;
     }
   g_dir = "fsr5_" + Fsr5_ModeName(g_mode);  
   FolderCreate(g_dir);
   FolderCreate(g_dir + "\\candles");
   g_trade.SetExpertMagicNumber((ulong)g_magic);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   LoadState();
   Incident("ea_start", StringFormat("mode=%s magic=%I64d state_positions=%d", Fsr5_ModeName(g_mode),
            g_magic, ArraySize(g_pos)));
   g_ready = true;
   // Khởi động giữa nến: KHÔNG vào lệnh (giá mở nến đã qua ⇒ lệch parity), chỉ bắt kịp thang SL + ghi đóng.
   g_last_bar = iTime(_Symbol, PERIOD_M15, 0);
   OnNewBar(g_last_bar, false);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_ready)
      Incident("ea_stop", StringFormat("reason=%d", reason));
  }

void OnTick()  { Pump(); }
void OnTimer() { Pump(); }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
  {
   if(!g_ready || trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
      return;
   long pid = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int k = FindPos(pid);    // lọc theo state, KHÔNG theo magic (deal đóng tay/SL có thể mang magic 0)
   if(k < 0)
      return;
   // chỉ ghi khi đã đóng hẳn
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t != 0 && PositionGetInteger(POSITION_IDENTIFIER) == pid)
         return;
     }
   LogClosed(k);
  }
//+------------------------------------------------------------------+
