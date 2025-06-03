//+------------------------------------------------------------------+
//|                                                    GVManager.mqh |
//|                                    Copyright 2025, ScalpingEA Pro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ScalpingEA Pro"

//--- Structure for GV data
struct SGVData
{
    string name;
    double value;
    datetime lastUpdate;
    bool isActive;
};

//+------------------------------------------------------------------+
//| Global Variables Manager Class                                   |
//+------------------------------------------------------------------+
class CGVManager
{
private:
    string            m_prefix;
    int               m_updateFrequency;
    bool              m_enableBackup;
    SGVData           m_gvData[];
    datetime          m_lastUpdate;
    int               m_totalGVs;
    
    // File handles for backup
    int               m_fileHandle;
    string            m_backupFile;
    
public:
    // Constructor
    CGVManager(string prefix, int updateFreq, bool enableBackup);
    
    // Destructor
    ~CGVManager();
    
    // Initialization
    bool Initialize();
    
    // Main update function
    bool Update();
    
    // GV operations
    bool SetGV(string name, double value);
    double GetGV(string name);
    bool DeleteGV(string name);
    
    // CSM specific GVs
    bool SetCSMStrength(string currency, ENUM_TIMEFRAMES tf, double strength);
    double GetCSMStrength(string currency, ENUM_TIMEFRAMES tf);
    
    bool SetCSMSignal(string pair, ENUM_TIMEFRAMES tf, int signal);
    int GetCSMSignal(string pair, ENUM_TIMEFRAMES tf);
    
    // Signal specific GVs
    bool SetSignalStrength(string pair, ENUM_TIMEFRAMES tf, double strength);
    double GetSignalStrength(string pair, ENUM_TIMEFRAMES tf);
    
    // Risk management GVs
    bool SetRiskLevel(double riskLevel);
    double GetRiskLevel();
    
    bool SetActivePositions(int count);
    int GetActivePositions();
    
    // Market environment GVs
    bool SetMarketSession(string session);
    string GetMarketSession();
    
    bool SetNewsAlert(bool isNews);
    bool GetNewsAlert();
    
    // Backup functions
    bool SaveToFile();
    bool LoadFromFile();
    
    // Utility functions
    int GetTotalGVs() { return m_totalGVs; }
    string GetPrefix() { return m_prefix; }
    void PrintGVStatus();
    
private:
    string CreateGVName(string baseName);
    bool ValidateGVName(string name);
    void CleanupGVs();
    string TimeframeToString(ENUM_TIMEFRAMES tf);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGVManager::CGVManager(string prefix, int updateFreq, bool enableBackup)
{
    m_prefix = prefix;
    m_updateFrequency = updateFreq;
    m_enableBackup = enableBackup;
    m_lastUpdate = 0;
    m_totalGVs = 0;
    m_fileHandle = INVALID_HANDLE;
    m_backupFile = "ScalpingEA_GV_Backup.csv";
    
    ArrayResize(m_gvData, 250); // Prepare for 250 GVs
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGVManager::~CGVManager()
{
    if(m_enableBackup)
        SaveToFile();
        
    if(m_fileHandle != INVALID_HANDLE)
        FileClose(m_fileHandle);
        
    CleanupGVs();
}

//+------------------------------------------------------------------+
//| Initialize GV system                                             |
//+------------------------------------------------------------------+
bool CGVManager::Initialize()
{
    Print("Initializing Global Variables Manager...");
    
    // Load from backup if enabled
    if(m_enableBackup)
    {
        LoadFromFile();
    }
    
    // Initialize core GVs
    string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD", "SEK"};
    string pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD", "USDSEK"};
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
    
    // Initialize CSM strength GVs
    for(int i = 0; i < ArraySize(currencies); i++)
    {
        for(int j = 0; j < ArraySize(timeframes); j++)
        {
            string gvName = CreateGVName("CSM_" + currencies[i] + "_" + TimeframeToString(timeframes[j]));
            SetGV(gvName, 0.0);
        }
    }
    
    // Initialize signal GVs
    for(int i = 0; i < ArraySize(pairs); i++)
    {
        for(int j = 0; j < ArraySize(timeframes); j++)
        {
            string gvName = CreateGVName("SIG_" + pairs[i] + "_" + TimeframeToString(timeframes[j]));
            SetGV(gvName, 0.0);
        }
    }
    
    // Initialize risk management GVs
    SetGV(CreateGVName("RISK_LEVEL"), 0.0);
    SetGV(CreateGVName("ACTIVE_POSITIONS"), 0.0);
    SetGV(CreateGVName("TOTAL_RISK"), 0.0);
    
    // Initialize market environment GVs
    SetGV(CreateGVName("MARKET_SESSION"), 0.0); // Will store as enum value
    SetGV(CreateGVName("NEWS_ALERT"), 0.0);
    SetGV(CreateGVName("VOLATILITY_LEVEL"), 0.0);
    
    Print("Global Variables Manager initialized successfully. Total GVs: ", m_totalGVs);
    return true;
}

//+------------------------------------------------------------------+
//| Update GV system                                                 |
//+------------------------------------------------------------------+
bool CGVManager::Update()
{
    datetime currentTime = TimeCurrent();
    
    if(currentTime - m_lastUpdate < m_updateFrequency / 1000)
        return true;
    
    m_lastUpdate = currentTime;
    
    // Update backup if enabled
    if(m_enableBackup && currentTime % 60 == 0) // Every minute
    {
        SaveToFile();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Set Global Variable                                              |
//+------------------------------------------------------------------+
bool CGVManager::SetGV(string name, double value)
{
    if(!ValidateGVName(name))
        return false;
    
    if(!GlobalVariableSet(name, value))
    {
        Print("Failed to set GV: ", name);
        return false;
    }
    
    // Update internal array
    bool found = false;
    for(int i = 0; i < m_totalGVs; i++)
    {
        if(m_gvData[i].name == name)
        {
            m_gvData[i].value = value;
            m_gvData[i].lastUpdate = TimeCurrent();
            found = true;
            break;
        }
    }
    
    if(!found && m_totalGVs < ArraySize(m_gvData))
    {
        m_gvData[m_totalGVs].name = name;
        m_gvData[m_totalGVs].value = value;
        m_gvData[m_totalGVs].lastUpdate = TimeCurrent();
        m_gvData[m_totalGVs].isActive = true;
        m_totalGVs++;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Global Variable                                              |
//+------------------------------------------------------------------+
double CGVManager::GetGV(string name)
{
    if(!GlobalVariableCheck(name))
        return 0.0;
    
    return GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
//| Delete Global Variable                                           |
//+------------------------------------------------------------------+
bool CGVManager::DeleteGV(string name)
{
    return GlobalVariableDel(name);
}

//+------------------------------------------------------------------+
//| Set CSM strength                                                 |
//+------------------------------------------------------------------+
bool CGVManager::SetCSMStrength(string currency, ENUM_TIMEFRAMES tf, double strength)
{
    string gvName = CreateGVName("CSM_" + currency + "_" + TimeframeToString(tf));
    return SetGV(gvName, strength);
}

//+------------------------------------------------------------------+
//| Get CSM strength                                                 |
//+------------------------------------------------------------------+
double CGVManager::GetCSMStrength(string currency, ENUM_TIMEFRAMES tf)
{
    string gvName = CreateGVName("CSM_" + currency + "_" + TimeframeToString(tf));
    return GetGV(gvName);
}

//+------------------------------------------------------------------+
//| Set CSM signal                                                   |
//+------------------------------------------------------------------+
bool CGVManager::SetCSMSignal(string pair, ENUM_TIMEFRAMES tf, int signal)
{
    string gvName = CreateGVName("SIG_" + pair + "_" + TimeframeToString(tf));
    return SetGV(gvName, (double)signal);
}

//+------------------------------------------------------------------+
//| Get CSM signal                                                   |
//+------------------------------------------------------------------+
int CGVManager::GetCSMSignal(string pair, ENUM_TIMEFRAMES tf)
{
    string gvName = CreateGVName("SIG_" + pair + "_" + TimeframeToString(tf));
    return (int)GetGV(gvName);
}

//+------------------------------------------------------------------+
//| Set signal strength                                              |
//+------------------------------------------------------------------+
bool CGVManager::SetSignalStrength(string pair, ENUM_TIMEFRAMES tf, double strength)
{
    string gvName = CreateGVName("STR_" + pair + "_" + TimeframeToString(tf));
    return SetGV(gvName, strength);
}

//+------------------------------------------------------------------+
//| Get signal strength                                              |
//+------------------------------------------------------------------+
double CGVManager::GetSignalStrength(string pair, ENUM_TIMEFRAMES tf)
{
    string gvName = CreateGVName("STR_" + pair + "_" + TimeframeToString(tf));
    return GetGV(gvName);
}

//+------------------------------------------------------------------+
//| Set risk level                                                   |
//+------------------------------------------------------------------+
bool CGVManager::SetRiskLevel(double riskLevel)
{
    return SetGV(CreateGVName("RISK_LEVEL"), riskLevel);
}

//+------------------------------------------------------------------+
//| Get risk level                                                   |
//+------------------------------------------------------------------+
double CGVManager::GetRiskLevel()
{
    return GetGV(CreateGVName("RISK_LEVEL"));
}

//+------------------------------------------------------------------+
//| Set active positions                                             |
//+------------------------------------------------------------------+
bool CGVManager::SetActivePositions(int count)
{
    return SetGV(CreateGVName("ACTIVE_POSITIONS"), (double)count);
}

//+------------------------------------------------------------------+
//| Get active positions                                             |
//+------------------------------------------------------------------+
int CGVManager::GetActivePositions()
{
    return (int)GetGV(CreateGVName("ACTIVE_POSITIONS"));
}

//+------------------------------------------------------------------+
//| Set market session                                               |
//+------------------------------------------------------------------+
bool CGVManager::SetMarketSession(string session)
{
    double sessionValue = 0;
    if(session == "ASIAN") sessionValue = 1;
    else if(session == "LONDON") sessionValue = 2;
    else if(session == "NEW_YORK") sessionValue = 3;
    else if(session == "OVERLAP") sessionValue = 4;
    
    return SetGV(CreateGVName("MARKET_SESSION"), sessionValue);
}

//+------------------------------------------------------------------+
//| Get market session                                               |
//+------------------------------------------------------------------+
string CGVManager::GetMarketSession()
{
    double sessionValue = GetGV(CreateGVName("MARKET_SESSION"));
    
    switch((int)sessionValue)
    {
        case 1: return "ASIAN";
        case 2: return "LONDON";
        case 3: return "NEW_YORK";
        case 4: return "OVERLAP";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Set news alert                                                   |
//+------------------------------------------------------------------+
bool CGVManager::SetNewsAlert(bool isNews)
{
    return SetGV(CreateGVName("NEWS_ALERT"), isNews ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
//| Get news alert                                                   |
//+------------------------------------------------------------------+
bool CGVManager::GetNewsAlert()
{
    return GetGV(CreateGVName("NEWS_ALERT")) > 0.5;
}

//+------------------------------------------------------------------+
//| Save to file                                                     |
//+------------------------------------------------------------------+
bool CGVManager::SaveToFile()
{
    int file = FileOpen(m_backupFile, FILE_WRITE | FILE_CSV);
    if(file == INVALID_HANDLE)
    {
        Print("Failed to open backup file for writing");
        return false;
    }
    
    FileWrite(file, "Name", "Value", "LastUpdate");
    
    for(int i = 0; i < m_totalGVs; i++)
    {
        if(m_gvData[i].isActive)
        {
            FileWrite(file, m_gvData[i].name, 
                     DoubleToString(m_gvData[i].value, 8),
                     TimeToString(m_gvData[i].lastUpdate));
        }
    }
    
    FileClose(file);
    return true;
}

//+------------------------------------------------------------------+
//| Load from file                                                   |
//+------------------------------------------------------------------+
bool CGVManager::LoadFromFile()
{
    int file = FileOpen(m_backupFile, FILE_READ | FILE_CSV);
    if(file == INVALID_HANDLE)
        return false;
    
    // Skip header
    string header = FileReadString(file);
    
    int index = 0;
    while(!FileIsEnding(file) && index < ArraySize(m_gvData))
    {
        string name = FileReadString(file);
        string valueStr = FileReadString(file);
        string timeStr = FileReadString(file);
        
        if(name != "" && valueStr != "")
        {
            double value = StringToDouble(valueStr);
            SetGV(name, value);
        }
        
        index++;
    }
    
    FileClose(file);
    return true;
}

//+------------------------------------------------------------------+
//| Create GV name with prefix                                       |
//+------------------------------------------------------------------+
string CGVManager::CreateGVName(string baseName)
{
    return m_prefix + baseName;
}

//+------------------------------------------------------------------+
//| Validate GV name                                                 |
//+------------------------------------------------------------------+
bool CGVManager::ValidateGVName(string name)
{
    if(StringLen(name) == 0 || StringLen(name) > 63)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Cleanup GVs                                                      |
//+------------------------------------------------------------------+
void CGVManager::CleanupGVs()
{
    for(int i = 0; i < m_totalGVs; i++)
    {
        if(m_gvData[i].isActive)
        {
            GlobalVariableDel(m_gvData[i].name);
        }
    }
}

//+------------------------------------------------------------------+
//| Convert timeframe to string                                      |
//+------------------------------------------------------------------+
string CGVManager::TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        default:         return "UN";
    }
}

//+------------------------------------------------------------------+
//| Print GV status                                                  |
//+------------------------------------------------------------------+
void CGVManager::PrintGVStatus()
{
    Print("=== Global Variables Status ===");
    Print("Total GVs: ", m_totalGVs);
    Print("Prefix: ", m_prefix);
    Print("Update Frequency: ", m_updateFrequency, "ms");
    Print("Backup Enabled: ", m_enableBackup ? "Yes" : "No");
    Print("===============================");
}