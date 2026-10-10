#!/usr/bin/env python3
"""ocx-plasma collector: group opencodex accounts into subscription pools.

The Plasma widget runs this via the executable data engine; panel, tooltip and
popup all read one shared cache so ocx is called at most once per refresh:

  ocx_pools.py collect               # refresh the cache
  ocx_pools.py json [--max-age S]    # print cache, refreshing first if older than S
  ocx_pools.py show [--max-age S]    # compact text summary

All ocx quota percents are USED percents; the cache stores REMAINING percents.
Reset times may arrive in seconds or milliseconds and are normalised to ms.

Environment:
  OCX_CMD          command used to call opencodex (default: "ocx"; may contain
                   arguments, e.g. "ocx --profile work")
  OCX_WARN_PCT     remaining % considered warning   (default: 25)
  OCX_CRIT_PCT     remaining % considered critical  (default: 10)
  XDG_CACHE_HOME   cache base dir (default: ~/.cache); file is
                   $XDG_CACHE_HOME/ocx-plasma/pools.json

Requires python3 >= 3.9, standard library only.
"""
import json, os, re, shlex, subprocess, sys, tempfile, time

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
                         "ocx-plasma")
CACHE = os.path.join(CACHE_DIR, "pools.json")
WARN_PCT = float(os.environ.get("OCX_WARN_PCT", "25"))
CRIT_PCT = float(os.environ.get("OCX_CRIT_PCT", "10"))
OCX = shlex.split(os.environ.get("OCX_CMD", "ocx"))
INSTALL_HINT = "install opencodex: npm i -g @bitkyc08/opencodex"

PROVIDER_LABELS = {
    "anthropic": "Claude", "openai": "Codex", "google-antigravity": "Antigravity",
    "devin": "Devin", "command-code": "Command Code", "kimi": "Kimi",
    "deepseek": "DeepSeek", "openrouter": "OpenRouter", "xai": "Grok",
}
BALANCE_RE = re.compile(r"balance \(\$([0-9.]+)\)", re.I)


def ms(t):
    """Reset times arrive as seconds or milliseconds; normalise to ms."""
    if t is None:
        return None
    return int(t * 1000) if t < 1e12 else int(t)


def provider_label(prov):
    """Display label for a provider id; title-cased fallback for unknown ones."""
    if prov in PROVIDER_LABELS:
        return PROVIDER_LABELS[prov]
    return re.sub(r"[-_]+", " ", str(prov or "?")).strip().title() or "?"


def window_key(label):
    """Neutral (untranslated) window key: '5h', 'week', 'month', 'day', or
    '<Family> <period>' for branded custom windows like 'Gem (Weekly)' ->
    'Gem week'. QML maps the trailing period key to a translated label."""
    label = (label or "").strip()
    m = re.match(r"^(.*?)\s*\(([^)]+)\)\s*$", label)
    par = m.group(2).lower() if m else label.lower()
    base = m.group(1).strip() if m else ""
    period = None
    for word, key in (("week", "week"), ("month", "month"), ("dai", "day"),
                      ("day", "day"), ("5h", "5h"), ("5 h", "5h"), ("5-h", "5h")):
        if word in par:
            period = key
            break
    if period is None:
        return label or "window"
    if not base:
        base = re.sub(r"(?i)\b(weekly|monthly|daily|week|month|day|5\s*-?\s*h)\b", "", label).strip()
    return f"{base} {period}" if base else period


def run_ocx(args, timeout=90):
    try:
        out = subprocess.run([*OCX, *args], capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        raise RuntimeError(f"'{OCX[0]}' not found — {INSTALL_HINT}")
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"'{OCX[0]} {' '.join(args)}' timed out after {timeout}s")
    if out.returncode != 0:
        raise RuntimeError(f"{OCX[0]} {' '.join(args)} exit {out.returncode}: {out.stderr.strip()[:200]}")
    return json.loads(out.stdout)


def account_windows(acct):
    """Normalise one account's quota into [{name, usedPct, resetAt}] + optional credits/balance."""
    q = acct.get("quota") or {}
    wins, credits, balance = [], None, None
    for key, name in (("fiveHour", "5h"), ("weekly", "week"), ("monthly", "month")):
        if q.get(f"{key}Percent") is not None:
            wins.append({"name": name, "usedPct": float(q[f"{key}Percent"]), "resetAt": ms(q.get(f"{key}ResetAt"))})
    for cw in q.get("customWindows") or []:
        m = BALANCE_RE.search(cw.get("label", ""))
        if m:
            balance = float(m.group(1))
            continue
        wins.append({"name": window_key(cw.get("label")), "usedPct": float(cw.get("percent") or 0),
                     "resetAt": ms(cw.get("resetAt"))})
    c = q.get("creditsUsd")
    if c:
        credits = {"remaining": c.get("remaining"), "limit": c.get("limit"), "expiresAt": ms(c.get("expiresAt"))}
    return wins, credits, balance


def account_usable(acct, wins, balance):
    if acct.get("paused") or acct.get("needsReauth"):
        return False
    if acct.get("health") not in (None, "Healthy"):
        return False
    if balance is not None and balance <= 0:
        return False
    return all(w["usedPct"] < 98 for w in wins)


def level_for(remaining):
    if remaining is None:
        return "unknown"
    return "crit" if remaining < CRIT_PCT else "warn" if remaining < WARN_PCT else "ok"


def build_pools(accounts, now):
    groups = {}
    for a in accounts:
        prov = a.get("provider")
        plan = a.get("plan")
        key = f"{prov}:{plan}" if plan else prov
        groups.setdefault(key, []).append(a)

    pools = []
    for key, accts in groups.items():
        prov = accts[0]["provider"]
        plan = accts[0].get("plan")
        label = provider_label(prov) + (f" {str(plan).capitalize()}" if plan else "")
        detail, by_window = [], {}
        credit_rem = credit_lim = 0.0
        has_credit, balances = False, []
        usable = paused = unknown = 0
        next_open = None
        for a in accts:
            wins, credits, balance = account_windows(a)
            ok = account_usable(a, wins, balance)
            quota_known = bool(wins) or credits is not None or balance is not None
            if a.get("paused"):
                paused += 1
            elif not quota_known:
                unknown += 1
            if ok:
                usable += 1
            if not a.get("paused"):
                for w in wins:
                    by_window.setdefault(w["name"], []).append(w)
                    if w["usedPct"] >= 98 and w["resetAt"] and w["resetAt"] > now:
                        next_open = min(next_open or w["resetAt"], w["resetAt"])
                if credits and credits["remaining"] is not None:
                    has_credit = True
                    credit_rem += credits["remaining"]
                    credit_lim += credits["limit"] or 0
                if balance is not None:
                    balances.append(balance)
            detail.append({
                "id": str(a.get("id"))[:8], "label": a.get("label") or a.get("masked") or "",
                "active": bool(a.get("active")), "paused": bool(a.get("paused")),
                "health": a.get("health") or ("Healthy" if a.get("type") == "api-key" else None),
                "usable": ok, "windows": wins, "credits": credits, "balance": balance,
                "quotaFailure": a.get("quotaFailure"),
            })
        windows = []
        for name, ws in by_window.items():
            rem = sum(100 - w["usedPct"] for w in ws) / len(ws)
            resets = [w["resetAt"] for w in ws if w["resetAt"] and w["resetAt"] > now]
            windows.append({"name": name, "remainingPct": round(rem, 1), "accounts": len(ws),
                            "nextResetAt": min(resets) if resets else None})
        remaining_vals = [w["remainingPct"] for w in windows]
        if has_credit and credit_lim:
            remaining_vals.append(100 * credit_rem / credit_lim)
        if balances:
            remaining_vals.append(0.0 if sum(balances) <= 0 else 100.0)
        lvl = level_for(min(remaining_vals) if remaining_vals else None)
        if usable == 0 and len(accts) - paused > 0 and lvl != "unknown":
            lvl = "crit"
        pools.append({
            "key": key, "provider": prov, "label": label, "accounts": len(accts),
            "usable": usable, "paused": paused, "unknownQuota": unknown,
            "windows": windows, "nextOpenAt": next_open,
            "credits": {"remaining": round(credit_rem, 2), "limit": round(credit_lim, 2)} if has_credit else None,
            "balance": round(sum(balances), 2) if balances else None,
            "level": lvl, "detail": detail,
        })
    order = {"crit": 0, "warn": 1, "ok": 2, "unknown": 3}
    pools.sort(key=lambda p: (order[p["level"]], p["label"]))
    return pools


def collect():
    now = int(time.time() * 1000)
    data = run_ocx(["account", "list", "--quota", "--json"])
    snap = {"generatedAt": now, "pools": build_pools(data.get("accounts") or [], now)}
    os.makedirs(CACHE_DIR, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=CACHE_DIR, prefix=".pools.")
    with os.fdopen(fd, "w") as f:
        json.dump(snap, f, ensure_ascii=False, indent=1)
    os.replace(tmp, CACHE)
    return snap


def read_cache():
    try:
        with open(CACHE) as f:
            snap = json.load(f)
        return snap if isinstance(snap, dict) and "generatedAt" in snap else None
    except (OSError, ValueError):
        return None


def load(max_age_s):
    cached = read_cache()
    fresh = cached is not None and time.time() * 1000 - cached["generatedAt"] <= max_age_s * 1000
    if fresh:
        return cached
    try:
        return collect()
    except Exception:
        if cached is not None:          # serve the stale cache, flag it for the UI
            cached["stale"] = True
            return cached
        raise


def hhmm(t):
    if not t:
        return "?"
    fmt = "%d.%m %H:%M" if abs(t / 1000 - time.time()) > 20 * 3600 else "%H:%M"
    return time.strftime(fmt, time.localtime(t / 1000))


def summary(snap):
    out = [f"ocx pools @ {hhmm(snap['generatedAt'])} (remaining %, usable/accounts)"]
    if snap.get("stale"):
        out[0] += " [stale cache]"
    for p in snap["pools"]:
        if p["level"] == "unknown" and not p["windows"]:
            out.append(f"- {p['label']} x{p['accounts']}: quota n/a")
            continue
        parts = [f"{w['name']} {w['remainingPct']:.0f}%" for w in p["windows"]]
        if p["credits"]:
            parts.append(f"${p['credits']['remaining']:.2f}/${p['credits']['limit']:.2f}")
        if p["balance"] is not None:
            parts.append(f"balance ${p['balance']:.2f}")
        tail = f" | {p['usable']}/{p['accounts']} usable"
        if p["paused"]:
            tail += f", {p['paused']} paused"
        if p["nextOpenAt"]:
            tail += f", next opens {hhmm(p['nextOpenAt'])}"
        mark = {"crit": "!!", "warn": "!", "ok": "", "unknown": "?"}[p["level"]]
        out.append(f"- {mark}{p['label']} x{p['accounts']}: " + ", ".join(parts) + tail)
    return "\n".join(out)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "show"
    max_age = 180
    if "--max-age" in argv:
        max_age = int(argv[argv.index("--max-age") + 1])
    try:
        if cmd == "collect":
            collect()
        elif cmd == "show":
            print(summary(load(max_age)))
        elif cmd == "json":
            print(json.dumps(load(max_age), ensure_ascii=False))
        else:
            print(__doc__)
            return 2
    except Exception as e:
        print(f"ocx-plasma: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
