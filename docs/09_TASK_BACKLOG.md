# Implementation backlog and dependencies
P0-01 inventory legacy and external sources, license audit, baseline compile, report.
P0-02 fix MQL5 prototype compile and build repeatable MT5 compile evidence.
P0-03 broker symbol discovery + suffix-aware eligibility + SymbolSelect + data synchronization.
P0-04 per-symbol handles and round-robin OnTimer scheduler + stale/latency budget.
P0-05 opportunity ledger and deterministic signal ID, regime + 3 independent strategies.
P0-06 MT5 on-chart dashboard with paginated all-symbol table, modes, error/health/risk indicators.
P0-07 strict request/response schema, replay adapter for Strategy Tester, Python tests.
P0-08 global risk guard and position manager with account mode/broker constraint fixtures.
P1-01 AI orchestrator calling exact active Wrappers models; quorum/timeout/provenance and offline mocks.
P1-02 robust order executor (demo only), idempotency/restart reconciliation.
P1-03 end-to-end MT5 demo smoke and fault injection; latency/resource measurement.
P1-04 reproducible backtests, walk-forward OOS, baseline vs AI comparison.
P2-01 optimize with pre-registered objective and holdout, forward demo, independent review.
P2-02 live release gate requires explicit approval.
For each task: owner, inputs, outputs, acceptance tests, evidence path, rollback and dependency tracked in report/. Never mark DONE without evidence.
