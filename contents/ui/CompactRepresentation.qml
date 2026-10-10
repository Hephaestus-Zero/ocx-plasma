pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Panel: one ring per pinned pool (the first `panelRings` in the user's order).
// Monochrome until a pool runs low; a small dot marks a critical pool off-panel.
MouseArea {
    id: compact

    required property var applet

    readonly property real ringSize: Math.max(Kirigami.Units.iconSizes.small,
        Math.min(parent ? parent.height : 24, parent ? parent.width : 24) * 0.72)
    readonly property bool hiddenCritical: applet.pools.slice(applet.panelPools.length).some(p => p.level === "crit")

    Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    hoverEnabled: true
    onClicked: applet.expanded = !applet.expanded

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 1.5

        Repeater {
            model: compact.applet.panelPools
            delegate: Ring {
                required property var modelData
                readonly property var rr: compact.applet.ringsOf(modelData)
                readonly property var rem: compact.applet.worstRemaining(modelData)
                size: Math.round(compact.ringSize)
                stroke: Math.max(2, Math.round(size * 0.09))
                gap: 1.5
                outer: rr.outer
                inner: rr.inner
                outerTone: compact.applet.ringTone(rr.outer, false)
                innerTone: compact.applet.ringTone(rr.inner, true)
                centerText: rem === null ? "–" : Math.round(rem)
                centerScale: rr.inner === rr.inner ? 0.30 : 0.34
            }
        }

        Rectangle {
            visible: compact.hiddenCritical
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 5
            Layout.preferredHeight: 5
            radius: 2.5
            color: Kirigami.Theme.negativeTextColor
        }
    }
}
