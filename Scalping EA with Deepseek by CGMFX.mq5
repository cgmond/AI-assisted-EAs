//version 1.23 (Spread buffer OK /retry logic maybe OK 6/17/2025)
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#define _Pip (_Point * 10)  // Add this after #property directives

#include <Trade/Trade.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

CTrade            trade;
CPositionInfo     posinfo;
COrderInfo        ordinfo;

      int adxHandle, fastMAHandle, slowMAHandle,handleTrailMA, handleIchimoku, buybarcounter, sellbarcounter;
      enum     TSLType{Default_Trail=0, Previous_Candle=1, Fast_MA=2, Tenkansen=3};
      // Add these with your other global variables:
      double spreadHistory[];
      int spreadCounter = 0;


   input group "=== Trading Profiles ==="
   
      enum  SystemType{Forex=0, Bitcoin=1, _Gold=2, US_Indices=3};
      input SystemType SType=0; //Trading System applied (Forex, Crypto, Gold, Indices)
      int SysChoice;

   input group "=== Common Trading Inputs ==="   
   
      input double   RiskPercent    =  3;    // Risk as % of Trading Capital
      input ENUM_TIMEFRAMES   Timeframe = PERIOD_M5; //Timeframe to run
      input int      InpMagic = 3333;      // EA identification no.
      input string   TradeComment   = "Scalping with DS by CGMFX"; //Trade Comments 

      enum StartHour {Inactive=0, _0100=1, _0200=2, _0300=3, _0400=4, _0500=5, _0600=6, _0700=7, _0800=8, _0900=9, _1000=10, _1100=11, _1200=12, _1300=13, _1400=14, _1500=15, _1600=16, _1700=17, _1800=18, _1900=19, _2000=20, _2100=21, _2200=22, _2300=23};
      input StartHour SHInput = 0; // Start Hour

      enum EndHour {Inactive=0, _0100=1, _0200=2, _0300=3, _0400=4, _0500=5, _0600=6, _0700=7, _0800=8, _0900=9, _1000=10, _1100=11, _1200=12, _1300=13, _1400=14, _1500=15, _1600=16, _1700=17, _1800=18, _1900=19, _2000=20, _2100=21, _2200=22, _2300=23};
      input EndHour EHInput = 0; // End Hour

      int SHChoice;
      int EHChoice;
      
      input int            BarsN = 5;              // Fixed BarsN (If you don't prefer Dynamic)
      input int            ExpirationBars = 100;
      input int            ExpBarsMult    =  4;    // Expiration bars multiplier
      double         OrderDistPoints = 100;  // No of Bars before order is expired
      double         Tppoints, Slpoints, TslTriggerPoints, TslPoints;
      
      int            handleRSI, handleMovAvg;
      input color    ChartColorTradingOff = clrPink;  // Chart color when EA is Inactive
      input color    ChartColorTradingOn  = clrWhite;  // Chart color when EA is Active
            bool     Tradingenabled       = true;
      input bool     HideIndicators       = true;     // Hide Indicators on Chart?
            string   TradingEnabledComm   = ""; 

   input group "=== Forex Trading Inputs ==="
   
      input int      TppointsInput  = 200;   // Take Profit (10 points = 1 pip)
      input int      SlpointsInput  = 200;   // Stoploss POints (10 points = 1 pip)
      input int      TslTriggerPointsInput  = 15; // Points in profit before Trailing SL is activated (10 points = 1 pip)
      input int      TslPointsInput      = 10;    // Trailing Stop Loss (10 points = 1 pip)

   input group "=== Trailing Stop Management ==="
   
      input TSLType           TrailType               =  0;          //Type of Trailing Stoploss
      input int               PrvCandleN              =  1;          //No of candles to trail SL (if selected)
      input int               FMAPeriod               =  5;          //Fast-moving avg period to trail on (if selected)
      input ENUM_MA_METHOD       MA_Mode           =     MODE_EMA;      //Moving average mode/method
      input ENUM_APPLIED_PRICE   MA_AppPrice       =     PRICE_MEDIAN;  //Moving Avg Applied price 

   input group "=== Crypto Related Input === (effective only under Bitcoin Profile)"
   
      input double TPasPct = 0.4;   //TP as % of Price
      input double SLasPct = 0.4;   // SL as % of Proce
      input double TSLasPctofTP = 5;   // Trail SL as % of TP
      input double TSLTgrasPctofTP = 7; //Trigger of Trail SL % of TP 

   input group "=== Gold Related Input === (effective only under Gold Profile)"
   
      input double TPasPctGold = 0.2;   //TP as % of Price
      input double SLasPctGold = 0.2;   // SL as % of Proce
      input double TSLasPctofTPGold = 5;   // Trail SL as % of TP
      input double TSLTgrasPctofTPGold = 7; //Trigger of Trail SL % of TP 

   input group "=== Indices Related Input === (effective only under Indices Profile)"
   
      input double TPasPctIndices = 0.4;   //TP as % of Price
      input double SLasPctIndices = 0.4;   // SL as % of Proce
      input double TSLasPctofTPIndices = 5;   // Trail SL as % of TP
      input double TSLTgrasPctofTPIndices = 7; //Trigger of Trail SL % of TP 


      input group "=== ADX Filter ==="
      
      // ADX Settings
      input bool                 UseADXFilter      =     false;        // Enable ADX Strength Filter?
      input ENUM_TIMEFRAMES      ADX_Timeframe     =     1;            // ADX Timeframe
      input int                  ADX_Period        =     14;           // ADX Period
      input int                  ADX_Weak          =     25;            
      input int                  ADX_Medium        =     50;          
      input int                  ADX_Strong        =     75;          

      input group "=== MA Crossover Filter ==="

      // MA Crossover Settings
      input bool                 UseMACrossover    =     false;         // Enable MA Crossover Filter?
      input int                  FastMA_Period     =     9;        
      input int                  SlowMA_Period     =     21;       
      input ENUM_MA_METHOD       MA_Method         =     MODE_EMA;       
      input ENUM_APPLIED_PRICE   FastMA_AppPrice   =     PRICE_MEDIAN;  // Fast Moving Avg Applied price 
      input ENUM_APPLIED_PRICE   SlowMA_AppPrice   =     PRICE_MEDIAN;  // Slow Moving Avg Applied price 

      input group "=== BarsN  ==="

      // Dynamic BarsN 
      input int BarsN_Weak = 50;          
      input int BarsN_Medium = 30;        
      input int BarsN_Strong = 15;        
      input int BarsN_VeryStrong = 5;     

      //=== Add this to your existing input groups ===//
      input group "=== Spread Control [Advanced] ==="
      
      input bool   UseSpreadControl    = true;     // Enable spread-based execution?
      input int    MaxSpreadForExec    = 15;       // Max allowed spread (pips)
      input int    SpreadSmoothingBars = 3;        // Bars to average spread over
      input bool   EnableRetry         = true;     // Auto-retry deleted orders?
      input int    RetryAfterBars      = 5;        // Bars to wait before retry
      input double MaxRetryPriceDistance = 50;     // Max distance (points) for retry
      
      input group "=== Trend Override ==="
      
      input bool   UseADXOverride      = true;     // Bypass spread in strong trends?
      input int    ADXOverrideLevel    = 60;       // Min ADX to ignore spread
      
      
//+------------------------------------------------------------------+
//| Calculate average of an array                                    |
//+------------------------------------------------------------------+
double ArrayAverage(double &arr[])
{
   double sum = 0.0;
   for(int i=0; i<ArraySize(arr); i++) sum += arr[i]; 
   return sum / ArraySize(arr);
}

//+------------------------------------------------------------------+
//| Check if price is within 1 pip of pending order                  |
//+------------------------------------------------------------------+
bool IsPriceNearOrder(double orderPrice, ENUM_ORDER_TYPE type)
{
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   return (type == ORDER_TYPE_BUY_STOP && currentAsk >= orderPrice - 20*_Point) ||
          (type == ORDER_TYPE_SELL_STOP && currentBid <= orderPrice + 20*_Point);
}          
//+------------------------------------------------------------------+
//| Spread Calculation Functions                                     |
//+------------------------------------------------------------------+
double GetCurrentSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point; // Spread in points
}

double GetSmoothedSpread()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      // Live market code
      double spreads[];
      CopyBuffer(iSpread(_Symbol, PERIOD_CURRENT, 0), 0, 0, SpreadSmoothingBars, spreads);
      Print("live code in - Average Spread: ", ArrayAverage(spreads));
      return ArrayAverage(spreads);
   }
   else
   {
      // Tester code
      double currentSpread = GetCurrentSpread();
      
      // Store in circular buffer
      spreadHistory[spreadCounter % SpreadSmoothingBars] = currentSpread;
      spreadCounter++;
      
      Print("tester code in, Average Spread: ", ArrayAverage(spreadHistory));
      
      // Return averaged value
      return ArrayAverage(spreadHistory);
   }
}
int OnInit()
{
   //--- Initialize trade settings
   trade.SetExpertMagicNumber(InpMagic);
   
   //--- Chart Appearance
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
      
   //--- Trading hours setup
   SHChoice = SHInput;
   EHChoice = EHInput;
  
   //--- System type selection
   if(SType==0) SysChoice=0;
   if(SType==1) SysChoice=1;
   if(SType==2) SysChoice=2;
   if(SType==3) SysChoice=3;
   
   //--- Risk parameters
   Tppoints = TppointsInput;
   Slpoints = SlpointsInput;
   TslTriggerPoints = TslTriggerPointsInput;
   TslPoints = TslTriggerPointsInput;
   
   //--- Indicator visibility
   if (HideIndicators==true) TesterHideIndicators(true);
   
   
   if (UseADXFilter==true) { adxHandle = iADX(_Symbol, ADX_Timeframe, ADX_Period);    ChartIndicatorAdd(0, 1, adxHandle); }

   if (UseMACrossover==true) {  
      fastMAHandle = iMA(_Symbol, Timeframe, FastMA_Period, 0, MA_Method, FastMA_AppPrice);
      slowMAHandle = iMA(_Symbol, Timeframe, SlowMA_Period, 0, MA_Method, SlowMA_AppPrice);
   }

   if(TrailType==2)  handleTrailMA  =  iMA(_Symbol,Timeframe,FMAPeriod,0,MA_Mode,MA_AppPrice);
   if(TrailType==3)  handleIchimoku =  iIchimoku(_Symbol,Timeframe,9,26,52);

   if(MQLInfoInteger(MQL_TESTER))
      ArrayResize(spreadHistory, SpreadSmoothingBars);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
}


void OnTick(){

   TrailStop();
 
   if(!IsNewBar()) return;
   
      if(UseSpreadControl){
      double avgSpreadPips = GetSmoothedSpread();
      double adxBuffer[];
      CopyBuffer(adxHandle, 0, 0, 1, adxBuffer);
      double adxValue = adxBuffer[0];
      bool spreadAllowed = (avgSpreadPips <= MaxSpreadForExec) || (UseADXOverride && adxValue >= ADXOverrideLevel);
      
      // Check pending orders
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         if(ordinfo.SelectByIndex(i) && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic)
         {  Print("Checking magic number: ", InpMagic);
            if(IsPriceNearOrder(ordinfo.PriceOpen(), ordinfo.OrderType()) && !spreadAllowed)
            {  Print("Checking is spread is allowed.");
               // Replace the order deletion code with:
               trade.OrderDelete(ordinfo.Ticket());
               Print("Order ", ordinfo.Ticket(), " deleted. Spread: ", GetSmoothedSpread(), 
                     " pips (Max: ", MaxSpreadForExec, ")");
                     
               if(EnableRetry) 
               {  
                  Print("Retry order buffer.");
                  ordinfo.SelectByIndex(i); // Ensure we have the correct order selected
                  RetryOrderBuffer(ordinfo.PriceOpen(), 
                                  ordinfo.OrderType(), 
                                  ordinfo.VolumeCurrent());
               }
            }
         }
      }
      
      // Process retries (called every bar)
      
      if(EnableRetry) 
         {//Print("Calling process retries function."); 
         ProcessRetries();}

        
   }
  
   //ChartSetInteger(0,CHART_COLOR_BACKGROUND,ChartColorTradingOn);
   //Print("This is after trading enabled comm IF");
   
//   if(!IsNewBar()) {Print("Is not new bar?? Why??"); return;}
   
      //Print("New bar? Yes.");

   MqlDateTime time;
   TimeToStruct(TimeCurrent(),time);
   
   int Hournow = time.hour;   
    
   if(Hournow<SHChoice){   Print("Hour now < Start choice."); CloseAllOrders(); return;}
   if(Hournow>=EHChoice && EHChoice!=0){Print("Hour now > End choice.");CloseAllOrders(); return;}
   
   if(SysChoice==1){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      Tppoints = ask * TPasPct;
      Slpoints = ask * SLasPct;
      OrderDistPoints = Tppoints/2;
      TslPoints = Tppoints * TSLTgrasPctofTP/100;
      TslTriggerPoints = Tppoints* TSLTgrasPctofTP/100;
   }
   
      if(SysChoice==2){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      Tppoints = ask * TPasPctGold;
      Slpoints = ask * SLasPctGold;
      OrderDistPoints = Tppoints/2;
      TslPoints = Tppoints * TSLTgrasPctofTPGold/100;
      TslTriggerPoints = Tppoints* TSLTgrasPctofTPGold/100;
   }
   
      if(SysChoice==3){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      Tppoints = ask * TPasPctIndices;
      Slpoints = ask * SLasPctIndices;
      OrderDistPoints = Tppoints/2;
      TslPoints = Tppoints * TSLTgrasPctofTPIndices/100;
      TslTriggerPoints = Tppoints* TSLTgrasPctofTPIndices/100;
   }
   
   
   int BuyTotal = 0;
   int SellTotal = 0;
   
   for (int i=PositionsTotal()-1; i>=0; i--){
      posinfo.SelectByIndex(i);
      if(posinfo.PositionType()==POSITION_TYPE_BUY && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) BuyTotal++;
      if(posinfo.PositionType()==POSITION_TYPE_SELL && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) SellTotal++;
   }
   
   for(int i=OrdersTotal()-1; i>=0; i--){
      ordinfo.SelectByIndex(i);
      if(ordinfo.OrderType()==ORDER_TYPE_BUY_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) BuyTotal++;
      if(ordinfo.OrderType()==ORDER_TYPE_SELL_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) SellTotal++;
   }
   
   int dynamicBarsN = GetDynamicBarsN();
   
   if (BuyTotal <= 0 && IsBullishCrossover()) {
      double high = findHigh(dynamicBarsN);
      if (high > 0) SendBuyOrder(high);
      Print("Previous buybarcounter: ", buybarcounter, "  Resetting to 0.\n");
      buybarcounter=0;
   }
   if (SellTotal <= 0 && IsBearishCrossover()) {
      double low = findLow(dynamicBarsN);
      if (low > 0) SendSellOrder(low);
      Print("Previous sellbarcounter: ", sellbarcounter, "  Resetting to 0.\n");
      sellbarcounter=0;
   }   
   
   if (BuyTotal>=1) buybarcounter++;
   if (SellTotal>=1) sellbarcounter++;
   
   if (buybarcounter >= GetDynamicBarsN() * ExpBarsMult)  CloseBuyOrders(); 
   if (sellbarcounter >= GetDynamicBarsN() * ExpBarsMult)  CloseSellOrders(); 
   
   
   double adxValue[1];
   CopyBuffer(adxHandle, 0, 0, 1, adxValue);
   
   Comment(
      "TREND FILTERS\n",
      "ADX: ", DoubleToString(adxValue[0], 1), " (", 
      (adxValue[0] > ADX_Strong ? "Very Strong" : 
       adxValue[0] > ADX_Medium ? "Strong" :
       adxValue[0] > ADX_Weak ? "Medium" : "Weak"), ")\n",
      "BarsN: ", GetDynamicBarsN(), "\n",
      "FastMA: ", DoubleToString(iMA(_Symbol,0,FastMA_Period,0,MA_Method,FastMA_AppPrice), _Digits), "\n",
      "SlowMA: ", DoubleToString(iMA(_Symbol,0,SlowMA_Period,0,MA_Method,SlowMA_AppPrice), _Digits), "\n",
      "Crossover: ", IsBullishCrossover() ? "Bullish" : (IsBearishCrossover() ? "Bearish" : "Neutral"),
      "\nExpiration Bars: ", GetExpirationBars(), "\n",
      "Bars count since last BUY order: ", buybarcounter, 
      "\nBars count since lasy SELL order: ", sellbarcounter,"\n"
   );

}

//+------------------------------------------------------------------+
//| Global variables for retry system                                |
//+------------------------------------------------------------------+
struct PendingOrderRetry
{
   double      price;
   double      volume;
   datetime    expiryTime;
   ENUM_ORDER_TYPE type;
   double      sl;
   double      tp;
};
PendingOrderRetry retryQueue[];

void RetryOrderBuffer(double price, ENUM_ORDER_TYPE type, double volume)
{
   // Don't buffer if retry is disabled
   if(!EnableRetry) return;
   
      // Get the original SL/TP from the order
   double sl = ordinfo.StopLoss();
   double tp = ordinfo.TakeProfit();
   
   // Check if this order already exists in queue
   for(int i = 0; i < ArraySize(retryQueue); i++)
   {
      if(MathAbs(retryQueue[i].price - price) < _Point && retryQueue[i].type == type)
         return; // Already exists
   }
   
   // Add to queue
   int size = ArraySize(retryQueue);
   ArrayResize(retryQueue, size+1);
   
   retryQueue[size].price      = price;
   retryQueue[size].type       = type;
   retryQueue[size].volume     = NormalizeDouble(volume, 2);
   retryQueue[size].sl         = sl;
   retryQueue[size].tp         = tp;
   retryQueue[size].expiryTime = TimeCurrent() + RetryAfterBars * PeriodSeconds(Timeframe);
   
   Print("Order buffered for retry. Price: ", price, 
         " Type: ", EnumToString(type), 
         " Volume: ", volume,
         " SL: ", sl,
         " TP: ", tp,
         " Will retry until: ", TimeToString(retryQueue[size].expiryTime));
}

//+------------------------------------------------------------------+
//| Process queued retries                                           |
//+------------------------------------------------------------------+
void ProcessRetries()
{
   // Don't process if spread control is disabled
   if(!UseSpreadControl || !EnableRetry) return;

   for(int i = ArraySize(retryQueue)-1; i >= 0; i--)
   {
      // Check expiry first
      if(TimeCurrent() >= retryQueue[i].expiryTime)
      {
         ArrayRemove(retryQueue, i, 1);
         continue;
      }
      
      // Get current market conditions
      double currentSpread = GetSmoothedSpread();
      double adxValue = 0;
      
      if(UseADXOverride)
      {
         double adxBuffer[];
         if(CopyBuffer(adxHandle, 0, 0, 1, adxBuffer) > 0)
            adxValue = adxBuffer[0];
      }
      
      // Check if conditions are good for retry
      bool spreadOK = (currentSpread <= MaxSpreadForExec) || 
                     (UseADXOverride && adxValue >= ADXOverrideLevel);
      
      if(spreadOK)
      {
         // Calculate price distance from current market
         double priceDistance = 0;
         if(retryQueue[i].type == ORDER_TYPE_BUY_STOP)
            priceDistance = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - retryQueue[i].price;
         else
            priceDistance = retryQueue[i].price - SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
         // Only retry if price hasn't moved too far
         if(priceDistance < (OrderDistPoints * _Point))
         {
            if(retryQueue[i].type == ORDER_TYPE_BUY_STOP)
            {
               trade.BuyStop(
                  retryQueue[i].volume,
                  retryQueue[i].price,
                  _Symbol,
                  retryQueue[i].sl,  // Use stored SL
                  retryQueue[i].tp,  // Use stored TP
                  ORDER_TIME_GTC,
                  0,
                  TradeComment
               );
            }
            else // SELL_STOP
            {
               trade.SellStop(
                  retryQueue[i].volume,
                  retryQueue[i].price,
                  _Symbol,
                  retryQueue[i].sl,  // Use stored SL
                  retryQueue[i].tp,  // Use stored TP
                  ORDER_TIME_GTC,
                  0,
                  TradeComment
               );
            }
            
            if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
               ArrayRemove(retryQueue, i, 1);
            else
               Print("Retry failed. Error: ", trade.ResultRetcodeDescription());
         }
      }
   }
}

void CloseBuyOrders() {

   for(int i=OrdersTotal()-1; i>=0; i--){
      ordinfo.SelectByIndex(i);
      ulong ticket = ordinfo.Ticket();
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic && (ordinfo.OrderType()==ORDER_TYPE_BUY_LIMIT || ordinfo.OrderType()==ORDER_TYPE_BUY_STOP)){
         trade.OrderDelete(ticket);
      }
   }
   
   Print("Close buy orders. Bar count expired. Buy bar counter = ", buybarcounter);
   buybarcounter=0;

}

void CloseSellOrders() {

   for(int i=OrdersTotal()-1; i>=0; i--){
      ordinfo.SelectByIndex(i);
      ulong ticket = ordinfo.Ticket();
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic && (ordinfo.OrderType()==ORDER_TYPE_SELL_LIMIT || ordinfo.OrderType()==ORDER_TYPE_SELL_STOP)){
         trade.OrderDelete(ticket);
      }
   }

   Print("Close sell orders. Bar count expired. Sell bar counter = ", sellbarcounter);

   sellbarcounter=0;
}

double findHigh(int barsToCheck){
   double highestHigh = 0;
      for(int i = 0; i < 200; i++){
         double high = iHigh(_Symbol,Timeframe,i);
         if(i > barsToCheck && iHighest(_Symbol,Timeframe,MODE_HIGH,barsToCheck*2+1,i-barsToCheck) == i){
           if(high > highestHigh){
              return   high;
           }
         }
         highestHigh = MathMax(high,highestHigh);
   }
   return -1;
}

double findLow(int barsToCheck){
   double lowestLow = DBL_MAX;
   for (int i = 0; i < 200; i++){
      double low = iLow(_Symbol,Timeframe,i);
      if(i > barsToCheck && iLowest(_Symbol,Timeframe,MODE_LOW,barsToCheck*2+1,i-barsToCheck) == i){
         if(low < lowestLow){
            return low;
         }
      }
      lowestLow = MathMin(low,lowestLow);
   }
   return -1;
}


bool IsNewBar(){ 
   //Print("Checking new bar function");
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,Timeframe,0);
   //Print("Inside isnewbar function. Symbol: ", _Symbol, " Timeframe: ", Timeframe);
   if (previousTime!=currentTime){ 
      //Print("It should be new bar!!!");
      previousTime=currentTime;
      return true;
   }
   return false;
}

void SendBuyOrder(double entry){

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
   if(ask > entry - OrderDistPoints * _Point) return;
   
   double tp = entry + Tppoints * _Point;
   double sl = entry - Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(entry-sl);

   datetime expiration = iTime(_Symbol,Timeframe,0) + GetExpirationBars() * PeriodSeconds(Timeframe);
   
      trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,0);
      Print("Buy Order Expiration: ", expiration);
}

int GetExpirationBars() {
   
   int NewDynamicBarsN = GetDynamicBarsN();
   
   int NewExpirationBars;
   
   NewExpirationBars = NewDynamicBarsN * ExpBarsMult;
   
   return NewExpirationBars;
   

}
void SendSellOrder(double entry){

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid < entry + OrderDistPoints * _Point) return;
   
   double tp = entry - Tppoints * _Point;
   
   double sl = entry + Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl-entry);
   
   datetime expiration = iTime(_Symbol,Timeframe,0) + GetExpirationBars() * PeriodSeconds(Timeframe);
   
      trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,0);
      Print("Sell Order Expiration: ", expiration);

}


double calcLots(double slPoints){
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;

   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minvolume = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double maxvolume = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   double volumelimit = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   
   
   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
   double lots = MathFloor(risk / moneyPerLotstep) * lotstep;
   
   if(volumelimit!=0) lots = MathMin(lots,volumelimit);
   if(maxvolume!=0) lots = MathMin(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   if(minvolume!=0) lots = MathMin(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble(lots,2);
   
   return lots;
}


void CloseAllOrders(){

   for(int i=OrdersTotal()-1; i>=0; i--){
      ordinfo.SelectByIndex(i);
      ulong ticket = ordinfo.Ticket();
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic){
         trade.OrderDelete(ticket);
      }
   }
   Print("Close all orders. Sell bar counter = ", sellbarcounter, "\nBuy bar counter = ", buybarcounter);
   buybarcounter=0;
   sellbarcounter=0;
}

void TrailStop(){

      double sl = 0;
      double tp = 0;
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      int   stoplevel   = (int) SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
      double indbuffer[]; 
      
      for (int i=PositionsTotal()-1; i>=0; i--){
         if(posinfo.SelectByIndex(i)){
            ulong ticket = posinfo.Ticket();
            if(posinfo.Magic()==InpMagic && posinfo.Symbol()==_Symbol){
            
               if(posinfo.PositionType()==POSITION_TYPE_BUY){
                  if(bid-posinfo.PriceOpen()>TslTriggerPoints*_Point){
                     tp = posinfo.TakeProfit();
                     if(posinfo.StopLoss()<posinfo.PriceOpen()){
                        sl = bid - (TslPoints *_Point);
                        trade.PositionModify(ticket,sl,tp);
                     }
                  }
                  switch(TrailType){
                     case 0:  sl = bid - (TslPoints * _Point);
                              break;
                     
                     case 1:  sl = iLow(_Symbol,Timeframe,PrvCandleN); 
                              Print("iLow: ", sl);
                              break;
                              
                     case 2:  CopyBuffer(handleTrailMA,MAIN_LINE,1,1,indbuffer);
                              ArraySetAsSeries(indbuffer,true);
                              sl = NormalizeDouble(indbuffer[0],_Digits);
                              break;
                              
                     case 3:  CopyBuffer(handleIchimoku,TENKANSEN_LINE,1,1,indbuffer);
                              ArraySetAsSeries(indbuffer,true);
                              sl = NormalizeDouble(indbuffer[0],_Digits);
                              break;                                 
                  }
                  if(sl > posinfo.StopLoss() && sl!=0 && sl > posinfo.PriceOpen() && sl < bid){
                     trade.PositionModify(ticket,sl,tp);
                  }
               }
              
               else if (posinfo.PositionType()==POSITION_TYPE_SELL){
                  if(ask+(TslTriggerPoints*_Point)<posinfo.PriceOpen()){
                     tp = posinfo.TakeProfit();
                     if(posinfo.StopLoss()>posinfo.PriceOpen()){
                        sl = ask + (TslPoints*_Point);
                        trade.PositionModify(ticket,sl,tp);
                     }
                  }
                  switch(TrailType){
                     case 0:  sl = ask + (TslPoints * _Point);
                              break;
                     
                     case 1:  sl = iHigh(_Symbol,Timeframe,PrvCandleN); 
                              Print("iHigh: ", sl);
                              break;
                              
                     case 2:  CopyBuffer(handleTrailMA,MAIN_LINE,1,1,indbuffer);
                              ArraySetAsSeries(indbuffer,true);
                              sl = NormalizeDouble(indbuffer[0],_Digits);
                              break;
                        
                     case 3:  CopyBuffer(handleIchimoku,TENKANSEN_LINE,1,1,indbuffer);
                              ArraySetAsSeries(indbuffer,true);
                              sl = NormalizeDouble(indbuffer[0],_Digits);
                              break;                             
                  }
                  if(sl <posinfo.StopLoss() && sl!=0 && sl < posinfo.PriceOpen() && sl > ask){
                     trade.PositionModify(ticket,sl,tp);
                  }   
               }
            }
         }
      }            
   
}


 
 

int GetDynamicBarsN()
{
   if(!UseADXFilter) 
   {
      Print("DEBUG | Using default BarsN: ", BarsN);
      return BarsN;
   }
   
   double adxValue[1];
   CopyBuffer(adxHandle, 0, 0, 1, adxValue);
   
   int calculatedBarsN = BarsN; // Default
   if(adxValue[0] <= ADX_Weak) calculatedBarsN = BarsN_Weak;
   else if(adxValue[0] <= ADX_Medium) calculatedBarsN = BarsN_Medium;
   else if(adxValue[0] <= ADX_Strong) calculatedBarsN = BarsN_Strong;
   else calculatedBarsN = BarsN_VeryStrong;
   
   return calculatedBarsN;
}

bool IsBullishCrossover() {
   if (!UseMACrossover) return true;

   double fastMA[], slowMA[];
   CopyBuffer(fastMAHandle, 0, 0, 1, fastMA);
   CopyBuffer(slowMAHandle, 0, 0, 1, slowMA);
   return (fastMA[0] > slowMA[0]);
}

bool IsBearishCrossover() {
   if (!UseMACrossover) return true;

   double fastMA[], slowMA[];
   CopyBuffer(fastMAHandle, 0, 0, 1, fastMA);
   CopyBuffer(slowMAHandle, 0, 0, 1, slowMA);
   return (fastMA[0] < slowMA[0]);
}
