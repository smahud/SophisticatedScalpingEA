# Product scope and non-negotiable outcomes
User-facing interface: MetaTrader 5 ONLY. User attaches ONE EA to ONE chart; all eligible broker FX pairs are discovered and analyzed without opening additional charts. Native on-chart dashboard displays health, opportunities, AI state, positions and global risk. Python and lokah1945/wrappers operate headlessly behind the scenes; no web dashboard required.
EA owns market data, regime, strategy signals, risk hard stops, position lifecycle and order execution. AI may APPROVE, REJECT or WAIT and recommend bounded risk reductions, but never invent trades, reverse direction, bypass stops, or increase baseline risk.
Support deterministic EA-only research mode, AI shadow mode, AI gated demo mode, and eventually live mode behind explicit approval. Missing AI => fail closed for new AI-gated entries; open positions remain locally protected.
All eligible broker FX symbols, including suffixes, subject to hard MaxSymbols and resource budgets; not all broker products, not guaranteed data availability. No promise every tick captured.
Success is a reproducibly tested, risk-bounded MT5 system with evidence of incremental value versus baseline; profit not guaranteed.
Non-goals: HFT co-location, guaranteed latency, guaranteed win rate, web UI, unattended live rollout without approval, unlicensed copying of GPL source.
