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
#define UNITS	 100000					 // 1ロット当たりの通貨数

input int    MovingPeriodFast	= 5;     // 短期移動平均の期間
input int    MovingPeriodSlow	= 50;    // 長期移動平均の期間
input int    MovingShiftFast 	= 6;     // 短期移動平均のシフト数
input int    MovingShiftSlow 	= 18;    // 長期移動平均のシフト数
input int    StopLossCriteria	= 48;    // 損切価格の算出基準とするバー数
input double RiskPercent		= 1;     // 許容可能なロスカット時の損失割合(%)
input double Lots				= 0.01;  // 注文量（標準：1000通貨）
input int	 MaxOrders			= 20;	 // 許容する同時注文数（ポジション含む）
input double OrderMargin		= 0.1;   // 指値/逆指値の余裕額
input bool	 MailAlert			= true;	 // 通知メールの送信のOn/Off
input bool   Debug              = false; // デバッグモードのOn/Off
input bool   LogSwitch          = false; // ログ出力のOn/Off

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
	double Spread        = MarketInfo(Symbol(),MODE_SPREAD) / 100; // スプレッド

	if (MarketTrend == 1){
	// 上げ相場＝買いポジションの場合 ----------

		MinPrice = Low[1];
		// 過去の最安値を算出する
		for (int i = 2; i <= StopLossCriteria; i++) {
		  if (MinPrice > Low[i]) MinPrice = Low[i];
		}

		// 損切り価格の算出（10pips余裕を持たせる）
		if (MinPrice < Ask)  //現在値が最安値の場合を除く
		  StopLossPrice = MinPrice - Spread - OrderMargin;

	} else 	if (MarketTrend == 2) {
	// 下げ相場＝売りポジションの場合 ----------

		// 過去の最高値を算出する
		MinPrice = High[1];
		for (int i = 2; i <= StopLossCriteria; i++) {
		  if (MinPrice < High[i]) MinPrice = High[i];
		}

		// 損切り価格の算出（10pips余裕を持たせる）
		if (MinPrice > Bid)  //現在値が最高値の場合を除く
		  StopLossPrice = MinPrice + Spread + OrderMargin;

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
		ExitPrice = Ask + (Ask - StopLossPrice) + OrderMargin;
	} else

	// 下げ相場＝売りポジションの場合 ----------
	if (MarketTrend == 2) {
		ExitPrice = Bid + (Bid - StopLossPrice) - OrderMargin;
	}

	return(ExitPrice);	
}

//+------------------------------------------------------------------+
//| エントリー可否を判断する関数                                     |
//+------------------------------------------------------------------+
bool isPossibleOrder(int MarketTrend, double StopLossPrice, double ExitPrice) {
	double RiskVal = RiskPercent / 100;
	double MaxLoss = 0;

	//--- 前提条件の確認（その１）
	// バーの始値での取引かを判定
	static int BarBefore = 0;
	int BarNow = Bars;
	if( (BarNow - BarBefore) != 1) {
		BarBefore = BarNow;
		return(false);
	}
	BarBefore = BarNow;

	//--- 前提条件の確認（その２）
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
	int    TicketNo      = 0;
	int    MarketTrend   = CheckMarketTrend();
	double StopLossPrice = CheckStopLossPrice(MarketTrend);
	double ExitPrice     = CheckExitPrice(MarketTrend,StopLossPrice);

	// 新規ポジションの取引可否を判断する
	if( isPossibleOrder(MarketTrend, StopLossPrice, ExitPrice) == false) return(0);

	// 移動平均の値を算出
	double maFastNow = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,1);
	double maFastPre = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,2);

	// 買いポジション取引
	if ( MarketTrend == 1) {
		if (Close[1] > maFastNow) {
			if (Close[2] < maFastPre ) {
				TicketNo = OrderSend(Symbol(),OP_BUY,Lots,Ask,3,StopLossPrice,ExitPrice,"",MAGICNA,0,Blue);

				if (MailAlert == true) SendAlertMail("BUY", Ask, StopLossPrice, ExitPrice,TicketNo);

				return(TicketNo);
			}
		}
	}

	 // 売りポジション取引
	if (MarketTrend == 2){
		if (Close[1] < maFastNow){
			if (Close[2] > maFastPre) {
				TicketNo = OrderSend(Symbol(),OP_SELL,Lots,Bid,3,StopLossPrice,ExitPrice,"",MAGICNA,0,Red);

				if (MailAlert == true) SendAlertMail("SELL", Bid, StopLossPrice, ExitPrice,TicketNo);

				return(TicketNo);
			}
		}
	}

	return(0);	
}

//+------------------------------------------------------------------+
//| 許容ポジション数＋注文数の確認関数                               |
//+------------------------------------------------------------------+
void SendAlertMail(string OrderKind, double OrderPrice, double StopLossPrice, double ExitPrice, int TicketNo) {
    string OrderResult = "";

	// 注文結果の情報取得
	if (OrderSelect(TicketNo, SELECT_BY_TICKET) == true) {
        OrderResult = StringConcatenate(
	    "注文結果: Success\n",
	    "約定価格: ", OrderOpenPrice(), "\n",
	    "約定時間: ", OrderOpenTime());
    } else
        OrderResult = StringConcatenate(
		"注文結果 : エラー（", GetLastError(), ")");

    // 通知メールの成形
	string subject = StringConcatenate(
	  "[MT4:注文実効] ea01 は ", OrderKind, " 注文を実行しました");
	string body = StringConcatenate(
      "Expert Adviser \"ea01\" が注文を行いました。\n\n",
      "----------------------------------\n",
      "注文価格 :", OrderPrice, "\n",
      "損切価格 :", StopLossPrice, "\n",
      "利確価格 :", ExitPrice, "\n",
      "----------------------------------\n",
      "チケット: #", TicketNo, "\n",
	  OrderResult, "\n");

	SendMail(subject,body);
}

//+------------------------------------------------------------------+
//| ログ取得関数　　　　　　　　　　　                               |
//+------------------------------------------------------------------+
void WriteLog(int TicketNo) {
  //--- 前提条件の確認（その１）
  // バーの始値での取引かを判定
  static int BarBefore = 0;
  int BarNow = Bars;
  if( (BarNow - BarBefore) != 1) {
    BarBefore = BarNow;
    return;
  }
  BarBefore = BarNow;

//  int FH = 0;
//	string FileName = "2015log.csv";
/*
    FH = FileOpen(FileName, FILE_CSV|FILE_READ|FILE_WRITE, ',');
    if(FH > 0) {
       FileWrite(FH, 
	     TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",TimeHour(TC),":",TimeMinute(TC), // 記録日時
		 Open[0], High[0], Low[0], Close[0], // 始値, 高値, 安値, 終値
	     iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0), //移動平均（短期）
         iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,0), //移動平均（長期）
         iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0),      // MACD(メイン）
         iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0),    // MACD（シグナル）
         iRSI(NULL,0,14,PRICE_CLOSE,0),                      // RSI値
         iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,0),   // ストキャスティクス（メイン）
         iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_SIGNAL,0)  // ストキャスティクス（シグナル）
       );
       FileClose(FH);
    }
*/

  // 発注したポジションの情報取得
  int      OrderOType  = 0;
  double   OrderOPrice = 0;
  datetime OrderOTime  = 0;
  if (TicketNo > 0) {
    if(OrderSelect(TicketNo, SELECT_BY_TICKET) == true) {
      OrderOType  = OrderType();
      OrderOPrice = OrderOpenPrice();
      OrderOTime  = OrderOpenTime();
    }
  }

  // 決済したポジションの情報取得
  static int OrderTotalPre = 0;
  int OrderTotalNow = OrdersTotal();
  int cnt = 0;
  string OrderCloseInfo ="";

  if (OrderTotalNow < OrderTotalPre) {
    int OrderNum = OrderTotalPre - OrderTotalNow;
	int OrderHT  = OrdersHistoryTotal();

    for (cnt = OrderHT - OrderNum; cnt == OrderHT; cnt++ ) {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_HISTORY) == true) {
         int OrderTypeText = OrderType();
		 double OrderCP    = OrderClosePrice();
		 double OrderOP    = OrderOpenPrice();
		 double ProfitNum     = 0;

		 // 損益計算
         if (OrderTypeText == OP_BUY) 
		   ProfitNum = (OrderCP - OrderOP) * 100000;
		 else
		   ProfitNum = (OrderOP - OrderCP) * 100000;
		   
         // 出力テキストの作成
         OrderCloseInfo = StringConcatenate(OrderCloseInfo,",",
		   OrderTicket(),",",
		   OrderTypeText,",",
		   OrderCloseTime(),",",
		   OrderCP,",",
		   OrderOpenTime(),",",
		   OrderOP,",",
		   ProfitNum,","
         );
      }
    }
  }
  OrderTotalPre = OrderTotalNow;

  // 情報出力
  datetime TC = TimeCurrent();
  Print("@@,",
    TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",TimeHour(TC),":",TimeMinute(TC),",", // 記録日時
    Open[0],",",  // 始値
	High[0],",",  // 高値
	Low[0],",",   // 安値
	Close[0],",", // 終値
    iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0),",", // 移動平均（短期）
    iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,0),",", // 移動平均（長期）
    iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0),",",      // MACD(メイン）
    iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0),",",    // MACD（シグナル）
    iRSI(NULL,0,14,PRICE_CLOSE,0),",",                      // RSI値
    iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,0),",",   // ストキャスティクス（メイン）
    iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_SIGNAL,0),",", // ストキャスティクス（シグナル）
    TicketNo,",",                                           // チケット番号
	OrderOType,",",                                         // 約定したポジションの種類
	OrderOTime,",",                                         // 約定したポジションの約定時間
	OrderOPrice,",",                                        // 約定したポジションの約定価格
	OrderCloseInfo,","                                      // ポジションの決済情報
  );
}

//+------------------------------------------------------------------+
//| 許容ポジション数＋注文数の確認関数                               |
//+------------------------------------------------------------------+
bool CheckOrders() {
   if (OrdersTotal() >= MaxOrders) return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| EA 初期化関数                                                    |
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

	if (Debug == true) {
		//--- バックテスト用処理（簡略化）
		int TicketNo = CheckForOpen();
		if (LogSwitch == true) WriteLog(TicketNo);

	} else {
		//--- 本番用処理

		//--- 状態確認：トレード可否、必要な過去データを入手可能か）
		if (IsTradeAllowed()==false) return;
		if (Bars <= StopLossCriteria) return;

		//--- ポジション取引
        int TicketNo = CheckForOpen();
	    if (TicketNo < 0) Print("Error: Code(",GetLastError(),")");
		if (LogSwitch == true) WriteLog(TicketNo);
	}	
}
//+------------------------------------------------------------------+
