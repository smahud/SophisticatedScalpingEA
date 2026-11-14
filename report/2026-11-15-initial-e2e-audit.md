# End-to-End Audit — Initial Verified Findings
Date: 2026-11-15
Branch: audit/end-to-end-ai-wrapper-20261115
Baseline: cf93cde3bc3166c69b21a3e72425be67d7305762
Scope: read-only inspection of source files via GitHub; no compilation, runtime testing, backtest or deployment performed.

## Source inventory verified
- CSM_Engine.mqh (549 lines): CCSMEngine currency strength, OHLC calculation, pair correlation, multi-timeframe weighting.
- MarketEnv.mqh (829 lines): CMarketEnv sessions, spread, ATR, volatility, news calendar.
- RiskManager.mqh (806 lines): CRiskManager position sizing, risk limits, drawdown, emergency mode, trading statistics.
- GVManager.mqh (507 lines): CGVManager terminal global variables and CSV backup.
- README.md: project title only.
Other files and main EA entrypoint have NOT been exhaustively inventoried. Do not infer that they are absent.

## Findings (static; runtime impact unverified)
- P0 CSM strength accumulates via +=/-= across Calculate() calls without observed per-cycle reset. Test repeated calculation on identical OHLC input.
- P0 CSM candleStrength=((close-open)+(high-low))/(high-low)*100 is nonnegative for valid OHLC, then clamped to [-100,100]; direction discrimination is compromised. Compare against symmetric candidate (close-open)/(high-low)*100.
- P1 CSM ValidatePair requires StringLen(pair)==6; broker suffixes are unsupported.
- P1 RiskManager current drawdown uses initial balance minus current equity, not peak-to-trough equity; verify reporting and limits.
- P1 GVManager destructor calls CleanupGVs(), deleting managed terminal globals; verify intended persistence and restart semantics.
- P1 MarketEnv uses news_calendar.csv and fallback news events; verify freshness, timezone, missing-data policy.
- P1 GVManager Update() compares TimeCurrent() seconds to updateFrequency/1000, potentially losing subsecond resolution.
- P1 CSM CopyOpen/High/Low/Close are independent calls; verify aligned bar timestamps and complete series before calculation.
- P1 RiskManager emergency mode reset conditions require fail-safe testing.

## Unverified audit gates
- Full file tree, main .mq5, OnInit/OnTick/OnTimer, signal generation and execution path.
- Build under current MetaEditor; MQL5 dependency resolution; compiler warnings.
- Account mode netting/hedging, symbol suffixes, lot step, stops/freeze levels.
- Backtests, out-of-sample, walk-forward, slippage, equity drawdown.
- Multi-model wrapper repository identity, API contract, auth, quotas, latency and costs.
- No claims of profitability or production readiness.

## Proposed integration contract (design only)
EA owns indicators, trigger, order management and hard risk limits.
Backend accepts immutable signal snapshot with signal_id, symbol, direction, price, timestamp, TTL, features, strategy_version and risk envelope.
Multi-model backend produces advisory APPROVE/REJECT/WAIT, optional bounded risk-profile recommendation, model votes, confidence calibration and trace IDs.
EA validates freshness, uniqueness, spread, account exposure, SL/TP and lot constraints; stale/unavailable backend => no new trade; existing positions remain locally managed.
Shadow mode first. Do not let AI override emergency stop.

## Experiment plan
1. Fix and test existing signal/context correctness without changing baseline results silently.
2. Record all eligible triggers, including rejected ones, with forward outcome labels.
3. Compare original EA, deterministic filter, single calibrated model, multi-model ensemble using identical walk-forward splits and trading costs.
4. Stress-test latency, provider outages, contradictory votes, model drift, replay and duplicate responses.
5. Demo forward testing; no live trading before explicit approval.

## Next required input
Identify the exact 'wrapper' project/repository intended for multi-model inference. Do not assume a similarly named project.

## Audit status
PARTIAL. This is a reproducible initial audit report, not a completed end-to-end certification.
