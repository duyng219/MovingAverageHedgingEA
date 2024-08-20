//+------------------------------------------------------------------+
//|                                       MovingAverageHedgingEA.mq5 |
//|                                                            duyng |
//|                                              github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property description "Moving Average Expert Advisor (Hedging)"
#property link "github.com/duyng219"
#property version "1.00"

// Expert Notes
// Expert Advisor that codes a Moving Average strategy
// It is designed to trade in direction of the trend, placing buy positions when last bar closes above the moving average and short sell positions when last bar closes below the moving average
// It incorporates two different alternative stop-loss that consists of fixed points below the open price or moving average, for long trades, or above the open price or moving average, for short trades
// It incorporates settings for placing profit taking, as well as break-even and trailing stop loss

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
input ENUM_MA_METHOD                      MAMethod                = MODE_SMA; //MODE_EMA,MODE_SMMA,MODE_LWMA
input ENUM_APPLIED_PRICE                  MAPrice                 = PRICE_CLOSE; //PRICE_OPEN,PRICE_HIGH,PRICE_LOW

sinput group                              "MONEY MANAGEMENT"
input double                              FixedVolume             = 0.01;

sinput group                              "POSITION MANAGEMENT"
input int                                 SLFixedPoints           = 0;
input int                                 SLFixedPointsMA         = 200;  
input int                                 TPFixedPoints           = 0;
input int                                 TSLFixedPoints          = 0;
input int                                 BEFixedPoints           = 0;

datetime    glTimeBarOpen;
int         MAHandle;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  glTimeBarOpen = D'1971.01.01 00:00';

  MAHandle = MA_Init(MAPeriod,MAShift,MAMethod,MAPrice);
  if(MAHandle == -1){
    return (INIT_FAILED);}

  return (INIT_SUCCEEDED);
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

    //--------------------//
    //   TRADE PLACEMENT  //
    //--------------------//

    string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
    if(entrySignal == "LONG")
    {
      Print("Long Trade Placed");
    } 
    else if(entrySignal == "SHORT")
    {
      Print("Short Trade Placed");
    }
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