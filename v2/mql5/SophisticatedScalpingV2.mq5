#property strict
#property version "2.00"
#property description "Research scaffold: analytical signals only, no live order execution"
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_M5;
input int FastEMAPeriod = 20;
input int SlowEMAPeriod = 50;
input int ADXPeriod = 14;
input int ATRPeriod = 14;
input double MinADX = 22.0;
input double MaxSpreadATRRatio = 0.12;
input bool EnableTrading = false; // intentionally unsupported: safe shadow-only prototype

int hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
int hADX = INVALID_HANDLE, hATR = INVALID_HANDLE;
datetime lastClosedBar = 0;

int OnInit()
{
   if(EnableTrading) {
      Print("V2 scaffold is shadow-only. Trading execution not implemented.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(FastEMAPeriod < 2 || SlowEMAPeriod <= FastEMAPeriod || ADXPeriod < 2 || ATRPeriod < 2)
      return INIT_PARAMETERS_INCORRECT;
   hFast = iMA(_Symbol, SignalTimeframe, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, SignalTimeframe, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hADX = iADX(_Symbol, SignalTimeframe, ADXPeriod);
   hATR = iATR(_Symbol, SignalTimeframe, ATRPeriod);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE ||
      hADX == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return INIT_FAILED;
   Print("V2 analytical shadow engine initialized for ", _Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
}

bool ReadClosed(const int handle, const int buffer, double &value)
{
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(handle, buffer, 1, 1, a) != 1) return false;
   value = a[0];
   return MathIsValidNumber(value) && value != EMPTY_VALUE;
}

void OnTick()
{
   datetime closed = iTime(_Symbol, SignalTimeframe, 1);
   if(closed <= 0 || closed == lastClosedBar) return;
   if(BarsCalculated(hFast) < SlowEMAPeriod + 2 ||
      BarsCalculated(hSlow) < SlowEMAPeriod + 2 ||
      BarsCalculated(hADX) < ADXPeriod + 2 ||
      BarsCalculated(hATR) < ATRPeriod + 2) return;

   double fast, slow, adx, atr;
   if(!ReadClosed(hFast, 0, fast) || !ReadClosed(hSlow, 0, slow) ||
      !ReadClosed(hADX, 0, adx) || !ReadClosed(hATR, 0, atr)) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= tick.bid || atr <= 0) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return;
   double spreadPts = (tick.ask - tick.bid) / point;
   double atrPts = atr / point;
   lastClosedBar = closed;
   string side = fast > slow ? "BUY" : fast < slow ? "SELL" : "NONE";
   bool eligible = side != "NONE" && adx >= MinADX &&
                   spreadPts / atrPts <= MaxSpreadATRRatio;
   PrintFormat("SHADOW signal=%s eligible=%s bar=%s EMAfast=%.8f EMAslow=%.8f ADX=%.2f ATRpts=%.1f spreadpts=%.1f",
               side, eligible ? "true" : "false",
               TimeToString(closed, TIME_DATE|TIME_SECONDS),
               fast, slow, adx, atrPts, spreadPts);
   // No order functions intentionally. Next stage: immutable signal contract and
   // asynchronous advisory bridge; risk validation and broker execution remain separate.
}
