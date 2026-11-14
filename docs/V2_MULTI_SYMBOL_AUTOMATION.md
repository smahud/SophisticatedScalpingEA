# V2 Multi-Symbol Automation — Architecture and Acceptance
Date: 2026-11-15
Status: Design / not implemented. All trading disabled by default.

## User goal
One-time setup, attach EA to one chart, automatically discover and monitor all eligible forex pairs in the broker's symbol catalog, run analytics for each symbol in background, and optionally route candidate signals to the collective AI decision backend. No manual chart opening or attaching an EA to every pair is necessary.

## Preferred architecture
One MT5 EA instance, one controller chart, N independent per-symbol state objects and indicator handles. This is not the same as programmatically attaching EA instances to charts, which is unnecessary and brittle. OnTimer schedules round-robin symbol evaluation; OnTick only handles lightweight wakeups/position protection where needed. MQL5 event handlers are serialized per EA, so do not claim true parallel MQL5 execution.

## Discovery
Use SymbolsTotal(false)/SymbolName(i,false) to enumerate broker catalog, SymbolInfoInteger/SymbolInfoString for trade mode, path, currencies and metadata, and SymbolSelect(symbol,true) to subscribe to eligible symbols. Never assume six-character names; broker suffixes and non-FX instruments exist. Filter by SYMBOL_CURRENCY_BASE and SYMBOL_CURRENCY_PROFIT, SYMBOL_TRADE_MODE, symbol availability and allow/deny lists. Broker catalog may include non-FX symbols; ALL_PAIR means all eligible FX pairs, not every CFD/future/crypto. Apply hard cap MaxSymbols and log excluded symbols and reasons.

## Scheduler
Per-symbol state: symbol, timeframe, indicator handles, last closed bar timestamp, last tick time, cooldown, last signal ID, position state and latest analytics. Refresh symbol list at a slow configurable interval; evaluate on closed bars with a round-robin budget and bounded work per timer event. Ensure handle creation/release, CopyBuffer synchronization, stale tick rejection and deterministic reinitialization.

## Risk controls
Account-wide total risk, per-symbol risk, max open positions, currency exposure and correlation cluster limits; hedging vs netting handling; trading permissions, broker stop/freeze levels, min/max/step volume, margin, spread, swap/session constraints. AI cannot override hard caps. Default fail-closed on AI timeout or invalid decision.

## Deployment
Attach the EA once to one chart and enable MT5 algo trading only after demo qualification. Optional terminal auto-start on OS boot and MT5 profile persistence require separate setup and testing. An EA cannot guarantee operation if terminal/host is shut down. 'Background' means the terminal remains running while charts need not be opened for each pair.

## Acceptance tests
- Broker catalog with suffixes and disabled symbols; no non-FX false positives.
- 1, 10, 30, 60+ symbols under timer budget, stale quotes and missing history.
- No duplicated signal/order after restart, chart reload or reconnect.
- Symbol selection failures and indicator handle cleanup.
- Account-wide exposure limits with simultaneous correlated signals.
- Deterministic replay, latency metrics, Strategy Tester constraints and demo forward tests.
- Shadow-only before explicit trade activation.

## Implementation gate
Current v2/mql5/SophisticatedScalpingV2.mq5 is single-symbol shadow-only. This document does NOT claim the scanner is implemented, compiled, or tested.
