//+------------------------------------------------------------------+
//|                                            outputMarcketData.mq4 |
//|                                                        sysfxtry1 |
//|                                      http://github.com/sysfxtry1 |
//+------------------------------------------------------------------+
#property copyright "sysfxtry1"
#property link      "https://github.com/sysfxtry1/"
#property version   "1.00"
#property strict

input int PreData           =   1;  // �L�^�Ώۂ̃o�[�iN�O�j
input bool OnMA             = true; // �ړ����ς��L�^���邩
input int MovingPeriodFast	=  10;  // �ړ�����/�Z���̊���
input int MovingShiftFast 	=   0;  // �ړ�����/�Z���̃V�t�g��
input int MovingPeriodSlow	= 100;  // �ړ�����/�����̊���
input int MovingShiftSlow 	=   0;  // �ړ�����/�����̃V�t�g��
input bool OnMACD           = true; // MACD���L�^���邩
input int MacdFast	        =  12;  // MACD/�Z���ړ����ς̊���
input int MacdSlow	        =  26;  // MACD/�����ړ����ς̊���
input int MacdSignal        =   9;  // MACD/�V�O�i���̈ړ����ϊ���
input bool OnRSI            = true; // RSI���L�^���邩
input int RsiPeriod         =  14;  // RSI/�v�Z����
input bool OnSto            = true; // �X�g�L���X�e�B�N�X���L�^���邩
input int StoK              =   5;  // �X�g�L���X�e�B�N�X/���j���C���̊���
input int StoP              =   3;  // �X�g�L���X�e�B�N�X/���c���C���̊���
input int StoSlow           =   3;  // �X�g�L���X�e�B�N�X/�X���[�l


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

  //--- �L�^�^�C�~���O�F�o�[�̎n�l
  static int BarBefore = 0;
  int BarNow = Bars;
  if( (BarNow - BarBefore) != 1) {
    BarBefore = BarNow;
    return;
  }
  BarBefore = BarNow;

  //-- �L�^�f�[�^�̐���
  //�t�B���^�����O�p�L��
  outData[0] = "@@";

  // �L�^�����̕����񐶐�
  datetime TC = iTime(NULL,PERIOD_CURRENT,PreData);
  outData[1] = StringConcatenate(
                 TimeYear(TC),"/",TimeMonth(TC),"/",TimeDay(TC)," ",
                 TimeHour(TC),":",TimeMinute(TC));

  // ���[�g������̐����i�n�l,���l,���l,�I�l�j
  outData[2] = DoubleToStr(Open[PreData],3);
  outData[3] = DoubleToStr(High[PreData],3);
  outData[4] = DoubleToStr(Low[PreData],3);
  outData[5] = DoubleToStr(Close[PreData],3);


  // �ړ����ϐ��i�Z���j
  if (OnMA == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMA(NULL,0,MovingPeriodFast,MovingShiftFast,MODE_SMA,PRICE_CLOSE,PreData),3);
  }

  // �ړ����ϐ��i�����j
  if (OnMA == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMA(NULL,0,MovingPeriodSlow,MovingShiftSlow,MODE_SMA,PRICE_CLOSE,PreData),3);
  }

  // MACD(���C���j
  if (OnMACD == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMACD(NULL,0,MacdFast,MacdSlow,MacdSignal,PRICE_CLOSE,MODE_MAIN,PreData),3);
  }

  // MACD�i�V�O�i���j
  if (OnMACD == true){
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iMACD(NULL,0,MacdFast,MacdSlow,MacdSignal,PRICE_CLOSE,MODE_SIGNAL,PreData),3);
  }

  // RSI�l
  if (OnRSI == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iRSI(NULL,0,RsiPeriod,PRICE_CLOSE,PreData),3);
  }

  // �X�g�L���X�e�B�N�X�i���C���j
  if (OnSto == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iStochastic(NULL,0,StoK,StoP,StoSlow,MODE_SMA,0,MODE_MAIN,PreData),3);
  }

  // �X�g�L���X�e�B�N�X�i�V�O�i���j
  if (OnSto == true) {
    iN++;
	tmp = ArrayResize(outData,iN);
    outData[iN-1] = DoubleToStr(iStochastic(NULL,0,StoK,StoP,StoSlow,MODE_SMA,0,MODE_SIGNAL,PreData),3);
  }


  //-- ���o��
  string outString = "";
  for (int i = 0; i < iN; i++)
    outString = StringConcatenate(outString,"\"",outData[i],"\",");
  Print(outString);

}
//+------------------------------------------------------------------+
