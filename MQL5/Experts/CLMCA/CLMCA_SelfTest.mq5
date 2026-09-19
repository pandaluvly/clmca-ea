//+------------------------------------------------------------------+
//| CLMCA_SelfTest.mq5 — tự kiểm hàm thuần. Kéo vào chart bất kỳ,     |
//| xem tab Experts: phải ra PASS ... fail=0.                         |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict
#include "CLMCACore.mqh"

int g_fail = 0, g_pass = 0;

void Check(const bool cond, const string name)
  {
   if(cond)
      g_pass++;
   else
     {
      g_fail++;
      PrintFormat("[FSR-SELFTEST] FAIL %s", name);
     }
  }

bool Near(const double a, const double b, const double eps = 1e-9) { return MathAbs(a - b) <= eps; }

int Sig(const int hour, const double adx, const double dragon, const double slope, const bool ready,
        const bool trend, const double c2l, const double c2e34, const double c2e89,
        const double c1o, const double c1c, const double c1e34, const double c1e89)
  {
   return Fsr_SignalReasons(hour, adx, dragon, slope, ready, trend, c2l, c2e34, c2e89, c1o, c1c, c1e34, c1e89);
  }

int Base(const int hour = 10, const double adx = 22.0, const double dragon = 1.2, const double slope = 0.25,
         const bool ready = true, const bool trend = true, const double c2l = 100.0, const double c1c = 101.0,
         const double c1e34 = 100.5, const double c1e89 = 100.9)
  {
   return Sig(hour, adx, dragon, slope, ready, trend, c2l, 100.0, 90.0, 100.0, c1c, c1e34, c1e89);
  }

long Ep(const int y, const int m, const int d, const int hh = 0, const int mi = 0)
  {
   return Fsr_DaysFromCivil(y, m, d) * 86400 + hh * 3600 + mi * 60;
  }

void OnStart()
  {
   // TV-FSR-01 EMA đệ quy
   double src[4] = {1.0, 2.0, 4.0, 8.0}, e[];
   Fsr_Ema(src, 4, 3, e);
   Check(Near(e[0], 1.0) && Near(e[1], 1.5) && Near(e[2], 2.75) && Near(e[3], 5.375), "TV-FSR-01 ema");

   // TV-FSR-02 ADX: chuỗi ngắn = 0; xu hướng mạnh > 50 cả hai chiều
   double h[60], l[60], c[60], a[];
   for(int i = 0; i < 60; i++) { h[i] = 100.0 + i; l[i] = 99.0 + i; c[i] = 99.8 + i; }
   Fsr_AdxEma(h, l, c, 15, 14, a);
   Check(ArraySize(a) == 15 && a[14] == 0.0, "TV-FSR-02 adx short n=15");
   Fsr_AdxEma(h, l, c, 16, 14, a);
   Check(a[15] > 0.0, "TV-FSR-02 adx n=16 computed");
   Fsr_AdxEma(h, l, c, 60, 14, a);
   Check(a[59] > 50.0, "TV-FSR-02 adx up");
   double hr[60], lr[60], cr[60];
   for(int i = 0; i < 60; i++) { hr[i] = h[59 - i]; lr[i] = l[59 - i]; cr[i] = c[59 - i]; }
   Fsr_AdxEma(hr, lr, cr, 60, 14, a);
   Check(a[59] > 50.0, "TV-FSR-02 adx down");

   // TV-FSR-03 tín hiệu: biên đúng ngưỡng = vào; từng điều kiện tách riêng
   Check(Base() == 0, "TV-FSR-03 all at threshold");
   Check(Base(6) == FSR_R_HOUR && Base(7) == 0 && Base(19) == 0 && Base(20) == FSR_R_HOUR, "TV-FSR-03 hours");
   Check(Base(10, 21.999999) == FSR_R_ADX, "TV-FSR-03 adx");
   Check(Base(10, 22.0, 1.1999999) == FSR_R_DRAGON, "TV-FSR-03 dragon");
   Check(Base(10, 22.0, 1.2, 0.2499999) == FSR_R_SLOPE, "TV-FSR-03 slope");
   Check(Base(10, 22.0, 1.2, 0.25, false) == FSR_R_NOT_READY, "TV-FSR-03 ready");
   Check(Base(10, 22.0, 1.2, 0.25, true, false) == FSR_R_HTF, "TV-FSR-03 htf");
   Check(Sig(10, 22, 1.2, 0.25, true, true, 100.0, 100.0, 90.0, 101.0, 101.0, 100.5, 100.9) == FSR_R_CONFIRM,
         "TV-FSR-03 close==open");
   Check(Base(10, 22.0, 1.2, 0.25, true, true, 100.0, 101.0, 101.0) == FSR_R_CONFIRM, "TV-FSR-03 close==ema34h");
   Check(Base(10, 22.0, 1.2, 0.25, true, true, 100.0, 101.0, 100.5, 101.0) == FSR_R_CONFIRM, "TV-FSR-03 close==ema89");

   // TV-FSR-04 pullback: một trong hai nhánh
   Check(Sig(10, 22, 1.2, 0.25, true, true, 100.0, 100.0, 50.0, 100, 101, 100.5, 100.9) == 0, "TV-FSR-04 ema34 branch");
   Check(Sig(10, 22, 1.2, 0.25, true, true, 90.0, 80.0, 90.0, 100, 101, 100.5, 100.9) == 0, "TV-FSR-04 ema89 branch");
   Check(Sig(10, 22, 1.2, 0.25, true, true, 100.01, 100.0, 100.0, 100, 101, 100.5, 100.9) == FSR_R_PULLBACK, "TV-FSR-04 none");
   Check(Fsr_HtfTrend(10, 9, 9, 10, 9, 9) && !Fsr_HtfTrend(9, 9, 9, 10, 9, 9) && !Fsr_HtfTrend(10, 9, 9, 10, 9, 10),
         "TV-FSR-04 htf trend");

   // TV-FSR-05 SL ban đầu
   double st;
   Check(Fsr_InitialStop(2000.0, 2000.0, st) && Near(st, 1998.5), "TV-FSR-05 stop ok");
   Check(!Fsr_InitialStop(2001.5, 2000.0, st), "TV-FSR-05 stop == entry rejected");

   // TV-FSR-06 oz
   Check(Fsr_Oz(50, 10.0) == 5 && Fsr_Oz(50, 49.99) == 1 && Fsr_Oz(50, 50.0) == 1 && Fsr_Oz(50, 50.01) == 0, "TV-FSR-06 oz");
   Check(Fsr_Oz(50, 3.0) == 16 && Fsr_Oz(50, 0.0) == 0 && Fsr_Oz(50, -1.0) == 0 && Fsr_Oz(50, 0.001) == FSR_MAX_OZ,
         "TV-FSR-06 oz edges");

   // TV-FSR-07 thang C/D (entry 2000, R 4)
   double mf[8] = {0.99, 1.0, 1.999, 2.0, 2.99, 3.0, 4.5, 7.0};
   double cexp[8] = {-1, -1, -1, 0, 0, 1, 2, 5};
   double dexp[8] = {-1, 0, 0, 0, 0, 1, 2, 5};
   for(int i = 0; i < 8; i++)
     {
      double tg;
      bool hc = Fsr_LadderTarget(FSR_VARIANT_C, 2000.0, 4.0, 2000.0 + mf[i] * 4.0, tg);
      Check(cexp[i] < 0 ? !hc : (hc && Near(tg, 2000.0 + cexp[i] * 4.0, 1e-6)), StringFormat("TV-FSR-07 C mfe=%.3f", mf[i]));
      bool hd = Fsr_LadderTarget(FSR_VARIANT_D, 2000.0, 4.0, 2000.0 + mf[i] * 4.0, tg);
      Check(dexp[i] < 0 ? !hd : (hd && Near(tg, 2000.0 + dexp[i] * 4.0, 1e-6)), StringFormat("TV-FSR-07 D mfe=%.3f", mf[i]));
     }
   double tg2;
   Check(Fsr_LadderTarget(FSR_VARIANT_C, 0.1, 0.1, 0.1 + 0.3 - 1e-12, tg2) && Near(tg2, 0.2, 1e-9), "TV-FSR-07 floor eps");
   Check(!Fsr_LadderTarget(FSR_VARIANT_C, 100.0, 0.0, 200.0, tg2) && !Fsr_LadderTarget(99, 100.0, 1.0, 200.0, tg2),
         "TV-FSR-07 invalid");

   // TV-FSR-08 chỉ siết
   Check(Fsr_ShouldTighten(100.0, 99.0) && !Fsr_ShouldTighten(100.0, 100.0) && !Fsr_ShouldTighten(98.0, 99.0), "TV-FSR-08 tighten");

   // TV-FSR-09 thua ngày qua nửa đêm UTC; hoà vốn tính là thua
   long d0 = 20000 * 86400;
   long ex[4];
   double nt[4] = {-10.0, 0.0, -5.0, 12.0};
   ex[0] = d0 + 23 * 3600 + 59 * 60;
   ex[1] = d0 + 86400 + 60;
   ex[2] = d0 + 86400 + 120;
   ex[3] = d0 + 3600;
   Check(Fsr_LossesOnDay(ex, nt, 4, 20000) == 1 && Fsr_LossesOnDay(ex, nt, 4, 20001) == 2, "TV-FSR-09 losses");
   Check(!Fsr_LossCapHit(1) && Fsr_LossCapHit(2), "TV-FSR-09 cap");
   Check(Fsr_SlotFree(FSR_VARIANT_C, 2) && !Fsr_SlotFree(FSR_VARIANT_C, 3) && Fsr_SlotFree(FSR_VARIANT_D, 19)
         && !Fsr_SlotFree(FSR_VARIANT_D, 20), "TV-FSR-09 slots");

   // TV-FSR-10 giờ server → UTC (DST Mỹ), gộp khung + as-of
   Check(Fsr_ServerToUtc(Ep(2026, 7, 1, 12), 2, 3) == Ep(2026, 7, 1, 9), "TV-FSR-10 summer");
   Check(Fsr_ServerToUtc(Ep(2026, 1, 15, 12), 2, 3) == Ep(2026, 1, 15, 10), "TV-FSR-10 winter");
   Check(Fsr_NthSunday(2026, 3, 2) == 8 && Fsr_NthSunday(2026, 11, 1) == 1 && Fsr_NthSunday(2025, 11, 1) == 2,
         "TV-FSR-10 sundays");
   Check(Fsr_ServerToUtc(Ep(2026, 3, 9, 12), 2, 3) == Ep(2026, 3, 9, 9)
         && Fsr_ServerToUtc(Ep(2026, 11, 2, 12), 2, 3) == Ep(2026, 11, 2, 10), "TV-FSR-10 transitions");
   Check(Fsr_YearOf(Ep(2026, 1, 1)) == 2026 && Fsr_YearOf(Ep(2025, 12, 31, 23)) == 2025, "TV-FSR-10 year");
   Check(Fsr_HourOf(Ep(2026, 9, 18, 19, 45)) == 19, "TV-FSR-10 hour");
   long t[7] = {0, 900, 1800, 2700, 3600, 4500, 15300};
   double o[7] = {1, 2, 3, 4, 5, 6, 7}, hh[7] = {2, 5, 4, 3, 6, 7, 8}, ll[7] = {0.5, 1, 2, 3, 4, 5, 6},
          cc[7] = {1.5, 3, 3.5, 4.5, 5.5, 6.5, 7.5};
   long bt[];
   double bo[], bh[], bl[], bc[];
   int m = Fsr_Aggregate(t, o, hh, ll, cc, 7, 3600, bt, bo, bh, bl, bc);
   Check(m == 3 && bt[1] == 3600 && bt[2] == 14400 && bo[0] == 1 && bh[0] == 5 && bl[0] == 0.5 && bc[0] == 4.5,
         "TV-FSR-10 aggregate");
   Check(Fsr_AsOfIndex(bt, m, 3600, 3599) == -1 && Fsr_AsOfIndex(bt, m, 3600, 3600) == 0
         && Fsr_AsOfIndex(bt, m, 3600, 18000) == 2, "TV-FSR-10 as-of");

   // TV-FSR-11 hành động thang / mồ côi / history thiếu
   Check(Fsr_LadderAction(100.0, 100.0, 0.5) == FSR_LA_CLOSE && Fsr_LadderAction(100.01, 100.0, 0.5) == FSR_LA_CLOSE,
         "TV-FSR-11 close at/above bid");
   Check(Fsr_LadderAction(99.99, 100.0, 0.5) == FSR_LA_STOPS_WAIT && Fsr_LadderAction(99.51, 100.0, 0.5) == FSR_LA_STOPS_WAIT,
         "TV-FSR-11 stops wait");
   Check(Fsr_LadderAction(99.5, 100.0, 0.5) == FSR_LA_MODIFY && Fsr_LadderAction(99.99, 100.0, 0.0) == FSR_LA_MODIFY
         && Fsr_LadderAction(99.99, 100.0, -1.0) == FSR_LA_MODIFY, "TV-FSR-11 modify");
   Check(Fsr_OrphanUsable(true, 99.0, 100.0) && !Fsr_OrphanUsable(false, 99.0, 100.0) && !Fsr_OrphanUsable(true, 0.0, 100.0)
         && !Fsr_OrphanUsable(true, 100.0, 100.0), "TV-FSR-11 orphan");
   Check(!Fsr_ShouldDropMissing(95) && Fsr_ShouldDropMissing(96), "TV-FSR-11 drop missing");

   // TV-FSR-12 khung giờ tuỳ chọn (mặc định 7..19, vắt nửa đêm, ngoài miền ⇒ false)
   Check(!Fsr_HourInWindow(6, 7, 19) && Fsr_HourInWindow(7, 7, 19) && Fsr_HourInWindow(19, 7, 19)
         && !Fsr_HourInWindow(20, 7, 19), "TV-FSR-12 default edges");
   Check(Fsr_HourInWindow(22, 22, 5) && Fsr_HourInWindow(0, 22, 5) && Fsr_HourInWindow(5, 22, 5)
         && !Fsr_HourInWindow(6, 22, 5) && !Fsr_HourInWindow(21, 22, 5), "TV-FSR-12 wrap");
   Check(Fsr_HourInWindow(0, 0, 23) && Fsr_HourInWindow(23, 0, 23) && !Fsr_HourInWindow(24, 0, 23)
         && !Fsr_HourInWindow(-1, 0, 23) && !Fsr_HourInWindow(5, 24, 3) && Fsr_HourInWindow(12, 12, 12)
         && !Fsr_HourInWindow(13, 12, 12), "TV-FSR-12 all/invalid/single");
   // TV-FSR-13 ATR14 Wilder + ngưỡng 4 mode
   {
    double ah[3] = {10.0, 12.0, 11.0}, al[3] = {8.0, 9.0, 7.0}, ac[3] = {9.0, 11.0, 8.0}, aa[];
    Fsr_AtrWilder(ah, al, ac, 3, 14, aa);
    double a1 = 2.0 + (3.0 - 2.0) / 14.0;
    Check(aa[0] == 2.0 && MathAbs(aa[1] - a1) < 1e-12 && MathAbs(aa[2] - (a1 + (4.0 - a1) / 14.0)) < 1e-12,
          "TV-FSR-13 atr hand");
    double md, ms, sb;
    Check(Fsr_ModeThresholds(FSR_MODE_C_V0, 0.0, md, ms, sb) && md == 1.2 && ms == 0.25 && sb == 1.5, "TV-FSR-13 v0 $");
    Check(Fsr_ModeThresholds(FSR_MODE_D_V1, 2.0, md, ms, sb) && md == FSR_K_WIDTH * 2.0 && ms == FSR_K_SLOPE * 2.0
          && sb == FSR_K_BUF * 2.0, "TV-FSR-13 v1 atr");
    Check(!Fsr_ModeThresholds(FSR_MODE_C_V1, 0.0, md, ms, sb) && !Fsr_ModeThresholds(FSR_MODE_C_V1, -1.0, md, ms, sb)
          && !Fsr_ModeThresholds(5, 1.0, md, ms, sb), "TV-FSR-13 fail-closed");
    Fsr_ModeThresholds(FSR_MODE_C_V1, 3.0, md, ms, sb);
    Check(Fsr_SignalReasons(10, 22.0, md, ms, true, true, 99.0, 100.0, 98.0, 100.0, 101.0, 100.5, 99.0, 7, 19, md, ms) == 0
          && Fsr_SignalReasons(10, 22.0, 1.44, 1.0, true, true, 99.0, 100.0, 98.0, 100.0, 101.0, 100.5, 99.0, 7, 19, md, ms) == FSR_R_DRAGON
          && Fsr_SignalReasons(10, 22.0, 1.44, 1.0, true, true, 99.0, 100.0, 98.0, 100.0, 101.0, 100.5, 99.0) == 0,
          "TV-FSR-13 v1 gate vs v0");
    double st1, st2;
    Check(Fsr_InitialStop(2617.3, 1e9, st1) == Fsr_InitialStopBuf(2617.3, FSR_STOP_BUFFER, 1e9, st2) && st1 == st2,
          "TV-FSR-13 v0 stop regression");
    Check(Fsr_ModeName(FSR_MODE_D_V1) == "D_V1" && Fsr_ModeVersion(FSR_MODE_C_V1) == "cand_c_step_r_v1"
          && Fsr_ModeVariant(FSR_MODE_D_V0) == FSR_VARIANT_D && Fsr_ModeIsV1(FSR_MODE_C_V1) && !Fsr_ModeIsV1(FSR_MODE_D_V0),
          "TV-FSR-13 mode map");
   }
   // TV-FSR-14 EA 5 chế độ: pullback P1b/P2, L07S, bảng mode
   {
    Check(Fsr_PullbackP1b(101.0, 100.0, 90.0, 2.0) && !Fsr_PullbackP1b(101.0, 100.0, 90.0, 1.99)
          && !Fsr_PullbackP1b(101.0, 100.0, 90.0, 0.0) && Fsr_PullbackP1b(99.0, 100.0, 90.0, 0.0), "TV-FSR-14 p1b");
    double pl[5] = {50.0, 200.0, 200.0, 200.0, 0.0}, pe[5] = {100, 100, 100, 100, 100}, p9[5] = {90, 90, 90, 90, 90},
           pa[5] = {1, 1, 1, 1, 1};
    Check(!Fsr5_Pullback(FSR_MODE_C_V1_P2, pl, pe, p9, pa, 4), "TV-FSR-14 p2 c5 ignored");
    pl[1] = 95.0;
    Check(Fsr5_Pullback(FSR_MODE_C_V1_P2, pl, pe, p9, pa, 4) && !Fsr5_Pullback(FSR_MODE_C_V1, pl, pe, p9, pa, 4),
          "TV-FSR-14 p2 c4 vs c_v1");
    Check(Fsr_ApplyPullback(FSR_R_ADX | FSR_R_PULLBACK, true) == FSR_R_ADX
          && Fsr_ApplyPullback(FSR_R_ADX, false) == (FSR_R_ADX | FSR_R_PULLBACK), "TV-FSR-14 apply pullback");
    long mon = Ep(2026, 9, 14, 7);
    double sl2 = FSR_K_SLOPE * 2.0;
    Check(Fsr_L07sReasons(mon, true, 10, 9, 9.5, sl2, 2.0) == 0
          && Fsr_L07sReasons(mon + 5 * 86400, true, 10, 9, 9.5, sl2, 2.0) == FSR_R_WEEKEND
          && Fsr_L07sReasons(mon + 900, true, 10, 9, 9.5, sl2, 2.0) == FSR_R_HOUR
          && Fsr_L07sReasons(mon, true, 9.5, 9, 9.5, sl2, 2.0) == FSR_R_HTF
          && Fsr_L07sReasons(mon, true, 10, 9, 9.5, sl2 - 1e-9, 2.0) == FSR_R_SLOPE
          && Fsr_L07sReasons(mon, false, 10, 9, 9.5, sl2, 2.0) == FSR_R_NOT_READY
          && Fsr_L07sReasons(mon, true, 10, 9, 9.5, sl2, 0.0) == FSR_R_ATR_INVALID, "TV-FSR-14 l07s");
    Check(Fsr5_ModeVersion(FSR_MODE_L07S) == "l07s_v1" && Fsr5_ModeVariant(FSR_MODE_C_V1_P2) == FSR_VARIANT_C
          && Fsr5_ModeVariant(FSR_MODE_D_V1) == FSR_VARIANT_D && !Fsr5_ModeValid(FSR_MODE_C_V0)
          && !Fsr_ModeValid(FSR_MODE_L07S), "TV-FSR-14 mode map");
   }
   PrintFormat("[FSR-SELFTEST] %s pass=%d fail=%d", g_fail == 0 ? "PASS" : "FAIL", g_pass, g_fail);
  }
