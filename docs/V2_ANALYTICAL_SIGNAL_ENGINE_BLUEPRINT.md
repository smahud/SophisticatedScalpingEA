# SophisticatedScalpingEA V2 — Analytical Signal Engine Rebuild Plan
Date: 2026-11-15
Status: DESIGN ONLY — no trading code changes, no compile/backtest claims
Branch: audit/end-to-end-ai-wrapper-20261115

## Decision
Rebuild as a clean modular MQL5 EA using existing SophisticatedScalpingEA as a source of requirements and selectively validated modules. EA owns analytics, signal and trigger. Python multi-model orchestrator via lokah1945/wrappers advises approve/reject/wait and bounded adaptive risk profile. MQL5 remains sole execution and hard risk authority.

## Reference sources (concepts, not blindly copied)
- EA31337/EA31337-strategies: concrete strategy catalog with check/compile/backtest CI badge links; validate current artifacts and target MetaEditor before adoption.
- EA31337/EA31337-Libre: MQL4/MQL5 multi-strategy implementation; README explicitly warns not suitable for real trading without knowledge.
- EA31337/EA31337-classes: framework for account, indicator, symbol, profiler, timer.
- MQL5 standard library: CTrade, symbol/account info, indicator handles.
- Existing EA: CSM_Engine.mqh, MarketEnv.mqh, RiskManager.mqh, GVManager.mqh require correctness tests before reuse.
GPLv3 code reuse requires license review and distribution compliance. Independent reimplementation of ideas is preferred if distribution policy is undecided.

## MVP modules
1. MarketData: cached synchronized bar/tick snapshots, indicator handle lifecycle, closed-bar default.
2. MarketEnvironment: spread, sessions, ATR/volatility, news validity, fail-closed when needed.
3. TrendSignal: EMA structure + ADX confirmation.
4. MeanReversionSignal: Bollinger/RSI with explicit range regime.
5. BreakoutSignal: range break + ATR + spread filter.
6. CurrencyStrength: corrected signed normalized candle contribution; robust broker symbol mapping.
7. RegimeDetector: trend/range/volatile/no-trade deterministic classifier.
8. SignalFusion: normalized evidence, conflict policy, one immutable candidate with rationale and expiry.
9. DecisionBridge: async/nonblocking integration to Python orchestrator, schema/TTL/duplicate validation.
10. RiskGuard: hard caps, peak-to-trough equity DD, daily loss, position exposure, volume/stops/margin checks.
11. Executor/PositionManager: broker retcode handling, idempotency, restart recovery, netting/hedging.
12. AuditLogger: signal, features, model votes, rejected candidates, order outcomes, latency, version IDs.

## Signal pipeline
OnTick -> snapshot -> eligibility -> regime -> independent strategies -> fusion -> candidate signal -> pre-risk -> AI advisory -> final risk -> execution -> position management.
OnTimer handles AI polling and housekeeping. Position protection must not depend on AI availability.

## Experiments and release gates
- Baseline deterministic EA (no AI), deterministic filter, one model, multi-model ensemble.
- Unit fixtures for signal direction, symbol mapping, zero-range candle, repeated calculation, stale tick, broker suffix.
- Compiler clean in MetaEditor, reproducible Strategy Tester, netting/hedging and restart tests.
- OOS/walk-forward and forward demo with costs; no profitability assumption.
- Latency and timeout stress, malformed JSON, provider outages, contradictory model votes.
- Preserve old EA in git history, implement new EA in separate v2 path and compare on identical data.
- No live deployment or merge to main without review.

## Unresolved
Full repository inventory and main EA execution path not yet verified. Wrapper coarena production metadata vs AGENTS.md scope discrepancy. Target symbols/timeframes, broker constraints, account mode and model budget require later specification.
