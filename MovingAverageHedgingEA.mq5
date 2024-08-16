//+------------------------------------------------------------------+
//|                                       MovingAverageHedgingEA.mq5 |
//|                                                            duyng |
//|                                              github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property description "Moving Average Expert Advisor (Hedging)"
#property link      "github.com/duyng219"
#property version   "1.00"

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
sinput group                            "EA GENERAL SETTINGS"   // Biến đầu vào giới hạn
input ulong                            MagicNumber           = 101;

sinput group                             "MOVING AVERAGE SETTINGS"
input int                               MAPeriod              = 30;
input ENUM_MA_METHOD                    MAMethod              = MODE_SMA;
input int                               MAShift               = 0;
input ENUM_APPLIED_PRICE                MAPrice               = PRICE_CLOSE;

sinput group                              "MONEY MANAGEMENT"
input double                            FixedVolume           = 0.01;

sinput group                              "POSITION MANAGEMENT"
input ushort                            SLFixedPoints         = 0;
input ushort                            SLFixedPointsMA       = 0;
input ushort                            TPFixedPoints         = 0;
input ushort                            TSLFixedPoins         = 0;
input ushort                            BEFixedPoints         = 0;

datetime glTimeBarOpen;

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  glTimeBarOpen = D'1971.01.01 00:00';

  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  Print("Expert removed");
}

void OnTick()
{
  //-----------------------------------------//
  // NEW BAR CONTROL | ĐIỀU KHIỂN THANH MỚI  //
  //-----------------------------------------//

  bool newBar = false;
  
  //Check for New Bar
  if(glTimeBarOpen != iTime(_Symbol,PERIOD_CURRENT,0))
  {
    newBar = true;
    glTimeBarOpen = iTime(_Symbol,PERIOD_CURRENT,0);
  }

  if(newBar == true)
  {
    double newBarClose1 = Close(1);
    Print("Nến đóng cửa của thanh thứ 2 từ phải qua trái: ", newBarClose1);

    double newBarClose2 = iClose(_Symbol,PERIOD_CURRENT,1);
    Print("Nến đóng cửa của thanh thứ 2 từ phải qua trái sử dụng Param Predifine: ", newBarClose2);
    //-----------------------------------------//
    //   PRICE & INDICATORS | GIÁ & CHỈ SỐ     //
    //-----------------------------------------//
    
    //-----------------------------------------//
    //      TRADE EXIT | THOÁT GIAO DỊCH       //
    //-----------------------------------------//
        
    //-----------------------------------------//
    //   TRADE PLACEMENT | ĐẶT HÀNG GIAO DỊCH  //
    //-----------------------------------------//
  }
}

//+------------------------------------------------------------------+
//| EA FUNCTIONS | CHỨC NĂNG EA                                      |
//+------------------------------------------------------------------+

double Close(int pShift)
{
  MqlRates bar[];                              //it create an object array of MlqRates strucure | tạo một mảng đối tượng của cấu trúc MlqRates
  ArraySetAsSeries(bar,true);                  //it sets our array as a series array (so current bar is positon 0, previous bar is 1..) | đặt mảng của chúng ta thành một mảng chuỗi (vì vậy thanh hiện tại là positon 0, thanh trước đó là 1..)
  CopyRates(_Symbol,PERIOD_CURRENT,0,3,bar);   //it copies the bar price information of bars position 0, 1 and 2 to our array "bar" | sao chép thông tin giá thanh của vị trí thanh 0, 1 và 2 vào mảng "bar"

  return bar[pShift].close;
}