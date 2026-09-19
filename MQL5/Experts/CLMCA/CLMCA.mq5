//+------------------------------------------------------------------+
//| CLMCA.mq5 — "Có Làm Mới Có Ăn" · XAUUSD M15 · 5 modes            |
//| C_V1 · C_V1_P1b · C_V1_P2 · D_V1 · L07S (xem README.md)          |
//| MIT License · KHÔNG bảo hành · chưa qua kiểm định thống kê.       |
//| Mọi lệnh mở kèm Stop-Loss cứng. Không TP, không martingale.       |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Step-R v1 (ATR) — 5 modes C_V1/P1b/P2/D_V1/L07S for Strategy Tester / demo."

#include <Trade\Trade.mqh>
#include "CLMCACore.mqh"

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
   FSR_RISK_USD = 0,      // Số tiền cố định ($) · Fixed amount ($)
   FSR_RISK_PERCENT = 1   // % số dư tài khoản · % of balance
  };

// Mức rủi ro % số dư mỗi lệnh — giá trị enum = % × 100.
enum ENUM_FSR_RISK_PCT
  {
   RISK_PCT_0_1 = 10,    // 0,1% · rất thận trọng / very conservative
   RISK_PCT_0_25 = 25,   // 0,25% · thận trọng / conservative
   RISK_PCT_0_5 = 50,    // 0,5% · vừa phải / moderate
   RISK_PCT_1 = 100,     // 1% · cao / high
   RISK_PCT_2 = 200,     // 2% · rất cao, dễ cháy tài khoản quỹ / very high
   RISK_PCT_3 = 300,     // 3% · nguy hiểm / dangerous
   RISK_PCT_5 = 500      // 5% · cực kỳ nguy hiểm, 20 lệnh thua ≈ mất 64% / extreme
  };
#define FSR_HISTORY_M15_BARS 12000   // số nến M15 nạp để tính chỉ báo (như backtest), không cho đổi

input group "1. Chiến lược · Strategy"
input ENUM_FSR5_MODE   InpMode           = C_V1;    // Chiến lược · Strategy
input group "2. Rủi ro mỗi lệnh · Risk per trade"
input ENUM_FSR_RISK_MODE InpRiskMode    = FSR_RISK_USD; // Tính rủi ro theo · Risk based on
input double           InpRiskUsd        = 50.0;    // Mất tối đa ($) nếu chạm cắt lỗ · Max loss per trade ($)
input ENUM_FSR_RISK_PCT InpRiskPercent   = RISK_PCT_0_1; // Mất tối đa (% số dư) nếu chạm cắt lỗ · Max loss per trade (% of balance)
input group "3. Giờ server của sàn · Broker server time"
input int              InpServerGmtWinter = 2;      // Lệch UTC mùa đông: Vantage 2, Exness 0 · UTC offset, winter
input int              InpServerGmtSummer = 3;      // Lệch UTC mùa hè: Vantage 3, Exness 0 · UTC offset, summer
input group "4. Nâng cao, không cần đổi · Advanced"
input long             InpMagic          = 0;       // Mã nhận diện lệnh; 0 = tự đặt theo chiến lược · Magic number (0 = auto)
input int              InpDeviationPoints = 50;     // Trượt giá tối đa khi vào lệnh (point) · Max slippage (points)
input int              InpMaxEntryDelaySec = 60;    // Bỏ lệnh nếu trễ quá N giây sau khi nến mở · Skip entry if later than N sec


CTrade   g_trade;
int      g_variant = FSR_VARIANT_C;
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
long ToUtc(const datetime server_t)
  {
   return Fsr_ServerToUtc((long)server_t, InpServerGmtWinter, InpServerGmtSummer);
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
      PrintFormat("[FSR] ❌ không mở được %s err=%d", path, GetLastError());
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
              Iso(now) + "," + Fsr5_ModeVersion(g_mode) + "," + kind + ",\"" + detail + "\"");
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
      PrintFormat("[FSR] ❌ không ghi được state err=%d", GetLastError());
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
                 Iso(now) + "," + Fsr5_ModeVersion(g_mode) + "," + IntegerToString(pid) + "," +
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
      reasons = Fsr_SignalReasons(Fsr_HourOf(t[i]), adx[i], dragon, slope, ready, trend,
                                  l[i - 1], e34h[i - 1], e89[i - 1], o[i], c[i], e34h[i], e89[i],
                                  FSR_HOUR_FIRST, FSR_HOUR_LAST,   // khung giờ CỐ ĐỊNH theo chiến lược (7–19 UTC), không cho đổi
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
      if(!Fsr_SlotFree(g_variant, open_now))
        {
         reasons |= FSR_R_MAX_OPEN;
         if(g_variant == FSR_VARIANT_D)
            Incident("max_open_hit", StringFormat("open=%d cap=%d", open_now, Fsr_MaxOpen(g_variant)));
        }
     }
   if(reasons == 0)
      action = TryEnter(t[i], e89[i], stop_buf, atr[i], dragon, slope, h4c_v, h4e34_v, h4e89_v, open_now, losses,
                        cur_bar_server);

   AppendLine("signals.csv",
              "c1_open_utc,strategy_version,reasons,adx14,dragon_width,ema34_slope,ema34_high,ema89,h1_ready_bars,h4_ready_bars,htf_trend,open_positions,losses_today,action,atr14,min_dragon,min_slope,stop_buf,h4_close,h4_ema34,h4_ema89",
              Iso(t[i]) + "," + Fsr5_ModeVersion(g_mode) + "," + IntegerToString(reasons) + "," +
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
      return AccountInfoDouble(ACCOUNT_BALANCE) * ((int)InpRiskPercent / 100.0) / 100.0;
   return InpRiskUsd;
  }

string TryEnter(const long signal_utc, const double ema89_c1, const double stop_buf, const double atr_c1,
                const double dragon_c1, const double slope_c1, const double h4c, const double h4e34,
                const double h4e89, const int open_now, const int losses,
                const datetime cur_bar_server)
  {
   long delay = (long)(TimeTradeServer() - cur_bar_server);
   if(delay > InpMaxEntryDelaySec)
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
   string sv = Fsr5_ModeVersion(g_mode);
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
   PrintFormat("[FSR] xuất nến tuần %s: %d nến M15 (bid; H1/H4 research tự gộp theo UTC) sha256=%s", tag, rows, sha);
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

int OnInit()
  {
   g_mode = (int)InpMode;
   if(!Fsr5_ModeValid(g_mode))
     {
      PrintFormat("[FSR] ⛔ InpMode không hợp lệ (%d).", g_mode);
      return INIT_FAILED;
     }
   g_variant = Fsr5_ModeVariant(g_mode);
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
      Print("[FSR] ⚠️ tài khoản KHÔNG phải DEMO — EA sẽ đặt lệnh TIỀN THẬT. chưa qua kiểm định (xem README).");
   if(_Period != PERIOD_M15 || StringFind(_Symbol, "XAUUSD") != 0)
     {
      PrintFormat("[FSR] ⛔ phải gắn chart XAUUSD M15 (đang %s %s).", _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period));
      return INIT_FAILED;
     }
   // Magic RIÊNG của EA 5 chế độ (khác EA 4 chế độ 881803xx) ⇒ chạy cạnh nhau trên cùng demo không lẫn lệnh.
   long mode_magic[8] = {0, 0, 0, 88180511, 88180512, 88180513, 88180514, 88180515};
   g_magic = InpMagic != 0 ? InpMagic : mode_magic[g_mode];
   if(InpRiskMode == FSR_RISK_USD && !(InpRiskUsd > 0.0))
     {
      Print("[FSR] ⛔ Mất tối đa ($) phải > 0 · Max loss ($) must be > 0.");
      return INIT_FAILED;
     }
   // Kiểm quy đổi giờ server → UTC khớp đồng hồ terminal (sai ⇒ lệch khung giờ 7–19 và biên H4).
   // Strategy Tester: TimeGMT() = giờ server giả lập (không có đồng hồ thật) ⇒ bỏ kiểm này; giờ UTC
   // trong tester dựa hoàn toàn vào InpServerGmtWinter/Summer — đặt đúng theo broker của dữ liệu.
   bool in_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   long est = ToUtc(TimeTradeServer());
   long gmt = (long)TimeGMT();
   if(!in_tester && MathAbs(est - gmt) > 300)
     {
      PrintFormat("[FSR] ⛔ quy đổi giờ server→UTC lệch %I64d s (server=%s gmt=%s). Sửa InpServerGmtWinter/Summer.",
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
