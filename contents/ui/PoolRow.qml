pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Compact pool row: dual ring · logo + name + account dots / quiet window caption ·
// big remaining % with the next reset under it. Accounts unfold below when expanded.
Item {
    id: row

    required property var applet
    required property var pool
    property bool expandable: false
    readonly property bool expanded: expandable && !!applet.expandedKeys[pool.key]

    readonly property var rings: applet.ringsOf(pool)
    readonly property var windows: applet.windowsOf(pool)
    readonly property real worst: windows.length ? Math.min(...windows.map(w => w.remaining)) : NaN
    readonly property var reset: applet.nextReset(pool)

    implicitHeight: col.implicitHeight
    implicitWidth: col.implicitWidth

    // "Gem · 5 hours" + "Gem · Week" collapse to their worst value under "Gem".
    function caption() {
        if (!row.windows.length)
            return i18n("no quota info");
        const fam = [];
        const worst = {};
        for (const w of row.windows) {
            const k = w.name.indexOf(" · ") > 0 ? w.name.split(" · ")[0] : w.name;
            if (!(k in worst)) {
                fam.push(k);
                worst[k] = w.remaining;
            } else {
                worst[k] = Math.min(worst[k], w.remaining);
            }
        }
        return fam.map(k => k + " " + Math.round(worst[k])).join("   ");
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Ring {
                size: Math.round(Kirigami.Units.gridUnit * 1.9)
                outer: row.rings.outer
                inner: row.rings.inner
                outerTone: row.applet.ringTone(row.rings.outer, false)
                innerTone: row.applet.ringTone(row.rings.inner, true)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 1.5
                    Logo {
                        provider: row.pool.provider
                        implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.75)
                        opacity: 0.9
                    }
                    PlasmaComponents.Label {
                        text: row.pool.label
                        font.weight: Font.DemiBold
                    }
                    AccountDots {
                        total: row.pool.accounts
                        usable: row.pool.usable
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: row.caption()
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                spacing: 2
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: isNaN(row.worst) ? "–" : Math.round(row.worst) + "%"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: row.applet.levelFor(row.worst) === "ok" || isNaN(row.worst)
                        ? Kirigami.Theme.textColor : row.applet.toneFor(row.applet.levelFor(row.worst))
                }
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    visible: !!row.reset
                    text: row.reset ? "↻ " + row.applet.untilText(row.reset) : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        AccountsList {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 1.9) + Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: row.expanded
            applet: row.applet
            pool: row.pool
        }
    }
}
