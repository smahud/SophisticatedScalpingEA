import time
import unittest
from decision_server import decide

class DecisionTests(unittest.TestCase):
    def sample(self):
        return dict(signal_id="a1", symbol="EURUSD", side="BUY",
                    timestamp=int(time.time()), ttl_seconds=30,
                    spread_points=10, atr_points=100, adx=30)
    def test_approve(self):
        self.assertEqual(decide(self.sample())["decision"], "APPROVE")
    def test_spread_reject(self):
        x = self.sample(); x["spread_points"] = 50
        self.assertEqual(decide(x)["decision"], "REJECT")
    def test_expired(self):
        x = self.sample(); x["timestamp"] -= 100
        self.assertEqual(decide(x)["decision"], "REJECT")
    def test_invalid(self):
        x = self.sample(); x["side"] = "HOLD"
        with self.assertRaises(ValueError):
            decide(x)

if __name__ == "__main__":
    unittest.main()
