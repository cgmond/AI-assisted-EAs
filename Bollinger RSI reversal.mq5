#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
   CTrade         trade;
   CPositionInfo  posinfo;
   COrderInfo     ordinfo;

#include <Indicators\Trend.mqh>
   CiBands           Bollinger;
   CiBands           TPBol;
   CiIchimoku        Ichimoku;
   CiMA              MovAvgFast, MovAvgSlow;
   
   
#include <Indicators\Oscilators.mqh>
   CiRSI             RSI;
   
   enum     LotTyp      {Lot_per_1k_Capital=0, Fixed_Lot_Size=1};
   enum     IcTypes     {Price_above_Cloud=0, Price_above_Ten=1, Price_above_Kij=2, Price_above_SenA=3, Price_above_SenB=4, Ten_above_Kij=5, Ten_above_Kij_above_Cloud=6, Ten_above_Cloud=7, Kij_above_Cloud=8};
 
      
input group "===   EA specific variables   ==="

   input    ulong             InpMagic          =  23948;            // EA Unique ID (Magic No)
   input    string            TradeComment      =  "BRSI reversal";  //Trade Comments
   input    string            Curren            =  "USDJPY,GBPUSD";  // Currencies for the EA
   input    ENUM_TIMEFRAMES   Timeframe         =  PERIOD_H1;        // Timeframe for the EA (trading)
   
input group "===   Trade Settings (criteria for taking trades)   ==="
   input    int               BollingerMAperiod =  200;              // Bollinger Mov. Avg Value   
   input    double            BollingerStDev    =  4;                // Bollinger st.dev for taking trade
   input    int               RSIUpper          =  80;               // RSI Upper Level (for taking trade)
   input    int               RSILower          =  20;               // RSI Lower Level (for taking trade)
   input    int               RSIPeriod         =  14;               // RSI Period       
   
input group "===   Trade Management   ==="
   input    LotTyp            Lot_Type          =  0;                // Type of Lotsize
   input    double            Lotsize           =  0.02;             // Lotsize if Fixed
   input    double            Lotsizeper1000    =  0.01;             // Lotsize per 1000 Capital
   input    double            TPBolStDev        =  3;                // Bollinger st.dev for TP setting
   input    int               BarsSince         =  100;              // No of Bars before new trade can be taken
   
   ENUM_APPLIED_PRICE         AppPrice          =  PRICE_MEDIAN;     // Moving Avg Applied Price                                                                                                                                                                      
   
   string         Currencies[];
   string         BarsTraded[][2];
   string         sep               =  ",";
   
input group "===   Moving Average Filter   ==="
   input    bool                 MAFilterOn        =  false;            // Buy when Fast MA > Slow MA (vise versa)
   input    ENUM_TIMEFRAMES      MATimeframe       =  PERIOD_D1;        // Timeframe for Mov Average Filter              
   input    int                  Slow_MA_Period    =  200;              // Slow Moving Average Period
   input    int                  Fast_MA_Period    =  50;               // Fast MOving Avergae Period
   input    ENUM_MA_METHOD       MA_Mode           =  MODE_EMA;         // Moving Avergae Mode/Method      
   input    ENUM_APPLIED_PRICE   MA_AppPrice       =  PRICE_MEDIAN;     // Moving Avg Applied Price
   
   
input group "===   Ichimoku Filter   ==="
   input    bool                 IchiFilterOn      =  false;            // Buy only above cloud and sell onmly below cloud
   input    IcTypes              IchiFilterType    =  0;                // Buy above which Ichimoku parameter?
   input    ENUM_TIMEFRAMES      IchiTimeframe     =  PERIOD_D1;        // Ichimoku cloud Timeframe
   input    int                  tenkan            =  9;                // Period of TenkanSen
   input    int                  kijun             =  26;               // Period of KijunSen
   input    int                  senkou_b          =  52;               // Period of SenkouSpanB   
      
      
int OnInit() {

   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0,CHART_SHOW_GRID,false);

   int sep_code   =  StringGetCharacter(sep,0);
   int k          =  StringSplit(Curren,sep_code,Currencies);
   
   ArrayResize(BarsTraded,k);
   for(int i=k-1; i>=0; i--) {
      BarsTraded[i][0]  =  Currencies[i];
      BarsTraded[i][1]  =  IntegerToString(i);
   }
   ArrayPrint(BarsTraded);

   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason) {


}


void OnTick() {

   if(!IsNewBar()) return;

   for(int i=ArraySize(Currencies)-1; i>=0; i--){
      RunSymbols(Currencies[i]);
   }
   
}

void RunSymbols(string symbol) {
   
   TrailSL(symbol);
   
   Bollinger         =  new CiBands;
   Bollinger.Create(symbol,Timeframe,BollingerMAperiod,0,BollingerStDev,AppPrice);
   RSI               =  new CiRSI;
   RSI.Create(symbol,Timeframe,RSIPeriod,AppPrice);
   RSI.Refresh(-1);
   Bollinger.Refresh(-1);
   
   double   FastMA=0, SlowMA=0;
   double   SenA=0, SenB=0, Ten=0, Kij=0;
   
   if(MAFilterOn) {
      MovAvgSlow     =  new CiMA;
      MovAvgSlow.Create(symbol,MATimeframe,Slow_MA_Period,0,MA_Mode,MA_AppPrice);
      MovAvgFast     =  new CiMA;
      MovAvgFast.Create(symbol,MATimeframe,Fast_MA_Period,0,MA_Mode,MA_AppPrice);
      
      MovAvgSlow.Refresh(-1);
      MovAvgFast.Refresh(-1);
      
      FastMA   =  MovAvgFast.Main(1);
      SlowMA   =  MovAvgSlow.Main(1);
   }
   
   if(IchiFilterOn) {
      Ichimoku =  new CiIchimoku;
      Ichimoku.Create(symbol,IchiTimeframe,tenkan,kijun,senkou_b);
      Ichimoku.Refresh(-1);
      
      SenA  =  Ichimoku.SenkouSpanA(1);
      SenB  =  Ichimoku.SenkouSpanB(1);
      Ten   =  Ichimoku.TenkanSen(1);
      Kij   =  Ichimoku.KijunSen(1);   
   }
   
   double   ask               =  SymbolInfoDouble(symbol,SYMBOL_ASK);
   double   bid               =  SymbolInfoDouble(symbol,SYMBOL_BID);
   double   Closex1           =  iClose(symbol,Timeframe,1);
   int      BarsLastTraded     =  GetBarsLastTraded(symbol);
   int      Barsnow           =  iBars(symbol,Timeframe);
   
   double   AccountBalance    =  AccountInfoDouble(ACCOUNT_BALANCE);
   double   lots              =  0.01;
   switch(Lot_Type) {
      case 0:  lots = NormalizeDouble(Lotsizeper1000 * AccountBalance / 1000,2); break;
      case 1:  lots = Lotsize;
   }      
   
   
   if (Closex1 < Bollinger.Lower(1) &&
      Barsnow > BarsLastTraded + BarsSince &&
      RSI.Main(1) < 20) {
   
         if(MAFilterOn && PricevsMovAvg(FastMA,SlowMA)!="above") return;
         if(IchiFilterOn && PricevsIchiCloud(symbol,SenA,SenB,Ten,Kij)!="above") return;
         
         double   tp    =  Bollinger.Upper(0);
         trade.Buy(lots,symbol,0,0,tp,TradeComment);
         SetBarsTraded(symbol);      
   }

   if (Closex1 > Bollinger.Upper(1) &&
      Barsnow > BarsLastTraded + BarsSince &&
      RSI.Main(0) > 80) {

         if(MAFilterOn && PricevsMovAvg(FastMA,SlowMA)!="below") return;
         if(IchiFilterOn && PricevsIchiCloud(symbol,SenA,SenB,Ten,Kij)!="below") return;
   
         double tp = Bollinger.Lower(0);
         trade.Sell(lots,symbol,0,0,tp,TradeComment);
         SetBarsTraded(symbol);
   }

}


bool IsNewBar() {

   static   datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT,0);
   if(previousTime!=currentTime){
      previousTime=currentTime;
      return true;   
   }
   return false;
}

void TrailSL(string symbol) {

   TPBol    =  new CiBands;
   TPBol.Create(symbol,Timeframe,BollingerMAperiod,0,TPBolStDev,AppPrice);
   TPBol.Refresh(-1);
   
   for(int i = PositionsTotal()-1; i>=0; i--) {
      posinfo.SelectByIndex(i);
      ulong ticket = posinfo.Ticket();
      double tp = posinfo.TakeProfit();
      
      switch(posinfo.PositionType()) {
         case POSITION_TYPE_BUY:    tp = TPBol.Upper(1); break;
         case POSITION_TYPE_SELL:   tp = TPBol.Lower(1); break;
      }
      
      if(posinfo.Symbol()==symbol && posinfo.Magic()==InpMagic) {
         trade.PositionModify(ticket,0,tp);
      }
   }
}

void SetBarsTraded(string symbol) {

   for(int i=ArraySize(Currencies)-1; i>=0; i--) {
      string   targetsymbol   =  BarsTraded[i][0];
      int      Barsnow        =  iBars(symbol,Timeframe);
      if(targetsymbol==symbol) {
         BarsTraded[i][1]     =  IntegerToString(Barsnow);
      }
   }
}

int GetBarsLastTraded(string symbol) {

   int BarsLastTraded = 0;
   for(int i=ArraySize(Currencies)-1; i>=0; i--) {
      string   targetsymbol   =  BarsTraded[i][0];
      if(targetsymbol==symbol) {
         BarsLastTraded = StringToInteger(BarsTraded[i][1]);
      }   
   }
   return BarsLastTraded;
}

string PricevsMovAvg(double MAfast, double MAslow) {

   if(MAfast > MAslow)  return "above";
   if(MAfast < MAslow)  return "below";
   
   return "error";

}

string PricevsIchiCloud(string symbol, double SenA, double SenB, double Ten, double Kij) {

   double ask  =  SymbolInfoDouble(symbol,SYMBOL_ASK);
   
   if(IchiFilterType==0) {
      if(ask>SenA && ask>SenB)   return "above";
      if(ask<SenA && ask<SenB)   return "below";
   }
   if(IchiFilterType==1) {
      if(ask>Ten) return "above";
      if(ask<Ten) return "below";
   }
   if(IchiFilterType==2) {
      if(ask>Kij) return "above";
      if(ask<Kij) return "below";
   }
   if(IchiFilterType==3) {
      if(ask>SenA) return "above";
      if(ask<SenA) return "below";
   }
   if(IchiFilterType==4) {
      if(ask>SenB) return "above";
      if(ask<SenB) return "below";
   }
   if(IchiFilterType==5) {
      if(Ten>Kij) return "above";
      if(Ten<Kij) return "below";
   }
   if(IchiFilterType==6) {
      if(Ten>Kij && Kij>SenA && Kij>SenB) return "above";
      if(Ten<Kij && Kij<SenA && Kij<SenB) return "below";
   } 
   if(IchiFilterType==7) {
      if(Ten>SenA && Ten>SenB) return "above";
      if(Ten<SenA && Ten<SenB) return "below";
   } 
   if(IchiFilterType==8) {
      if(Kij>SenA && Kij>SenB) return "above";
      if(Kij<SenA && Kij<SenB) return "below";
   } 
 
return "Incloud";
 
         
}