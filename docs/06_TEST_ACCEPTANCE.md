# Verification matrix and release gates
G0 inventory and baseline: record git HEAD, all .mq5/.mqh, licenses, original strategy behavior; classify IMPLEMENTED/DOCUMENTED/PARTIAL/UNVERIFIED/CONFLICT.
G1 compile: clean MetaEditor MQL5 compilation with logs, version and artifact hash; Python unit tests; static analysis.
G2 correctness: unit/fixtures for indicator buffers, closed-bar alignment, spread, suffixes, stale quotes, missing data, duplicate signals, clocks, JSON, risk bounds, volume rounding, stop/freeze levels, netting/hedging.
G3 integration: MT5 local smoke test in shadow, backend outages, invalid/mismatched response, expiry, rate limits, reboot, high symbol count, kill switch, reconciliation; no order placed.
G4 research: reproducible real-tick backtest with variable spread, commission, swaps, slippage and execution assumptions; walk-forward and untouched out-of-sample; compare baseline vs rule filter vs single-model vs ensemble; include all candidates/rejections.
G5 forward demo: multi-week multi-regime demo with equity/drawdown, expectancy, profit factor, trade count, latency p50/p95/p99, opportunity capture, CPU/memory, broker rejects. Duration and pass thresholds must be specified BEFORE test to avoid overfitting.
G6 live: only after independent review and explicit user permission; small exposure with monitoring and rollback.
No claim of success without raw logs, commands, versions, dates, hashes and report/ evidence. Test failure => gate blocked. Strategy Tester cannot call WebRequest.
