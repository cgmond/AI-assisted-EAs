//version 1.1x
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

CTrade            trade;
CPositionInfo     posinfo;
COrderInfo        ordinfo;

int adxHandle, fastMAHandle, slowMAHandle;


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
      
      input int      BarsN = 5;              // No of Bars to identify hihg/low
      int            ExpirationBars = 100;
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

   input group "=== News Filter ==="
      input bool           NewsFilterOn   =     false;    // Filter for News?
      enum sep_dropdown{comma=0, semicolon=1};
      input sep_dropdown   separator      =     0;          // Separator to separate news keywords
      input string         KeyNews        =     "BCB,NFP,JOLTS,Nonfarm,PMI,Reatil,GBDP,Confidence,Interest Rate"; //Keywords in News to avoid (separated by separator)
      input string         NewsCurrencies =     "USD,GBP,EUR,JPY"; //Currencies for News LookUp
      input int            DaysNewsLookup =     100; //No of days to look up news
      input int            StopBeforeMin  =     15; //Stop Trading before (in minutes)
      input int            StartTradingMin=     15; //Start trading after (in minutes)
            bool           TrDisabledNews =     false; //variable to store if trading disabled due to news
            
      ushort   sep_code;
      string   Newstoavoid[];
      datetime LastNewsAvoided;
      
   input group "=== RSI filter ==="
   
      input bool                 RSIFilterOn       =     false;         //Filter for RSI extremes?
      input ENUM_TIMEFRAMES      RSITimeframe      =     PERIOD_H1;     //Timeframe for RSI filter
      input int                  RSIlowerlvl       =     20;            //RSI lower level to filter
      input int                  RSIupperlvl       =     80;            //RSI upper level to filter
      input int                  RSI_MA            =     14;            //RSI Period
      input ENUM_APPLIED_PRICE   RSI_AppPrice      =     PRICE_MEDIAN;  //RSI Applied Price
      
   input group "=== Moving Average Filter ==="
   
      input bool                 MAFilterOn        =     false;         //Filter for Moving Average extremes?
      input ENUM_TIMEFRAMES      MATimeframe       =     PERIOD_H4;     //Timeframe for Moving Average filter
      input int                  PctPricefromMA    =     3;             //% Price is away from MovAvg to be extreme
      input int                  MA_Period         =     200;           //Moving Average period
      input ENUM_MA_METHOD       MA_Mode           =     MODE_EMA;      //Moving average mode/method
      input ENUM_APPLIED_PRICE   MA_AppPrice       =     PRICE_MEDIAN;  //Moving Avg Applied price 


      input group "=== Trend Filter ==="
      
      // ADX Settings
      input bool UseADXFilter = false;     // Enable ADX Strength Filter?
      input int ADX_Period = 14;          
      input int ADX_Weak = 25;            
      input int ADX_Medium = 50;          
      input int ADX_Strong = 75;          
      
      // MA Crossover Settings
      input bool UseMACrossover = false;   // Enable MA Crossover Filter?
      input int FastMA_Period = 9;        
      input int SlowMA_Period = 21;       
      input ENUM_MA_METHOD MA_Method = MODE_EMA;       
      
      // Dynamic BarsN 
      input int BarsN_Weak = 50;          
      input int BarsN_Medium = 30;        
      input int BarsN_Strong = 15;        
      input int BarsN_VeryStrong = 5;     
      
      
      
          

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
   if(HideIndicators==true) TesterHideIndicators(true);
   
   //--- Initialize indicators
   handleRSI = iRSI(_Symbol,RSITimeframe,RSI_MA,RSI_AppPrice);
   
   //--- ADX initialization
   adxHandle = iADX(_Symbol, Timeframe, ADX_Period);
   if(adxHandle == INVALID_HANDLE) {
      Print("Failed to create ADX handle!");
      return(INIT_FAILED);
   }
   ChartIndicatorAdd(0, 1, adxHandle);
   
   
//--- PROPER MA initialization (6 parameters)
   fastMAHandle = iMA(_Symbol, Timeframe, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
   slowMAHandle = iMA(_Symbol, Timeframe, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);

   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE) {
      Print("MA initialization failed! Error: ", GetLastError());
      return(INIT_FAILED);
   }
/*
   // Add to chart
   ChartIndicatorAdd(0, 0, fastMAHandle);
   ChartIndicatorAdd(0, 0, slowMAHandle);

   //--- Strategy Tester Visual Fix (simplified and corrected)
   if(MQLInfoInteger(MQL_TESTER))
   {
      // Get current MA values using indicator buffers
      double fastMAValue[1], slowMAValue[1];
      CopyBuffer(fastMAHandle, 0, 0, 1, fastMAValue);
      CopyBuffer(slowMAHandle, 0, 0, 1, slowMAValue);
      
      // Create visual objects
      ObjectCreate(0, "FastMA_Line", OBJ_TREND, 0, TimeCurrent(), fastMAValue[0]);
      ObjectSetInteger(0, "FastMA_Line", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "FastMA_Line", OBJPROP_WIDTH, 2);
      
      ObjectCreate(0, "SlowMA_Line", OBJ_TREND, 0, TimeCurrent(), slowMAValue[0]);
      ObjectSetInteger(0, "SlowMA_Line", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, "SlowMA_Line", OBJPROP_WIDTH, 2);
      
      // Make lines horizontal
      ObjectSetInteger(0, "FastMA_Line", OBJPROP_RAY, true);
      ObjectSetInteger(0, "SlowMA_Line", OBJPROP_RAY, true);
   }
*/
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
}


void OnTick(){
   
   TrailStop();

   if(IsRSIFilter() || IsUpcomingNews() || IsMAFilter()){
      CloseAllOrders();;
      Tradingenabled=false;
      //ChartSetInteger(0,CHART_COLOR_BACKGROUND,ChartColorTradingOff);
      if(TradingEnabledComm!="Printed")
         Print(TradingEnabledComm);
      TradingEnabledComm="Printed";
      return;   
   }
   
   Tradingenabled=true;
   if(TradingEnabledComm!=""){
      Print("Trading is enabled again.");
      TradingEnabledComm = "";
   }
   
   //ChartSetInteger(0,CHART_COLOR_BACKGROUND,ChartColorTradingOn);
   
   if(!IsNewBar()) return;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(),time);
   
   int Hournow = time.hour;   
    
   if(Hournow<SHChoice){CloseAllOrders(); return;}
   if(Hournow>=EHChoice && EHChoice!=0){CloseAllOrders(); return;}
   
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
   }
   if (SellTotal <= 0 && IsBearishCrossover()) {
      double low = findLow(dynamicBarsN);
      if (low > 0) SendSellOrder(low);
   }   

   double adxValue[1];
   CopyBuffer(adxHandle, 0, 0, 1, adxValue);
   
   Comment(
      "TREND FILTERS\n",
      "ADX: ", DoubleToString(adxValue[0], 1), " (", 
      (adxValue[0] > ADX_Strong ? "Very Strong" : 
       adxValue[0] > ADX_Medium ? "Strong" :
       adxValue[0] > ADX_Weak ? "Medium" : "Weak"), ")\n",
      "BarsN: ", GetDynamicBarsN(), "\n",
      "FastMA: ", DoubleToString(iMA(NULL,0,FastMA_Period,0,MA_Method,PRICE_CLOSE), _Digits), "\n",
      "SlowMA: ", DoubleToString(iMA(NULL,0,SlowMA_Period,0,MA_Method,PRICE_CLOSE), _Digits), "\n",
      "Crossover: ", IsBullishCrossover() ? "Bullish" : (IsBearishCrossover() ? "Bearish" : "Neutral")
   );

}

double findHigh(int barsToCheck) {
   Print("BarsN as per ADX in finding high: ", barsToCheck);
   for (int i = 0; i < 200; i++) {
      if (i > barsToCheck && iHighest(_Symbol, Timeframe, MODE_HIGH, barsToCheck*2+1, i-barsToCheck) == i) 
         return iHigh(_Symbol, Timeframe, i);
   }
   return -1;
}

double findLow(int barsToCheck) {
   Print("BarsN as per ADX in finding low: ", barsToCheck);
   for (int i = 0; i < 200; i++) {
      if (i > barsToCheck && iLowest(_Symbol, Timeframe, MODE_LOW, barsToCheck*2+1, i-barsToCheck) == i) 
         return iLow(_Symbol, Timeframe, i);
   }
   return -1;
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,Timeframe,0);
   if (previousTime!=currentTime){
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

   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationBars * PeriodSeconds(Timeframe);
   
      trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);
}

void SendSellOrder(double entry){

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid < entry + OrderDistPoints * _Point) return;
   
   double tp = entry - Tppoints * _Point;
   
   double sl = entry + Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl-entry);
   
   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationBars * PeriodSeconds(Timeframe);
   
      trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);
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
}

void TrailStop(){

      double sl = 0;
      double tp = 0;
      
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
      for (int i=PositionsTotal()-1; i>=0; i--){
         if(posinfo.SelectByIndex(i)){
            ulong ticket = posinfo.Ticket();
            
               if(posinfo.Magic()==InpMagic && posinfo.Symbol()==_Symbol){
               
                  if(posinfo.PositionType()==POSITION_TYPE_BUY){
                     if(bid-posinfo.PriceOpen()>TslTriggerPoints*_Point){
                        tp = posinfo.TakeProfit();
                        sl = bid - (TslPoints *_Point);
                        
                        if(sl > posinfo.StopLoss() && sl!=0){
                           trade.PositionModify(ticket,sl,tp);
                        }
                     }
                  }
                  else if (posinfo.PositionType()==POSITION_TYPE_SELL){
                     if(ask+(TslTriggerPoints*_Point)<posinfo.PriceOpen()){
                        tp = posinfo.TakeProfit();
                        sl = ask + (TslPoints*_Point);
                        if(sl < posinfo.StopLoss() && sl!=0){
                           trade.PositionModify(ticket,sl,tp);
                        }
                     }
                  }
         }
      }         
   }
}

bool IsUpcomingNews(){

   if(NewsFilterOn==false) return(false);
   
   if(TrDisabledNews && TimeCurrent()-LastNewsAvoided < StartTradingMin*PeriodSeconds(PERIOD_M1)) return true;
   
   TrDisabledNews=false;
   
   string sep;
   switch(separator){
     case 0: sep = ","; break;
     case 1: sep = ";"; 
   }
   
   sep_code = StringGetCharacter(sep,0);
   
   int k = StringSplit(KeyNews,sep_code,Newstoavoid);
   
   MqlCalendarValue values[];
   datetime starttime   = TimeCurrent(); //iTime(_Symbol,PERIOD_D1,0);
   datetime endtime     = starttime + PeriodSeconds(PERIOD_D1) * DaysNewsLookup;
   
   CalendarValueHistory(values,starttime,endtime,NULL,NULL);
   
   for(int i=0; i < ArraySize(values); i++){
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);
      MqlCalendarCountry country;
      CalendarCountryById(event.country_id,country);
      
      if(StringFind(NewsCurrencies,country.currency) < 0) continue;
      
         for(int j=0; j<k; j++){
            string currentevent = Newstoavoid[j];
            string currentnews = event.name;
            if(StringFind(currentnews,currentevent) < 0) continue;
            
            Comment("Next News: ", country.currency, ": ", event.name, " -> ", values[i].time);
            if(values[i].time - TimeCurrent() < StopBeforeMin*PeriodSeconds(PERIOD_M1)){
               LastNewsAvoided = values[i].time;
               TrDisabledNews = true;
               if(TradingEnabledComm=="" || TradingEnabledComm!="Printed"){
                  TradingEnabledComm = "Trading is disabled due to upcoming news: " + event.name;
               }
               return true;
            }
            return false;
         }
         
   }
   return false; 
 }
 
 bool IsRSIFilter(){
 
   if(RSIFilterOn==false)  return(false);
   
   double RSI[];
   
   CopyBuffer(handleRSI,MAIN_LINE,0,1,RSI);
   ArraySetAsSeries(RSI,true);
   
   double RSInow  = RSI[0];
   
   //Comment("RSI = ", RSInow);
   
   if(RSInow>RSIupperlvl || RSInow<RSIlowerlvl){
      if(TradingEnabledComm=="" || TradingEnabledComm!="Printed"){
         TradingEnabledComm = "Trading is disabled due to RSI filter";
      }
      return(true);
   }
   return false;
 }
 
 
 bool IsMAFilter(){
 
   if(MAFilterOn==false)   return(false);
   
   double MovAvg[];
   
   CopyBuffer(handleMovAvg,MAIN_LINE,0,1,MovAvg);
   ArraySetAsSeries(MovAvg,true);
   
   double MAnow   =  MovAvg[0];
   double ask     =  SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
   if (   ask > MAnow * (1 + PctPricefromMA/100) ||
         ask < MAnow * (1 - PctPricefromMA/100)
      ){
         if(TradingEnabledComm=="" || TradingEnabledComm!="Printed"){
            TradingEnabledComm = "Trading is disabled due to Mov Avg Filter";
         }
         return true;
      }
      return false;            
       
 }
/* 
int GetDynamicBarsN() {
   if (!UseADXFilter) return BarsN;

   double adxValue[];
   CopyBuffer(adxHandle, 0, 0, 1, adxValue);
   double adx = adxValue[0];

   if (adx <= ADX_Weak) return BarsN_Weak;
   else if (adx <= ADX_Medium) return BarsN_Medium;
   else if (adx <= ADX_Strong) return BarsN_Strong;
   return BarsN_VeryStrong;
}
*/

//=== REPLACE EXISTING GetDynamicBarsN() WITH THIS ===//
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
   
/*   Print(StringFormat(
      "DEBUG | ADX: %.2f | Selected BarsN: %d (Ranges: W%d/M%d/S%d/VS%d)",
      adxValue[0], calculatedBarsN, BarsN_Weak, BarsN_Medium, BarsN_Strong, BarsN_VeryStrong
   ));
*/   
   return calculatedBarsN;
}
//=== END REPLACE ===//

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
/*
bool IsBullishCrossover() {
   if(!UseMACrossover) return true;

   double fastMA[], slowMA[];
   CopyBuffer(fastMAHandle, 0, 0, 1, fastMA);
   CopyBuffer(slowMAHandle, 0, 0, 1, slowMA);
   
   bool result = (fastMA[0] > slowMA[0]);
   Print("DEBUG | MA Crossover Check | Fast: ", fastMA[0], " | Slow: ", slowMA[0], " | Bullish: ", result);
   
   return result;
}

bool IsBearishCrossover() {
   if(!UseMACrossover) return true;

   double fastMA[], slowMA[];
   CopyBuffer(fastMAHandle, 0, 0, 1, fastMA);
   CopyBuffer(slowMAHandle, 0, 0, 1, slowMA);
   
   bool result = (fastMA[0] < slowMA[0]);
   Print("DEBUG | MA Crossover Check | Fast: ", fastMA[0], " | Slow: ", slowMA[0], " | Bearish: ", result);
   
   return result;
}*/