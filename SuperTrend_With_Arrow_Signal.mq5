//+------------------------------------------------------------------+
//|                                  SuperTrend_With_Arrow_Signal.mq5|
//|                                Copyright 2026, by - 0xisl4m       |
//+------------------------------------------------------------------+
#property copyright " Author of Indicator : 0xisl4m"
#property link      "@0xisl4m"
#property version   "3.0" // Updated: Fixed Alert to prevent touch-alerts
#property indicator_chart_window
#property indicator_plots   3
#property indicator_buffers 5

// --- SECURITY SETTINGS ---
long    TargetAccount = 25336941; 

//--- SuperTrend Line
#property indicator_type1   DRAW_COLOR_LINE 
#property indicator_style1   STYLE_DASH
#property indicator_color1   clrAqua, clrMagenta
#property indicator_width1   1
#property indicator_label1   "SuperTrend"

//--- Buy Arrow
#property indicator_type2   DRAW_ARROW 
#property indicator_color2   clrWhite
#property indicator_width2   1
#property indicator_label2   "Buy Signal"

//--- Sell Arrow
#property indicator_type3   DRAW_ARROW
#property indicator_color3   clrWhite
#property indicator_width3   1
#property indicator_label3   "Sell Signal"

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input int                ATRPeriod           = 10;            
input double             Multiplier          = 5.0;           
input ENUM_APPLIED_PRICE SourcePrice         = PRICE_MEDIAN;  
input bool               TakeWicksIntoAccount= false;         

input group "=== Alert Settings ==="
input bool               EnablePushAlert     = true;          // Send to Mobile App
input bool               EnableDesktopAlert  = false;          // Show Popup on PC

//--- Buffers
double ST_Buffer[];
double ST_Color[];
double BuyArrow[];
double SellArrow[];
double TrendDir[]; 

int atrHandle;
datetime lastAlertTime = 0; 

//+------------------------------------------------------------------+
int OnInit()
{
   if(AccountInfoInteger(ACCOUNT_LOGIN) != TargetAccount)
   {
      Alert("UNAUTHORIZED");
      return(INIT_FAILED);
   }

   atrHandle = iATR(_Symbol, _Period, ATRPeriod);
   
   SetIndexBuffer(0, ST_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, ST_Color,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BuyArrow,  INDICATOR_DATA);
   SetIndexBuffer(3, SellArrow, INDICATOR_DATA);
   SetIndexBuffer(4, TrendDir,  INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(1, PLOT_ARROW, 233); 
   PlotIndexSetInteger(2, PLOT_ARROW, 234); 

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total <= ATRPeriod) return 0;

   int limit = (prev_calculated <= 0) ? 0 : prev_calculated - 1;

   double atr[];
   ArrayResize(atr, rates_total);
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atr) <= 0) return 0;

   for(int i = limit; i < rates_total; i++)
   {
      BuyArrow[i]  = EMPTY_VALUE;
      SellArrow[i] = EMPTY_VALUE;

      double src = (high[i] + low[i]) / 2.0;
      double highPrice = TakeWicksIntoAccount ? high[i] : close[i];
      double lowPrice  = TakeWicksIntoAccount ? low[i]  : close[i];

      double upperBand = src + Multiplier * atr[i];
      double lowerBand = src - Multiplier * atr[i];

      static double finalUpper = 0, finalLower = 0;
      int prevDir = (i > 0) ? (int)TrendDir[i-1] : 1;
      int dir = prevDir;

      if(i > 0)
      {
         if(lowerBand > ST_Buffer[i-1] || close[i-1] < ST_Buffer[i-1]) finalLower = lowerBand;
         else finalLower = ST_Buffer[i-1];

         if(upperBand < ST_Buffer[i-1] || close[i-1] > ST_Buffer[i-1]) finalUpper = upperBand;
         else finalUpper = ST_Buffer[i-1];
      }

      if(prevDir == -1 && highPrice > finalUpper) dir = 1;
      else if(prevDir == 1 && lowPrice < finalLower) dir = -1;

      TrendDir[i] = dir;

      if(dir == 1)
      {
         ST_Buffer[i] = finalLower;
         ST_Color[i]  = 0; 
         if(prevDir == -1) BuyArrow[i] = low[i] - (atr[i] * 0.5);
      }
      else
      {
         ST_Buffer[i] = finalUpper;
         ST_Color[i]  = 1; 
         if(prevDir == 1) SellArrow[i] = high[i] + (atr[i] * 0.5);
      }

      // --- 🛠️ FIX: ALERT ONLY ON CLOSED CANDLE (Non-Repainting) ---
      // rates_total - 2 মানে হলো ঠিক আগের ক্যান্ডেলটি মাত্র ক্লোজ হয়েছে
      if(i == rates_total - 2 && time[i] > lastAlertTime)
      {
         string tf = EnumToString((ENUM_TIMEFRAMES)_Period);
         
         if(prevDir == -1 && dir == 1) // Trend changed to Buy
         {
            string msg = StringFormat("[Trend Alert] %s %s Buy potential from OB (follow Tokyo, New York session) ", _Symbol, tf);
            if(EnableDesktopAlert) Alert(msg);
            if(EnablePushAlert)    SendNotification(msg);
            lastAlertTime = time[i];
         }
         else if(prevDir == 1 && dir == -1) // Trend changed to Sell
         {
            string msg = StringFormat("[Trend Alert] %s %s Sell potential from OB (follow Tokyo, New York session) ", _Symbol, tf);
            if(EnableDesktopAlert) Alert(msg);
            if(EnablePushAlert)    SendNotification(msg);
            lastAlertTime = time[i];
         }
      }
   }
   return rates_total;
}

void OnDeinit(const int reason) { IndicatorRelease(atrHandle); }
