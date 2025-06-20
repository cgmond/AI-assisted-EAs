//+------------------------------------------------------------------+
//| PSAR Hedge EA - Fibonacci Edition                                |
//| v 1.1 © 2025                                                     |
//+------------------------------------------------------------------+

#property copyright "Mangesh"
#property version   "1.1"
#property strict
#property description "PSAR Hedge EA with Fibonacci position sizing and dynamic risk management"
#property description "Includes visual indicators and improved hedge management"

#include <Trade/Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>

CTrade trade;

// -------------------------------------------------------------------
// Input Parameters
// -------------------------------------------------------------------
input group "General Settings"
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;      // Timeframe
input double InitialLotSize     = 0.1;            // Initial lot size
input double MaxSpreadPips      = 20.0;           // Maximum allowed spread (pips)
input int    MaxHedgeLevels     = 7;              // Maximum hedge levels (1-13)

input group "PSAR Settings"
input double PSARStep           = 0.02;           // PSAR Step
input double PSARMaxStep        = 0.2;            // PSAR Maximum Step

input group "Risk Management"
input double HedgeLossThreshold = 0.25;           // X% of balance/equity to trigger hedging
input double HedgeReductionPerc = 0.5;            // PnL improvement % to reduce hedge
input double HardStopLossPerc   = 5.0;            // Hard Stop-Loss (% of balance)
input double HappyTakeProfitPerc = 3.0;           // Happy Take-Profit (% of balance)

input group "Trading Hours (UTC)"
input int StartHour             = 0;              // Start trading hour (0=all hours)
input int EndHour               = 0;              // End trading hour (0=all hours)

input group "Visual Settings"
input bool ShowVisuals          = true;           // Enable visual indicators
input color LongColor           = clrDodgerBlue;  // Long position color
input color ShortColor          = clrOrangeRed;   // Short position color
input color HedgeColor          = clrGold;        // Hedge indicator color

// -------------------------------------------------------------------
// Global Variables
// -------------------------------------------------------------------
int psarHandle = INVALID_HANDLE;
double psarBuffer[];
double balance;
double equity;
double initialPnL = 0.0;
int hedgeLevel = 0;
ENUM_POSITION_TYPE currentDirection = POSITION_TYPE_BUY;
datetime lastBar = 0;
double fibLotSizes[13] = {1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233}; // Fibonacci sequence

// -------------------------------------------------------------------
// Utility Functions
// -------------------------------------------------------------------
double GetCurrentPnL()
{
   double totalPnL = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         totalPnL += PositionGetDouble(POSITION_PROFIT);
      }
   }
   return totalPnL;
}

double CalculateLotSize()
{
   // Fibonacci position sizing
   if(hedgeLevel >= ArraySize(fibLotSizes)) 
      return InitialLotSize * fibLotSizes[ArraySize(fibLotSizes)-1];
   
   return InitialLotSize * fibLotSizes[hedgeLevel];
}

bool TradingWindowOpen()
{
   if(StartHour == 0 && EndHour == 0) return true;
   if(StartHour == EndHour) return true;
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   
   if(StartHour < EndHour)
      return (hour >= StartHour && hour < EndHour);
   else
      return (hour >= StartHour || hour < EndHour);
}

bool IsNewBar()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, Timeframe, 0, 1, rates) != 1) return false;
   if(rates[0].time == lastBar) return false;
   lastBar = rates[0].time;
   return true;
}

bool LoadPSAR()
{
   ArraySetAsSeries(psarBuffer, true);
   if(CopyBuffer(psarHandle, 0, 0, 1, psarBuffer) != 1)
   {
      Print("Failed to load PSAR buffer: ", GetLastError());
      return false;
   }
   return true;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         trade.PositionClose(ticket);
      }
   }
   hedgeLevel = 0;
   initialPnL = 0.0;
}

void CloseMostRecentHedgePosition()
{
   if(PositionsTotal() == 0) return;
   
   // Find most recent hedge position
   datetime newestTime = 0;
   ulong newestTicket = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > newestTime)
         {
            newestTime = openTime;
            newestTicket = ticket;
         }
      }
   }
   
   if(newestTicket != 0)
   {
      trade.PositionClose(newestTicket);
      if(hedgeLevel > 0) hedgeLevel--;
   }
}

// -------------------------------------------------------------------
// Visual Indicators
// -------------------------------------------------------------------
void CreateVisuals()
{
   if(!ShowVisuals) return;
   
   // Direction Indicator
   ObjectCreate(0, "DirectionLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DirectionLabel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "DirectionLabel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "DirectionLabel", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "DirectionLabel", OBJPROP_FONTSIZE, 10);
   
   // Hedge Level Indicator
   ObjectCreate(0, "HedgeLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HedgeLabel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "HedgeLabel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HedgeLabel", OBJPROP_YDISTANCE, 40);
   ObjectSetInteger(0, "HedgeLabel", OBJPROP_FONTSIZE, 10);
   
   // PnL Indicator
   ObjectCreate(0, "PnLLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PnLLabel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PnLLabel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PnLLabel", OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, "PnLLabel", OBJPROP_FONTSIZE, 10);
   
   // PSAR Status
   ObjectCreate(0, "PSARLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PSARLabel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "PSARLabel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PSARLabel", OBJPROP_YDISTANCE, 80);
   ObjectSetInteger(0, "PSARLabel", OBJPROP_FONTSIZE, 10);
}

void UpdateVisuals()
{
   if(!ShowVisuals) return;
   
   // Get current values
   double currentPnL = GetCurrentPnL();
   double pnlPercent = (balance != 0) ? (currentPnL / balance) * 100 : 0;
   string directionText = (currentDirection == POSITION_TYPE_BUY) ? "LONG" : "SHORT";
   color directionColor = (currentDirection == POSITION_TYPE_BUY) ? LongColor : ShortColor;
   
   // Update direction label
   ObjectSetString(0, "DirectionLabel", OBJPROP_TEXT, "Position: " + directionText);
   ObjectSetInteger(0, "DirectionLabel", OBJPROP_COLOR, directionColor);
   
   // Update hedge label
   ObjectSetString(0, "HedgeLabel", OBJPROP_TEXT, "Hedge Level: " + IntegerToString(hedgeLevel));
   ObjectSetInteger(0, "HedgeLabel", OBJPROP_COLOR, (hedgeLevel > 0) ? HedgeColor : directionColor);
   
   // Update PnL label
   string pnlText = StringFormat("PnL: %.2f (%.2f%%)", currentPnL, pnlPercent);
   ObjectSetString(0, "PnLLabel", OBJPROP_TEXT, pnlText);
   ObjectSetInteger(0, "PnLLabel", OBJPROP_COLOR, (currentPnL >= 0) ? clrLime : clrRed);
   
   // Update PSAR label
   string psarText = (psarBuffer[0] < iClose(NULL, Timeframe, 1)) ? "PSAR: Bullish" : "PSAR: Bearish";
   ObjectSetString(0, "PSARLabel", OBJPROP_TEXT, psarText);
   ObjectSetInteger(0, "PSARLabel", OBJPROP_COLOR, (psarBuffer[0] < iClose(NULL, Timeframe, 1)) ? clrLime : clrRed);
}

// -------------------------------------------------------------------
// Initialization
// -------------------------------------------------------------------
int OnInit()
{
   // Initialize indicators
   psarHandle = iSAR(_Symbol, Timeframe, PSARStep, PSARMaxStep);
   if(psarHandle == INVALID_HANDLE)
   {
      Print("Failed to initialize PSAR: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Set trade parameters
   trade.SetExpertMagicNumber(12345);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Initialize account values
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Create visual objects
   if(ShowVisuals) CreateVisuals();
   
   return INIT_SUCCEEDED;
}

// -------------------------------------------------------------------
// Deinitialization
// -------------------------------------------------------------------
void OnDeinit(const int reason)
{
   if(psarHandle != INVALID_HANDLE)
      IndicatorRelease(psarHandle);
      
   // Delete visual objects
   if(ShowVisuals)
   {
      ObjectDelete(0, "DirectionLabel");
      ObjectDelete(0, "HedgeLabel");
      ObjectDelete(0, "PnLLabel");
      ObjectDelete(0, "PSARLabel");
   }
}

// -------------------------------------------------------------------
// Main Trading Logic
// -------------------------------------------------------------------
void OnTick()
{
   // Update account values
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Check trading window
   if(!TradingWindowOpen()) return;
   
   // Only process on new bar
   if(!IsNewBar()) return;
   
   // Load indicator values
   if(!LoadPSAR()) return;
   
   // Check spread
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spreadPips = spread * _Point / _Point;
   if(spreadPips > MaxSpreadPips)
   {
      Print("Spread too high: ", spreadPips, " pips (max: ", MaxSpreadPips, ")");
      return;
   }
   
   // Get current price and PSAR value
   double closePrice = iClose(NULL, Timeframe, 1);
   double psarValue = psarBuffer[0];
   bool isPSARBelow = psarValue < closePrice;
   
   // Calculate current PnL
   double currentPnL = GetCurrentPnL();
   double pnlPercent = (balance != 0) ? (currentPnL / balance) * 100 : 0;
   
   // Check Hard Stop-Loss and Happy Take-Profit
   if(currentPnL <= (-balance * (HardStopLossPerc / 100.0)))
   {
      Print("Hard Stop-Loss triggered at ", currentPnL);
      CloseAllPositions();
      return;
   }
   else if(currentPnL >= (balance * (HappyTakeProfitPerc / 100.0)))
   {
      Print("Happy Take-Profit reached at ", currentPnL);
      CloseAllPositions();
      return;
   }
   
   // Dynamic Hedge Reduction
   if(hedgeLevel > 0 && currentPnL > initialPnL * (1 + (HedgeReductionPerc / 100.0)))
   {
      Print("PnL improved by ", HedgeReductionPerc, "%. Reducing hedge level.");
      CloseMostRecentHedgePosition();
      initialPnL = currentPnL;
   }
   
   // Check for PSAR flip
   bool positionExists = PositionsTotal() > 0;
   ENUM_POSITION_TYPE newDirection = isPSARBelow ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   if(!positionExists)
   {
      // No positions - enter new trade
      double lotSize = CalculateLotSize();
      if(newDirection == POSITION_TYPE_BUY)
      {
         trade.Buy(lotSize, _Symbol, 0, 0, 0, "Initial BUY");
      }
      else
      {
         trade.Sell(lotSize, _Symbol, 0, 0, 0, "Initial SELL");
      }
      currentDirection = newDirection;
      hedgeLevel = 0;
      initialPnL = 0.0;
   }
   else if(newDirection != currentDirection)
   {
      // PSAR flip detected
      if(currentPnL > 0)
      {
         // Profit - close all and reverse
         Print("PSAR flip with profit. Closing all positions.");
         CloseAllPositions();
      }
      else if(pnlPercent >= -HedgeLossThreshold)
      {
         // Small loss - close all
         Print("PSAR flip with small loss (", pnlPercent, "%). Closing all.");
         CloseAllPositions();
      }
      else
      {
         // Large loss - add hedge
         if(hedgeLevel >= MaxHedgeLevels)
         {
            Print("Max hedge levels reached. Closing all positions.");
            CloseAllPositions();
         }
         else
         {
            hedgeLevel++;
            double lotSize = CalculateLotSize();
            Print("Adding hedge level ", hedgeLevel, " (", lotSize, " lots)");
            
            if(newDirection == POSITION_TYPE_BUY)
            {
               trade.Buy(lotSize, _Symbol, 0, 0, 0, "Hedge BUY L"+IntegerToString(hedgeLevel));
            }
            else
            {
               trade.Sell(lotSize, _Symbol, 0, 0, 0, "Hedge SELL L"+IntegerToString(hedgeLevel));
            }
            currentDirection = newDirection;
            initialPnL = currentPnL;
         }
      }
   }
   
   // Update visual indicators
   if(ShowVisuals) UpdateVisuals();
}
//+------------------------------------------------------------------+