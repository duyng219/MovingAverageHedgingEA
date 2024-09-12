//+------------------------------------------------------------------+
//|                                       MovingAverageHedgingEA.mq5 |
//|                                                            duyng |
//|                                              github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property description "Moving Average Expert Advisor (Hedging)"
#property link "github.com/duyng219"
#property version "1.00"
//#include <stdDirectoryFunctions.mqh>

// EA mã hóa chiến lược Trung bình động
// Nó được thiết kế để giao dịch theo hướng của xu hướng, đặt các vị thế mua khi thanh cuối cùng đóng trên đường trung bình động và các vị thế bán khống khi thanh cuối cùng đóng dưới đường trung bình động
// Nó kết hợp hai mức dừng lỗ thay thế khác nhau bao gồm các điểm cố định bên dưới giá mở cửa hoặc đường trung bình động đối với các giao dịch dài hạn hoặc trên giá mở cửa hoặc đường trung bình động đối với các giao dịch ngắn hạn.
// Nó kết hợp các cài đặt để đặt chốt lời, cũng như điểm hòa vốn và điểm dừng lỗ cuối cùng

//+------------------------------------------------------------------+
//| EA Enumerations / Bảng liệt kê EA                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Input & Global Variables | Biến đầu vào và biến toàn cục         |
//+------------------------------------------------------------------+
sinput group                              "EA GENERAL SETTINGS" // Biến đầu vào giới hạn (Title)
input ulong                               MagicNumber             = 101;

sinput group                              "MOVING AVERAGE SETTINGS"
input int                                 MAPeriod                = 30;
input int                                 MAShift                 = 0;
input ENUM_MA_METHOD                      MAMethod                = MODE_SMA; 
input ENUM_APPLIED_PRICE                  MAPrice                 = PRICE_CLOSE;

sinput group                              "MONEY MANAGEMENT"
input double                              FixedVolume             = 0.1;

sinput group                              "POSITION MANAGEMENT"
input int                                 SLFixedPoints           = 0;
input int                                 SLFixedPointsMA         = 200;  
input int                                 TPFixedPoints           = 0;
input int                                 TSLFixedPoints          = 0;
input int                                 BEFixedPoints           = 0;

datetime                                  glTimeBarOpen;
ENUM_ORDER_TYPE_FILLING                   glFillingPolicy;
int                                       MAHandle;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //-- Initialization of variables
  glTimeBarOpen = D'1971.01.01 00:00';

  if(IsFillingTypeAllowed(SYMBOL_FILLING_FOK))        glFillingPolicy = ORDER_FILLING_FOK;
  else if(IsFillingTypeAllowed(SYMBOL_FILLING_IOC))   glFillingPolicy = ORDER_FILLING_IOC;
  else                                                glFillingPolicy = ORDER_FILLING_RETURN;
  
  //-- Indicator handles
  MAHandle = MA_Init(MAPeriod,MAShift,MAMethod,MAPrice);

  if(MAHandle == -1) return(INIT_FAILED);

  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  Print("Expert removed");
}

void OnTick()
{
  //--------------------//
  //  NEW BAR CONTROL   //
  //--------------------//
  bool newBar = false;

  // Check for New Bar
  if (glTimeBarOpen != iTime(_Symbol, PERIOD_CURRENT, 0))
  {
    newBar = true;
    glTimeBarOpen = iTime(_Symbol, PERIOD_CURRENT, 0);
  }

  if (newBar == true)
  {
    //--------------------//
    // PRICE & INDICATORS //
    //--------------------//

    //Price
    double close1 =Close(1);
    double close2 =Close(2);

    //Normalization of close price to tick size | Bình thường hóa giá đóng theo kích thước đánh dấu
    double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); //USDJPY 100.185 -- > 0.001 TSL 85.54 --> 0.01
    close1 = round(close1/tickSize) * tickSize;
    close2 = round(close2/tickSize) * tickSize;

    //Moving Average
    double ma1 = ma(MAHandle,1);
    double ma2 = ma(MAHandle,2);
         
    //--------------------//
    //     TRADE EXIT     //
    //--------------------//

    //Exit Signals & Close Trades Execution
    string exitSignal = MA_ExitSignal(close1,close2,ma1,ma2);

    if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT_SHORT"){
      CloseTrades(MagicNumber,exitSignal);}

    Sleep(1000);

    //--------------------//
    //   TRADE PLACEMENT  //
    //--------------------//

    //Entry Signals & Order Placement Execution
    string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
    Comment("EA #", MagicNumber, " | ", exitSignal, " | ", entrySignal, " SIGNALS DETECTED");

    if((entrySignal == "LONG" || entrySignal == "SHORT") && CheckPlacedPositions(MagicNumber) == false)
    {
      ulong ticket = OpenTrades(entrySignal,MagicNumber,FixedVolume);

      //SL & TP Trade Modification
      if(ticket > 0)
      {
        double stopLoss = CalculateStopLoss(entrySignal,SLFixedPoints,SLFixedPointsMA,ma1);
        double takeProfit = CalculateTakeProfit(entrySignal,TPFixedPoints);
        TradeModification(ticket,MagicNumber,stopLoss,takeProfit);
      }
    } 

    //--------------------//
    //POSITION MANAGEMENT //
    //--------------------//

    if(TSLFixedPoints > 0) TrailingStopLoss(MagicNumber,TSLFixedPoints);
    if(BEFixedPoints > 0) BreakEven(MagicNumber,BEFixedPoints);
  }
}

//+------------------------------------------------------------------+
//| EA FUNCTIONS | CHỨC NĂNG EA                                      |
//+------------------------------------------------------------------+

//+--------+// Price Functions //+--------+//

double Close(int pShift)
{
  //It create an object array of MlqRates strucure
  //It sets our array as a series array (so current bar is positon 0, previous bar is 1..)
  //It copies the bar price information of bars position 0, 1 and 2 to our array "bar"
  //It returns the close price of the bar object
  //Tạo một mảng đối tượng của cấu trúc MlqRates
  //Đặt mảng bar thành một mảng chuỗi (vì vậy thanh hiện tại là positon 0, thanh trước đó là 1..)
  //Sao chép thông tin giá thanh của vị trí thanh 0, 1 và 2 vào mảng "bar"
  //Trả về giá đóng cửa của bar
  MqlRates bar[];
  ArraySetAsSeries(bar, true);
  CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, bar);

  return bar[pShift].close;
}

double Open(int pShift)
{
  //It create an object array of MlqRates strucure
  //It sets our array as a series array (so current bar is positon 0, previous bar is 1..)
  //It copies the bar price information of bars position 0, 1 and 2 to our array "bar"
  //It returns the open price of the bar object
  //Tạo một mảng đối tượng của cấu trúc MlqRates
  //Đặt mảng bar thành một mảng chuỗi (vì vậy thanh hiện tại là positon 0, thanh trước đó là 1..)
  //Sao chép thông tin giá thanh của vị trí thanh 0, 1 và 2 vào mảng "bar"
  //Trả về giá mở cửa của bar
  MqlRates bar[];
  ArraySetAsSeries(bar, true);
  CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, bar);

  return bar[pShift].open;
}

//+--------+// Moving Average Functions //+--------+//

int MA_Init(int pMAPeriod, int pMAShift, ENUM_MA_METHOD pMAMethod, ENUM_APPLIED_PRICE pMAPrice)
{
  //In case of error when initializing the MA, GetLastError() will get the error code and store it in _lastError
  //ResetLastError will change _lastError variable to 0
  //Trong th lỗi khi khởi tạo MA, GetLastError() sẽ lấy mã lỗi và lưu trữ trong _lastError
  //ResetLastError sẽ thay đổi biến _lastError thành 0
  ResetLastError();

  //A unique identifier for the indicator. Used for all actions related to the indicator, such as copying data and removing the indicator
  //Một định danh duy nhất cho chỉ báo. Được sử dụng cho tất cả các hành động liên quan đến chỉ báo, chẳng hạn như sao chép dữ liệu và xóa chỉ báo
  int Hanlde = iMA(_Symbol,PERIOD_CURRENT,pMAPeriod,pMAShift,pMAMethod,pMAPrice);

  if(Hanlde == INVALID_HANDLE)
  {
    return -1;
    //Print("There was an error creating the MA Indicator Handle: ", GetLastError());
    Print("Đã xảy ra lỗi khi tạo MA Indicator Hanlde: ", GetLastError());
  }

  //Print("MA Indicator handle initialized successfully");
  Print("MA Indicator Hanlde đã được khởi tạo thành công!");

  return Hanlde;
}

double ma(int pMaHandle, int pShift)
{
  ResetLastError();

  //We create and fill an array with MA values
  double ma[];
  ArraySetAsSeries(ma,true);

  //We fill the array
  bool fillResult = CopyBuffer(pMaHandle,0,0,3,ma);
  if(fillResult == false) {
    Print("FILL_ERROR: ", GetLastError());}
  
  //We ask for the ma value stored in pShift
  double maValue = ma[pShift];
  
  //We normalize the maValue to our symbol's digits and return it
  maValue = NormalizeDouble(maValue,_Digits);
  
  return maValue;
}

string MA_EntrySignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
  string str = "";
  string indicatorValues;

  if(pPrice1 > pMA1 && pPrice2 <= pMA2) {str = "LONG";}
  else if(pPrice1 < pMA1 && pPrice2 >= pMA2) {str = "SHORT";}
  else{str = "NO_TRADE";}

  StringConcatenate(indicatorValues,"MA 1: ", DoubleToString(pMA1,_Digits), " | ","MA 2: ", DoubleToString(pMA2,_Digits), " | ",
                    "Close 1: ", DoubleToString(pPrice1,_Digits), " | ","Close 2: ", DoubleToString(pPrice2,_Digits));
  Print("Inditator Values: ", indicatorValues);

  return str;
}

string MA_ExitSignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
  string str = "";
  string indicatorValues;

  if(pPrice1 > pMA1 && pPrice2 <= pMA2) {str = "EXIT_SHORT";}
  else if(pPrice1 < pMA1 && pPrice2 >= pMA2) {str = "EXIT_LONG";}
  else{str = "NO_EXIT";}

  StringConcatenate(indicatorValues,"MA 1: ", DoubleToString(pMA1,_Digits), " | ","MA 2: ", DoubleToString(pMA2,_Digits), " | ",
                    "Close 1: ", DoubleToString(pPrice1,_Digits), " | ","Close 2: ", DoubleToString(pPrice2,_Digits));
  Print("Inditator Values: ", indicatorValues);

  return str;
}

//+--------+// Bollinger Bands Functions //+--------+//
int BB_Init(int pBBPeriod, int pBBShift, double pBBDeviation, ENUM_APPLIED_PRICE pBBPrice)
{
  //In case of error when initializing the BB, GetLastError() will get the error code and store it in _lastError
  //ResetLastError will change _lastError variable to 0
  //Trong th lỗi khi khởi tạo BB, GetLastError() sẽ lấy mã lỗi và lưu trữ trong _lastError
  //ResetLastError sẽ thay đổi biến _lastError thành 0
  ResetLastError();

  //A unique identifier for the indicator. Used for all actions related to the indicator, such as copying data and removing the indicator
  //Một định danh duy nhất cho chỉ báo. Được sử dụng cho tất cả các hành động liên quan đến chỉ báo, chẳng hạn như sao chép dữ liệu và xóa chỉ báo
  int Hanlde = iBands(_Symbol,PERIOD_CURRENT,pBBPeriod,pBBShift,pBBDeviation,pBBPrice);

  if(Hanlde == INVALID_HANDLE)
  {
    return -1;
    //Print("There was an error creating the BB Indicator Handle: ", GetLastError());
    Print("Đã xảy ra lỗi khi tạo BB Indicator Hanlde: ", GetLastError());
  }

  //Print("BB Indicator handle initialized successfully");
  Print("BB Indicator Hanlde đã được khởi tạo thành công!");

  return Hanlde;
}
double BB(int pBBHandle, int pBBLineBuffer, int pShift)
{
  /*
    pBBLineBuffer:   0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND
    pShift: 0 - Nen dau tien, 1 - Nen thu hai, 2 - Nen thu 3
    //KHOI TAO BB
    int bbPeriod = 20;
    int bbStd = 2;
    int BBHandle = BB_Init(bbPeriod,0,bbStd,PRICE_CLOSE);

    if(BBHandle == -1) Print("Khoi tao that bai");

    double bbUperBand = BB(BBHandle,1,1);
    double bbMidBand = BB(BBHandle,0,1);
    double bbLowerBand = BB(BBHandle,2,1);
    Print("Gia tri UpperBand: ", bbUperBand);
    Print("Gia tri MidBand : ", bbMidBand);
    Print("Gia tri LowerBand: ", bbLowerBand);
  */
  ResetLastError();

  //We create and fill an array with BB values
  double BB[];
  ArraySetAsSeries(BB,true);

  //We fill the array
  bool fillResult = CopyBuffer(pBBHandle,pBBLineBuffer,0,3,BB);
  if(fillResult == false) {
    Print("FILL_ERROR: ", GetLastError());}
  
  //We ask for the bb value stored in pShift
  double BBValue = BB[pShift];
  
  //We normalize the BBValue to our symbol's digits and return it
  BBValue = NormalizeDouble(BBValue,_Digits);
  
  return BBValue;
}

//+--------+// RSI Functions //+--------+//
int RSI_Init(int pRSIPerriod, ENUM_APPLIED_PRICE pRSIPrice)
{
  ResetLastError();
  int Hanlde = iRSI(_Symbol,PERIOD_CURRENT,pRSIPerriod,pRSIPrice);
  if(Hanlde == INVALID_HANDLE)
  {
    return -1;
    Print("Đã xảy ra lỗi khi tạo RSI Indicator Hanlde: ", GetLastError());
  }
  Print("RSI Indicator Hanlde đã được khởi tạo thành công!");
  return Hanlde;
}
double RSI(int pRSIHandle, int pShift)
{
  /*
  // Khoi tao RSI
  int RSIHandle = RSI_Init(14,PRICE_CLOSE);
  double RSIValue = RSI(RSIHandle,2);
  Print("");
  Print("Gia tri cua RSI : ", RSIValue);

  if(currentRSI > 30 && previousRSI < 30)
  {
    // i crossed from bellow the 20 line
  }
  */
  ResetLastError();

  double RSI[];
  ArraySetAsSeries(RSI,true);

  bool fillResult = CopyBuffer(pRSIHandle,0,0,3,RSI);
  if(fillResult == false) {
    Print("FILL_ERROR: ", GetLastError());}
  
  double RSIValue = RSI[pShift];
  RSIValue = NormalizeDouble(RSIValue,_Digits);
  return RSIValue;
}


//+--------+// Orders Placement Functions //+--------+//

ulong OpenTrades(string pEntrySignal, ulong pMagicNumber, double pFixedVol)
{
  //Buy position open trades at Ask but close them at Bid
  //Sell position open trades at Bid but close them at Ask
  double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

  //Price must be normalized either to digits or ticksize | Normalized gias bangw ditgis or ticksize
  askPrice = round(askPrice/tickSize) * tickSize;
  bidPrice = round(bidPrice/tickSize) * tickSize;

  string comment = pEntrySignal + " | " + _Symbol + " | " + string(pMagicNumber);

  //Request and Result Declaration and Initializtion
  MqlTradeRequest request = {};
  MqlTradeResult result = {};

  if(pEntrySignal == "LONG")
  {
    //Request Parameters
    request.action    = TRADE_ACTION_DEAL;
    request.symbol    = _Symbol;
    request.volume    = pFixedVol;
    request.type      = ORDER_TYPE_BUY;
    request.price     = askPrice;
    request.deviation = 10;
    request.magic     = pMagicNumber;
    request.comment   = comment;

    //Request Send
    if(!OrderSend(request,result))
      Print("OrderSend trade placement error: ", GetLastError()); //if request was not send, print error code

    //Trade Information 
    Print("Open ",request.symbol," LONG"," order #",result.order,": ",result.retcode,", Volume: ",result.volume,", Price: ",DoubleToString(askPrice, _Digits));
  }
  else if(pEntrySignal == "SHORT")
  {
    //Request Parameters
    request.action    = TRADE_ACTION_DEAL;
    request.symbol    = _Symbol;
    request.volume    = pFixedVol;
    request.type      = ORDER_TYPE_SELL;
    request.price     = bidPrice;
    request.deviation = 10;
    request.magic     = pMagicNumber;
    request.comment   = comment;

    //Request Send
    if(!OrderSend(request,result))
      Print("OrderSend trade placement error: ", GetLastError()); //if request was not send, print error code

    //Trade Information 
    Print("Open ",request.symbol," SHORT"," order #",result.order,": ",result.retcode,", Volume: ",result.volume,", Price: ",DoubleToString(bidPrice, _Digits));
  }

  if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES)
    {
      return result.order;
    }
    else return 0;
}

void TradeModification(ulong ticket, ulong pMagic, double pSLPrice, double pTPPrice)
{
  double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

  MqlTradeRequest request = {};
  MqlTradeResult result = {};

  request.action = TRADE_ACTION_SLTP;
  request.position = ticket;
  request.symbol = _Symbol;
  request.sl = round(pSLPrice/tickSize) * tickSize;
  request.tp = round(pTPPrice/tickSize) * tickSize;
  request.comment = "MOD. " + " | " + _Symbol + " | " + string(pMagic) 
                            + ", SL: " + DoubleToString(request.sl,_Digits) + ", TP: " + DoubleToString(request.tp,_Digits);

  if(request.sl > 0 || request.tp > 0)
  {
    Sleep(1000);
    bool send = OrderSend(request,result);
    Print(result.comment);

    if(!send){
      Print("OrderSend Modification error: ", GetLastError());
      Sleep(3000);

      send = OrderSend(request,result);
      Print(result.comment);
      if(!send) Print("OrderSend Modification error: ", GetLastError());
    }
  }
}

bool CheckPlacedPositions(ulong pMagic)
{
  bool placedPosition = false;

  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    PositionSelectByTicket(positionTicket);

    ulong posMagic = PositionGetInteger(POSITION_MAGIC);

    if(posMagic == pMagic)
    {
      placedPosition = true;
      break;
    }
  }
  return placedPosition;
}

void CloseTrades(ulong pMagic, string pExitSignal)
{
  //Request and Result Declaration and Initialization
  MqlTradeRequest request = {};
  MqlTradeResult result   = {};

  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    ulong positionTicket = PositionGetTicket(i);
    PositionSelectByTicket(positionTicket);

    ulong posMagic = PositionGetInteger(POSITION_MAGIC);
    ulong posType = PositionGetInteger(POSITION_TYPE);

    if(posMagic == pMagic && pExitSignal == "EXIT_LONG" && posType == ORDER_TYPE_BUY)
    {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_SELL;
      request.symbol = _Symbol;
      request.position = positionTicket;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      request.deviation = 10;

      bool sent = OrderSend(request,result);
      if(sent == true) {Print("Position #",positionTicket, " closed");}
    }
    else if(posMagic == pMagic && pExitSignal == "EXIT_SHORT" && posType == ORDER_TYPE_SELL)
    {
      request.action = TRADE_ACTION_DEAL;
      request.type = ORDER_TYPE_BUY;
      request.symbol = _Symbol;
      request.position = positionTicket;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      request.deviation = 10;

      bool sent = OrderSend(request,result);
      if(sent == true) {Print("Position #",positionTicket, " closed");}
    }
  }
}

//+--------+// Position Management Functions //+--------+//

double CalculateStopLoss(string pEntrySignal, int pSLFixedPoints, int pSLFixedPointsMA, double pMA)
{
  double stoploss = 0.0;
  double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

  if(pEntrySignal == "LONG")
  {
    if(pSLFixedPoints > 0) stoploss = askPrice - (pSLFixedPoints * _Point); //1.11125 - (100 * 0.00001)
    else if(pSLFixedPointsMA > 0) stoploss = pMA - (pSLFixedPointsMA * _Point);

    if(stoploss > 0) stoploss = AdjustBelowStopLevel(askPrice,stoploss);
  }
  else if(pEntrySignal == "SHORT")
  {
    if(pSLFixedPoints > 0) stoploss = bidPrice + (pSLFixedPoints * _Point); //1.11125 + (100 * 0.00001)
    else if(pSLFixedPointsMA > 0) stoploss = pMA + (pSLFixedPointsMA * _Point);

    if(stoploss > 0) stoploss = AdjustAboveStopLevel(bidPrice,stoploss);
  }

  stoploss = round(stoploss/tickSize) * tickSize;
  return stoploss;
}

double CalculateTakeProfit(string pEntrySignal, int pTPFixedPoints)
{
  double takeprofit = 0.0;
  double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

  if(pEntrySignal == "LONG")
  {
    if(pTPFixedPoints > 0) takeprofit = askPrice + (pTPFixedPoints * _Point); //1.11125 + (100 * 0.00001)

    if(takeprofit > 0) takeprofit = AdjustAboveStopLevel(askPrice,takeprofit);
  }
  else if(pEntrySignal == "SHORT")
  {
    if(pTPFixedPoints > 0) takeprofit = bidPrice - (pTPFixedPoints * _Point); //1.11125 - (100 * 0.00001)

    if(takeprofit > 0) takeprofit = AdjustBelowStopLevel(bidPrice,takeprofit);
  }

  takeprofit = round(takeprofit/tickSize) * tickSize;
  return takeprofit;
}

void TrailingStopLoss(ulong pMagic, int pTSLFixedPoints)
{
  //Request and Result Declaration and Initialization
  MqlTradeRequest request = {};
  MqlTradeResult result = {};

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    ulong positionTicket = PositionGetTicket(i);
    PositionSelectByTicket(positionTicket);

    ulong posMagic = PositionGetInteger(POSITION_MAGIC);
    ulong posType = PositionGetInteger(POSITION_TYPE);
    double currentStopLoss = PositionGetDouble(POSITION_SL);
    double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

    double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);  
    double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);       
    double newStopLoss;

    if(posMagic == pMagic && posType == ORDER_TYPE_BUY)
    {
      newStopLoss = askPrice - (pTSLFixedPoints * _Point);
      newStopLoss = AdjustBelowStopLevel(askPrice,newStopLoss);
      newStopLoss = round(newStopLoss/tickSize) * tickSize;

      // if(newStopLoss > currentStopLoss)
      if(NormalizeDouble(newStopLoss-currentStopLoss,_Digits) > 0 || currentStopLoss==0)
      {
        request.action = TRADE_ACTION_SLTP;
        request.position = positionTicket;
        request.comment = "TSL. " + " | " + _Symbol + " | " + string(pMagic);
        request.sl = newStopLoss;
        request.tp = PositionGetDouble(POSITION_TP);

        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend TSL error: ", GetLastError());
      }
    }
    else if(posMagic == pMagic && posType == ORDER_TYPE_SELL)
    {
      newStopLoss = bidPrice + (pTSLFixedPoints * _Point);
      newStopLoss = AdjustAboveStopLevel(askPrice,newStopLoss);
      newStopLoss = round(newStopLoss/tickSize) * tickSize;

      // if(newStopLoss < currentStopLoss)
      if(NormalizeDouble(newStopLoss-currentStopLoss,_Digits) < 0 || currentStopLoss==0)
      {
        request.action = TRADE_ACTION_SLTP;
        request.position = positionTicket;
        request.comment = "TSL. " + " | " + _Symbol + " | " + string(pMagic);
        request.sl = newStopLoss;
        request.tp = PositionGetDouble(POSITION_TP);

        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend TSL error: ", GetLastError());
      }
    }
  }
}

void BreakEven(ulong pMagic, int pBEFixedPoints)
{
  //Request and Result Declaration and Initialization
  MqlTradeRequest request = {};
  MqlTradeResult result = {};

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    //Reset of request and result values
    ZeroMemory(request);
    ZeroMemory(result);

    ulong positionTicket = PositionGetTicket(i);
    PositionSelectByTicket(positionTicket);

    ulong posMagic = PositionGetInteger(POSITION_MAGIC);
    ulong posType = PositionGetInteger(POSITION_TYPE);
    double currentStopLoss = PositionGetDouble(POSITION_SL);
    double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double newStopLoss = round(openPrice/tickSize) * tickSize;

    if(posMagic == pMagic && posType == ORDER_TYPE_BUY)
    {
      double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double BEThreshould = openPrice + (pBEFixedPoints*_Point);

      if(newStopLoss > currentStopLoss && bidPrice > BEThreshould)
      {
        request.action = TRADE_ACTION_SLTP;
        request.position = positionTicket;
        request.comment = "BE. " + " | " + _Symbol + " | " + string(pMagic);
        request.sl = newStopLoss;

        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend BE error: ", GetLastError());
      }
    }
    else if(posMagic == pMagic && posType == ORDER_TYPE_SELL)
    {
      double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double BEThreshould = openPrice - (pBEFixedPoints*_Point);

      if(newStopLoss < currentStopLoss && askPrice < BEThreshould)
      {
        request.action = TRADE_ACTION_SLTP;
        request.position = positionTicket;
        request.comment = "BE. " + " | " + _Symbol + " | " + string(pMagic);
        request.sl = newStopLoss;

        bool sent = OrderSend(request,result);
        if(!sent) Print("OrderSend BE error: ", GetLastError());
      }
    }
  }
}

double AdjustAboveStopLevel(double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
  double adjustedPrice = pPriceToAdjust;

  double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  long stopsLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);

  if(stopsLevel > 0)
  {
    double stopsLevelPrice = stopsLevel * point;        //stops level points in price
    stopsLevelPrice = pCurrentPrice + stopsLevelPrice;  //stops price level - distance from bid/ask

    double addPoints = pPointsToAdd * point;            // Points that will be added/substracted to stops level price to make sure we respect the distance fixed by stops level

    if(adjustedPrice <= stopsLevelPrice + addPoints)
    {
      adjustedPrice = stopsLevelPrice + addPoints;
      Print("Price adjusted above stop level to " + string(adjustedPrice));
    }
  }
  return adjustedPrice;
}

double AdjustBelowStopLevel(double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
  double adjustedPrice = pPriceToAdjust;

  double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  long stopsLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);

  if(stopsLevel > 0)
  {
    double stopsLevelPrice = stopsLevel * point;        //stops level points in price
    stopsLevelPrice = pCurrentPrice - stopsLevelPrice;  //stops price level - distance from bid/ask

    double addPoints = pPointsToAdd * point;            // Points that will be added/substracted to stops level price to make sure we respect the distance fixed by stops level

    if(adjustedPrice >= stopsLevelPrice - addPoints)
    {
      adjustedPrice = stopsLevelPrice - addPoints;
      Print("Price adjusted below stop level to " + string(adjustedPrice));
    }
  }
  return adjustedPrice;
}

//Filling Policy
bool IsFillingTypeAllowed(int pFillType)
{
  //-- get the value of the property describing the filling mode
  int symbolFillingMode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  //-- return "true" if the fill_type mode if allowed
  return ((symbolFillingMode & pFillType) == pFillType);
}
