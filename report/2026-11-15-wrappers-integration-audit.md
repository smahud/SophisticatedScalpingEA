# Wrappers Backend Integration Audit — Initial
Date: 2026-11-15
EA repo branch: audit/end-to-end-ai-wrapper-20261115
Upstream: https://github.com/lokah1945/wrappers (read-only)

## Verified source
Read upstream README.md, AGENTS.md, wrappers.json, model-registry/README.md.
Production provider metadata lists nvidia-python:9101, nous:9102, openrouter:9103, coarena:9107; model-registry:9200. Pending/frozen opencode:9104 and blackbox:9105 must not be inspected or tested. AGENTS.md narrative lists only first three active inference wrappers, while wrappers.json additionally lists coarena production: scope discrepancy requires reconciliation with owner before coarena integration.
Upstream README claims historical production qualification on 2026-10-11; this audit did not reproduce tests or contact providers.
Wrapper supports OpenAI/Anthropic compatible API, multi-key rotation, pacing, metrics, streaming, exact requested model selection. Registry resolves requested model and MUST NOT silently select another provider/model.

## Architectural implication
Wrappers is a protocol/provider gateway, NOT an existing collective trading decision engine. Create a separate EA-specific decision orchestrator (in our EA project) to dispatch explicitly configured models in parallel, parse structured advisory responses, validate schema and provenance, aggregate calibrated votes, apply deadlines, and return a bounded recommendation to MQL5. Do not modify upstream wrappers for trading logic.
Use model-registry as model metadata/capability source, not voting/routing fallback. Enforce allowlist and active lifecycle status. Do not use frozen providers.

## Proposed contract
MQL5 EA owns market data, indicators, trigger, baseline SL/TP, position management, hard risk limits.
SignalContext: signal_id, timestamp, TTL, symbol, side, market context, candidate SL/TP, risk envelope, account exposure, feature_schema_version.
Decision: signal_id, APPROVE/REJECT/WAIT, selected approved profile, risk_multiplier in [0,1], model_votes, model_versions, decision_time, expires_at, rationale, audit_trace.
MQL5 independently checks stale/replayed/duplicate responses, allowed profiles, spread, stops/freeze levels, margin, drawdown and emergency stop. AI cannot create new trades, reverse direction, increase risk above EA baseline or disable protection.
On timeout, malformed response, disagreement or outage: no NEW trade; open positions managed by local EA.

## Verification gates
- Check current exact upstream revision and scope discrepancy (coarena).
- Inspect only authorized active provider API contracts, auth, limits, timeout and cancellation handling.
- Validate structured JSON response fidelity per model; wrappers documentation explicitly limits model-side strict schema guarantees.
- Simulate 1/3/all providers unavailable, rate limiting, 429, delayed responses, malformed JSON, conflicting votes, network partition.
- Measure p50/p95/p99 end-to-end latency relative to EA signal TTL.
- Compare EA-only vs rule-filter vs single-model vs ensemble on identical forward-chained data; account for transaction costs, rejected signals, selection bias and multiple testing.
- Security: loopback/private network, scoped bearer tokens, secret redaction, no credentials in prompts, rate caps, audit retention.

## Status
PARTIAL, source/documentation inspection only. No upstream writes, live requests, compilation or trading tests.