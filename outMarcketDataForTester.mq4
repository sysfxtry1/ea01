//+------------------------------------------------------------------+
//|                                            outputMarcketData.mq4 |
//|                                                        sysfxtry1 |
//|                                      http://github.com/sysfxtry1 |
//+------------------------------------------------------------------+
#property copyright "sysfxtry1"
#property link      "https://github.com/sysfxtry1/"
#property version   "1.00"
#property strict

input int PreData           =   1;  // 記録対象のバー（N個前）
input bool OnMA             = true; // 移動平均を記録するか
input int MovingPeriodFast	=  10;  // 移動平均/短期の期間
input int MovingShiftFast 	=   0;  // 移動平均/短期のシフト数
input int MovingPeriodSlow	= 100;  // 移動平均/長期の期間
input int MovingShiftSlow 	=   0;  // 移動平均/長期のシフト数
input bool OnMACD           = true; // MACDを記録するか
input int MacdFast	        =  12;  // MACD/短期移動平均の期間
input int MacdSlow	        =  26;  // MACD/長期移動平均の期間
input int MacdSignal        =   9;  // MACD/シグナルの移動平均期間
input bool OnRSI            = true; // RSIを記録するか
input int RsiPeriod         =  14;  // RSI/計算期間
input bool OnSto            = true; // ストキャスティクスを記録するか
input int StoK              =   5;  // ストキャスティクス/％Ｋラインの期間
input int StoP              =   3;  // ストキャスティクス/％Ｄラインの期間
input int StoSlow           =   3;  // ストキャスティクス/スロー値


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() { return(INIT_SUCCEEDED); }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  int iN = 6;
  int tmp = 0;
  string outData[6];

  //--- 記録タイミング：バーの始値
  static int BarBefore = 0;
  int BarNow = Bars;
  if( (BarNow - BarBefore) != 1) {
    BarBefore = BarNow;
    return;
  }
  BarBefore = BarNow;

  //-- 記録データの生成
  //フィルタリング用記号
  outData[0] = "@@";

  // 記録時刻の文字列生成
  datetime TC = iTime(NULL,PERIOD_CURRENT,PreData);
  outData[1] = StringConcatenate(
                 TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",
                 TimeHour(TC),":",TimeMinute(TC));

  // レート文字列の生成（始値,高値,安値,終値）
  outData[2] = DoubleToStr(Open[PreData],3);
  outData[3] = DoubleToStr(High[PreData],3);
  outData[4] = DoubleToStr(Low[PreData],3);
  outData[5] = DoubleToStr(Close[PreData],3);


  // 移動平均線（短期）
  if (OnMA == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,PreData),3);
  }

  // 移動平均線（長期）
  if (OnMA == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,PreData),3);
  }

  // MACD(メイン）
  if (OnMACD == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMACD(NULL,0,MacdFast,MacdSlow,MacdSignal,PRICE_CLOSE,MODE_MAIN,PreData),3);
  }

  // MACD（シグナル）
  if (OnMACD == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMACD(NULL,0,MacdFast,MacdSlow,MacdSignal,PRICE_CLOSE,MODE_SIGNAL,PreData),3);
  }

  // RSI値
  if (OnRSI == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iRSI(NULL,0,RsiPeriod,PRICE_CLOSE,PreData),3);
  }

  // ストキャスティクス（メイン）
  if (OnSto == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iStochastic(NULL,0,StoK,StoP,StoSlow,MODE_SMA,0,MODE_MAIN,PreData),3);
  }

  // ストキャスティクス（シグナル）
  if (OnSto == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iStochastic(NULL,0,StoK,StoP,StoSlow,MODE_SMA,0,MODE_SIGNAL,PreData),3);
  }


  //-- 情報出力
  string outString = "";
  for (int i = 0; i < iN; i++)
    outString = StringConcatenate(outString,"\"",outData[i],"\",");
  Print(outString);

}
//+------------------------------------------------------------------+
