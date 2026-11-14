# Analytical signal specification
Inputs: symbol/timeframe, synchronized closed OHLC bars, timestamped tick snapshot, ATR, ADX, EMA, RSI/Bands, spread, sessions, currency strength, broker metadata. No lookahead: bar shift >=1 for closed-bar strategies; data freshness and bars alignment mandatory.
MVP strategy A Trend: EMA20/EMA50 direction, ADX>=22, price/structure confirmation; B Range: RSI/Bollinger mean reversion only when regime RANGE; C Breakout: rolling high/low breakout with ATR/volume/spread conditions. All numeric defaults are research hypotheses, not optimized trading claims.
Each strategy returns {signal_id, symbol, timeframe, side, regime, strategy_id, trigger_time_utc, expiry_utc, features, rationale, proposed_entry, sl, tp, baseline_risk, version}. NO_TRADE with reason is logged.
Regime: TREND, RANGE, HIGH_VOL, INSUFFICIENT_DATA. Fusion rejects conflicting directions unless a documented deterministic rule resolves them. Cross-strategy ranking based on calibrated out-of-sample net expectancy, not arbitrary confidence scores. Prevent duplicate candidate per symbol/strategy/bar and enforce cooldown.
Currency strength bug audit: ensure accumulation resets each calculation; bearish candles have signed contribution; support broker suffixes; aligned bars and missing symbols.
No strategy accepted based on visual chart appearance or unverified backtest.
