//+------------------------------------------------------------------+
//|                                                    MarketEnv.mqh |
//|                                    Copyright 2025, ScalpingEA Pro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ScalpingEA Pro"

//--- Enumerations
enum ENUM_MARKET_SESSION
{
    SESSION_NONE = 0,
    SESSION_ASIAN = 1,
    SESSION_LONDON = 2,
    SESSION_NEW_YORK = 3,
    SESSION_LONDON_NY_OVERLAP = 4
};

enum ENUM_VOLATILITY_LEVEL
{
    VOLATILITY_LOW = 0,
    VOLATILITY_NORMAL = 1,
    VOLATILITY_HIGH = 2,
    VOLATILITY_EXTREME = 3
};

//--- Structures
struct SNewsEvent
{
    datetime eventTime;
    string currency;
    string eventName;
    int impact; // 1=Low, 2=Medium, 3=High
    bool isActive;
};

struct SMarketCondition
{
    ENUM_MARKET_SESSION currentSession;
    ENUM_VOLATILITY_LEVEL volatilityLevel;
    bool isNewsTime;
    bool isTradingAllowed;
    double atrValue;
    double spreadLevel;
    string description;
};

//+------------------------------------------------------------------+
//| Market Environment Detector Class                               |
//+------------------------------------------------------------------+
class CMarketEnv
{
private:
    // Session timing (GMT/UTC)
    int               m_asianStart;        // 21:00
    int               m_asianEnd;          // 06:00
    int               m_londonStart;       // 07:00
    int               m_londonEnd;         // 16:00
    int               m_newYorkStart;      // 12:00
    int               m_newYorkEnd;        // 21:00
    
    // Market condition variables
    SMarketCondition  m_currentCondition;
    datetime          m_lastUpdate;
    
    // Volatility measurement
    int               m_atrHandle;
    double            m_atrBuffer[100];
    double            m_avgATR;
    double            m_currentATR;
    
    // News events
    SNewsEvent        m_newsEvents[50];
    int               m_newsCount;
    datetime          m_newsBufferTime; // Time before/after news to avoid
    
    // Spread monitoring
    double            m_avgSpread;
    double            m_currentSpread;
    double            m_maxAllowedSpread;
    
    // Holiday calendar
    bool              m_holidayMode;
    datetime          m_holidays[20];
    int               m_holidayCount;
    
public:
    // Constructor
    CMarketEnv();
    
    // Destructor
    ~CMarketEnv();
    
    // Initialization
    bool Initialize();
    
    // Main update function
    void Update();
    
    // Session detection
    ENUM_MARKET_SESSION GetCurrentSession();
    bool IsOptimalSession();
    bool IsSessionOverlap();
    string GetSessionName(ENUM_MARKET_SESSION session);
    
    // Trading permission
    bool IsTradingAllowed();
    bool IsMarketOpen();
    bool IsWeekend();
    bool IsHoliday();
    
    // Volatility analysis
    ENUM_VOLATILITY_LEVEL GetVolatilityLevel();
    double GetATRValue();
    double GetVolatilityRatio();
    bool IsHighVolatility();
    bool IsLowVolatility();
    
    // News management
    bool IsNewsTime();
    void AddNewsEvent(datetime eventTime, string currency, string eventName, int impact);
    void LoadNewsCalendar();
    bool IsNewsImpactHigh();
    string GetUpcomingNews();
    
    // Spread analysis
    double GetCurrentSpread();
    double GetAverageSpread();
    bool IsSpreadAcceptable();
    void UpdateSpreadStatistics();
    
    // Market condition assessment
    SMarketCondition GetMarketCondition();
    bool IsMarketStable();
    bool IsMarketVolatile();
    string GetMarketDescription();
    
    // Session utilities
    bool IsAsianSession();
    bool IsLondonSession();
    bool IsNewYorkSession();
    bool IsLondonNYOverlap();
    
private:
    // Internal functions
    void UpdateSessionInfo();
    void UpdateVolatilityInfo();
    void UpdateNewsInfo();
    void UpdateSpreadInfo();
    void CalculateAverageATR();
    bool IsTimeInRange(int currentHour, int startHour, int endHour);
    void InitializeHolidays();
    void LoadDefaultNewsEvents();
    double CalculateSpread();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketEnv::CMarketEnv()
{
    // Set session times (GMT/UTC)
    m_asianStart = 21;      // 21:00 GMT
    m_asianEnd = 6;         // 06:00 GMT
    m_londonStart = 7;      // 07:00 GMT
    m_londonEnd = 16;       // 16:00 GMT
    m_newYorkStart = 12;    // 12:00 GMT
    m_newYorkEnd = 21;      // 21:00 GMT
    
    // Initialize variables
    m_lastUpdate = 0;
    m_atrHandle = INVALID_HANDLE;
    m_avgATR = 0;
    m_currentATR = 0;
    m_newsCount = 0;
    m_newsBufferTime = 1800; // 30 minutes before/after news
    m_avgSpread = 0;
    m_currentSpread = 0;
    m_maxAllowedSpread = 30; // 3 pips
    m_holidayMode = false;
    m_holidayCount = 0;
    
    // Initialize current condition
    m_currentCondition.currentSession = SESSION_NONE;
    m_currentCondition.volatilityLevel = VOLATILITY_NORMAL;
    m_currentCondition.isNewsTime = false;
    m_currentCondition.isTradingAllowed = true;
    m_currentCondition.atrValue = 0;
    m_currentCondition.spreadLevel = 0;
    m_currentCondition.description = "";
    
    ArrayInitialize(m_atrBuffer, 0.0);
    
    // Initialize news events array
    for(int i = 0; i < ArraySize(m_newsEvents); i++)
    {
        m_newsEvents[i].eventTime = 0;
        m_newsEvents[i].currency = "";
        m_newsEvents[i].eventName = "";
        m_newsEvents[i].impact = 0;
        m_newsEvents[i].isActive = false;
    }
    
    // Initialize holidays array
    ArrayInitialize(m_holidays, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketEnv::~CMarketEnv()
{
    if(m_atrHandle != INVALID_HANDLE)
        IndicatorRelease(m_atrHandle);
}

//+------------------------------------------------------------------+
//| Initialize Market Environment                                    |
//+------------------------------------------------------------------+
bool CMarketEnv::Initialize()
{
    Print("Initializing Market Environment Detector...");
    
    // Create ATR indicator handle
    m_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
    if(m_atrHandle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create ATR indicator handle");
        return false;
    }
    
    // Load holidays
    InitializeHolidays();
    
    // Load news calendar
    LoadNewsCalendar();
    
    // Initial update
    Update();
    
    Print("Market Environment Detector initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Update market environment                                        |
//+------------------------------------------------------------------+
void CMarketEnv::Update()
{
    datetime currentTime = TimeCurrent();
    
    // Update every minute
    if(currentTime - m_lastUpdate < 60)
        return;
    
    m_lastUpdate = currentTime;
    
    // Update all components
    UpdateSessionInfo();
    UpdateVolatilityInfo();
    UpdateNewsInfo();
    UpdateSpreadInfo();
    
    // Update overall condition
    m_currentCondition.isTradingAllowed = IsTradingAllowed();
    m_currentCondition.description = GetMarketDescription();
}

//+------------------------------------------------------------------+
//| Get current session                                              |
//+------------------------------------------------------------------+
ENUM_MARKET_SESSION CMarketEnv::GetCurrentSession()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int currentHour = dt.hour;
    
    // Check for overlaps first
    if(IsTimeInRange(currentHour, m_londonStart, m_londonEnd) && 
       IsTimeInRange(currentHour, m_newYorkStart, m_newYorkEnd))
    {
        return SESSION_LONDON_NY_OVERLAP;
    }
    
    // Check individual sessions
    if(IsTimeInRange(currentHour, m_asianStart, m_asianEnd))
        return SESSION_ASIAN;
    else if(IsTimeInRange(currentHour, m_londonStart, m_londonEnd))
        return SESSION_LONDON;
    else if(IsTimeInRange(currentHour, m_newYorkStart, m_newYorkEnd))
        return SESSION_NEW_YORK;
    
    return SESSION_NONE;
}

//+------------------------------------------------------------------+
//| Check if optimal session                                         |
//+------------------------------------------------------------------+
bool CMarketEnv::IsOptimalSession()
{
    ENUM_MARKET_SESSION session = GetCurrentSession();
    
    // London and NY sessions are optimal for scalping
    return (session == SESSION_LONDON || 
            session == SESSION_NEW_YORK || 
            session == SESSION_LONDON_NY_OVERLAP);
}

//+------------------------------------------------------------------+
//| Check if session overlap                                         |
//+------------------------------------------------------------------+
bool CMarketEnv::IsSessionOverlap()
{
    return (GetCurrentSession() == SESSION_LONDON_NY_OVERLAP);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CMarketEnv::IsTradingAllowed()
{
    // Check if market is open
    if(!IsMarketOpen())
        return false;
    
    // Check if weekend
    if(IsWeekend())
        return false;
    
    // Check if holiday
    if(IsHoliday())
        return false;
    
    // Check news time
    if(IsNewsTime())
        return false;
    
    // Check spread
    if(!IsSpreadAcceptable())
        return false;
    
    // Check extreme volatility
    if(GetVolatilityLevel() == VOLATILITY_EXTREME)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if market is open                                          |
//+------------------------------------------------------------------+
bool CMarketEnv::IsMarketOpen()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Forex market is closed from Friday 22:00 GMT to Sunday 22:00 GMT
    if(dt.day_of_week == 6) // Saturday
        return false;
    
    if(dt.day_of_week == 0 && dt.hour < 22) // Sunday before 22:00
        return false;
    
    if(dt.day_of_week == 5 && dt.hour >= 22) // Friday after 22:00
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if weekend                                                 |
//+------------------------------------------------------------------+
bool CMarketEnv::IsWeekend()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

//+------------------------------------------------------------------+
//| Check if holiday                                                 |
//+------------------------------------------------------------------+
bool CMarketEnv::IsHoliday()
{
    if(!m_holidayMode)
        return false;
    
    datetime currentDate = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    for(int i = 0; i < m_holidayCount; i++)
    {
        if(m_holidays[i] == currentDate)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get volatility level                                             |
//+------------------------------------------------------------------+
ENUM_VOLATILITY_LEVEL CMarketEnv::GetVolatilityLevel()
{
    if(m_avgATR <= 0)
        return VOLATILITY_NORMAL;
    
    double ratio = m_currentATR / m_avgATR;
    
    if(ratio < 0.5)
        return VOLATILITY_LOW;
    else if(ratio < 1.5)
        return VOLATILITY_NORMAL;
    else if(ratio < 2.5)
        return VOLATILITY_HIGH;
    else
        return VOLATILITY_EXTREME;
}

//+------------------------------------------------------------------+
//| Check if news time                                               |
//+------------------------------------------------------------------+
bool CMarketEnv::IsNewsTime()
{
    datetime currentTime = TimeCurrent();
    
    for(int i = 0; i < m_newsCount; i++)
    {
        if(!m_newsEvents[i].isActive)
            continue;
        
        // Check if within news buffer time
        if(MathAbs(currentTime - m_newsEvents[i].eventTime) <= m_newsBufferTime)
        {
            // Only avoid high impact news
            if(m_newsEvents[i].impact >= 2)
                return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update session information                                       |
//+------------------------------------------------------------------+
void CMarketEnv::UpdateSessionInfo()
{
    m_currentCondition.currentSession = GetCurrentSession();
}

//+------------------------------------------------------------------+
//| Update volatility information                                    |
//+------------------------------------------------------------------+
void CMarketEnv::UpdateVolatilityInfo()
{
    // Get current ATR
    double atrBuffer[];
    if(CopyBuffer(m_atrHandle, 0, 1, 1, atrBuffer) > 0)
    {
        m_currentATR = atrBuffer[0];
        m_currentCondition.atrValue = m_currentATR;
    }
    
    // Calculate average ATR
    CalculateAverageATR();
    
    // Update volatility level
    m_currentCondition.volatilityLevel = GetVolatilityLevel();
}

//+------------------------------------------------------------------+
//| Update news information                                          |
//+------------------------------------------------------------------+
void CMarketEnv::UpdateNewsInfo()
{
    m_currentCondition.isNewsTime = IsNewsTime();
    
    // Clean up expired news events
    datetime currentTime = TimeCurrent();
    for(int i = 0; i < m_newsCount; i++)
    {
        if(m_newsEvents[i].isActive && 
           currentTime - m_newsEvents[i].eventTime > m_newsBufferTime)
        {
            m_newsEvents[i].isActive = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Update spread information                                        |
//+------------------------------------------------------------------+
void CMarketEnv::UpdateSpreadInfo()
{
    m_currentSpread = CalculateSpread();
    m_currentCondition.spreadLevel = m_currentSpread;
    
    // Update average spread
    UpdateSpreadStatistics();
}

//+------------------------------------------------------------------+
//| Calculate average ATR                                            |
//+------------------------------------------------------------------+
void CMarketEnv::CalculateAverageATR()
{
    double atrArray[];
    int copied = CopyBuffer(m_atrHandle, 0, 1, 100, atrArray);
    
    if(copied > 0)
    {
        double sum = 0;
        for(int i = 0; i < copied; i++)
        {
            sum += atrArray[i];
        }
        m_avgATR = sum / copied;
    }
}

//+------------------------------------------------------------------+
//| Check if time is in range                                        |
//+------------------------------------------------------------------+
bool CMarketEnv::IsTimeInRange(int currentHour, int startHour, int endHour)
{
    if(startHour <= endHour)
    {
        return (currentHour >= startHour && currentHour < endHour);
    }
    else
    {
        // Handles overnight sessions (like Asian)
        return (currentHour >= startHour || currentHour < endHour);
    }
}

//+------------------------------------------------------------------+
//| Calculate current spread                                         |
//+------------------------------------------------------------------+
double CMarketEnv::CalculateSpread()
{
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (askPrice - bidPrice) / _Point;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CMarketEnv::IsSpreadAcceptable()
{
    return (m_currentSpread <= m_maxAllowedSpread);
}

//+------------------------------------------------------------------+
//| Update spread statistics                                         |
//+------------------------------------------------------------------+
void CMarketEnv::UpdateSpreadStatistics()
{
    static double spreadHistory[100];
    static int spreadIndex = 0;
    static bool arrayFilled = false;
    
    spreadHistory[spreadIndex] = m_currentSpread;
    spreadIndex = (spreadIndex + 1) % 100;
    
    if(spreadIndex == 0)
        arrayFilled = true;
    
    // Calculate average
    double sum = 0;
    int count = arrayFilled ? 100 : spreadIndex;
    
    for(int i = 0; i < count; i++)
    {
        sum += spreadHistory[i];
    }
    
    if(count > 0)
        m_avgSpread = sum / count;
}

//+------------------------------------------------------------------+
//| Add news event                                                   |
//+------------------------------------------------------------------+
void CMarketEnv::AddNewsEvent(datetime eventTime, string currency, string eventName, int impact)
{
    if(m_newsCount >= ArraySize(m_newsEvents))
        return;
    
    m_newsEvents[m_newsCount].eventTime = eventTime;
    m_newsEvents[m_newsCount].currency = currency;
    m_newsEvents[m_newsCount].eventName = eventName;
    m_newsEvents[m_newsCount].impact = impact;
    m_newsEvents[m_newsCount].isActive = true;
    
    m_newsCount++;
}

//+------------------------------------------------------------------+
//| Load news calendar                                               |
//+------------------------------------------------------------------+
void CMarketEnv::LoadNewsCalendar()
{
    // Load default high-impact news events
    LoadDefaultNewsEvents();
    
    // Try to load from file if available
    int fileHandle = FileOpen("news_calendar.csv", FILE_READ | FILE_CSV);
    if(fileHandle != INVALID_HANDLE)
    {
        while(!FileIsEnding(fileHandle) && m_newsCount < ArraySize(m_newsEvents))
        {
            string dateStr = FileReadString(fileHandle);
            string timeStr = FileReadString(fileHandle);
            string currency = FileReadString(fileHandle);
            string eventName = FileReadString(fileHandle);
            int impact = (int)FileReadNumber(fileHandle);
            
            if(dateStr != "" && timeStr != "")
            {
                datetime eventTime = StringToTime(dateStr + " " + timeStr);
                AddNewsEvent(eventTime, currency, eventName, impact);
            }
        }
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+
//| Load default news events                                         |
//+------------------------------------------------------------------+
void CMarketEnv::LoadDefaultNewsEvents()
{
    // Add some common high-impact news times (example)
    Print("Loading default news events...");
}

//+------------------------------------------------------------------+
//| Initialize holidays                                              |
//+------------------------------------------------------------------+
void CMarketEnv::InitializeHolidays()
{
    // Major holidays that affect forex market
    m_holidays[0] = StringToTime("2025.01.01"); // New Year
    m_holidays[1] = StringToTime("2025.12.25"); // Christmas
    m_holidays[2] = StringToTime("2025.07.04"); // US Independence Day
    m_holidays[3] = StringToTime("2025.11.28"); // US Thanksgiving
    // Add more holidays as needed
    
    m_holidayCount = 4;
    m_holidayMode = true;
}

//+------------------------------------------------------------------+
//| Get market description                                           |
//+------------------------------------------------------------------+
string CMarketEnv::GetMarketDescription()
{
    string description = "";
    
    // Session info
    description += "Session: " + GetSessionName(m_currentCondition.currentSession);
    
    // Volatility info
    switch(m_currentCondition.volatilityLevel)
    {
        case VOLATILITY_LOW: description += " | Volatility: LOW"; break;
        case VOLATILITY_NORMAL: description += " | Volatility: NORMAL"; break;
        case VOLATILITY_HIGH: description += " | Volatility: HIGH"; break;
        case VOLATILITY_EXTREME: description += " | Volatility: EXTREME"; break;
    }
    
    // News info
    if(m_currentCondition.isNewsTime)
        description += " | NEWS ALERT";
    
    // Spread info
    description += " | Spread: " + DoubleToString(m_currentCondition.spreadLevel, 1);
    
    return description;
}

//+------------------------------------------------------------------+
//| Get session name                                                 |
//+------------------------------------------------------------------+
string CMarketEnv::GetSessionName(ENUM_MARKET_SESSION session)
{
    switch(session)
    {
        case SESSION_ASIAN: return "ASIAN";
        case SESSION_LONDON: return "LONDON";
        case SESSION_NEW_YORK: return "NEW_YORK";
        case SESSION_LONDON_NY_OVERLAP: return "OVERLAP";
        default: return "NONE";
    }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double CMarketEnv::GetATRValue()
{
    return m_currentATR;
}

//+------------------------------------------------------------------+
//| Get volatility ratio                                             |
//+------------------------------------------------------------------+
double CMarketEnv::GetVolatilityRatio()
{
    return (m_avgATR > 0) ? m_currentATR / m_avgATR : 1.0;
}

//+------------------------------------------------------------------+
//| Check if high volatility                                         |
//+------------------------------------------------------------------+
bool CMarketEnv::IsHighVolatility()
{
    return (GetVolatilityLevel() >= VOLATILITY_HIGH);
}

//+------------------------------------------------------------------+
//| Check if low volatility                                          |
//+------------------------------------------------------------------+
bool CMarketEnv::IsLowVolatility()
{
    return (GetVolatilityLevel() == VOLATILITY_LOW);
}

//+------------------------------------------------------------------+
//| Get current spread                                               |
//+------------------------------------------------------------------+
double CMarketEnv::GetCurrentSpread()
{
    return m_currentSpread;
}

//+------------------------------------------------------------------+
//| Get average spread                                               |
//+------------------------------------------------------------------+
double CMarketEnv::GetAverageSpread()
{
    return m_avgSpread;
}

//+------------------------------------------------------------------+
//| Get market condition                                             |
//+------------------------------------------------------------------+
SMarketCondition CMarketEnv::GetMarketCondition()
{
    return m_currentCondition;
}

//+------------------------------------------------------------------+
//| Check if market is stable                                        |
//+------------------------------------------------------------------+
bool CMarketEnv::IsMarketStable()
{
    return (GetVolatilityLevel() <= VOLATILITY_NORMAL && IsSpreadAcceptable());
}

//+------------------------------------------------------------------+
//| Check if market is volatile                                      |
//+------------------------------------------------------------------+
bool CMarketEnv::IsMarketVolatile()
{
    return (GetVolatilityLevel() >= VOLATILITY_HIGH);
}

//+------------------------------------------------------------------+
//| Session utility functions                                        |
//+------------------------------------------------------------------+
bool CMarketEnv::IsAsianSession()
{
    return (GetCurrentSession() == SESSION_ASIAN);
}

bool CMarketEnv::IsLondonSession()
{
    return (GetCurrentSession() == SESSION_LONDON);
}

bool CMarketEnv::IsNewYorkSession()
{
    return (GetCurrentSession() == SESSION_NEW_YORK);
}

bool CMarketEnv::IsLondonNYOverlap()
{
    return (GetCurrentSession() == SESSION_LONDON_NY_OVERLAP);
}

//+------------------------------------------------------------------+
//| News related functions                                           |
//+------------------------------------------------------------------+
bool CMarketEnv::IsNewsImpactHigh()
{
    datetime currentTime = TimeCurrent();
    
    for(int i = 0; i < m_newsCount; i++)
    {
        if(m_newsEvents[i].isActive && 
           MathAbs(currentTime - m_newsEvents[i].eventTime) <= m_newsBufferTime)
        {
            if(m_newsEvents[i].impact >= 3) // High impact
                return true;
        }
    }
    
    return false;
}

string CMarketEnv::GetUpcomingNews()
{
    string upcomingNews = "";
    datetime currentTime = TimeCurrent();
    
    for(int i = 0; i < m_newsCount; i++)
    {
        if(m_newsEvents[i].isActive && 
           m_newsEvents[i].eventTime > currentTime &&
           m_newsEvents[i].eventTime - currentTime <= 3600) // Next hour
        {
            upcomingNews += m_newsEvents[i].eventName + " ";
        }
    }
    
    return upcomingNews;
}