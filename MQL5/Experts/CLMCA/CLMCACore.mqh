//+------------------------------------------------------------------+
//| CLMCACore.mqh — hàm thuần (chỉ báo, tín hiệu, thang SL) cho CLMCA |
//| Không I/O, không đặt lệnh. MIT License.                           |
//+------------------------------------------------------------------+
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
