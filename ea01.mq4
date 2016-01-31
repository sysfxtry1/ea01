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
#define UNITS	 100000					 // 1���b�g������̒ʉݐ�

input int    MovingPeriodFast	= 5;     // �Z���ړ����ς̊���
input int    MovingPeriodSlow	= 50;    // �����ړ����ς̊���
input int    MovingShiftFast 	= 6;     // �Z���ړ����ς̃V�t�g��
input int    MovingShiftSlow 	= 18;    // �����ړ����ς̃V�t�g��
input int    StopLossCriteria	= 48;    // ���؉��i�̎Z�o��Ƃ���o�[��
input double RiskPercent		= 1;     // ���e�\�ȃ��X�J�b�g���̑�������(%)
input double Lots				= 0.01;  // �����ʁi�W���F1000�ʉ݁j
input int	 MaxOrders			= 20;	 // ���e���铯���������i�|�W�V�����܂ށj
input double OrderMargin		= 0.1;   // �w�l/�t�w�l�̗]�T�z
input bool	 MailAlert			= true;	 // �ʒm���[���̑��M��On/Off
input bool   Debug              = false; // �f�o�b�O���[�h��On/Off
input bool   LogSwitch          = false; // ���O�o�͂�On/Off

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
	if(maFast > maSlow)  return(1); // �A�b�v�g�����h����
	if(maSlow > maFast)  return(2); // �_�E���g�����h����

	return(0);	
}

//+------------------------------------------------------------------+
//| ���؂艿�i�̎Z�o�֐�                                             |
//+------------------------------------------------------------------+
double CheckStopLossPrice(int MarketTrend) {
	double StopLossPrice = 0; // ���؂肷�鉿�i
	double MinPrice      = 0; // �ߋ��̍ň��l
	double Spread        = MarketInfo(Symbol(),MODE_SPREAD) / 100; // �X�v���b�h

	if (MarketTrend == 1){
	// �グ���ꁁ�����|�W�V�����̏ꍇ ----------

		MinPrice = Low[1];
		// �ߋ��̍ň��l���Z�o����
		for (int i = 2; i <= StopLossCriteria; i++) {
		  if (MinPrice > Low[i]) MinPrice = Low[i];
		}

		// ���؂艿�i�̎Z�o�i10pips�]�T����������j
		if (MinPrice < Ask)  //���ݒl���ň��l�̏ꍇ������
		  StopLossPrice = MinPrice - Spread - OrderMargin;

	} else 	if (MarketTrend == 2) {
	// �������ꁁ����|�W�V�����̏ꍇ ----------

		// �ߋ��̍ō��l���Z�o����
		MinPrice = High[1];
		for (int i = 2; i <= StopLossCriteria; i++) {
		  if (MinPrice < High[i]) MinPrice = High[i];
		}

		// ���؂艿�i�̎Z�o�i10pips�]�T����������j
		if (MinPrice > Bid)  //���ݒl���ō��l�̏ꍇ������
		  StopLossPrice = MinPrice + Spread + OrderMargin;

	}

	return(StopLossPrice);	
}

//+------------------------------------------------------------------+
//| ���v�m�艿�i�̎Z�o�֐�                                           |
//+------------------------------------------------------------------+
double CheckExitPrice(int MarketTrend, double StopLossPrice) {
	double ExitPrice = 0; // ���v�m�肷�鉿�i

	if (StopLossPrice <= 0) return(0);
	// �グ���ꁁ�����|�W�V�����̗��v�m�艿�i�̎Z�o
	if (MarketTrend == 1){
		ExitPrice = Ask + (Ask - StopLossPrice) + OrderMargin;
	} else

	// �������ꁁ����|�W�V�����̏ꍇ ----------
	if (MarketTrend == 2) {
		ExitPrice = Bid + (Bid - StopLossPrice) - OrderMargin;
	}

	return(ExitPrice);	
}

//+------------------------------------------------------------------+
//| �G���g���[�ۂ𔻒f����֐�                                     |
//+------------------------------------------------------------------+
bool isPossibleOrder(int MarketTrend, double StopLossPrice, double ExitPrice) {
	double RiskVal = RiskPercent / 100;
	double MaxLoss = 0;

	//--- �O������̊m�F�i���̂P�j
	// �o�[�̎n�l�ł̎�����𔻒�
	static int BarBefore = 0;
	int BarNow = Bars;
	if( (BarNow - BarBefore) != 1) {
		BarBefore = BarNow;
		return(false);
	}
	BarBefore = BarNow;

	//--- �O������̊m�F�i���̂Q�j
	if (MarketTrend <= 0)	return(false); // �s��g�����h�����m�Ȃ���
	if (StopLossPrice <= 0) return(false); // ���؂艿�i���Z�o�\�ȏꍇ�̂� 
	if (ExitPrice <= 0)		return(false); // ���v�m�艿�i���Z�o�\�ȏꍇ�̂� 
	if (CheckOrders() == false)
							return(false); // ����/�|�W�V�����̐������e�͈͓��̏ꍇ

	//--- ���e�ł���ő呹���z�̊m�F
	//���e�\�ȑ������������_�̗L���؋����i�]��؋����j�~�Q��
	double PermissibleLoss = AccountFreeMargin() * RiskVal;

	if (MarketTrend == 1) { // �グ����i�����|�W�V�����j�̏ꍇ
		MaxLoss = (Ask - StopLossPrice) * Lots * UNITS;

	} else if (MarketTrend == 2){ //��������i����|�W�V�����j�̏ꍇ
		MaxLoss = (StopLossPrice - Bid) * Lots * UNITS;
	}

	// �ő呹�������e�z�ȏ�Ȃ�NG
	if (PermissibleLoss <= MaxLoss) return(false);

	return(true);
}

//+------------------------------------------------------------------+
//| �V�K�|�W�V��������֐�                                           |
//+------------------------------------------------------------------+
int CheckForOpen() {
	int    TicketNo      = 0;
	int    MarketTrend   = CheckMarketTrend();
	double StopLossPrice = CheckStopLossPrice(MarketTrend);
	double ExitPrice     = CheckExitPrice(MarketTrend,StopLossPrice);

	// �V�K�|�W�V�����̎���ۂ𔻒f����
	if( isPossibleOrder(MarketTrend, StopLossPrice, ExitPrice) == false) return(0);

	// �ړ����ς̒l���Z�o
	double maFastNow = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,1);
	double maFastPre = iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,2);

	// �����|�W�V�������
	if ( MarketTrend == 1) {
		if (Close[1] > maFastNow) {
			if (Close[2] < maFastPre ) {
				TicketNo = OrderSend(Symbol(),OP_BUY,Lots,Ask,3,StopLossPrice,ExitPrice,"",MAGICNA,0,Blue);

				if (MailAlert == true) SendAlertMail("BUY", Ask, StopLossPrice, ExitPrice,TicketNo);

				return(TicketNo);
			}
		}
	}

	 // ����|�W�V�������
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
//| ���e�|�W�V�������{�������̊m�F�֐�                               |
//+------------------------------------------------------------------+
void SendAlertMail(string OrderKind, double OrderPrice, double StopLossPrice, double ExitPrice, int TicketNo) {
    string OrderResult = "";

	// �������ʂ̏��擾
	if (OrderSelect(TicketNo, SELECT_BY_TICKET) == true) {
        OrderResult = StringConcatenate(
	    "��������: Success\n",
	    "��艿�i: ", OrderOpenPrice(), "\n",
	    "��莞��: ", OrderOpenTime());
    } else
        OrderResult = StringConcatenate(
		"�������� : �G���[�i", GetLastError(), ")");

    // �ʒm���[���̐��`
	string subject = StringConcatenate(
	  "[MT4:��������] ea01 �� ", OrderKind, " ���������s���܂���");
	string body = StringConcatenate(
      "Expert Adviser \"ea01\" ���������s���܂����B\n\n",
      "----------------------------------\n",
      "�������i :", OrderPrice, "\n",
      "���؉��i :", StopLossPrice, "\n",
      "���m���i :", ExitPrice, "\n",
      "----------------------------------\n",
      "�`�P�b�g: #", TicketNo, "\n",
	  OrderResult, "\n");

	SendMail(subject,body);
}

//+------------------------------------------------------------------+
//| ���O�擾�֐��@�@�@�@�@�@�@�@�@�@�@                               |
//+------------------------------------------------------------------+
void WriteLog(int TicketNo) {
  //--- �O������̊m�F�i���̂P�j
  // �o�[�̎n�l�ł̎�����𔻒�
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
	     TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",TimeHour(TC),":",TimeMinute(TC), // �L�^����
		 Open[0], High[0], Low[0], Close[0], // �n�l, ���l, ���l, �I�l
	     iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0), //�ړ����ρi�Z���j
         iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,0), //�ړ����ρi�����j
         iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0),      // MACD(���C���j
         iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0),    // MACD�i�V�O�i���j
         iRSI(NULL,0,14,PRICE_CLOSE,0),                      // RSI�l
         iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,0),   // �X�g�L���X�e�B�N�X�i���C���j
         iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_SIGNAL,0)  // �X�g�L���X�e�B�N�X�i�V�O�i���j
       );
       FileClose(FH);
    }
*/

  // ���������|�W�V�����̏��擾
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

  // ���ς����|�W�V�����̏��擾
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

		 // ���v�v�Z
         if (OrderTypeText == OP_BUY) 
		   ProfitNum = (OrderCP - OrderOP) * 100000;
		 else
		   ProfitNum = (OrderOP - OrderCP) * 100000;
		   
         // �o�̓e�L�X�g�̍쐬
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

  // ���o��
  datetime TC = TimeCurrent();
  Print("@@,",
    TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",TimeHour(TC),":",TimeMinute(TC),",", // �L�^����
    Open[0],",",  // �n�l
	High[0],",",  // ���l
	Low[0],",",   // ���l
	Close[0],",", // �I�l
    iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,0),",", // �ړ����ρi�Z���j
    iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,0),",", // �ړ����ρi�����j
    iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0),",",      // MACD(���C���j
    iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0),",",    // MACD�i�V�O�i���j
    iRSI(NULL,0,14,PRICE_CLOSE,0),",",                      // RSI�l
    iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,0),",",   // �X�g�L���X�e�B�N�X�i���C���j
    iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_SIGNAL,0),",", // �X�g�L���X�e�B�N�X�i�V�O�i���j
    TicketNo,",",                                           // �`�P�b�g�ԍ�
	OrderOType,",",                                         // ��肵���|�W�V�����̎��
	OrderOTime,",",                                         // ��肵���|�W�V�����̖�莞��
	OrderOPrice,",",                                        // ��肵���|�W�V�����̖�艿�i
	OrderCloseInfo,","                                      // �|�W�V�����̌��Ϗ��
  );
}

//+------------------------------------------------------------------+
//| ���e�|�W�V�������{�������̊m�F�֐�                               |
//+------------------------------------------------------------------+
bool CheckOrders() {
   if (OrdersTotal() >= MaxOrders) return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| EA �������֐�                                                    |
//+------------------------------------------------------------------+
int OnInit() { return(0); }

//+------------------------------------------------------------------+
//| EA �I�������֐�                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { }

//+------------------------------------------------------------------+
//| EA���C���֐�                                                     |
//+------------------------------------------------------------------+
void OnTick() {

	if (Debug == true) {
		//--- �o�b�N�e�X�g�p�����i�ȗ����j
		int TicketNo = CheckForOpen();
		if (LogSwitch == true) WriteLog(TicketNo);

	} else {
		//--- �{�ԗp����

		//--- ��Ԋm�F�F�g���[�h�ہA�K�v�ȉߋ��f�[�^�����\���j
		if (IsTradeAllowed()==false) return;
		if (Bars <= StopLossCriteria) return;

		//--- �|�W�V�������
        int TicketNo = CheckForOpen();
	    if (TicketNo < 0) Print("Error: Code(",GetLastError(),")");
		if (LogSwitch == true) WriteLog(TicketNo);
	}	
}
//+------------------------------------------------------------------+
