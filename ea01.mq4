//+------------------------------------------------------------------+
//|                                                         ea01.mq4 |
//|                                                        sysfxtry1 |
//|                                    https://github.com/sysfxtry1/ |
//+------------------------------------------------------------------+
#property copyright "sysfxtry1"
#property link      "https://github.com/sysfxtry1/"
#property version   "1.00"
#property strict

#define MAGICNA  2016010500
#define UNITS	 1000

input int    MovingPeriodFast	= 5;    // 短期移動平均の期間
input int    MovingPeriodSlow	= 50;   // 長期移動平均の期間
input int    MovingShiftFast 	= 6;    // 短期移動平均のシフト数
input int    MovingShiftSlow 	= 18;   // 長期移動平均のシフト数
input int    StopLossCriteria	= 48;   // 損切価格の算出基準とするバー数
input double RiskPercent		= 2;    // 許容可能なロスカット時の損失割合(%)
input double Lots				= 0.01; // 注文量（標準：1000通貨）
input int	 MaxOrders			= 10;	// 許容する同時注文数（ポジション含む）

//+------------------------------------------------------------------+
//| The function of judgment the trend of the market                 |
//|   return value: 1 = Up trend                                     |
//|                 2 = Down trend                                   |
//|                 0 = Neither Up trend nor down trend              |
//+------------------------------------------------------------------+
int CheckMarketTrend() {
	//--- get Moving Average 
	double maSlow = iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,0);
	double maFast = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0);

	//--- Judge the trend of the market
	if(maFast > maSlow)  return(1); // アップトレンド判定
	if(maSlow > maFast)  return(2); // ダウントレンド判定

	return(0);	
}

//+------------------------------------------------------------------+
//| 損切り価格の算出関数                                             |
//+------------------------------------------------------------------+
double CheckStopLossPrice(int MarketTrend) {
	double StopLossPrice = 0; // 損切りする価格
	double MinPrice      = 0; // 過去の最安値

	if (MarketTrend == 1){
	// 上げ相場＝買いポジションの場合 ----------

		// 過去の最安値を算出する
		for (int i = 1; i <= StopLossCriteria; i++) {
		  if (MinPrice < Low[i]) MinPrice = Low[i];
		}

		// 損切り価格の算出（10pips余裕を持たせる）
		if (MinPrice < Ask)  //現在値が最安値の場合を除く
		  StopLossPrice = MinPrice - 0.1;

	} else 	if (MarketTrend == 2) {
	// 下げ相場＝売りポジションの場合 ----------

		// 過去の最高値を算出する
		for (int i = 1; i <= StopLossCriteria; i++) {
		  if (MinPrice > High[i]) MinPrice = High[i];
		}

		// 損切り価格の算出（10pips余裕を持たせる）
		if (MinPrice > Bid)  //現在値が最高値の場合を除く
		  StopLossPrice = MinPrice + 0.1;

	}

	return(StopLossPrice);	
}

//+------------------------------------------------------------------+
//| 利益確定価格の算出関数                                           |
//+------------------------------------------------------------------+
double CheckExitPrice(int MarketTrend, double StopLossPrice) {
	double ExitPrice = 0; // 利益確定する価格

	if (StopLossPrice <= 0) return(0);

	// 上げ相場＝買いポジションの利益確定価格の算出
	if (MarketTrend == 1){
		ExitPrice = Ask + (Ask - StopLossPrice) + 0.1;
	} else

	// 下げ相場＝売りポジションの場合 ----------
	if (MarketTrend == 2) {
		ExitPrice = Bid + (Bid - StopLossPrice) + 0.1;
	}

	return(ExitPrice);	
}

//+------------------------------------------------------------------+
//| 保有量からのエントリー可否を判断する関数                         |
//+------------------------------------------------------------------+
bool isPossibleOrder(int MarketTrend, double StopLossPrice, double ExitPrice) {
	double RiskVal = RiskPercent / 100;
	double MaxLoss = 0;

	//--- 前提条件の確認
	if (Volume[0] > 1)		return(false); // 最初のティック時のみ許可
	if (MarketTrend <= 0)	return(false); // 市場トレンドが明確なこと
	if (StopLossPrice <= 0) return(false); // 損切り価格が算出可能な場合のみ 
	if (ExitPrice <= 0)		return(false); // 利益確定価格が算出可能な場合のみ 
	if (CheckOrders() == false)
							return(false); // 注文/ポジションの数が許容範囲内の場合

	//--- 許容できる最大損失額の確認
	//許容可能な損失＝発注時点の有効証拠金（余剰証拠金）×２％
	double PermissibleLoss = AccountFreeMargin() * RiskVal;

	if (MarketTrend == 1) { // 上げ相場（買いポジション）の場合
		MaxLoss = (Ask - StopLossPrice) * Lots * UNITS;

	} else if (MarketTrend == 2){ //下げ相場（売りポジション）の場合
		MaxLoss = (StopLossPrice - Bid) * Lots * UNITS;
	}

	// 最大損失が許容額以上ならNG
	if (PermissibleLoss <= MaxLoss) return(false);

	return(true);
}

//+------------------------------------------------------------------+
//| 新規ポジション取引関数                                           |
//+------------------------------------------------------------------+
int CheckForOpen() {
	int    MarketTrend   = CheckMarketTrend();
	double StopLossPrice = CheckStopLossPrice(MarketTrend);
	double ExitPrice     = CheckExitPrice(MarketTrend,StopLossPrice);

	// 新規ポジションの取引可否を判断する
	if( isPossibleOrder(MarketTrend, StopLossPrice, ExitPrice) == false) return(0);

	// 移動平均の値を算出
	double maFastNow = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0);
	double maFastPre = iMA(NULL,60,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0);

	// 買いポジション取引
	if ( MarketTrend == 1 && Close[1] > maFastNow && Close[2] > maFastPre )
		return(OrderSend(Symbol(),OP_BUY,Lots,Ask,3,StopLossPrice,ExitPrice,"",MAGICNA,0,Blue));

	 // 売りポジション取引
	if ( MarketTrend == 2 && Close[1] < maFastNow && Close[2] < maFastPre )
		return(OrderSend(Symbol(),OP_SELL,Lots,Bid,3,StopLossPrice,ExitPrice,"",MAGICNA,0,Red));

	return(0);	
}

//+------------------------------------------------------------------+
//| 許容ポジション数＋注文数の確認関数								                     |
//+------------------------------------------------------------------+
bool CheckOrders() {
   if (OrdersTotal() >= MaxOrders) return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| EA 初期化関数								                     |
//+------------------------------------------------------------------+
int OnInit() { return(0); }

//+------------------------------------------------------------------+
//| EA 終了処理関数                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { }

//+------------------------------------------------------------------+
//| EAメイン関数                                                     |
//+------------------------------------------------------------------+
void OnTick() {

	//--- 状態確認：トレード可否、必要な過去データを入手可能か）
	if (IsTradeAllowed()==false || Bars<=StopLossCriteria ) return;

	//--- ポジション取引
    if (CheckForOpen() < 0) Print("Error: Code(",GetLastError(),")");

}
//+------------------------------------------------------------------+
