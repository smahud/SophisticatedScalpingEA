//+------------------------------------------------------------------+
//|                                                   CSM_Engine.mqh |
//|                                    Copyright 2025, ScalpingEA Pro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ScalpingEA Pro"

//--- Structures
struct SCurrencyData
{
    string currency;
    double strength[6]; // For 6 timeframes
    double avgStrength;
    datetime lastUpdate;
};

struct SPairData
{
    string pair;
    string baseCurrency;
    string quoteCurrency;
    double correlation[6];
    datetime lastUpdate;
};

//+------------------------------------------------------------------+
//| Currency Strength Meter Engine Class                            |
//+------------------------------------------------------------------+
class CCSMEngine
{
private:
    SCurrencyData     m_currencies[9]; // 9 major currencies
    SPairData         m_pairs[8];      // 8 USD pairs
    ENUM_TIMEFRAMES   m_timeframes[6];
    int               m_calculationPeriod;
    datetime          m_lastCalculation;
    
    // CSM calculation variables
    double            m_weights[6];    // Timeframe weights
    double            m_correlationMatrix[9][9];
    
public:
    // Constructor
    CCSMEngine(int calculationPeriod);
    
    // Destructor
    ~CCSMEngine();
    
    // Initialization
    bool Initialize(string &pairs[], ENUM_TIMEFRAMES &timeframes[]);
    
    // Main calculation function
    bool Calculate();
    
    // Currency strength functions
    double GetCurrencyStrength(string currency);
    double GetCurrencyStrength(string currency, ENUM_TIMEFRAMES tf);
    
    // Correlation functions
    double GetCorrelationConfidence();
    double GetPairCorrelation(string pair1, string pair2);
    
    // Utility functions
    bool IsStrongCurrency(string currency, double threshold = 70.0);
    bool IsWeakCurrency(string currency, double threshold = -70.0);
    string GetStrongestCurrency();
    string GetWeakestCurrency();
    
    // Analysis functions
    double CalculateUSDIndex();
    bool IsUSDStrong(double threshold = 70.0);
    bool IsUSDWeak(double threshold = -70.0);
    
private:
    // Core calculation functions
    double CalculateOHLCStrength(string pair, ENUM_TIMEFRAMES tf);
    double CalculateWeightedStrength(string currency);
    void UpdateCorrelationMatrix();
    double CalculateCorrelation(string pair1, string pair2, ENUM_TIMEFRAMES tf);
    
    // Utility functions
    int GetCurrencyIndex(string currency);
    int GetPairIndex(string pair);
    int GetTimeframeIndex(ENUM_TIMEFRAMES tf);
    string ExtractBaseCurrency(string pair);
    string ExtractQuoteCurrency(string pair);
    
    // Validation functions
    bool ValidatePair(string pair);
    bool ValidateTimeframe(ENUM_TIMEFRAMES tf);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCSMEngine::CCSMEngine(int calculationPeriod)
{
    m_calculationPeriod = calculationPeriod;
    m_lastCalculation = 0;
    
    // Set timeframe weights (higher weight for lower timeframes in scalping)
    m_weights[0] = 0.30; // M1
    m_weights[1] = 0.25; // M5
    m_weights[2] = 0.20; // M15
    m_weights[3] = 0.15; // M30
    m_weights[4] = 0.07; // H1
    m_weights[5] = 0.03; // H4
    
    // Initialize correlation matrix
    ArrayInitialize(m_correlationMatrix, 0.0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCSMEngine::~CCSMEngine()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize CSM engine                                            |
//+------------------------------------------------------------------+
bool CCSMEngine::Initialize(string &pairs[], ENUM_TIMEFRAMES &timeframes[])
{
    Print("Initializing CSM Engine...");
    
    // Copy timeframes
    int tfCount = ArraySize(timeframes);
    if(tfCount > 6) tfCount = 6;
    
    for(int i = 0; i < tfCount; i++)
    {
        m_timeframes[i] = timeframes[i];
    }
    
    // Initialize currencies
    string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD", "SEK"};
    
    for(int i = 0; i < ArraySize(currencies) && i < 9; i++)
    {
        m_currencies[i].currency = currencies[i];
        m_currencies[i].avgStrength = 0.0;
        m_currencies[i].lastUpdate = 0;
        ArrayInitialize(m_currencies[i].strength, 0.0);
    }
    
    // Initialize pairs
    int pairCount = ArraySize(pairs);
    if(pairCount > 8) pairCount = 8;
    
    for(int i = 0; i < pairCount; i++)
    {
        if(!ValidatePair(pairs[i]))
        {
            Print("Invalid pair: ", pairs[i]);
            continue;
        }
        
        m_pairs[i].pair = pairs[i];
        m_pairs[i].baseCurrency = ExtractBaseCurrency(pairs[i]);
        m_pairs[i].quoteCurrency = ExtractQuoteCurrency(pairs[i]);
        m_pairs[i].lastUpdate = 0;
        ArrayInitialize(m_pairs[i].correlation, 0.0);
    }
    
    Print("CSM Engine initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Main calculation function                                        |
//+------------------------------------------------------------------+
bool CCSMEngine::Calculate()
{
    datetime currentTime = TimeCurrent();
    
    // Skip if calculated recently (every 5 seconds)
    if(currentTime - m_lastCalculation < 5)
        return true;
    
    m_lastCalculation = currentTime;
    
    // Calculate OHLC strength for each pair and timeframe
    for(int i = 0; i < ArraySize(m_pairs); i++)
    {
        if(m_pairs[i].pair == "")
            continue;
            
        for(int j = 0; j < ArraySize(m_timeframes); j++)
        {
            if(m_timeframes[j] == PERIOD_CURRENT)
                continue;
                
            double pairStrength = CalculateOHLCStrength(m_pairs[i].pair, m_timeframes[j]);
            
            // Update base currency strength
            int baseIndex = GetCurrencyIndex(m_pairs[i].baseCurrency);
            if(baseIndex >= 0)
            {
                m_currencies[baseIndex].strength[j] += pairStrength;
            }
            
            // Update quote currency strength (inverse)
            int quoteIndex = GetCurrencyIndex(m_pairs[i].quoteCurrency);
            if(quoteIndex >= 0)
            {
                m_currencies[quoteIndex].strength[j] -= pairStrength;
            }
        }
    }
    
    // Calculate weighted average strength for each currency
    for(int i = 0; i < ArraySize(m_currencies); i++)
    {
        if(m_currencies[i].currency == "")
            continue;
            
        m_currencies[i].avgStrength = CalculateWeightedStrength(m_currencies[i].currency);
        m_currencies[i].lastUpdate = currentTime;
    }
    
    // Update correlation matrix
    UpdateCorrelationMatrix();
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate OHLC strength                                          |
//+------------------------------------------------------------------+
double CCSMEngine::CalculateOHLCStrength(string pair, ENUM_TIMEFRAMES tf)
{
    double strength = 0.0;
    
    // Get OHLC data
    double open[], high[], low[], close[];
    
    if(CopyOpen(pair, tf, 1, m_calculationPeriod, open) <= 0 ||
       CopyHigh(pair, tf, 1, m_calculationPeriod, high) <= 0 ||
       CopyLow(pair, tf, 1, m_calculationPeriod, low) <= 0 ||
       CopyClose(pair, tf, 1, m_calculationPeriod, close) <= 0)
    {
        return 0.0;
    }
    
    int count = ArraySize(close);
    double totalStrength = 0.0;
    
    for(int i = 0; i < count; i++)
    {
        if(high[i] - low[i] == 0)
            continue;
            
        // CSM Formula: ((Close-Open) + (High-Low)) / (High-Low) * 100
        double candleStrength = ((close[i] - open[i]) + (high[i] - low[i])) / (high[i] - low[i]) * 100.0;
        totalStrength += candleStrength;
    }
    
    if(count > 0)
        strength = totalStrength / count;
    
    // Normalize to -100 to +100 range
    if(strength > 100.0) strength = 100.0;
    if(strength < -100.0) strength = -100.0;
    
    return strength;
}

//+------------------------------------------------------------------+
//| Calculate weighted strength                                      |
//+------------------------------------------------------------------+
double CCSMEngine::CalculateWeightedStrength(string currency)
{
    int currIndex = GetCurrencyIndex(currency);
    if(currIndex < 0)
        return 0.0;
    
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for(int i = 0; i < ArraySize(m_timeframes); i++)
    {
        if(m_timeframes[i] == PERIOD_CURRENT)
            continue;
            
        weightedSum += m_currencies[currIndex].strength[i] * m_weights[i];
        totalWeight += m_weights[i];
    }
    
    return (totalWeight > 0) ? weightedSum / totalWeight : 0.0;
}

//+------------------------------------------------------------------+
//| Get currency strength                                            |
//+------------------------------------------------------------------+
double CCSMEngine::GetCurrencyStrength(string currency)
{
    int index = GetCurrencyIndex(currency);
    if(index < 0)
        return 0.0;
    
    return m_currencies[index].avgStrength;
}

//+------------------------------------------------------------------+
//| Get currency strength for specific timeframe                    |
//+------------------------------------------------------------------+
double CCSMEngine::GetCurrencyStrength(string currency, ENUM_TIMEFRAMES tf)
{
    int currIndex = GetCurrencyIndex(currency);
    int tfIndex = GetTimeframeIndex(tf);
    
    if(currIndex < 0 || tfIndex < 0)
        return 0.0;
    
    return m_currencies[currIndex].strength[tfIndex];
}

//+------------------------------------------------------------------+
//| Update correlation matrix                                        |
//+------------------------------------------------------------------+
void CCSMEngine::UpdateCorrelationMatrix()
{
    for(int i = 0; i < ArraySize(m_pairs); i++)
    {
        for(int j = i + 1; j < ArraySize(m_pairs); j++)
        {
            if(m_pairs[i].pair == "" || m_pairs[j].pair == "")
                continue;
                
            double correlation = 0.0;
            int validCorrelations = 0;
            
            // Calculate correlation across timeframes
            for(int k = 0; k < ArraySize(m_timeframes); k++)
            {
                double tfCorr = CalculateCorrelation(m_pairs[i].pair, m_pairs[j].pair, m_timeframes[k]);
                if(tfCorr != 0.0)
                {
                    correlation += tfCorr;
                    validCorrelations++;
                }
            }
            
            if(validCorrelations > 0)
                correlation /= validCorrelations;
            
            m_correlationMatrix[i][j] = correlation;
            m_correlationMatrix[j][i] = correlation; // Symmetric matrix
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate correlation between two pairs                         |
//+------------------------------------------------------------------+
double CCSMEngine::CalculateCorrelation(string pair1, string pair2, ENUM_TIMEFRAMES tf)
{
    double close1[], close2[];
    
    if(CopyClose(pair1, tf, 1, 50, close1) <= 0 ||
       CopyClose(pair2, tf, 1, 50, close2) <= 0)
    {
        return 0.0;
    }
    
    int count = MathMin(ArraySize(close1), ArraySize(close2));
    if(count < 10)
        return 0.0;
    
    // Calculate correlation coefficient
    double sum1 = 0, sum2 = 0, sum1sq = 0, sum2sq = 0, sum12 = 0;
    
    for(int i = 0; i < count; i++)
    {
        sum1 += close1[i];
        sum2 += close2[i];
        sum1sq += close1[i] * close1[i];
        sum2sq += close2[i] * close2[i];
        sum12 += close1[i] * close2[i];
    }
    
    double num = count * sum12 - sum1 * sum2;
    double den = MathSqrt((count * sum1sq - sum1 * sum1) * (count * sum2sq - sum2 * sum2));
    
    return (den != 0) ? num / den : 0.0;
}

//+------------------------------------------------------------------+
//| Get correlation confidence                                       |
//+------------------------------------------------------------------+
double CCSMEngine::GetCorrelationConfidence()
{
    double totalCorrelation = 0.0;
    int correlationCount = 0;
    
    for(int i = 0; i < ArraySize(m_pairs); i++)
    {
        for(int j = i + 1; j < ArraySize(m_pairs); j++)
        {
            if(m_correlationMatrix[i][j] != 0.0)
            {
                totalCorrelation += MathAbs(m_correlationMatrix[i][j]);
                correlationCount++;
            }
        }
    }
    
    return (correlationCount > 0) ? (totalCorrelation / correlationCount) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| Calculate USD index                                              |
//+------------------------------------------------------------------+
double CCSMEngine::CalculateUSDIndex()
{
    return GetCurrencyStrength("USD");
}

//+------------------------------------------------------------------+
//| Check if USD is strong                                           |
//+------------------------------------------------------------------+
bool CCSMEngine::IsUSDStrong(double threshold = 70.0)
{
    return GetCurrencyStrength("USD") > threshold;
}

//+------------------------------------------------------------------+
//| Check if USD is weak                                             |
//+------------------------------------------------------------------+
bool CCSMEngine::IsUSDWeak(double threshold = -70.0)
{
    return GetCurrencyStrength("USD") < threshold;
}

//+------------------------------------------------------------------+
//| Get strongest currency                                           |
//+------------------------------------------------------------------+
string CCSMEngine::GetStrongestCurrency()
{
    double maxStrength = -1000.0;
    string strongest = "";
    
    for(int i = 0; i < ArraySize(m_currencies); i++)
    {
        if(m_currencies[i].currency != "" && m_currencies[i].avgStrength > maxStrength)
        {
            maxStrength = m_currencies[i].avgStrength;
            strongest = m_currencies[i].currency;
        }
    }
    
    return strongest;
}

//+------------------------------------------------------------------+
//| Get weakest currency                                             |
//+------------------------------------------------------------------+
string CCSMEngine::GetWeakestCurrency()
{
    double minStrength = 1000.0;
    string weakest = "";
    
    for(int i = 0; i < ArraySize(m_currencies); i++)
    {
        if(m_currencies[i].currency != "" && m_currencies[i].avgStrength < minStrength)
        {
            minStrength = m_currencies[i].avgStrength;
            weakest = m_currencies[i].currency;
        }
    }
    
    return weakest;
}

//+------------------------------------------------------------------+
//| Get currency index                                               |
//+------------------------------------------------------------------+
int CCSMEngine::GetCurrencyIndex(string currency)
{
    for(int i = 0; i < ArraySize(m_currencies); i++)
    {
        if(m_currencies[i].currency == currency)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Get pair index                                                   |
//+------------------------------------------------------------------+
int CCSMEngine::GetPairIndex(string pair)
{
    for(int i = 0; i < ArraySize(m_pairs); i++)
    {
        if(m_pairs[i].pair == pair)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Get timeframe index                                              |
//+------------------------------------------------------------------+
int CCSMEngine::GetTimeframeIndex(ENUM_TIMEFRAMES tf)
{
    for(int i = 0; i < ArraySize(m_timeframes); i++)
    {
        if(m_timeframes[i] == tf)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Extract base currency from pair                                  |
//+------------------------------------------------------------------+
string CCSMEngine::ExtractBaseCurrency(string pair)
{
    if(StringLen(pair) >= 3)
        return StringSubstr(pair, 0, 3);
    return "";
}

//+------------------------------------------------------------------+
//| Extract quote currency from pair                                 |
//+------------------------------------------------------------------+
string CCSMEngine::ExtractQuoteCurrency(string pair)
{
    if(StringLen(pair) >= 6)
        return StringSubstr(pair, 3, 3);
    return "";
}

//+------------------------------------------------------------------+
//| Validate pair                                                    |
//+------------------------------------------------------------------+
bool CCSMEngine::ValidatePair(string pair)
{
    return (StringLen(pair) == 6);
}

//+------------------------------------------------------------------+
//| Validate timeframe                                               |
//+------------------------------------------------------------------+
bool CCSMEngine::ValidateTimeframe(ENUM_TIMEFRAMES tf)
{
    return (tf != PERIOD_CURRENT && tf > 0);
}