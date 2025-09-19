//+------------------------------------------------------------------+
//|                                               AutoTradingSystem.mq5    |
//+------------------------------------------------------------------+
#property copyright "Modified by Thurein - Optimized Version"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>

// Structure for Currency trading times
struct TradingTime_Signal {
    int hour;
    int minute;
};

//+------------------------------------------------------------------+
//| OPTIMIZED: Symbol data cache structure                          |
//+------------------------------------------------------------------+
struct SymbolData {
    string symbol;
    double rsi_4h_current;
    double rsi_4h_prev;
    double rsi_4h_prev2;
    double rsi_8h_current;
    double rsi_8h_prev;
    double rsi_8h_prev2;
    double rsi_1d_current;
    double rsi_1d_prev;
    double rsi_1d_prev2;
    double bb_percentB_4h;
    double cci_4h;
    double macd_2h_main_current;
    double macd_2h_main_prev;
    double macd_2h_signal_current;
    double macd_2h_signal_prev;
    double ema20_1h_current;
    double ema20_1h_prev;
    double ema20_1h_prev2;
    double ema9_3h_data[6];  // Store 6 values for 3H trend calculation
    bool dataValid;
};

// Global cache arrays
SymbolData symbolCache[28];
bool cacheInitialized = false;
datetime lastCacheUpdate = 0;

//+------------------------------------------------------------------+
//| Currency ranking cache structure                                |
//+------------------------------------------------------------------+
struct CurrencyRankingCache {
    int rsiRank[8];      // USD=0, EUR=1, GBP=2, AUD=3, JPY=4, CAD=5, CHF=6, NZD=7
    int cciRank[8];
    int bbRank[8];
    int overallRank[8];  // NEW: Overall ranking based on average
    bool valid;
};

CurrencyRankingCache rankingCache;

// Updated CurrencyRank structure with copy constructor
struct CurrencyRank {
    string currency;
    double strength;
    int rank;
    
    CurrencyRank(const CurrencyRank& other) {
        currency = other.currency;
        strength = other.strength;
        rank = other.rank;
    }
    
    CurrencyRank() {
        currency = "";
        strength = 0.0;
        rank = 0;
    }
    
    CurrencyRank(string curr, double str, int r) {
        currency = curr;
        strength = str;
        rank = r;
    }
};

// BB%B Currency ranking
struct BBPercentBRank {
    string currency;
    double strength;
    int rank;
    
    BBPercentBRank(const BBPercentBRank& other) {
        currency = other.currency;
        strength = other.strength;
        rank = other.rank;
    }
    
    BBPercentBRank() {
        currency = "";
        strength = 0.0;
        rank = 0;
    }
    
    BBPercentBRank(string curr, double str, int r) {
        currency = curr;
        strength = str;
        rank = r;
    }
};

// Time difference between server and JST
input int TimeDifference = 6; 

// Variables for logs
datetime lastLogCheck_Signal = 0;
               
// Currency Trading times array
TradingTime_Signal tradingTimes_Signal[] = {
    {0, 01}, {1, 01}, {2, 01}, {3, 01}, {4, 01}, {5, 01}, {6, 01}, {7, 01},
    {8, 01}, {9, 01}, {10, 01}, {11, 01}, {12, 01}, {13, 01}, {14, 01}, {15, 01},
    {16, 01}, {17, 01}, {18, 01}, {19, 01}, {20, 01}, {21, 01}, {22, 01}, {23, 01}
};

//+------------------------------------------------------------------+
//| Check if current time matches Currency system trading time
//+------------------------------------------------------------------+
bool IsCurrencyLongTradeTime()
{
    datetime serverTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    int currentHour = dt.hour;
    int currentMinute = dt.min;

    for(int i = 0; i < ArraySize(tradingTimes_Signal); i++) {
        int targetHour = tradingTimes_Signal[i].hour - TimeDifference;
        if(targetHour < 0) targetHour += 24;
        
        if((currentHour == targetHour) &&
           (currentMinute >= tradingTimes_Signal[i].minute) && 
           (currentMinute <= tradingTimes_Signal[i].minute + 1)) {
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get JST time for log file naming                                |
//+------------------------------------------------------------------+
datetime GetJSTTimeForLogFile() {
    datetime serverTime = TimeCurrent();
    MqlDateTime serverDt;
    TimeToStruct(serverTime, serverDt);
    
    for(int i = 0; i < ArraySize(tradingTimes_Signal); i++) {
        int targetServerHour = tradingTimes_Signal[i].hour - TimeDifference;
        if(targetServerHour < 0) targetServerHour += 24;
        
        if((serverDt.hour == targetServerHour) &&
           (serverDt.min >= tradingTimes_Signal[i].minute) && 
           (serverDt.min <= tradingTimes_Signal[i].minute + 1)) {
            
            datetime jstTime = serverTime + (TimeDifference * 3600);
            MqlDateTime jstDt;
            TimeToStruct(jstTime, jstDt);
            
            if(jstDt.hour != tradingTimes_Signal[i].hour) {
                jstDt.hour = tradingTimes_Signal[i].hour;
                jstDt.min = tradingTimes_Signal[i].minute;
                jstTime = StructToTime(jstDt);
            }
            
            return jstTime;
        }
    }
    
    return serverTime + (TimeDifference * 3600);
}

//+------------------------------------------------------------------+
//| OPTIMIZED: Initialize all symbol data cache                     |
//+------------------------------------------------------------------+
bool InitializeSymbolCache(string suffix = "") {
    string symbols[28] = {
        "USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "NZDJPY", "CADJPY", "CHFJPY",
        "EURUSD", "AUDUSD", "GBPUSD", "NZDUSD", "USDCHF", "USDCAD",
        "EURGBP", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
        "GBPAUD", "GBPCHF", "GBPCAD", "GBPNZD",
        "AUDCAD", "AUDCHF", "AUDNZD", "CADCHF", "NZDCAD", "NZDCHF"
    };
    
    Print("PERFORMANCE: Initializing symbol cache...");
    datetime startTime = GetTickCount();
    
    for(int i = 0; i < 28; i++) {
        string fullSymbol = symbols[i] + suffix;
        symbolCache[i].symbol = symbols[i];
        symbolCache[i].dataValid = false;
        
        // RSI 4H data
        int rsiHandle = iRSI(fullSymbol, PERIOD_H4, 14, PRICE_CLOSE);
        if(rsiHandle != INVALID_HANDLE) {
            double rsiBuffer[];
            ArrayResize(rsiBuffer, 3);
            ArraySetAsSeries(rsiBuffer, true);
            if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) == 3) {
                symbolCache[i].rsi_4h_current = rsiBuffer[0];
                symbolCache[i].rsi_4h_prev = rsiBuffer[1];
                symbolCache[i].rsi_4h_prev2 = rsiBuffer[2];
            }
            IndicatorRelease(rsiHandle);
        }
        
        // RSI 8H data
        int rsi8hHandle = iRSI(fullSymbol, PERIOD_H8, 14, PRICE_CLOSE);
        if(rsi8hHandle != INVALID_HANDLE) {
            double rsi8hBuffer[];
            ArrayResize(rsi8hBuffer, 2);
            ArraySetAsSeries(rsi8hBuffer, true);
            if(CopyBuffer(rsi8hHandle, 0, 0, 3, rsi8hBuffer) == 3) {
                symbolCache[i].rsi_8h_current = rsi8hBuffer[0];
                symbolCache[i].rsi_8h_prev = rsi8hBuffer[1];
                symbolCache[i].rsi_8h_prev2 = rsi8hBuffer[2];
            }
            IndicatorRelease(rsi8hHandle);
        }
        
        // RSI 1D data
        int rsi1dHandle = iRSI(fullSymbol, PERIOD_D1, 14, PRICE_CLOSE);
        if(rsi1dHandle != INVALID_HANDLE) {
            double rsi1dBuffer[];
            ArrayResize(rsi1dBuffer, 2);
            ArraySetAsSeries(rsi1dBuffer, true);
            if(CopyBuffer(rsi1dHandle, 0, 0, 2, rsi1dBuffer) == 3) {
                symbolCache[i].rsi_1d_current = rsi1dBuffer[0];
                symbolCache[i].rsi_1d_prev = rsi1dBuffer[1];
                symbolCache[i].rsi_1d_prev2 = rsi1dBuffer[2];
            }
            IndicatorRelease(rsi1dHandle);
        }
        
        // BB%B data
        symbolCache[i].bb_percentB_4h = GetBBPercentB(fullSymbol, PERIOD_H4);
        
        // CCI data
        int cciHandle = iCCI(fullSymbol, PERIOD_H4, 14, PRICE_CLOSE);
        if(cciHandle != INVALID_HANDLE) {
            double cciBuffer[];
            ArrayResize(cciBuffer, 1);
            ArraySetAsSeries(cciBuffer, true);
            if(CopyBuffer(cciHandle, 0, 1, 1, cciBuffer) == 1) {
                symbolCache[i].cci_4h = cciBuffer[0];
            }
            IndicatorRelease(cciHandle);
        }
        
        // MACD 2H data
        int macdHandle = iMACD(fullSymbol, PERIOD_H2, 12, 26, 9, PRICE_CLOSE);
        if(macdHandle != INVALID_HANDLE) {
            double macdMain[];
            double macdSignal[];
            ArrayResize(macdMain, 2);
            ArrayResize(macdSignal, 2);
            ArraySetAsSeries(macdMain, true);
            ArraySetAsSeries(macdSignal, true);
            
            if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) == 3 &&
               CopyBuffer(macdHandle, 1, 0, 3, macdSignal) == 3) {
                symbolCache[i].macd_2h_main_current = macdMain[1];
                symbolCache[i].macd_2h_main_prev = macdMain[2];
                symbolCache[i].macd_2h_signal_current = macdSignal[1];
                symbolCache[i].macd_2h_signal_prev = macdSignal[2];
            }
            IndicatorRelease(macdHandle);
        }
        
        // EMA20 1H data
        int ema20Handle = iMA(fullSymbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
        if(ema20Handle != INVALID_HANDLE) {
            double ema20Buffer[];
            ArrayResize(ema20Buffer, 3);
            ArraySetAsSeries(ema20Buffer, true);
            if(CopyBuffer(ema20Handle, 0, 0, 3, ema20Buffer) == 3) {
                symbolCache[i].ema20_1h_current = ema20Buffer[0];
                symbolCache[i].ema20_1h_prev = ema20Buffer[1];
                symbolCache[i].ema20_1h_prev2 = ema20Buffer[2];
            }
            IndicatorRelease(ema20Handle);
        }
        
        // EMA9 3H data (6 values for trend calculation)
        int ema9Handle = iMA(fullSymbol, PERIOD_H3, 9, 0, MODE_EMA, PRICE_CLOSE);
        if(ema9Handle != INVALID_HANDLE) {
            double ema9Buffer[];
            ArrayResize(ema9Buffer, 6);
            ArraySetAsSeries(ema9Buffer, true);
            if(CopyBuffer(ema9Handle, 0, 0, 6, ema9Buffer) == 6) {
                for(int j = 0; j < 6; j++) {
                    symbolCache[i].ema9_3h_data[j] = ema9Buffer[j];
                }
            }
            IndicatorRelease(ema9Handle);
        }
        
        symbolCache[i].dataValid = true;
    }
    
    datetime endTime = GetTickCount();
    Print("PERFORMANCE: Cache initialization completed in ", (endTime - startTime), " ms");
    cacheInitialized = true;
    lastCacheUpdate = TimeCurrent();
    return true;
}

//+------------------------------------------------------------------+
//| Get Bollinger Band %B value                                     |
//+------------------------------------------------------------------+
double GetBBPercentB(string symbol, ENUM_TIMEFRAMES timeframe) {
    int bbHandle = iBands(symbol, timeframe, 20, 0, 2.0, PRICE_CLOSE);
    if(bbHandle == INVALID_HANDLE) return EMPTY_VALUE;
    
    double upperBand[], lowerBand[], close[];
    ArraySetAsSeries(upperBand, true);
    ArraySetAsSeries(lowerBand, true);
    ArraySetAsSeries(close, true);
    
    if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0 ||
       CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0 ||
       CopyClose(symbol, timeframe, 0, 1, close) <= 0) {
        IndicatorRelease(bbHandle);
        return EMPTY_VALUE;
    }
    
    IndicatorRelease(bbHandle);
    
    double bandWidth = upperBand[0] - lowerBand[0];
    if(bandWidth < 0.0000001) return EMPTY_VALUE;
    
    return (close[0] - lowerBand[0]) / bandWidth;
}

//+------------------------------------------------------------------+
//| OPTIMIZED: Pre-calculate all currency rankings                  |
//+------------------------------------------------------------------+
void CalculateAllRankingsOnce() {
    datetime startTime = GetTickCount();
    
    string currencies[8] = {"USD", "EUR", "GBP", "AUD", "JPY", "CAD", "CHF", "NZD"};
    double rsiStrength[8] = {0,0,0,0,0,0,0,0};
    double cciStrength[8] = {0,0,0,0,0,0,0,0};
    double bbStrength[8] = {0,0,0,0,0,0,0,0};
    double overallStrength[8] = {0,0,0,0,0,0,0,0};  
    
    // Calculate RSI and CCI strengths using cached data
    for(int i = 0; i < 28; i++) {
        if(!symbolCache[i].dataValid) continue;
        
        string baseCurrency = StringSubstr(symbolCache[i].symbol, 0, 3);
        string quoteCurrency = StringSubstr(symbolCache[i].symbol, 3, 3);
        
        // RSI strength
        if(symbolCache[i].rsi_4h_current != EMPTY_VALUE) {
            double baseStrength = symbolCache[i].rsi_4h_current - 50.0;
            double quoteStrength = -(symbolCache[i].rsi_4h_current - 50.0);
            
            for(int j = 0; j < 8; j++) {
                if(currencies[j] == baseCurrency) rsiStrength[j] += baseStrength;
                if(currencies[j] == quoteCurrency) rsiStrength[j] += quoteStrength;
            }
        }
        
        // CCI strength
        if(symbolCache[i].cci_4h != EMPTY_VALUE) {
            double cciBase = symbolCache[i].cci_4h;
            double cciQuote = -symbolCache[i].cci_4h;
            
            for(int j = 0; j < 8; j++) {
                if(currencies[j] == baseCurrency) cciStrength[j] += cciBase;
                if(currencies[j] == quoteCurrency) cciStrength[j] += cciQuote;
            }
        }
    }
    
    // Calculate BB%B strength using your original logic
    // USD strength calculation
    string usdPairs[] = {"USDJPY", "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDCHF", "USDCAD"};
    bool usdInvert[] = {false, true, true, true, true, false, false};
    double usdTotal = 0.0;
    int usdCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == usdPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(usdInvert[i]) {
                    usdTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    usdTotal += symbolCache[j].bb_percentB_4h;
                }
                usdCount++;
                break;
            }
        }
    }
    if(usdCount > 0) bbStrength[0] = usdTotal / usdCount;
    
    // EUR strength calculation
    string eurPairs[] = {"EURUSD", "EURJPY", "EURGBP", "EURAUD", "EURCAD", "EURCHF", "EURNZD"};
    double eurTotal = 0.0;
    int eurCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == eurPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                eurTotal += symbolCache[j].bb_percentB_4h;
                eurCount++;
                break;
            }
        }
    }
    if(eurCount > 0) bbStrength[1] = eurTotal / eurCount;
    
    // GBP strength calculation
    string gbpPairs[] = {"GBPUSD", "GBPJPY", "EURGBP", "GBPAUD", "GBPCHF", "GBPCAD", "GBPNZD"};
    bool gbpInvert[] = {false, false, true, false, false, false, false};
    double gbpTotal = 0.0;
    int gbpCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == gbpPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(gbpInvert[i]) {
                    gbpTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    gbpTotal += symbolCache[j].bb_percentB_4h;
                }
                gbpCount++;
                break;
            }
        }
    }
    if(gbpCount > 0) bbStrength[2] = gbpTotal / gbpCount;
    
    // JPY strength calculation (all inverted)
    string jpyPairs[] = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "NZDJPY", "CADJPY", "CHFJPY"};
    double jpyTotal = 0.0;
    int jpyCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == jpyPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                jpyTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                jpyCount++;
                break;
            }
        }
    }
    if(jpyCount > 0) bbStrength[4] = jpyTotal / jpyCount;
    
    // AUD strength calculation
    string audPairs[] = {"AUDUSD", "AUDJPY", "EURAUD", "GBPAUD", "AUDCAD", "AUDCHF", "AUDNZD"};
    bool audInvert[] = {false, false, true, true, false, false, false};
    double audTotal = 0.0;
    int audCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == audPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(audInvert[i]) {
                    audTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    audTotal += symbolCache[j].bb_percentB_4h;
                }
                audCount++;
                break;
            }
        }
    }
    if(audCount > 0) bbStrength[3] = audTotal / audCount;
    
    // NZD strength calculation
    string nzdPairs[] = {"NZDUSD", "NZDJPY", "EURNZD", "GBPNZD", "AUDNZD", "NZDCAD", "NZDCHF"};
    bool nzdInvert[] = {false, false, true, true, true, false, false};
    double nzdTotal = 0.0;
    int nzdCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == nzdPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(nzdInvert[i]) {
                    nzdTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    nzdTotal += symbolCache[j].bb_percentB_4h;
                }
                nzdCount++;
                break;
            }
        }
    }
    if(nzdCount > 0) bbStrength[7] = nzdTotal / nzdCount;
    
    // CAD strength calculation
    string cadPairs[] = {"USDCAD", "CADJPY", "EURCAD", "GBPCAD", "AUDCAD", "CADCHF", "NZDCAD"};
    bool cadInvert[] = {true, false, true, true, true, false, true};
    double cadTotal = 0.0;
    int cadCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == cadPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(cadInvert[i]) {
                    cadTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    cadTotal += symbolCache[j].bb_percentB_4h;
                }
                cadCount++;
                break;
            }
        }
    }
    if(cadCount > 0) bbStrength[5] = cadTotal / cadCount;
    
    // CHF strength calculation
    string chfPairs[] = {"USDCHF", "CHFJPY", "EURCHF", "GBPCHF", "AUDCHF", "CADCHF", "NZDCHF"};
    bool chfInvert[] = {true, false, true, true, true, true, true};
    double chfTotal = 0.0;
    int chfCount = 0;
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 28; j++) {
            if(symbolCache[j].symbol == chfPairs[i] && symbolCache[j].bb_percentB_4h != EMPTY_VALUE) {
                if(chfInvert[i]) {
                    chfTotal += (1.0 - symbolCache[j].bb_percentB_4h);
                } else {
                    chfTotal += symbolCache[j].bb_percentB_4h;
                }
                chfCount++;
                break;
            }
        }
    }
    if(chfCount > 0) bbStrength[6] = chfTotal / chfCount;

    // Sort RSI rankings
    int rsiOrder[8] = {0,1,2,3,4,5,6,7};
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 7-i; j++) {
            if(rsiStrength[rsiOrder[j]] < rsiStrength[rsiOrder[j+1]]) {
                int temp = rsiOrder[j];
                rsiOrder[j] = rsiOrder[j+1];
                rsiOrder[j+1] = temp;
            }
        }
    }
    for(int i = 0; i < 8; i++) {
        rankingCache.rsiRank[rsiOrder[i]] = i + 1;
    }
    
    // Sort CCI rankings
    int cciOrder[8] = {0,1,2,3,4,5,6,7};
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 7-i; j++) {
            if(cciStrength[cciOrder[j]] < cciStrength[cciOrder[j+1]]) {
                int temp = cciOrder[j];
                cciOrder[j] = cciOrder[j+1];
                cciOrder[j+1] = temp;
            }
        }
    }
    for(int i = 0; i < 8; i++) {
        rankingCache.cciRank[cciOrder[i]] = i + 1;
    }
    
    // Sort BB%B rankings
    int bbOrder[8] = {0,1,2,3,4,5,6,7};
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 7-i; j++) {
            if(bbStrength[bbOrder[j]] < bbStrength[bbOrder[j+1]]) {
                int temp = bbOrder[j];
                bbOrder[j] = bbOrder[j+1];
                bbOrder[j+1] = temp;
            }
        }
    }
    for(int i = 0; i < 8; i++) {
        rankingCache.bbRank[bbOrder[i]] = i + 1;
    }
   
        // Calculate average ranking for each currency
    for(int i = 0; i < 8; i++) {
        double avgRank = (double)(rankingCache.rsiRank[i] + rankingCache.cciRank[i] + rankingCache.bbRank[i]) / 3.0;
        overallStrength[i] = avgRank;
    }
    
    // Sort currencies by their average ranking (lower average = better overall rank)
    int overallOrder[8] = {0,1,2,3,4,5,6,7};
    for(int i = 0; i < 7; i++) {
        for(int j = 0; j < 7-i; j++) {
            if(overallStrength[overallOrder[j]] > overallStrength[overallOrder[j+1]]) {
                int temp = overallOrder[j];
                overallOrder[j] = overallOrder[j+1];
                overallOrder[j+1] = temp;
            }
        }
    }
    
    // Assign overall rankings (1 = best, 8 = worst)
    for(int i = 0; i < 8; i++) {
        rankingCache.overallRank[overallOrder[i]] = i + 1;
    }
    
    // Debug output for overall rankings
    Print("PERFORMANCE: Overall Rankings calculated:");
    for(int i = 0; i < 8; i++) {
        Print("Currency: ", currencies[i], 
              " RSI:", rankingCache.rsiRank[i], 
              " CCI:", rankingCache.cciRank[i], 
              " BB%B:", rankingCache.bbRank[i],
              " Overall:", rankingCache.overallRank[i],
              " (Avg:", DoubleToString(overallStrength[i], 2), ")");
    }
    
    rankingCache.valid = true;
    
    datetime endTime = GetTickCount();
}

//+------------------------------------------------------------------+
//| NEW: Get Overall Ranking string function                        |
//+------------------------------------------------------------------+
string GetOverallRankingString(string pairName) {
    string baseCurrency = StringSubstr(pairName, 0, 3);
    string quoteCurrency = StringSubstr(pairName, 3, 3);
    
    int baseIndex = GetCurrencyIndex(baseCurrency);
    int quoteIndex = GetCurrencyIndex(quoteCurrency);
    
    if(baseIndex == -1 || quoteIndex == -1 || !rankingCache.valid) return "X/X";
    
    int baseRank = rankingCache.overallRank[baseIndex];
    int quoteRank = rankingCache.overallRank[quoteIndex];
    
    return IntegerToString(baseRank) + "/" + IntegerToString(quoteRank);
}

//+------------------------------------------------------------------+
//| Get currency index                                              |
//+------------------------------------------------------------------+
int GetCurrencyIndex(string currency) {
    if(currency == "USD") return 0;
    if(currency == "EUR") return 1;
    if(currency == "GBP") return 2;
    if(currency == "AUD") return 3;
    if(currency == "JPY") return 4;
    if(currency == "CAD") return 5;
    if(currency == "CHF") return 6;
    if(currency == "NZD") return 7;
    return -1;
}

//+------------------------------------------------------------------+
//| OPTIMIZED: Cached signal functions                              |
//+------------------------------------------------------------------+
string GetRSI_4H_CurrentValue_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            return IntegerToString((int)MathRound(symbolCache[i].rsi_4h_current));
        }
    }
    return "X";
}

string GetRSI_4H_GoldenCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_4h_prev2 < 30.0) && (symbolCache[i].rsi_4h_prev > 30.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetRSI_4H_DeadCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_4h_prev2 > 70.0) && (symbolCache[i].rsi_4h_prev < 70.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetRSI_8H_GoldenCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_8h_prev2 < 30.0) && (symbolCache[i].rsi_8h_prev > 30.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetRSI_8H_DeadCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_8h_prev2 > 70.0) && (symbolCache[i].rsi_8h_prev2 < 70.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetRSI_1D_GoldenCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_1d_prev2 < 30.0) && (symbolCache[i].rsi_1d_prev > 30.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetRSI_1D_DeadCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].rsi_1d_prev2 > 70.0) && (symbolCache[i].rsi_1d_prev < 70.0);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetMACD_2H_GoldenCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].macd_2h_main_prev <= symbolCache[i].macd_2h_signal_prev) && 
                         (symbolCache[i].macd_2h_main_current > symbolCache[i].macd_2h_signal_current);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetMACD_2H_DeadCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            bool signal = (symbolCache[i].macd_2h_main_prev >= symbolCache[i].macd_2h_signal_prev) && 
                         (symbolCache[i].macd_2h_main_current < symbolCache[i].macd_2h_signal_current);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetEMA20_1H_GoldenCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            // Get current close price
            double close[];
            ArrayResize(close, 3);
            ArraySetAsSeries(close, true);
            if(CopyClose(symbol, PERIOD_H1, 0, 3, close) == 3) {
                bool signal = (close[2] < symbolCache[i].ema20_1h_prev2) && (close[1] > symbolCache[i].ema20_1h_prev);
                return signal ? "O" : "X";
            }
            return "X";
        }
    }
    return "X";
}

string GetEMA20_1H_DeadCrossSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            // Get current close price
            double close[];
            ArrayResize(close, 3);
            ArraySetAsSeries(close, true);
            if(CopyClose(symbol, PERIOD_H1, 0, 3, close) == 3) {
                bool signal = (close[2] > symbolCache[i].ema20_1h_prev2) && (close[1] < symbolCache[i].ema20_1h_prev);
                return signal ? "O" : "X";
            }
            return "X";
        }
    }
    return "X";
}

string GetEMA9_3H_UptrendSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            double recent_avg = (symbolCache[i].ema9_3h_data[0] + symbolCache[i].ema9_3h_data[1] + symbolCache[i].ema9_3h_data[2]) / 3.0;
            double prev_avg = (symbolCache[i].ema9_3h_data[3] + symbolCache[i].ema9_3h_data[4] + symbolCache[i].ema9_3h_data[5]) / 3.0;
            bool signal = (recent_avg > prev_avg);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetEMA9_3H_DowntrendSignal_Cached(string symbol) {
    for(int i = 0; i < 28; i++) {
        if(symbolCache[i].symbol == symbol && symbolCache[i].dataValid) {
            double recent_avg = (symbolCache[i].ema9_3h_data[0] + symbolCache[i].ema9_3h_data[1] + symbolCache[i].ema9_3h_data[2]) / 3.0;
            double prev_avg = (symbolCache[i].ema9_3h_data[3] + symbolCache[i].ema9_3h_data[4] + symbolCache[i].ema9_3h_data[5]) / 3.0;
            bool signal = (recent_avg < prev_avg);
            return signal ? "O" : "X";
        }
    }
    return "X";
}

string GetCachedRankingString(string pairName, int rankingType) {
    string baseCurrency = StringSubstr(pairName, 0, 3);
    string quoteCurrency = StringSubstr(pairName, 3, 3);
    
    int baseIndex = GetCurrencyIndex(baseCurrency);
    int quoteIndex = GetCurrencyIndex(quoteCurrency);
    
    if(baseIndex == -1 || quoteIndex == -1 || !rankingCache.valid) return "X";
    
    int baseRank, quoteRank;
    if(rankingType == 0) {  // RSI ranking
        baseRank = rankingCache.rsiRank[baseIndex];
        quoteRank = rankingCache.rsiRank[quoteIndex];
    } else if(rankingType == 1) {  // CCI ranking
        baseRank = rankingCache.cciRank[baseIndex];
        quoteRank = rankingCache.cciRank[quoteIndex];
    } else {  // BB%B ranking
        baseRank = rankingCache.bbRank[baseIndex];
        quoteRank = rankingCache.bbRank[quoteIndex];
    }
    
    return IntegerToString(baseRank) + "/" + IntegerToString(quoteRank);
}

//+------------------------------------------------------------------+
//| Original ranking-based signal (kept for compatibility)          |
//+------------------------------------------------------------------+
string GetRankingBasedSignal(string pairName, bool isBuy, string suffix = "") {
    string baseCurrency = StringSubstr(pairName, 0, 3);
    string quoteCurrency = StringSubstr(pairName, 3, 3);
    
    int baseIndex = GetCurrencyIndex(baseCurrency);
    int quoteIndex = GetCurrencyIndex(quoteCurrency);
    
    if(baseIndex == -1 || quoteIndex == -1 || !rankingCache.valid) return "X";
    
    int baseRank = rankingCache.rsiRank[baseIndex];
    int quoteRank = rankingCache.rsiRank[quoteIndex];
    
    bool isBreakoutPair = ((baseRank == 1 && quoteRank == 8) || (baseRank == 8 && quoteRank == 1));
    if(!isBreakoutPair) return "X";
    
    if(isBuy) {
        return (baseRank == 1 && quoteRank == 8) ? "O" : "X";
    } else {
        return (baseRank == 8 && quoteRank == 1) ? "O" : "X";
    }
}

//+------------------------------------------------------------------+
//| OPTIMIZED: Fast signal file generation                          |
//+------------------------------------------------------------------+
bool GenerateCombinedSignalFile_Optimized(string suffix = "") {
    datetime totalStartTime = GetTickCount();
    
    // Check if cache needs refresh (every hour)
    datetime currentTime = TimeCurrent();
    if(!cacheInitialized || (currentTime - lastCacheUpdate) > 3600) {
        InitializeSymbolCache(suffix);
        CalculateAllRankingsOnce();
    }
    
    Print("PERFORMANCE: Starting file generation...");
    datetime fileStartTime = GetTickCount();
    
    // File creation
    datetime jstTime = GetJSTTimeForLogFile();
    MqlDateTime dt;
    TimeToStruct(jstTime, dt);
    
    string fileName = StringFormat("%04d%02d%02d_%02d.log", dt.year, dt.mon, dt.day, dt.hour);
    
    int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
    if(fileHandle == INVALID_HANDLE) {
        Print("PERFORMANCE: Failed to create file: ", fileName);
        return false;
    }
    
    string symbols[28] = {
        "USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "NZDJPY", "CADJPY", "CHFJPY",
        "EURUSD", "AUDUSD", "GBPUSD", "NZDUSD", "USDCHF", "USDCAD",
        "EURGBP", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
        "GBPAUD", "GBPCHF", "GBPCAD", "GBPNZD",
        "AUDCAD", "AUDCHF", "AUDNZD", "CADCHF", "NZDCAD", "NZDCHF"
    };
    
    // Fast signal generation using cached data
    for(int i = 0; i < 28; i++) {
        // Currency strength signals
        string buySignal = GetRankingBasedSignal(symbols[i], true, suffix);
        string sellSignal = GetRankingBasedSignal(symbols[i], false, suffix);
        
        // Rankings using cached calculations
        FileWrite(fileHandle, "[" + symbols[i] + "][Currency_Strength_Rank_all_pair]=" + GetCachedRankingString(symbols[i], 0));
        FileWrite(fileHandle, "[" + symbols[i] + "][CCI_Currency_Strength_Rank_all_pair]=" + GetCachedRankingString(symbols[i], 1));
        FileWrite(fileHandle, "[" + symbols[i] + "][BB_percent_ranking]=" + GetCachedRankingString(symbols[i], 2));
        
        // RSI current value
        FileWrite(fileHandle, "[" + symbols[i] + "][RSI_breakout]=" + GetRSI_4H_CurrentValue_Cached(symbols[i]));
        
       // NEW: Overall Ranking - Average of RSI, CCI, and BB%B rankings
        FileWrite(fileHandle, "[" + symbols[i] + "][Overall_Ranking]=" + GetOverallRankingString(symbols[i]));
       
        // Single confidence value - the main addition you requested
        FileWrite(fileHandle, "[" + symbols[i] + "][Confidence]=" + IntegerToString((int)CalculateMarketConfidence(symbols[i])));
    }
    
    
    FileClose(fileHandle);
    
    datetime totalEndTime = GetTickCount();
    Print("PERFORMANCE: File generation completed in ", (totalEndTime - fileStartTime), " ms");
    Print("PERFORMANCE: Total process time: ", (totalEndTime - totalStartTime), " ms");
    
    return true;
}
//+------------------------------------------------------------------+
//| Simple JSON generation - Fix encoding issues with Signal logic |
//+------------------------------------------------------------------+
bool GenerateJSONSignalFile_Simple() {
    string fileName = "fx_signals.json";
    
    // Open file in simple text mode
    int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
    if(fileHandle == INVALID_HANDLE) {
        Print("Failed to create file: ", fileName);
        return false;
    }
    
    string symbols[28] = {
        "USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "NZDJPY", "CADJPY", "CHFJPY",
        "EURUSD", "AUDUSD", "GBPUSD", "NZDUSD", "USDCHF", "USDCAD",
        "EURGBP", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
        "GBPAUD", "GBPCHF", "GBPCAD", "GBPNZD",
        "AUDCAD", "AUDCHF", "AUDNZD", "CADCHF", "NZDCAD", "NZDCHF"
    };
    
    // Write JSON line by line
    FileWrite(fileHandle, "{");
    FileWrite(fileHandle, "  \"forexData\": {");
    
    for(int i = 0; i < 28; i++) {
        // Get signal data with fallback values
        string currencyRank = GetCachedRankingString(symbols[i], 0);
        string cciRank = GetCachedRankingString(symbols[i], 1);
        string bbRank = GetCachedRankingString(symbols[i], 2);
        string rsiValue = GetRSI_4H_CurrentValue_Cached(symbols[i]);
        string overallRank = GetOverallRankingString(symbols[i]);
        
        // Set defaults for invalid data
        if(currencyRank == "X") currencyRank = "0/0";
        if(cciRank == "X") cciRank = "0/0";
        if(bbRank == "X") bbRank = "0/0";
        if(rsiValue == "X") rsiValue = "50";
        if(overallRank == "X") overallRank = "0/0";
        
        int confidence = (int)CalculateMarketConfidence(symbols[i]);
        
        // Generate signal based on RSI value
        string signal = "Stay";  // Default signal
        double rsiNumeric = StringToDouble(rsiValue);
        
        if(rsiNumeric < 34.0) {
            signal = "Buy";
        }
        else if(rsiNumeric > 64.0) {
            signal = "Sell";
        }
        else {
            signal = "Stay";
        }
        
        // Write symbol data
        FileWrite(fileHandle, "    \"" + symbols[i] + "\": {");
        FileWrite(fileHandle, "      \"Currency_Strength_Rank_all_pair\": \"" + currencyRank + "\",");
        FileWrite(fileHandle, "      \"CCI_Currency_Strength_Rank_all_pair\": \"" + cciRank + "\",");
        FileWrite(fileHandle, "      \"BB_percent_ranking\": \"" + bbRank + "\",");
        FileWrite(fileHandle, "      \"RSI_breakout\": " + rsiValue + ",");
        FileWrite(fileHandle, "      \"Overall_Ranking\": \"" + overallRank + "\",");
        FileWrite(fileHandle, "      \"Confidence\": " + IntegerToString(confidence) + ",");
        FileWrite(fileHandle, "      \"Signal\": \"" + signal + "\"");
        
        if(i < 27) {
            FileWrite(fileHandle, "    },");
        } else {
            FileWrite(fileHandle, "    }");
        }
    }
    
    FileWrite(fileHandle, "  }");
    FileWrite(fileHandle, "}");
    
    FileClose(fileHandle);
    Print("JSON file created: ", fileName);
    return true;
}

//+------------------------------------------------------------------+
//| SIMPLIFIED CONFIDENCE CALCULATION - 50/50 Point System          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate market confidence using simplified 50/50 point system |
//+------------------------------------------------------------------+
double CalculateMarketConfidence(string symbol) {
    // Get the ranking strings and RSI value
    string rsiRankStr = GetCachedRankingString(symbol, 0);      // RSI ranking
    string cciRankStr = GetCachedRankingString(symbol, 1);      // CCI ranking  
    string bbRankStr = GetCachedRankingString(symbol, 2);       // BB%B ranking
    string rsiBreakoutStr = GetRSI_4H_CurrentValue_Cached(symbol); // RSI current value
    
    // Calculate Currency Strength Score (50 points maximum)
    double currencyScore = CalculateCurrencyStrengthScore(rsiRankStr, cciRankStr, bbRankStr);
    
    // Calculate RSI Level Score (50 points maximum)  
    int rsiValue = (int)StringToInteger(rsiBreakoutStr);
    double rsiScore = CalculateRSILevelScore(rsiValue);
    
    // Simple addition (no weights)
    double totalScore = currencyScore + rsiScore;
    
    return MathRound(totalScore); // Return as percentage (0-100)
}

//+------------------------------------------------------------------+
//| Calculate Currency Strength Score (Maximum 50 points)           |
//+------------------------------------------------------------------+
double CalculateCurrencyStrengthScore(string rsiRankStr, string cciRankStr, string bbRankStr) {
    double totalScore = 0.0;
    
    // Parse rankings from strings (format: "1/7")
    int baseRSI, quoteRSI, baseCCI, quoteCCI, baseBB, quoteBB;
    
    // Extract RSI rankings
    string rsiParts[];
    if(StringSplit(rsiRankStr, StringGetCharacter("/", 0), rsiParts) == 2) {
        baseRSI = (int)StringToInteger(rsiParts[0]);
        quoteRSI = (int)StringToInteger(rsiParts[1]);
    } else {
        return 0.0; // Invalid data
    }
    
    // Extract CCI rankings
    string cciParts[];
    if(StringSplit(cciRankStr, StringGetCharacter("/", 0), cciParts) == 2) {
        baseCCI = (int)StringToInteger(cciParts[0]);
        quoteCCI = (int)StringToInteger(cciParts[1]);
    } else {
        return 0.0; // Invalid data
    }
    
    // Extract BB%B rankings
    string bbParts[];
    if(StringSplit(bbRankStr, StringGetCharacter("/", 0), bbParts) == 2) {
        baseBB = (int)StringToInteger(bbParts[0]);
        quoteBB = (int)StringToInteger(bbParts[1]);
    } else {
        return 0.0; // Invalid data
    }
    
    // Calculate buy direction score
    double buyScore = 0.0;
    buyScore += CalculateRankingScore(baseRSI, quoteRSI);    // RSI component (max ~16.7 points)
    buyScore += CalculateRankingScore(baseCCI, quoteCCI);    // CCI component (max ~16.7 points)  
    buyScore += CalculateRankingScore(baseBB, quoteBB);      // BB%B component (max ~16.7 points)
    
    // Calculate sell direction score  
    double sellScore = 0.0;
    sellScore += CalculateRankingScore(quoteRSI, baseRSI);   // Reverse for sell
    sellScore += CalculateRankingScore(quoteCCI, baseCCI);   // Reverse for sell
    sellScore += CalculateRankingScore(quoteBB, baseBB);     // Reverse for sell
    
    // Take the higher score (best direction)
    totalScore = MathMax(buyScore, sellScore);
    
    return MathMin(totalScore, 50.0); // Cap at 50 points
}

//+------------------------------------------------------------------+
//| Calculate individual ranking component score                     |
//+------------------------------------------------------------------+
double CalculateRankingScore(int strongRank, int weakRank) {
    // Perfect setup: 1/8 or 2/7, etc.
    if(strongRank == 1 && weakRank == 8) return 16.7;      // Perfect
    if(strongRank == 1 && weakRank == 7) return 15.0;      // Near perfect
    if(strongRank == 2 && weakRank == 8) return 15.0;      // Near perfect
    
    // Very good setups
    if(strongRank <= 2 && weakRank >= 7) return 13.0;      // Very good
    if(strongRank <= 3 && weakRank >= 6) return 10.0;      // Good
    
    // Moderate setups
    if(strongRank <= 4 && weakRank >= 5) return 6.0;       // Moderate
    if(strongRank < weakRank) return 3.0;                  // Base stronger than quote
    
    return 0.0; // No clear signal or negative signal
}

//+------------------------------------------------------------------+
//| Calculate RSI Level Score (Maximum 50 points)                   |
//+------------------------------------------------------------------+
double CalculateRSILevelScore(int rsiValue) {
    if(rsiValue <= 0 || rsiValue > 100) return 0.0; // Invalid RSI
    
    // Extreme levels (highest confidence)
    if(rsiValue <= 20) return 50.0;        // Extreme oversold
    if(rsiValue >= 80) return 50.0;        // Extreme overbought
    
    // Strong levels  
    if(rsiValue <= 25) return 45.0;        // Very oversold
    if(rsiValue >= 75) return 45.0;        // Very overbought
    
    if(rsiValue <= 30) return 40.0;        // Strong oversold  
    if(rsiValue >= 70) return 40.0;        // Strong overbought
    
    // Moderate levels
    if(rsiValue <= 35) return 25.0;        // Mild oversold
    if(rsiValue >= 65) return 25.0;        // Mild overbought
    
    // Approaching significant levels
    if(rsiValue <= 40) return 15.0;        // Approaching oversold
    if(rsiValue >= 60) return 15.0;        // Approaching overbought
    
    // Weak signals
    if(rsiValue <= 45) return 10.0;        // Slight buy bias
    if(rsiValue >= 55) return 10.0;        // Slight sell bias
    
    // Neutral zone (lowest confidence)
    return 5.0;                            // RSI around 50 (neutral)
}

//+------------------------------------------------------------------+
//| Helper function to parse ranking string and extract values      |
//+------------------------------------------------------------------+
bool ParseRankingString(string rankStr, int &baseRank, int &quoteRank) {
    string parts[];
    if(StringSplit(rankStr, StringGetCharacter("/", 0), parts) == 2) {
        baseRank = (int)StringToInteger(parts[0]);
        quoteRank = (int)StringToInteger(parts[1]);
        return true;
    }
    baseRank = 0;
    quoteRank = 0;
    return false;
}

//+------------------------------------------------------------------+
//| Debug function to show confidence calculation breakdown          |
//+------------------------------------------------------------------+
void PrintConfidenceDebug(string symbol) {
    string rsiRankStr = GetCachedRankingString(symbol, 0);
    string cciRankStr = GetCachedRankingString(symbol, 1);  
    string bbRankStr = GetCachedRankingString(symbol, 2);
    string rsiBreakoutStr = GetRSI_4H_CurrentValue_Cached(symbol);
    
    double currencyScore = CalculateCurrencyStrengthScore(rsiRankStr, cciRankStr, bbRankStr);
    int rsiValue = (int)StringToInteger(rsiBreakoutStr);
    double rsiScore = CalculateRSILevelScore(rsiValue);
    double totalScore = currencyScore + rsiScore;
    
    Print("=== CONFIDENCE DEBUG: ", symbol, " ===");
    Print("RSI Ranking: ", rsiRankStr);
    Print("CCI Ranking: ", cciRankStr);
    Print("BB%B Ranking: ", bbRankStr);
    Print("RSI Value: ", rsiValue);
    Print("Currency Strength Score: ", DoubleToString(currencyScore, 1), "/50.0");
    Print("RSI Level Score: ", DoubleToString(rsiScore, 1), "/50.0");
    Print("Total Confidence: ", DoubleToString(totalScore, 0), "%");
    Print("================================");
}


//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick(){   
    if(IsCurrencyLongTradeTime()){
        InitializeSymbolCache();   
        CalculateAllRankingsOnce();
        Sleep(3600);
        datetime currentLogTime = TimeCurrent();
        if((currentLogTime - lastLogCheck_Signal) >= 120) {
            Print("PERFORMANCE: Starting signal generation cycle...");
            GenerateCombinedSignalFile_Optimized();
            GenerateJSONSignalFile_Simple();
        }
        lastLogCheck_Signal = currentLogTime;
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("PERFORMANCE: Optimized EA initialized");
    Print("Using time difference: ", TimeDifference, " hours");
    Print("Processing 28 currency pairs with optimized caching");
    
    // Pre-initialize cache on startup
    Print("PERFORMANCE: Pre-loading data cache...");
    InitializeSymbolCache();
    CalculateAllRankingsOnce();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("PERFORMANCE: EA deinitialized. Reason: ", reason);
}