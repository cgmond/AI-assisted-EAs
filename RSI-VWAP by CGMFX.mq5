//+------------------------------------------------------------------+
//|                                                      RSI-VWAP.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"

// Indicator handles
int higherRSIHandle;
int lowerRSIHandle;
int higherATRHandle;
int trailingATRHandle;

//+------------------------------------------------------------------+
//| Risk calculation methods                                         |
//+------------------------------------------------------------------+
enum ENUM_RISK_TYPE
{
   RISK_FIXED_LOT,       // Fixed lot size
   RISK_BALANCE_PERCENT, // % of account balance
   RISK_EQUITY_PERCENT   // % of account equity
};

//+------------------------------------------------------------------+
//| Input parameters                                                |
//+------------------------------------------------------------------+
input group "Timeframe Settings"
input ENUM_TIMEFRAMES HigherTF = PERIOD_W1;    // Higher timeframe filter
input ENUM_TIMEFRAMES LowerTF = PERIOD_H4;     // Lower timeframe for trades

input group "Indicator Settings"
input int RSIPeriod = 14;                      // RSI period
input int VWAPPeriod = 20;                     // VWAP lookback period
input int ATRPeriod = 14;                      // ATR period
input double ATRMultiplier = 1.0;              // ATR multiplier for SL
input double BuyRSIThreshold = 30.0;           // Buy when RSI <= this value
input double SellRSIThreshold = 70.0;          // Sell when RSI >= this value

input group "Risk Management"
input ENUM_RISK_TYPE RiskType = RISK_BALANCE_PERCENT; // Risk calculation method
input double RiskValue = 1.5;                  // Lot size or % based on RiskType
input double MaxRiskPerTrade = 2.0;            // Maximum risk % per trade
input double MaxSpread = 2.5;                  // Max allowed spread (points)
input bool RetryOnSpread = true;               // Retry if spread exceeds limit
input int MaxRetries = 3;                      // Maximum retry attempts
input int RetryDelay = 500;                    // Retry delay in milliseconds

input group "Trailing Stop"
input bool UseTrailingStop = true;             // Enable trailing stop
input ENUM_TIMEFRAMES TrailingATRTF = PERIOD_D1; // TF for trailing ATR
input double TrailingATRMultiplier = 1.5;      // Multiplier for trailing ATR
input int TrailingStepPips = 10;               // Min distance to move SL

input group "Trade Execution"
input int MagicNumber = 123456;                // EA Magic Number
input string TradeComment = "RSI-VWAP EA";     // Trade comment
input bool EnableFridayClose = true;           // Close 10% on Friday
input int FridayCloseHour = 22;                // Hour to close Friday trades (broker time)

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
datetime LastBarTime;
int SpreadRetryCount = 0;
double PositionSize;
double TrailingATRValue;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   higherATRHandle = iATR(_Symbol, HigherTF, ATRPeriod);
   trailingATRHandle = iATR(_Symbol, TrailingATRTF, ATRPeriod);
   
   if(higherATRHandle == INVALID_HANDLE || trailingATRHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handles");
      return(INIT_FAILED);
   }
   
   // Create indicator handles
   higherRSIHandle = iRSI(_Symbol, HigherTF, RSIPeriod, PRICE_CLOSE);
   lowerRSIHandle = iRSI(_Symbol, LowerTF, RSIPeriod, PRICE_CLOSE);
   
   if(higherRSIHandle == INVALID_HANDLE || lowerRSIHandle == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator handles");
      return(INIT_FAILED);
   }
   // Validate timeframe inputs
   if(LowerTF >= HigherTF)
   {
      Alert("Error: Lower timeframe must be smaller than higher timeframe");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Validate risk parameters
   if(RiskType != RISK_FIXED_LOT && (RiskValue <= 0 || RiskValue > MaxRiskPerTrade))
   {
      Alert("Error: Invalid risk value");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Check for sufficient bars
   if(Bars(_Symbol, HigherTF) < RSIPeriod || Bars(_Symbol, LowerTF) < VWAPPeriod)
   {
      Alert("Error: Not enough historical data");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(higherRSIHandle != INVALID_HANDLE)
      IndicatorRelease(higherRSIHandle);
   if(lowerRSIHandle != INVALID_HANDLE)
      IndicatorRelease(lowerRSIHandle);
   if(higherATRHandle != INVALID_HANDLE)
      IndicatorRelease(higherATRHandle);
   if(trailingATRHandle != INVALID_HANDLE)
      IndicatorRelease(trailingATRHandle);      
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   if(!IsNewBar(LowerTF))
      return;
      
   // Check spread conditions
   if(!CheckSpread())
      return;
      
   // Manage open positions
   ManageOpenPositions();
   
   // Check for new trading signals
   CheckForSignals();
   
   // Friday close routine
   if(EnableFridayClose && IsFridayCloseTime())
      CloseFridayPositions();
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   if(currentBarTime != LastBarTime)
   {
      LastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check spread conditions                                          |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   if(currentSpread > MaxSpread * _Point)
   {
      if(RetryOnSpread && SpreadRetryCount < MaxRetries)
      {
         SpreadRetryCount++;
         Sleep(RetryDelay);
         return false;
      }
      Print("Spread too high: ", currentSpread/_Point, " > ", MaxSpread);
      return false;
   }
   
   SpreadRetryCount = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDistance)
{
   double size = 0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(stopLossDistance <= 0 || tickValue <= 0)
      return 0;
   
   switch(RiskType)
   {
      case RISK_FIXED_LOT:
         size = RiskValue;
         break;
         
      case RISK_BALANCE_PERCENT:
         size = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskValue / 100) / 
               (stopLossDistance * _Point / tickValue);
         break;
         
      case RISK_EQUITY_PERCENT:
         size = (AccountInfoDouble(ACCOUNT_EQUITY) * RiskValue / 100) / 
               (stopLossDistance * _Point / tickValue);
         break;
   }
   
   // Normalize and validate lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   size = MathRound(size / lotStep) * lotStep;
   size = MathMin(MathMax(size, minLot), maxLot);
   
   return size;
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   double higherRSI[1], lowerRSI[1];
   
   // Get higher timeframe RSI
   if(CopyBuffer(higherRSIHandle, 0, 0, 1, higherRSI) != 1)
   {
      Print("Failed to get higher TF RSI");
      return;
   }
   
   // Get lower timeframe RSI
   if(CopyBuffer(lowerRSIHandle, 0, 0, 1, lowerRSI) != 1)
   {
      Print("Failed to get lower TF RSI");
      return;
   }
   
   // Rest of your signal checking logic...
   if(higherRSI[0] > 50.0 && lowerRSI[0] <= BuyRSIThreshold)
   {
      // Buy logic
   }
}

//+------------------------------------------------------------------+
//| Open new position                                                |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType, double lotSize, double sl, double tp)
{
   MqlTradeRequest request;
   ZeroMemory(request);
   MqlTradeResult result = {0};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
      return;
   }
   
   Print("Position opened: ", EnumToString(orderType), " ", lotSize, " lots, SL: ", sl, ", TP: ", tp);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = posType == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      // Get current RSI on lower timeframe
      double currentRSI[1];
      if(CopyBuffer(lowerRSIHandle, 0, 0, 1, currentRSI) != 1)
      {
         Print("Failed to get current RSI");
         return;
      }
// Then use currentRSI[0] instead of currentRSI      
      // Manage buy positions
      if(posType == POSITION_TYPE_BUY)
      {
         // Check if we should close 90%
         if(currentRSI[0] <= 30.0 && volume == PositionSize)
         {
            double closeVolume = NormalizeDouble(volume * 0.9, 2);
            ClosePartialPosition(ticket, closeVolume);
         }
         
         // Update trailing stop if enabled
         if(UseTrailingStop)
            UpdateTrailingStop(ticket, posType, currentPrice);
      }
      // Manage sell positions
      else if(posType == POSITION_TYPE_SELL)
      {
         // Check if we should close 90%
         if(currentRSI[0] <= 30.0 && volume == PositionSize)
         {
            double closeVolume = NormalizeDouble(volume * 0.9, 2);
            ClosePartialPosition(ticket, closeVolume);
         }
         
         // Update trailing stop if enabled
         if(UseTrailingStop)
            UpdateTrailingStop(ticket, posType, currentPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice)
{
   // Get current stop loss
   double currentSL = PositionGetDouble(POSITION_SL);
   
   // Calculate new ATR value for trailing
   double atrValue[1];
   if(CopyBuffer(trailingATRHandle, 0, 0, 1, atrValue) != 1)
   {
      Print("Failed to get ATR value");
      return;
   }
   TrailingATRValue = atrValue[0] * TrailingATRMultiplier;   
   // Calculate new stop loss
   double newSL = 0;
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - TrailingATRValue;
      newSL = MathMax(newSL, currentSL + (TrailingStepPips * _Point));
   }
   else
   {
      newSL = currentPrice + TrailingATRValue;
      newSL = MathMin(newSL, currentSL - (TrailingStepPips * _Point));
   }
   
   // Only modify if we need to move SL
   if((posType == POSITION_TYPE_BUY && newSL > currentSL) || 
      (posType == POSITION_TYPE_SELL && newSL < currentSL))
   {
   MqlTradeRequest request;
   ZeroMemory(request);      
   MqlTradeResult result = {0};
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      request.sl = newSL;
      request.magic = MagicNumber;
      
      if(!OrderSend(request, result))
         Print("Trailing stop update failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Close partial position                                           |
//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double volume)
{
   MqlTradeRequest request;
   ZeroMemory(request);
   MqlTradeResult result = {0};
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Partial close";
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
      Print("Partial close failed: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Check if it's Friday close time                                  |
//+------------------------------------------------------------------+
bool IsFridayCloseTime()
{
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);
   
   return (timeStruct.day_of_week == 5 && // Friday
           timeStruct.hour >= FridayCloseHour &&
           !PositionSelectByTicket(0)); // No positions selected (indicates new check)
}

//+------------------------------------------------------------------+
//| Close Friday positions (10% runner)                              |
//+------------------------------------------------------------------+
void CloseFridayPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double originalVolume = PositionSize;
      
      // Check if this is the 10% runner (volume is ~10% of original)
      if(MathAbs(volume - (originalVolume * 0.1)) < (originalVolume * 0.01)) // Allow 1% tolerance
      {
         // Get higher timeframe RSI
         double higherRSI[1];
         if(CopyBuffer(higherRSIHandle, 0, 0, 1, higherRSI) != 1)
         {
            Print("Failed to get higher TF RSI");
            return;
         }
         // Then use higherRSI[0] instead of higherRSI         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Check if we should close based on weekly RSI
         if((posType == POSITION_TYPE_BUY && higherRSI[0] < 50.0) ||
            (posType == POSITION_TYPE_SELL && higherRSI[0] > 50.0))
         {
            ClosePartialPosition(ticket, volume);
         }
      }
   }
}
//+------------------------------------------------------------------+