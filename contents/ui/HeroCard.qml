pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// The first pool in the user's order, large: dual ring with the remaining % in the
// middle, then one aligned line per window (name · % · reset).
Item {
    id: hero

    required property var applet
    required property var pool
    property bool expandable: false
    readonly property bool expanded: expandable && !!applet.expandedKeys[pool.key]

    readonly property var rings: applet.ringsOf(pool)
    readonly property var windows: applet.windowsOf(pool)
    readonly property real worst: windows.length ? Math.min(...windows.map(w => w.remaining)) : NaN

    implicitHeight: col.implicitHeight
    implicitWidth: col.implicitWidth

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.gridUnit

            Ring {
                size: Math.round(Kirigami.Units.gridUnit * 4.6)
                stroke: Math.round(size * 0.065)
                gap: 3
                outer: hero.rings.outer
                inner: hero.rings.inner
                outerTone: hero.applet.ringTone(hero.rings.outer, false)
                innerTone: hero.applet.ringTone(hero.rings.inner, true)
                centerText: isNaN(hero.worst) ? "–" : Math.round(hero.worst)
                centerScale: 0.27
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 1.5
                    Logo {
                        provider: hero.pool.provider
                        implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.9)
                    }
                    PlasmaComponents.Label {
                        text: hero.pool.label
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    AccountDots {
                        total: hero.pool.accounts
                        usable: hero.pool.usable
                    }
                }

                Item { implicitHeight: 2 }

                Repeater {
                    model: hero.windows
                    delegate: RowLayout {
                        id: line
                        required property var modelData
                        readonly property string lvl: hero.applet.levelFor(modelData.remaining)
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing * 2

                        PlasmaComponents.Label {
                            text: line.modelData.name
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            visible: line.modelData.extra !== ""
                            text: line.modelData.extra
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            color: Kirigami.Theme.disabledTextColor
                        }
                        PlasmaComponents.Label {
                            text: Math.round(line.modelData.remaining) + "%"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: line.lvl === "ok" ? Kirigami.Theme.textColor : hero.applet.toneFor(line.lvl)
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        }
                        PlasmaComponents.Label {
                            text: line.modelData.resetAt && line.modelData.remaining < 95 ? "↻ " + hero.applet.untilText(line.modelData.resetAt) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            color: Kirigami.Theme.disabledTextColor
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        }
                    }
                }
            }
        }

        AccountsList {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(Kirigami.Units.gridUnit * 4.6) + Kirigami.Units.gridUnit
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: hero.expanded
            applet: hero.applet
            pool: hero.pool
        }
    }
}
