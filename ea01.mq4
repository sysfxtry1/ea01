//+------------------------------------------------------------------+
//|                                                         test.mq4 |
//|                                                        sysfxtry1 |
//|                                    https://github.com/sysfxtry1/ |
//+------------------------------------------------------------------+
#property copyright "sysfxtry1"
#property link      "https://github.com/sysfxtry1/"
#property version   "1.00"
#property strict

input int    MovingPeriodShort  =5;
input int    MovingPeriodLong   =50;
input int    MovingShiftShort   =6;
input int    MovingShiftLong    =18;

//+------------------------------------------------------------------+
//| The function of judgment the trend of the market                 |
//|   return value: 1 = Up trend                                     |
//|                 2 = Down trend                                   |
//|                 0 = Neither Up trend nor down trend              |
//|                -1 = Other than first tiks of new bar             |
//+------------------------------------------------------------------+
int CheckMarketTrend() {
  double maLong;
  double maShort;
  int    res;

  //--- go trading only for first tiks of new bar
  if(Volume[0]>1) return(-1);

  //--- get Moving Average 
  maLong  = iMA(NULL,0,MovingPeriodLong, MovingShiftLong, MODE_SMA,PRICE_CLOSE,0);
  maShort = iMA(NULL,0,MovingPeriodShort,MovingShiftShort,MODE_SMA,PRICE_CLOSE,0);

  //--- Judge the trend of the market
  if(maShort > maLong) { // アップトレンド判定
    res = 1;
  }else if(maLong > maShort) { // ダウントレンド判定
    res = 2;
  } else {
    res = 0;
  }

  return(res);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   Alert(__FUNCTION__);
  }
//+------------------------------------------------------------------+
