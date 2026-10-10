pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Accounts behind a pool: tiny ring, label (● = active), per-window remaining.
ColumnLayout {
    id: list
    required property var applet
    required property var pool
    spacing: Kirigami.Units.smallSpacing * 1.5

    Repeater {
        model: list.pool.detail
        delegate: RowLayout {
            id: acct
            required property var modelData
            readonly property var short_: (modelData.windows || []).filter(w => list.applet.isShortWindow(w.name))
            readonly property var long_: (modelData.windows || []).filter(w => !list.applet.isShortWindow(w.name))
            readonly property real o: short_.length ? Math.min(...short_.map(w => 100 - w.usedPct)) : (long_.length ? Math.min(...long_.map(w => 100 - w.usedPct)) : NaN)
            readonly property real i: short_.length && long_.length ? Math.min(...long_.map(w => 100 - w.usedPct)) : NaN
            readonly property var blocked: (modelData.windows || []).filter(w => w.usedPct >= 98 && w.resetAt)
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2
            opacity: modelData.usable ? 1 : 0.55

            Ring {
                size: Math.round(Kirigami.Units.gridUnit * 1.1)
                stroke: 2
                gap: 1.5
                outer: acct.o
                inner: acct.i
                outerTone: list.applet.ringTone(acct.o, false)
                innerTone: list.applet.ringTone(acct.i, true)
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: (acct.modelData.label || acct.modelData.id) + (acct.modelData.active ? "  ●" : "")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                text: acct.modelData.paused ? i18n("paused")
                    : acct.blocked.length ? "↻ " + list.applet.untilText(Math.min(...acct.blocked.map(w => w.resetAt)))
                    : (acct.modelData.windows || []).map(w => Math.round(100 - w.usedPct)).join(" · ")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
