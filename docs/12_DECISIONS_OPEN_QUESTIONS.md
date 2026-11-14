# Decisions and unresolved constraints
DECIDED: MT5 sole user UI; one EA on one chart; all eligible broker FX pairs scanned; headless Python Wrappers AI advisory; MQL5 owns signals/risk/orders; no live until authorized; main preserved.
OPEN before full integration: broker and symbol catalog; account netting/hedging; leverage, currency, stop/freeze/lot constraints; OS/MT5 host and whether Python runs locally or on remote VPS; selected exact Wrappers providers/models, API credentials and rate budgets; supported timeframes; permissible risk caps; latency and opportunity TTL; required regulatory/compliance context.
Defaults must be conservative and documented. Do not invent broker constraints, test results or profitability.
