import QtQuick
import QtTest
import "../contents/ui"

// Drag-to-reorder in the popup: press the grip of a row, move, release →
// applet.movePool(from, to) with the right indices.
Item {
    id: top
    width: 420; height: 600

    QtObject {
        id: fake
        property var moves: []
        property var expandedKeys: ({})
        property string failure: ""
        property var snap: ({ generatedAt: Date.now() })
        property double nowMs: Date.now()
        property var pools: ["a", "b", "c", "d"].map((k, i) => ({
            key: k, provider: k, label: "Pool " + k.toUpperCase(), accounts: 1, usable: 1,
            level: "ok", windows: [{ name: "5h", remainingPct: 90 - i * 10, nextResetAt: null }],
            detail: [], credits: null, balance: null, nextOpenAt: null }))
        function movePool(f, t) { moves = moves.concat([[f, t]]); }
        function toggleExpanded(k) {}
        function prettyWindow(n) { return ({ "5h": "5 hours", "week": "Week", "month": "Month", "day": "Day" })[n] || n; }
        function isShortWindow(n) { return /(^| )5h$/.test(n) || /(^| )day$/.test(n); }
        function windowsOf(pool) {
            return (pool.windows || []).map(w => ({ name: prettyWindow(w.name), remaining: Number(w.remainingPct),
                resetAt: w.nextResetAt, isShort: isShortWindow(w.name), extra: "" }));
        }
        function ringsOf(pool) {
            const ws = windowsOf(pool);
            const min = a => a.length ? Math.min(...a.map(w => w.remaining)) : NaN;
            const s = min(ws.filter(w => w.isShort)), l = min(ws.filter(w => !w.isShort));
            return isNaN(s) ? { outer: l, inner: NaN } : { outer: s, inner: l };
        }
        function ringTone(r, inner) { return "white"; }
        function worstRemaining(p) { return Math.min(...p.windows.map(w => w.remainingPct)); }
        function levelFor(r) { return "ok"; }
        function toneFor(l) { return "white"; }
        function untilText(ms) { return ""; }
        function nextReset(p) { return null; }
        function ageText() { return ""; }
        function refresh(c) {}
    }

    FullRepresentation { id: full; applet: fake; anchors.fill: parent }

    TestCase {
        name: "drag"
        when: windowShown

        function dragRow(from, toRowCenterOf, below) {
            const rep = findChild(full, "poolRows");
            const src = rep.itemAt(from);
            const dst = rep.itemAt(toRowCenterOf);
            const g = src.children.find(c => c.source === "drag-handle-symbolic");
            const ma = g.children[0];
            const p0 = ma.mapToItem(top, ma.width / 2, ma.height / 2);
            const target = dst.mapToItem(top, 0, below ? dst.height * 0.9 : dst.height * 0.1);
            mousePress(top, p0.x, p0.y);
            for (let s = 1; s <= 8; s++)
                mouseMove(top, p0.x, p0.y + (target.y - p0.y) * s / 8);
            mouseRelease(top, p0.x, target.y);
        }

        function test_down_and_up() {
            fake.moves = [];
            tryVerify(() => findChild(full, "poolRows") && findChild(full, "poolRows").count === 4);
            dragRow(0, 2, true);          // drop below row 2 → index 2
            dragRow(3, 0, false);         // drop above row 0 → index 0
            dragRow(1, 1, false);         // drop on itself → no-op (from==to)
            compare(fake.moves, [[0, 2], [3, 0], [1, 1]]);
        }
    }
}
