# SophisticatedScalpingEA V2 — Executable Research Scaffold

Status: **prototype / research**, NOT production ready. Existing EA remains untouched.

## Components
- `python/decision_server.py`: localhost-only HTTP decision service, authenticated with bearer token. Currently a **deterministic rule baseline**, not AI. It cannot send broker orders.
- `python/test_decision_server.py`: offline decision validation.
- `mql5/SophisticatedScalpingV2.mq5`: MQL5 indicator signal generator and risk-gated paper/shadow execution scaffold.

## Python quickstart
```bash
cd v2/python
python -m unittest -v test_decision_server.py
EA_DECISION_TOKEN=replace-with-long-random-secret python decision_server.py
```
Set EA_DECISION_TOKEN via environment; never commit real credentials.

## Safety and milestones
1. Compile MQL5 in MetaEditor (not yet verified).
2. Strategy Tester with **EnableTrading=false** and **UseDecisionServer=false** first.
3. Check all signal timestamps, indicator handles, symbol digits, spread, volume, stop/freeze levels and broker retcodes.
4. Run the local server; MT5 WebRequest requires an explicitly allowlisted URL and is not available in Strategy Tester. WebRequest is synchronous, so avoid it in OnTick and enforce bounded timeout in OnTimer.
5. Replace deterministic Python rule with an independently tested multi-model orchestrator calling only active lokah1945/wrappers providers; never silently substitute models.
6. Perform reproducible cost-inclusive backtests, walk-forward, untouched OOS, shadow and demo forward tests before any live execution.

**Default trading is disabled.** No profitability guarantee. No external provider requests are made by this scaffold.
