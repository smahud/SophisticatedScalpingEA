//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                    Copyright 2025, ScalpingEA Pro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ScalpingEA Pro"

//--- Include required libraries
#include <Trade\PositionInfo.mqh>

//--- Structures
struct SPositionData
{
    ulong ticket;
    string symbol;
    double volume;
    double openPrice;
    double stopLoss;
    double takeProfit;
    datetime openTime;
    double riskAmount;
    bool isActive;
};

struct SRiskSettings
{
    double riskPerTrade;      // Risk per trade in %
    double maxTotalRisk;      // Maximum total risk in %
    int maxPositions;         // Maximum concurrent positions
    int maxPositionsPerPair;  // Maximum positions per pair
    double maxDrawdown;       // Maximum drawdown in %
    double emergencyStopLevel; // Emergency stop level in %
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    SRiskSettings     m_settings;
    SPositionData     m_positions[50];
    int               m_positionCount;
    int               m_magicNumber;
    
    // Account information
    double            m_accountBalance;
    double            m_accountEquity;
    double            m_initialBalance;
    double            m_currentDrawdown;
    double            m_maxDrawdown;
    
    // Risk metrics
    double            m_totalRiskAmount;
    double            m_dailyLoss;
    datetime          m_lastResetDate;
    int               m_consecutiveLosses;
    
    // Emergency protection
    bool              m_emergencyMode;
    datetime          m_emergencyStartTime;
    
    // Position info helper
    CPositionInfo*    m_positionInfo;
    
public:
    // Constructor
    CRiskManager(double riskPerTrade, double maxTotalRisk, int maxPositions, int maxPositionsPerPair);
    
    // Destructor
    ~CRiskManager();
    
    // Initialization
    bool Initialize(int magicNumber);
    
    // Position management
    bool CanOpenPosition(string symbol);
    double CalculatePositionSize(string symbol, double stopLossPoints);
    bool RegisterPosition(ulong ticket, string symbol, double volume);
    bool UnregisterPosition(ulong ticket);
    void UpdatePositions();
    
    // Risk monitoring
    bool CheckRiskLimits();
    double GetCurrentRisk();
    double GetTotalRiskAmount();
    int GetActivePositions();
    int GetActivePositions(string symbol);
    
    // Drawdown management
    void UpdateDrawdown();
    double GetCurrentDrawdown();
    double GetMaxDrawdown();
    bool IsDrawdownExcessive();
    
    // Emergency protection
    bool CheckEmergencyConditions();
    void ActivateEmergencyMode();
    void DeactivateEmergencyMode();
    bool IsEmergencyMode();
    
    // Daily risk reset
    void CheckDailyReset();
    void ResetDailyCounters();
    
    // Position sizing algorithms
    double CalculateFixedLotSize(double riskAmount, double stopLossPoints);
    double CalculatePercentageSize(double riskPercentage, double stopLossPoints);
    double CalculateVolatilityBasedSize(string symbol, double riskAmount);
    
    // Correlation risk management
    bool CheckCorrelationRisk(string symbol);
    double GetPortfolioCorrelation();
    
    // Trade statistics
    void UpdateTradeStatistics(bool isWin, double profit);
    double GetWinRate();
    double GetProfitFactor();
    
    // Utility functions
    void PrintRiskStatus();
    string GetRiskReport();
    
private:
    // Internal functions
    void UpdateAccountInfo();
    bool ValidatePositionSize(double volume);
    double NormalizeLotSize(double volume);
    int FindPositionIndex(ulong ticket);
    void CleanupInactivePositions();
    
    // Risk calculation helpers
    double CalculateRiskAmount(double volume, double stopLossPoints);
    double GetMinLotSize();
    double GetMaxLotSize();
    double GetLotStep();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double riskPerTrade, double maxTotalRisk, int maxPositions, int maxPositionsPerPair)
{
    m_settings.riskPerTrade = riskPerTrade;
    m_settings.maxTotalRisk = maxTotalRisk;
    m_settings.maxPositions = maxPositions;
    m_settings.maxPositionsPerPair = maxPositionsPerPair;
    m_settings.maxDrawdown = 20.0; // 20% maximum drawdown
    m_settings.emergencyStopLevel = 15.0; // 15% emergency stop
    
    m_positionCount = 0;
    m_magicNumber = 0;
    m_accountBalance = 0;
    m_accountEquity = 0;
    m_initialBalance = 0;
    m_currentDrawdown = 0;
    m_maxDrawdown = 0;
    m_totalRiskAmount = 0;
    m_dailyLoss = 0;
    m_lastResetDate = 0;
    m_consecutiveLosses = 0;
    m_emergencyMode = false;
    m_emergencyStartTime = 0;
    
    // Initialize position info helper
    m_positionInfo = new CPositionInfo();
    
    // Initialize positions array
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        m_positions[i].ticket = 0;
        m_positions[i].symbol = "";
        m_positions[i].volume = 0;
        m_positions[i].openPrice = 0;
        m_positions[i].stopLoss = 0;
        m_positions[i].takeProfit = 0;
        m_positions[i].openTime = 0;
        m_positions[i].riskAmount = 0;
        m_positions[i].isActive = false;
    }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
    if(m_positionInfo != NULL)
    {
        delete m_positionInfo;
        m_positionInfo = NULL;
    }
}

//+------------------------------------------------------------------+
//| Initialize Risk Manager                                          |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(int magicNumber)
{
    Print("Initializing Risk Manager...");
    
    m_magicNumber = magicNumber;
    
    // Update account information
    UpdateAccountInfo();
    m_initialBalance = m_accountBalance;
    
    // Reset daily counters
    ResetDailyCounters();
    
    // Load existing positions
    UpdatePositions();
    
    Print("Risk Manager initialized successfully");
    Print("Account Balance: ", m_accountBalance);
    Print("Risk per Trade: ", m_settings.riskPerTrade, "%");
    Print("Max Total Risk: ", m_settings.maxTotalRisk, "%");
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if can open position                                       |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenPosition(string symbol)
{
    // Check emergency mode
    if(m_emergencyMode)
    {
        Print("Cannot open position: Emergency mode active");
        return false;
    }
    
    // Check maximum positions
    if(GetActivePositions() >= m_settings.maxPositions)
    {
        Print("Cannot open position: Maximum positions reached");
        return false;
    }
    
    // Check positions per pair
    if(GetActivePositions(symbol) >= m_settings.maxPositionsPerPair)
    {
        Print("Cannot open position: Maximum positions per pair reached for ", symbol);
        return false;
    }
    
    // Check total risk
    if(GetCurrentRisk() >= m_settings.maxTotalRisk)
    {
        Print("Cannot open position: Maximum total risk reached");
        return false;
    }
    
    // Check drawdown
    if(IsDrawdownExcessive())
    {
        Print("Cannot open position: Excessive drawdown");
        return false;
    }
    
    // Check correlation risk
    if(!CheckCorrelationRisk(symbol))
    {
        Print("Cannot open position: Correlation risk too high for ", symbol);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double stopLossPoints)
{
    if(stopLossPoints <= 0)
        return 0;
    
    // Update account info
    UpdateAccountInfo();
    
    // Calculate risk amount
    double riskAmount = m_accountBalance * m_settings.riskPerTrade / 100.0;
    
    // Adjust for consecutive losses
    if(m_consecutiveLosses >= 3)
    {
        double reductionFactor = 1.0 - (m_consecutiveLosses - 2) * 0.1;
        if(reductionFactor < 0.5) reductionFactor = 0.5;
        riskAmount *= reductionFactor;
    }
    
    // Calculate position size
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double pointValue = tickValue * _Point / tickSize;
    
    double volume = riskAmount / (stopLossPoints * pointValue);
    
    // Normalize lot size
    volume = NormalizeLotSize(volume);
    
    // Validate position size
    if(!ValidatePositionSize(volume))
        return 0;
    
    return volume;
}

//+------------------------------------------------------------------+
//| Register position                                                |
//+------------------------------------------------------------------+
bool CRiskManager::RegisterPosition(ulong ticket, string symbol, double volume)
{
    if(m_positionCount >= ArraySize(m_positions))
        return false;
    
    // Find empty slot
    int index = -1;
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        if(!m_positions[i].isActive)
        {
            index = i;
            break;
        }
    }
    
    if(index < 0)
        return false;
    
    // Get position info
    if(m_positionInfo == NULL || !m_positionInfo.SelectByTicket(ticket))
        return false;
    
    // Register position
    m_positions[index].ticket = ticket;
    m_positions[index].symbol = symbol;
    m_positions[index].volume = volume;
    m_positions[index].openPrice = m_positionInfo.PriceOpen();
    m_positions[index].stopLoss = m_positionInfo.StopLoss();
    m_positions[index].takeProfit = m_positionInfo.TakeProfit();
    m_positions[index].openTime = m_positionInfo.Time();
    m_positions[index].isActive = true;
    
    // Calculate risk amount
    double slDistance = MathAbs(m_positions[index].openPrice - m_positions[index].stopLoss);
    m_positions[index].riskAmount = CalculateRiskAmount(volume, slDistance / _Point);
    
    m_positionCount++;
    m_totalRiskAmount += m_positions[index].riskAmount;
    
    Print("Position registered: Ticket=", ticket, " Symbol=", symbol, " Risk=", m_positions[index].riskAmount);
    
    return true;
}

//+------------------------------------------------------------------+
//| Unregister position                                              |
//+------------------------------------------------------------------+
bool CRiskManager::UnregisterPosition(ulong ticket)
{
    int index = FindPositionIndex(ticket);
    if(index < 0)
        return false;
    
    // Get position result for statistics
    if(m_positionInfo != NULL && m_positionInfo.SelectByTicket(ticket))
    {
        double profit = m_positionInfo.Profit();
        UpdateTradeStatistics(profit > 0, profit);
    }
    
    // Remove from tracking
    m_totalRiskAmount -= m_positions[index].riskAmount;
    m_positions[index].isActive = false;
    m_positionCount--;
    
    Print("Position unregistered: Ticket=", ticket);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update positions                                                 |
//+------------------------------------------------------------------+
void CRiskManager::UpdatePositions()
{
    if(m_positionInfo == NULL)
        return;
        
    // Check for closed positions
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        if(!m_positions[i].isActive)
            continue;
        
        if(!m_positionInfo.SelectByTicket(m_positions[i].ticket))
        {
            // Position closed
            UnregisterPosition(m_positions[i].ticket);
        }
    }
    
    // Update account info
    UpdateAccountInfo();
    
    // Update drawdown
    UpdateDrawdown();
    
    // Check daily reset
    CheckDailyReset();
    
    // Check emergency conditions
    CheckEmergencyConditions();
}

//+------------------------------------------------------------------+
//| Check risk limits                                                |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRiskLimits()
{
    UpdatePositions();
    
    // Check total risk
    if(GetCurrentRisk() > m_settings.maxTotalRisk)
    {
        Print("WARNING: Total risk exceeded: ", GetCurrentRisk(), "%");
        return false;
    }
    
    // Check drawdown
    if(IsDrawdownExcessive())
    {
        Print("WARNING: Excessive drawdown: ", GetCurrentDrawdown(), "%");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current risk                                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentRisk()
{
    if(m_accountBalance <= 0)
        return 0;
    
    return (m_totalRiskAmount / m_accountBalance) * 100.0;
}

//+------------------------------------------------------------------+
//| Get total risk amount                                            |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalRiskAmount()
{
    return m_totalRiskAmount;
}

//+------------------------------------------------------------------+
//| Get active positions                                             |
//+------------------------------------------------------------------+
int CRiskManager::GetActivePositions()
{
    return m_positionCount;
}

//+------------------------------------------------------------------+
//| Get active positions for symbol                                  |
//+------------------------------------------------------------------+
int CRiskManager::GetActivePositions(string symbol)
{
    int count = 0;
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        if(m_positions[i].isActive && m_positions[i].symbol == symbol)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Update drawdown                                                  |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDrawdown()
{
    UpdateAccountInfo();
    
    if(m_initialBalance > 0)
    {
        m_currentDrawdown = ((m_initialBalance - m_accountEquity) / m_initialBalance) * 100.0;
        
        if(m_currentDrawdown > m_maxDrawdown)
            m_maxDrawdown = m_currentDrawdown;
    }
}

//+------------------------------------------------------------------+
//| Get current drawdown                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
    return m_currentDrawdown;
}

//+------------------------------------------------------------------+
//| Get max drawdown                                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxDrawdown()
{
    return m_maxDrawdown;
}

//+------------------------------------------------------------------+
//| Check if drawdown is excessive                                   |
//+------------------------------------------------------------------+
bool CRiskManager::IsDrawdownExcessive()
{
    return (m_currentDrawdown > m_settings.maxDrawdown);
}

//+------------------------------------------------------------------+
//| Check emergency conditions                                       |
//+------------------------------------------------------------------+
bool CRiskManager::CheckEmergencyConditions()
{
    // Check emergency drawdown level
    if(m_currentDrawdown > m_settings.emergencyStopLevel)
    {
        if(!m_emergencyMode)
        {
            ActivateEmergencyMode();
            return true;
        }
    }
    else
    {
        // Deactivate emergency mode if conditions improve
        if(m_emergencyMode && TimeCurrent() - m_emergencyStartTime > 3600) // 1 hour
        {
            DeactivateEmergencyMode();
        }
    }
    
    return m_emergencyMode;
}

//+------------------------------------------------------------------+
//| Activate emergency mode                                          |
//+------------------------------------------------------------------+
void CRiskManager::ActivateEmergencyMode()
{
    m_emergencyMode = true;
    m_emergencyStartTime = TimeCurrent();
    
    Print("*** EMERGENCY MODE ACTIVATED ***");
    Print("Current Drawdown: ", m_currentDrawdown, "%");
    Print("Trading suspended until conditions improve");
}

//+------------------------------------------------------------------+
//| Deactivate emergency mode                                        |
//+------------------------------------------------------------------+
void CRiskManager::DeactivateEmergencyMode()
{
    m_emergencyMode = false;
    m_emergencyStartTime = 0;
    
    Print("*** EMERGENCY MODE DEACTIVATED ***");
    Print("Normal trading resumed");
}

//+------------------------------------------------------------------+
//| Is emergency mode                                                |
//+------------------------------------------------------------------+
bool CRiskManager::IsEmergencyMode()
{
    return m_emergencyMode;
}

//+------------------------------------------------------------------+
//| Check daily reset                                                |
//+------------------------------------------------------------------+
void CRiskManager::CheckDailyReset()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime currentDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(currentDate != m_lastResetDate)
    {
        ResetDailyCounters();
        m_lastResetDate = currentDate;
    }
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyCounters()
{
    m_dailyLoss = 0;
    // Don't reset consecutive losses - they persist across days
}

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo()
{
    m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLotSize(double volume)
{
    double minLot = GetMinLotSize();
    double maxLot = GetMaxLotSize();
    double lotStep = GetLotStep();
    
    // Ensure minimum lot size
    if(volume < minLot)
        volume = minLot;
    
    // Ensure maximum lot size
    if(volume > maxLot)
        volume = maxLot;
    
    // Round to lot step
    volume = MathRound(volume / lotStep) * lotStep;
    
    return volume;
}

//+------------------------------------------------------------------+
//| Validate position size                                           |
//+------------------------------------------------------------------+
bool CRiskManager::ValidatePositionSize(double volume)
{
    double minLot = GetMinLotSize();
    double maxLot = GetMaxLotSize();
    
    return (volume >= minLot && volume <= maxLot);
}

//+------------------------------------------------------------------+
//| Get minimum lot size                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetMinLotSize()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
//| Get maximum lot size                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxLotSize()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
}

//+------------------------------------------------------------------+
//| Get lot step                                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetLotStep()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
}

//+------------------------------------------------------------------+
//| Find position index                                              |
//+------------------------------------------------------------------+
int CRiskManager::FindPositionIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        if(m_positions[i].isActive && m_positions[i].ticket == ticket)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Calculate risk amount                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskAmount(double volume, double stopLossPoints)
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double pointValue = tickValue * _Point / tickSize;
    
    return volume * stopLossPoints * pointValue;
}

//+------------------------------------------------------------------+
//| Update trade statistics                                          |
//+------------------------------------------------------------------+
void CRiskManager::UpdateTradeStatistics(bool isWin, double profit)
{
    if(isWin)
    {
        m_consecutiveLosses = 0;
    }
    else
    {
        m_consecutiveLosses++;
        m_dailyLoss += MathAbs(profit);
    }
}

//+------------------------------------------------------------------+
//| Check correlation risk                                           |
//+------------------------------------------------------------------+
bool CRiskManager::CheckCorrelationRisk(string symbol)
{
    // Simple correlation check - can be enhanced
    int sameBasePositions = 0;
    int sameQuotePositions = 0;
    
    string baseCurrency = StringSubstr(symbol, 0, 3);
    string quoteCurrency = StringSubstr(symbol, 3, 3);
    
    for(int i = 0; i < ArraySize(m_positions); i++)
    {
        if(!m_positions[i].isActive)
            continue;
        
        string posBase = StringSubstr(m_positions[i].symbol, 0, 3);
        string posQuote = StringSubstr(m_positions[i].symbol, 3, 3);
        
        if(posBase == baseCurrency || posQuote == baseCurrency)
            sameBasePositions++;
        if(posBase == quoteCurrency || posQuote == quoteCurrency)
            sameQuotePositions++;
    }
    
    // Limit correlated positions
    return (sameBasePositions < 3 && sameQuotePositions < 3);
}

//+------------------------------------------------------------------+
//| Print risk status                                                |
//+------------------------------------------------------------------+
void CRiskManager::PrintRiskStatus()
{
    Print("=== Risk Manager Status ===");
    Print("Active Positions: ", GetActivePositions());
    Print("Current Risk: ", DoubleToString(GetCurrentRisk(), 2), "%");
    Print("Current Drawdown: ", DoubleToString(GetCurrentDrawdown(), 2), "%");
    Print("Emergency Mode: ", m_emergencyMode ? "YES" : "NO");
    Print("Consecutive Losses: ", m_consecutiveLosses);
    Print("==========================");
}

//+------------------------------------------------------------------+
//| Get risk report                                                  |
//+------------------------------------------------------------------+
string CRiskManager::GetRiskReport()
{
    string report = "Risk Report: ";
    report += "Positions=" + IntegerToString(GetActivePositions());
    report += " Risk=" + DoubleToString(GetCurrentRisk(), 1) + "%";
    report += " DD=" + DoubleToString(GetCurrentDrawdown(), 1) + "%";
    return report;
}

//--- Additional method implementations
double CRiskManager::CalculateFixedLotSize(double riskAmount, double stopLossPoints)
{
    return CalculatePositionSize(_Symbol, stopLossPoints);
}

double CRiskManager::CalculatePercentageSize(double riskPercentage, double stopLossPoints)
{
    return CalculatePositionSize(_Symbol, stopLossPoints);
}

double CRiskManager::CalculateVolatilityBasedSize(string symbol, double riskAmount)
{
    return CalculatePositionSize(symbol, 200); // Default 200 points SL
}

double CRiskManager::GetPortfolioCorrelation()
{
    return 0.5; // Placeholder implementation
}

double CRiskManager::GetWinRate()
{
    return 0.0; // Placeholder implementation
}

double CRiskManager::GetProfitFactor()
{
    return 0.0; // Placeholder implementation
}

void CRiskManager::CleanupInactivePositions()
{
    // Cleanup logic if needed
}