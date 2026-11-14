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
input bool UseDecisionServer = false;
input string DecisionURL = "http://127.0.0.1:8765/v1/decision";
input string DecisionToken = ""; // never store production secrets in shared presets
input int DecisionTimeoutMs = 700;
input bool EnableTrading = false; // intentionally unsupported: safe shadow-only prototype

int hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
int hADX = INVALID_HANDLE, hATR = INVALID_HANDLE;
datetime lastClosedBar = 0;
string pendingSignal = "";
string pendingSymbol = "";
string pendingSide = "";
datetime pendingTimestamp = 0;
double pendingSpread = 0, pendingATR = 0, pendingADX = 0;

bool Approved(const string json, const string signalId)
{
   return StringFind(json, "\"signal_id\":\"" + signalId + "\"") >= 0 &&
          StringFind(json, "\"decision\":\"APPROVE\"") >= 0;
}
void OnTimer()
{
   if(!UseDecisionServer || pendingSignal == "") return;
   string id = pendingSignal;
   pendingSignal = ""; // consume once, including failures
   if(TimeCurrent() - pendingTimestamp > 20) { Print("Decision expired: ", id); return; }
   if(DecisionToken == "") { Print("Decision token missing; fail closed"); return; }
   string payload = StringFormat("{\"signal_id\":\"%s\",\"symbol\":\"%s\",\"side\":\"%s\",\"timestamp\":%I64d,\"ttl_seconds\":20,\"spread_points\":%.4f,\"atr_points\":%.4f,\"adx\":%.4f}",
      id, pendingSymbol, pendingSide, (long)TimeGMT(), pendingSpread, pendingATR, pendingADX);
   char body[], response[];
   StringToCharArray(payload, body, 0, StringLen(payload), CP_UTF8);
   string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + DecisionToken + "\r\n";
   string responseHeaders;
   ResetLastError();
   int status = WebRequest("POST", DecisionURL, headers, DecisionTimeoutMs, body, response, responseHeaders);
   if(status != 200) { PrintFormat("Decision unavailable HTTP=%d err=%d; fail closed", status, GetLastError()); return; }
   string result = CharArrayToString(response, 0, -1, CP_UTF8);
   // Deliberately informational only. Robust JSON schema validation and trade
   // execution are separate release gates.
   PrintFormat("ADVISORY %s %s raw=%s", id, Approved(result,id) ? "APPROVE" : "NOT_APPROVED", result);
}


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
   EventSetTimer(1);
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
   if(eligible && UseDecisionServer && pendingSignal == "")
   {
      pendingSymbol = _Symbol;
      pendingSide = side;
      pendingTimestamp = TimeCurrent();
      pendingSpread = spreadPts;
      pendingATR = atrPts;
      pendingADX = adx;
      pendingSignal = _Symbol + "_" + IntegerToString((long)closed) + "_" + side;
   }
   // No order functions intentionally. Next stage: immutable signal contract and
   // asynchronous advisory bridge; risk validation and broker execution remain separate.
}
