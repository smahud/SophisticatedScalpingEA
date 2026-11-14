#!/usr/bin/env python3
"""Local advisory service for EA V2. Standard library only. No orders or credentials."""
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get("EA_DECISION_TOKEN", "")
HOST = os.environ.get("EA_DECISION_HOST", "127.0.0.1")
PORT = int(os.environ.get("EA_DECISION_PORT", "8765"))
MAX_BYTES = 16384

def decide(data):
    required = ("signal_id", "symbol", "side", "timestamp", "ttl_seconds", "spread_points", "atr_points", "adx")
    if any(k not in data for k in required):
        raise ValueError("missing required signal fields")
    if data["side"] not in ("BUY", "SELL"):
        raise ValueError("invalid side")
    now = int(time.time())
    if int(data["timestamp"]) > now + 5 or now - int(data["timestamp"]) > int(data["ttl_seconds"]):
        return {"signal_id": data["signal_id"], "decision": "REJECT", "risk_multiplier": 0.0, "reason": "expired"}
    # Baseline only. This is NOT an AI ensemble and does not establish profitability.
    spread = float(data["spread_points"])
    atr = float(data["atr_points"])
    adx = float(data["adx"])
    eligible = atr > 0 and spread >= 0 and spread / atr <= 0.12 and adx >= 22
    return {"signal_id": data["signal_id"], "decision": "APPROVE" if eligible else "REJECT",
            "risk_multiplier": 0.5 if eligible else 0.0, "profile": "BASELINE",
            "reason": "deterministic_baseline_v1", "model_version": "rule-v1"}

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/v1/decision":
            self.send_error(404)
            return
        if not TOKEN or self.headers.get("Authorization") != "Bearer " + TOKEN:
            self.send_error(401)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= MAX_BYTES:
                self.send_error(413)
                return
            payload = json.loads(self.rfile.read(length))
            response = decide(payload)
            encoded = json.dumps(response, separators=(",", ":")).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
            self.send_error(400, str(exc))

if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("Set EA_DECISION_TOKEN first")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
