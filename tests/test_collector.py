#!/usr/bin/env python3
"""Unit tests for contents/code/ocx_pools.py — FAKE fixtures only.

Run: python3 -m unittest discover -s tests -v   (or: python3 tests/test_collector.py)
"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location(
    "ocx_pools", os.path.join(ROOT, "contents", "code", "ocx_pools.py"))
ocx_pools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ocx_pools)

NOW = 1_800_000_000_000  # arbitrary ms timestamp


def acct(provider="anthropic", plan=None, **kw):
    a = {"id": kw.pop("id", "aaaabbbbccccdddd"), "provider": provider, "plan": plan,
         "label": kw.pop("label", "alice@example.com"), "active": kw.pop("active", True)}
    a.update(kw)
    return a


def quota(five=None, weekly=None, monthly=None, credits=None, custom=None):
    q = {}
    if five is not None:
        q["fiveHourPercent"], q["fiveHourResetAt"] = five
    if weekly is not None:
        q["weeklyPercent"], q["weeklyResetAt"] = weekly
    if monthly is not None:
        q["monthlyPercent"], q["monthlyResetAt"] = monthly
    if credits is not None:
        q["creditsUsd"] = credits
    if custom is not None:
        q["customWindows"] = custom
    return q


class TestMs(unittest.TestCase):
    def test_seconds_become_ms(self):
        self.assertEqual(ocx_pools.ms(NOW // 1000), NOW - NOW % 1000)

    def test_ms_passthrough(self):
        self.assertEqual(ocx_pools.ms(NOW), NOW)

    def test_none(self):
        self.assertIsNone(ocx_pools.ms(None))


class TestGrouping(unittest.TestCase):
    def test_group_per_provider_and_plan(self):
        pools = ocx_pools.build_pools([
            acct(provider="anthropic", id="a1"),
            acct(provider="anthropic", id="a2", label="bob@example.com"),
            acct(provider="openai", plan="go", id="c1"),
            acct(provider="openai", plan="pro", id="c2", label="carol@example.com"),
        ], NOW)
        keys = sorted(p["key"] for p in pools)
        self.assertEqual(keys, ["anthropic", "openai:go", "openai:pro"])
        by_key = {p["key"]: p for p in pools}
        self.assertEqual(by_key["anthropic"]["accounts"], 2)
        self.assertEqual(by_key["openai:go"]["label"], "Codex Go")
        self.assertEqual(by_key["openai:pro"]["label"], "Codex Pro")

    def test_unknown_provider_titlecased(self):
        pools = ocx_pools.build_pools([acct(provider="acme-cloud", id="x1")], NOW)
        self.assertEqual(pools[0]["label"], "Acme Cloud")
        self.assertEqual(pools[0]["provider"], "acme-cloud")

    def test_known_provider_labels(self):
        for prov, label in [("xai", "Grok"), ("devin", "Devin"), ("kimi", "Kimi"),
                            ("command-code", "Command Code")]:
            pools = ocx_pools.build_pools([acct(provider=prov, id="x")], NOW)
            self.assertEqual(pools[0]["label"], label, prov)


class TestWindows(unittest.TestCase):
    def test_used_becomes_remaining(self):
        a = acct(quota=quota(five=(40.0, NOW + 3600_000), weekly=(80.0, NOW + 86_400_000)))
        pools = ocx_pools.build_pools([a], NOW)
        wins = {w["name"]: w["remainingPct"] for w in pools[0]["windows"]}
        self.assertEqual(wins["5h"], 60.0)
        self.assertEqual(wins["week"], 20.0)

    def test_reset_seconds_normalised(self):
        a = acct(quota=quota(five=(10.0, NOW // 1000 + 60)))
        pools = ocx_pools.build_pools([a], NOW)
        w = pools[0]["windows"][0]
        self.assertGreater(w["nextResetAt"], NOW)          # treated as seconds -> ms
        self.assertLess(w["nextResetAt"], NOW + 120_000)

    def test_reset_ms_passthrough(self):
        a = acct(quota=quota(five=(10.0, NOW + 60_000)))
        pools = ocx_pools.build_pools([a], NOW)
        self.assertEqual(pools[0]["windows"][0]["nextResetAt"], NOW + 60_000)

    def test_remaining_is_average_across_accounts(self):
        pools = ocx_pools.build_pools([
            acct(id="a1", quota=quota(weekly=(50.0, None))),
            acct(id="a2", label="bob@example.com", quota=quota(weekly=(70.0, None))),
        ], NOW)
        w = pools[0]["windows"][0]
        self.assertEqual(w["accounts"], 2)
        self.assertAlmostEqual(w["remainingPct"], 40.0)

    def test_custom_window_keys_are_neutral(self):
        custom = [{"label": "Gem (Weekly)", "percent": 30, "resetAt": None},
                  {"label": "Daily", "percent": 5, "resetAt": None}]
        a = acct(provider="google-antigravity", quota=quota(custom=custom))
        pools = ocx_pools.build_pools([a], NOW)
        names = sorted(w["name"] for w in pools[0]["windows"])
        self.assertEqual(names, ["Gem week", "day"])

    def test_monthly(self):
        a = acct(quota=quota(monthly=(25.0, None)))
        pools = ocx_pools.build_pools([a], NOW)
        self.assertEqual(pools[0]["windows"][0]["name"], "month")


class TestCreditsBalance(unittest.TestCase):
    def test_credits_aggregated(self):
        cr = {"remaining": 3.0, "limit": 10.0, "expiresAt": NOW + 99_000}
        pools = ocx_pools.build_pools([acct(id="a1", quota=quota(credits=cr)),
                                       acct(id="a2", label="b@example.com", quota=quota(credits=cr))], NOW)
        self.assertEqual(pools[0]["credits"], {"remaining": 6.0, "limit": 20.0})

    def test_balance_custom_window(self):
        custom = [{"label": "credit balance ($4.50)", "percent": 0, "resetAt": None}]
        pools = ocx_pools.build_pools([acct(provider="devin", quota=quota(custom=custom))], NOW)
        self.assertEqual(pools[0]["balance"], 4.5)
        self.assertEqual(pools[0]["windows"], [])           # balance is not a window


class TestUsability(unittest.TestCase):
    def test_paused_not_usable_not_counted_unknown(self):
        pools = ocx_pools.build_pools([
            acct(id="a1", paused=True, quota=quota(weekly=(10.0, None)))], NOW)
        p = pools[0]
        self.assertEqual(p["usable"], 0)
        self.assertEqual(p["paused"], 1)
        self.assertEqual(p["unknownQuota"], 0)

    def test_exhausted_window_not_usable(self):
        pools = ocx_pools.build_pools([
            acct(quota=quota(weekly=(99.0, NOW + 3600_000)))], NOW)
        self.assertEqual(pools[0]["usable"], 0)
        self.assertEqual(pools[0]["nextOpenAt"], NOW + 3600_000)
        self.assertEqual(pools[0]["level"], "crit")

    def test_unhealthy_not_usable(self):
        pools = ocx_pools.build_pools([
            acct(health="RateLimited", quota=quota(weekly=(10.0, None)))], NOW)
        self.assertEqual(pools[0]["usable"], 0)

    def test_zero_balance_not_usable(self):
        custom = [{"label": "balance ($0.00)", "percent": 0}]
        pools = ocx_pools.build_pools([acct(provider="devin", quota=quota(custom=custom))], NOW)
        self.assertEqual(pools[0]["usable"], 0)

    def test_no_quota_is_unknown(self):
        pools = ocx_pools.build_pools([acct()], NOW)
        p = pools[0]
        self.assertEqual(p["level"], "unknown")
        self.assertEqual(p["unknownQuota"], 1)

    def test_levels(self):
        mk = lambda pct: ocx_pools.build_pools(
            [acct(quota=quota(weekly=(pct, None)))], NOW)[0]["level"]
        self.assertEqual(mk(50.0), "ok")        # 50 % remaining
        self.assertEqual(mk(80.0), "warn")      # 20 % remaining  < 25
        self.assertEqual(mk(95.0), "crit")      # 5 % remaining   < 10


class TestSorting(unittest.TestCase):
    def test_crit_first(self):
        pools = ocx_pools.build_pools([
            acct(provider="openai", id="c", quota=quota(weekly=(10.0, None))),      # ok
            acct(provider="anthropic", id="a", quota=quota(weekly=(95.0, None)))], NOW)  # crit
        self.assertEqual(pools[0]["provider"], "anthropic")


class TestCli(unittest.TestCase):
    def test_json_fresh_cache_shortcircuits_ocx(self):
        with tempfile.TemporaryDirectory() as d:
            cache_dir = os.path.join(d, "ocx-plasma")
            os.makedirs(cache_dir)
            snap = {"generatedAt": int(ocx_pools.time.time() * 1000), "pools": []}
            with open(os.path.join(cache_dir, "pools.json"), "w") as f:
                json.dump(snap, f)
            with mock.patch.object(ocx_pools, "CACHE_DIR", cache_dir), \
                 mock.patch.object(ocx_pools, "CACHE", os.path.join(cache_dir, "pools.json")), \
                 mock.patch.object(ocx_pools, "collect", side_effect=AssertionError("collect called")):
                self.assertEqual(ocx_pools.load(60), snap)

    def test_stale_cache_served_when_ocx_fails(self):
        with tempfile.TemporaryDirectory() as d:
            cache_dir = os.path.join(d, "ocx-plasma")
            os.makedirs(cache_dir)
            snap = {"generatedAt": 1, "pools": [{"label": "x"}]}
            with open(os.path.join(cache_dir, "pools.json"), "w") as f:
                json.dump(snap, f)
            with mock.patch.object(ocx_pools, "CACHE_DIR", cache_dir), \
                 mock.patch.object(ocx_pools, "CACHE", os.path.join(cache_dir, "pools.json")), \
                 mock.patch.object(ocx_pools, "collect", side_effect=RuntimeError("ocx gone")):
                out = ocx_pools.load(60)
            self.assertTrue(out["stale"])
            self.assertEqual(out["pools"], snap["pools"])

    def test_ocx_missing_message(self):
        with mock.patch.object(ocx_pools, "OCX", ["definitely-not-ocx-xyz"]):
            with self.assertRaises(RuntimeError) as ctx:
                ocx_pools.run_ocx(["account", "list"])
            self.assertIn("npm i -g @bitkyc08/opencodex", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
