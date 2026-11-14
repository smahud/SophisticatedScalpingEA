# V2 MT5-only user interface with background AI Wrappers
Date: 2026-11-15
Status: Prototype, uncompiled, not production-ready.

## Architectural decision
User operates ONLY MetaTrader 5. The EA is the sole dashboard and trade controller. Python is an optional background advisory service; Wrappers is the downstream model provider gateway. No web dashboard required.

## Implemented on audit branch
- Single-symbol closed-bar EMA/ADX/ATR analytical shadow EA.
- OnTimer-based POST of an eligible candidate to localhost /v1/decision.
- Local Python bearer-authenticated deterministic decision service with APPROVE/REJECT and TTL.
- No broker order execution, no AI ensemble, no multi-symbol discovery, no integrated tests performed.

## Current limitations / correctness gates
- WebRequest is synchronous even in OnTimer and may block the EA thread for the configured timeout. No claim of nonblocking async operation.
- WebRequest is unavailable in MT5 Strategy Tester; use a deterministic local mock/replay interface for backtests.
- Current string-matching advisory response is NOT sufficient for trading. Replace with strict JSON parsing, schema, signal ID, symbol, direction, timestamps, bounded risk multiplier, and signature/auth checks before execution.
- Python baseline uses local time.time() while EA sends TimeGMT(); test clock skew, TTL, DST and reconnect.
- Localhost URL works only if MT5 and service share host; for separate VPS use authenticated TLS endpoint and never expose bare HTTP publicly.
- EA currently reads _Symbol only. All-pair discovery and unified MT5 dashboard are NOT implemented.
- Python service does not call Wrappers yet. Integrate explicit configured exact model IDs with per-model deadlines, provenance, quorum and fallback REJECT.
- Keep trade execution disabled until strict risk validation and extensive testing.
- Secrets in EA input fields are sensitive; avoid distributing presets and printing tokens.
- Single MT5 EA event loop is serialized; round-robin scheduling, tick capture and performance budgets must be measured.

## MT5 setup for local smoke test (after MetaEditor compilation)
1. Start Python service with EA_DECISION_TOKEN set in its environment.
2. MT5 Tools > Options > Expert Advisors: allow WebRequest for http://127.0.0.1:8765 (local development only).
3. Attach V2 EA to one chart, UseDecisionServer=true, DecisionToken matching server, EnableTrading=false.
4. Observe Experts log for SHADOW and ADVISORY lines; verify valid/rejected/timeout cases.
5. Never treat this smoke test as live trading validation.

## Next implementation increments
A. Multi-symbol broker catalog discovery and per-symbol state/indicator lifecycle.
B. Round-robin timer scheduler with stale-data detection and global opportunity ledger.
C. Native MT5 unified dashboard and risk visualization.
D. Strict JSON bridge with replayable adapter for Strategy Tester.
E. Wrappers multi-model decision orchestrator and offline fixtures.
F. Global risk engine, execution engine, account-mode and broker-constraint tests.
G. Compile, deterministic backtest, walk-forward, forward demo; review before live activation.
