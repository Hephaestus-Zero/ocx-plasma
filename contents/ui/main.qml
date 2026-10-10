pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

// Runs the bundled collector (contents/code/ocx_pools.py) through the executable
// engine and shows remaining quota per subscription pool. The collector caches to
// $XDG_CACHE_HOME/ocx-plasma/pools.json, so every widget instance shares one ocx
// call per refresh. The pool order is the user's (drag in the popup); the panel
// shows rings for the first few.
PlasmoidItem {
    id: root

    property var snap: null
    property string failure: ""
    property double nowMs: Date.now()
    property var expandedKeys: ({})

    // Path of the collector inside this package (file:///… → /…).
    readonly property string collector: {
        const u = Qt.resolvedUrl("../code/ocx_pools.py").toString();
        return u.indexOf("file://") === 0 ? u.substring(7) : u;
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    readonly property string envPrefix: "OCX_CMD=" + shellQuote(Plasmoid.configuration.ocxCommand)
        + " OCX_WARN_PCT=" + shellQuote(Plasmoid.configuration.warnPercent)
        + " OCX_CRIT_PCT=" + shellQuote(Plasmoid.configuration.critPercent) + " "

    // Cached read (refresh if older than the poll interval) vs. forced collect.
    readonly property string dataCmd: root.envPrefix + "python3 " + shellQuote(root.collector)
        + " json --max-age " + Math.max(10, Plasmoid.configuration.refreshSeconds)
    readonly property string collectCmd: root.envPrefix + "python3 " + shellQuote(root.collector)
        + " json --max-age 0"

    readonly property var hidden: String(Plasmoid.configuration.hiddenProviders).split(",").map(s => s.trim()).filter(s => s)
    readonly property var order: String(Plasmoid.configuration.poolOrder || "").split(",").map(s => s.trim()).filter(s => s)

    // User order first; pools the user never placed follow, most constrained first.
    readonly property var pools: {
        if (!root.snap || !Array.isArray(root.snap.pools))
            return [];
        const visible = root.snap.pools.filter(p => p && root.hidden.indexOf(p.provider) === -1);
        const rank = p => {
            const i = root.order.indexOf(p.key);
            return i === -1 ? 1000 + (root.worstRemaining(p) ?? 101) : i;
        };
        return visible.sort((a, b) => rank(a) - rank(b));
    }
    readonly property var panelPools: root.pools.slice(0, Math.max(1, Plasmoid.configuration.panelRings))

    Plasmoid.icon: "speedometer"
    switchWidth: Kirigami.Units.gridUnit * 16
    switchHeight: Kirigami.Units.gridUnit * 12

    compactRepresentation: CompactRepresentation { applet: root }
    fullRepresentation: FullRepresentation { applet: root }
    toolTipItem: PoolToolTip { applet: root }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh(true)
        },
        PlasmaCore.Action {
            text: i18n("Reset order")
            icon.name: "edit-undo"
            onTriggered: Plasmoid.configuration.poolOrder = ""
        }
    ]

    // Move pool `from` to position `to` in the visible list and persist the order.
    function movePool(from, to) {
        if (from === to || from < 0 || to < 0)
            return;
        const keys = root.pools.map(p => p.key);
        const [k] = keys.splice(from, 1);
        keys.splice(to, 0, k);
        // Keep hidden pools' saved positions at the end so they are not lost.
        const rest = root.order.filter(o => keys.indexOf(o) === -1);
        Plasmoid.configuration.poolOrder = keys.concat(rest).join(",");
    }

    function toggleExpanded(key) {
        const m = Object.assign({}, root.expandedKeys);
        m[key] = !m[key];
        root.expandedKeys = m;
    }

    // ---- windows: short (5h / day) feeds the outer ring, long (week / month / credits) the inner ----
    // The collector emits neutral period keys; family names pass through unchanged.
    function prettyWindow(name) {
        const m = { "5h": i18n("5 hours"), "week": i18n("Week"), "month": i18n("Month"),
                    "day": i18n("Day"), "credits": i18n("Credits") };
        if (m[name])
            return m[name];
        const i = String(name).lastIndexOf(" ");
        if (i > 0 && m[name.substring(i + 1)])
            return name.substring(0, i) + " · " + m[name.substring(i + 1)];
        return name;
    }

    function isShortWindow(name) {
        return /(^| )5h$/.test(name) || /(^| )day$/.test(name);
    }

    function windowsOf(pool) {
        const out = (pool.windows || []).map(w => ({
            name: root.prettyWindow(w.name),
            remaining: Number(w.remainingPct),
            resetAt: w.nextResetAt,
            isShort: root.isShortWindow(w.name),
            extra: ""
        }));
        if (pool.credits && pool.credits.limit)
            out.push({ name: i18n("Credits"), remaining: 100 * pool.credits.remaining / pool.credits.limit,
                       resetAt: null, isShort: false,
                       extra: "$" + pool.credits.remaining.toFixed(0) + " / $" + pool.credits.limit.toFixed(0) });
        return out;
    }

    // {outer, inner} remaining for the rings; a pool with one kind of window uses only the outer ring.
    function ringsOf(pool) {
        const ws = root.windowsOf(pool);
        const min = a => a.length ? Math.min(...a.map(w => w.remaining)) : NaN;
        const s = min(ws.filter(w => w.isShort));
        const l = min(ws.filter(w => !w.isShort));
        return isNaN(s) ? { outer: l, inner: NaN } : { outer: s, inner: l };
    }

    function ringTone(remaining, inner) {
        const lvl = root.levelFor(remaining);
        if (lvl === "crit" || lvl === "warn")
            return root.toneFor(lvl);
        return Qt.alpha(Kirigami.Theme.textColor, inner ? 0.42 : 0.92);
    }

    // ---- formatting helpers shared by every view ----
    function worstRemaining(pool) {
        if (!pool || !pool.windows || pool.windows.length === 0)
            return null;
        return Math.min(...pool.windows.map(w => Number(w.remainingPct)));
    }

    function levelFor(remaining) {
        if (remaining === null || remaining === undefined || isNaN(remaining))
            return "unknown";
        return remaining < Plasmoid.configuration.critPercent ? "crit"
            : remaining < Plasmoid.configuration.warnPercent ? "warn" : "ok";
    }

    function toneFor(level) {
        if (level === "crit")
            return Kirigami.Theme.negativeTextColor;
        if (level === "warn")
            return Kirigami.Theme.neutralTextColor;
        return Qt.alpha(Kirigami.Theme.textColor, 0.88);
    }

    function untilText(ms) {
        if (!ms)
            return "";
        const d = ms - root.nowMs;
        if (d <= 0)
            return i18n("now");
        const min = Math.round(d / 60000);
        if (min < 60)
            return i18n("%1 min", min);
        const h = Math.floor(min / 60);
        if (h < 24)
            return min % 60 ? i18n("%1 h %2 min", h, min % 60) : i18n("%1 h", h);
        return i18n("%1 d", Math.round(h / 24));
    }

    // Next reset that matters: the soonest reset of a window below 100% left.
    function nextReset(pool) {
        if (pool.nextOpenAt)
            return pool.nextOpenAt;
        const r = (pool.windows || []).filter(w => w.remainingPct < 95 && w.nextResetAt).map(w => w.nextResetAt);
        return r.length ? Math.min(...r) : null;
    }

    function ageText() {
        if (!root.snap || !root.snap.generatedAt)
            return "";
        const s = Math.max(0, Math.round((root.nowMs - root.snap.generatedAt) / 1000));
        return s < 90 ? i18n("just now") : i18n("%1 min ago", Math.round(s / 60));
    }

    // ---- data ----
    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (data["exit code"] !== 0) {
                root.failure = String(data.stderr || "").trim() || i18n("could not read quota data");
                return;
            }
            try {
                const parsed = JSON.parse(data.stdout);
                if (!parsed || typeof parsed !== "object")
                    throw new Error("not an object");
                root.snap = parsed;
                root.failure = "";
            } catch (e) {
                root.failure = i18n("invalid quota data: %1", e.message);
            }
        }
    }

    function refresh(collect) {
        const cmd = collect ? root.collectCmd : root.dataCmd;
        if (reader.connectedSources.indexOf(cmd) === -1)
            reader.connectSource(cmd);
    }

    Timer {
        interval: Math.max(10, Plasmoid.configuration.refreshSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.nowMs = Date.now();
            root.refresh(false);
        }
    }
}
