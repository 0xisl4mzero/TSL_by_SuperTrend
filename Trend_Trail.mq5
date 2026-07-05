//+------------------------------------------------------------------+
//|                                    SuperTrend_EA_With_TSL_v6.mq5 |
//|                                     Copyright 2026, by - 0xisl4m |
//+------------------------------------------------------------------+
#property copyright "Author of Indicator : 0xisl4m"
#property link      "@0xisl4m"
#property version   "6.00"
#property description "EA that works both as a visual indicator and an active TSL trailing stop."

//--- Includes
#include <Trade\Trade.mqh> 

// --- SECURITY SETTINGS ---
long TargetAccount = 25336941; 

//+------------------------------------------------------------------+
//--- Input Group for Organization
input group "=== SuperTrend Settings ==="   // This group for live chart indicator visual rendering
input int                InpMagic             = 915100;
input int                ATRPeriod            = 10;            
input double             Multiplier           = 5.0;           
input ENUM_APPLIED_PRICE SourcePrice          = PRICE_MEDIAN;  
input bool               TakeWicksIntoAccount = false;         

input group "=== TSL Settings ==="         // This group for independent timeframe TSL trailing rules
input bool               TSLFilterOn          = true;         // FIX: Set default to true so it works immediately!
input ENUM_TIMEFRAMES    TSLTimeframe         = PERIOD_M5;     // Timeframe for TSL calculation working
input int                TSL_ATRPeriod        = 10;            
input double             TSL_Multiplier       = 5.0;           
input ENUM_APPLIED_PRICE TSL_SourcePrice      = PRICE_MEDIAN;  
input bool               TSL_TakeWicksIntoAccount = false;  

input group "=== Alert Settings ==="
input bool               EnablePushAlert      = true;          // Send to Mobile App
input bool               EnableDesktopAlert   = false;         // Show Popup on PC

//--- Global Handles & Variable Declarations
int    handleVisualIndicator = INVALID_HANDLE;
int    handleTSLIndicator    = INVALID_HANDLE;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Structural Security Validation Check
   if(AccountInfoInteger(ACCOUNT_LOGIN) != TargetAccount)
   {
      Alert("UNAUTHORIZED");
      return(INIT_FAILED);
   }

   // 2. Initialize Visual Chart Indicator Instance
   handleVisualIndicator = iCustom(_Symbol, PERIOD_CURRENT, "SuperTrend_With_Arrow_Signal", 
                                   ATRPeriod, Multiplier, SourcePrice, TakeWicksIntoAccount, 
                                   EnablePushAlert, EnableDesktopAlert);
                                   
   if(handleVisualIndicator == INVALID_HANDLE)
   {
      Print("Failed to load visual SuperTrend indicator file.");
      return(INIT_FAILED);
   }

   // Attach the indicator view cleanly to the main chart grid space
   if(!ChartIndicatorAdd(0, 0, handleVisualIndicator))
   {
      Print("Error pushing indicators presentation layer to main window. Code: ", GetLastError());
   }

   // 3. Initialize TSL Core Handle (Always initialize safely to prevent broken buffers)
   handleTSLIndicator = iCustom(_Symbol, TSLTimeframe, "SuperTrend_With_Arrow_Signal", 
                                TSL_ATRPeriod, TSL_Multiplier, TSL_SourcePrice, TSL_TakeWicksIntoAccount, 
                                false, false); 
                                   
   if(handleTSLIndicator == INVALID_HANDLE)
   {
      Print("Failed to build backend tracking TSL engine handle.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleVisualIndicator != INVALID_HANDLE) IndicatorRelease(handleVisualIndicator);
   if(handleTSLIndicator != INVALID_HANDLE)    IndicatorRelease(handleTSLIndicator);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Manage Stop Loss changes only if trailing engine is flagged true
   if(TSLFilterOn)
   {
      RunTSLEngine();
   }
}

//+------------------------------------------------------------------+
//| Multi-timeframe Trailing Stop Loss Management Engine             |
//+------------------------------------------------------------------+
void RunTSLEngine()
{
   if(handleTSLIndicator == INVALID_HANDLE) return;

   double stLineBuffer[];
   double trendDirBuffer[];
   ArraySetAsSeries(stLineBuffer, true);
   ArraySetAsSeries(trendDirBuffer, true);
   
   // Read tracking parameters from Index 1 (completed closed candle)
   if(CopyBuffer(handleTSLIndicator, 0, 1, 1, stLineBuffer) <= 0) return;
   if(CopyBuffer(handleTSLIndicator, 4, 1, 1, trendDirBuffer) <= 0) return;
   
   if(stLineBuffer[0] == EMPTY_VALUE || stLineBuffer[0] <= 0) return;
   
   double targetSLValue    = NormalizeDouble(stLineBuffer[0], _Digits);
   int    currentDirection = (int)trendDirBuffer[0];

   // Scan open terminals positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         long posMagic = PositionGetInteger(POSITION_MAGIC);
         
         // Strict Validation: Explicit check filtering out other EAs but cleanly handling Manual (0) or matching inputs
         if(posMagic == 0 || posMagic == InpMagic)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentTP = PositionGetDouble(POSITION_TP);
               ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

               // --- BUY POSITION TRAILING RULES ---
               if(type == POSITION_TYPE_BUY && currentDirection == 1)
               {
                  targetSLValue = NormalizeDouble(targetSLValue, _Digits);
                  // Modify if target is above current SL (or if SL isn't set yet)
                  if(targetSLValue > currentSL || currentSL == 0)
                  {
                     if(targetSLValue < SymbolInfoDouble(_Symbol, SYMBOL_BID))
                     {
                        trade.PositionModify(ticket, targetSLValue, currentTP);
                     }
                  }
               }
               // --- SELL POSITION TRAILING RULES ---
               else if(type == POSITION_TYPE_SELL && currentDirection == -1)
               {
                  targetSLValue = NormalizeDouble(targetSLValue, _Digits);
                  // Modify if target is below current SL (or if SL isn't set yet)
                  if(targetSLValue < currentSL || currentSL == 0)
                  {
                     if(targetSLValue > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
                     {
                        trade.PositionModify(ticket, targetSLValue, currentTP);
                     }
                  }
               }
            }
         }
      }
   }
}
