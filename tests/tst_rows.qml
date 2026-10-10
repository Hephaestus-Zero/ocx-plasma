import QtQuick
import QtTest
import "../contents/ui"

// Renders HeroCard and PoolRow (incl. the expanded account list) against a fake
// applet and fake pools; any QML error or broken binding fails the test run.
Item {
    id: top
    width: 420; height: 700

    QtObject {
        id: fake
        property var expandedKeys: ({})
        property string failure: ""
        property var snap: ({ generatedAt: Date.now(), pools: [] })
        property double nowMs: Date.now()
        property var pools: [
            { key: "anthropic", provider: "anthropic", label: "Claude", accounts: 2, usable: 2,
              paused: 0, level: "ok", nextOpenAt: null, balance: null,
              credits: { remaining: 6.5, limit: 10 },
              windows: [{ name: "5h", remainingPct: 82.5, accounts: 2, nextResetAt: Date.now() + 5400000 },
                        { name: "week", remainingPct: 61.0, accounts: 2, nextResetAt: Date.now() + 259200000 },
                        { name: "Gem week", remainingPct: 44.0, accounts: 1, nextResetAt: null }],
              detail: [
                  { id: "a1b2c3d4", label: "alice@example.com", active: true, paused: false, usable: true,
                    health: "Healthy", balance: null, credits: null, quotaFailure: null,
                    windows: [{ name: "5h", usedPct: 15, resetAt: Date.now() + 5400000 },
                              { name: "week", usedPct: 40, resetAt: Date.now() + 259200000 }] },
                  { id: "e5f6a7b8", label: "bob@example.com", active: false, paused: true, usable: false,
                    health: "Healthy", balance: null, credits: null, quotaFailure: null,
                    windows: [{ name: "5h", usedPct: 99, resetAt: Date.now() + 3600000 }] }] },
            { key: "unknown-thing", provider: "acme-cloud", label: "Acme Cloud", accounts: 1, usable: 0,
              paused: 0, level: "warn", nextOpenAt: null, balance: null, credits: null,
              windows: [{ name: "day", remainingPct: 18.0, accounts: 1, nextResetAt: Date.now() + 7200000 }],
              detail: [
                  { id: "zz11yy22", label: "carol@example.com", active: true, paused: false, usable: false,
                    health: "RateLimited", balance: null, credits: null, quotaFailure: null,
                    windows: [{ name: "day", usedPct: 82, resetAt: Date.now() + 7200000 }] }] }
        ]
        function movePool(f, t) {}
        function toggleExpanded(k) { const m = Object.assign({}, expandedKeys); m[k] = !m[k]; expandedKeys = m; }
        function prettyWindow(n) {
            const m = { "5h": "5 hours", "week": "Week", "month": "Month", "day": "Day", "credits": "Credits" };
            if (m[n]) return m[n];
            const i = String(n).lastIndexOf(" ");
            return i > 0 && m[n.substring(i + 1)] ? n.substring(0, i) + " · " + m[n.substring(i + 1)] : n;
        }
        function isShortWindow(n) { return /(^| )5h$/.test(n) || /(^| )day$/.test(n); }
        function windowsOf(pool) {
            const out = (pool.windows || []).map(w => ({ name: prettyWindow(w.name), remaining: Number(w.remainingPct),
                resetAt: w.nextResetAt, isShort: isShortWindow(w.name), extra: "" }));
            if (pool.credits && pool.credits.limit)
                out.push({ name: "Credits", remaining: 100 * pool.credits.remaining / pool.credits.limit,
                           resetAt: null, isShort: false,
                           extra: "$" + pool.credits.remaining.toFixed(0) + " / $" + pool.credits.limit.toFixed(0) });
            return out;
        }
        function ringsOf(pool) {
            const ws = windowsOf(pool);
            const min = a => a.length ? Math.min(...a.map(w => w.remaining)) : NaN;
            const s = min(ws.filter(w => w.isShort)), l = min(ws.filter(w => !w.isShort));
            return isNaN(s) ? { outer: l, inner: NaN } : { outer: s, inner: l };
        }
        function ringTone(r, inner) { return "white"; }
        function worstRemaining(p) { return p.windows.length ? Math.min(...p.windows.map(w => w.remainingPct)) : null; }
        function levelFor(r) { return isNaN(r) || r === null ? "unknown" : r < 10 ? "crit" : r < 25 ? "warn" : "ok"; }
        function toneFor(l) { return l === "crit" ? "red" : l === "warn" ? "orange" : "white"; }
        function untilText(ms) { return "2 h"; }
        function nextReset(p) { const r = (p.windows || []).filter(w => w.remainingPct < 95 && w.nextResetAt).map(w => w.nextResetAt); return r.length ? Math.min(...r) : null; }
        function ageText() { return "just now"; }
        function refresh(c) {}
    }

    Column {
        anchors.fill: parent
        HeroCard { id: hero; applet: fake; pool: fake.pools[0]; expandable: true; width: top.width }
        PoolRow { id: rowB; applet: fake; pool: fake.pools[1]; expandable: true; width: top.width }
        PoolRow { id: rowEmpty; applet: fake; width: top.width
                  pool: ({ key: "empty", provider: "nope", label: "Nope", accounts: 0, usable: 0,
                           level: "unknown", windows: [], detail: [], credits: null, balance: null, nextOpenAt: null }) }
    }

    TestCase {
        name: "rows"
        when: windowShown

        function test_render() {
            tryVerify(() => hero.implicitHeight > 0);
            tryVerify(() => rowB.implicitHeight > 0);
            tryVerify(() => rowEmpty.implicitHeight > 0);
            compare(hero.windows.length, 4);          // 3 windows + credits
            compare(hero.windows[2].name, "Gem · Week");
        }

        function test_expand_accounts() {
            fake.expandedKeys = ({ "anthropic": true });
            tryVerify(() => hero.expanded);
            fake.expandedKeys = ({});
            tryVerify(() => !hero.expanded);
        }
    }
}
