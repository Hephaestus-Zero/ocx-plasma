pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Hover card: every visible pool in the user's order, no interaction.
Item {
    id: tip

    required property var applet

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: tip.applet.pools
            delegate: Loader {
                id: entry
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.bottomMargin: index === 0 ? Kirigami.Units.smallSpacing : 0
                sourceComponent: index === 0 ? heroC : rowC
                Component { id: heroC; HeroCard { applet: tip.applet; pool: entry.modelData } }
                Component { id: rowC; PoolRow { applet: tip.applet; pool: entry.modelData } }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tip.applet.failure !== "" ? tip.applet.failure
                : tip.applet.snap ? (tip.applet.snap.stale ? i18n("offline · %1", tip.applet.ageText()) : tip.applet.ageText())
                : i18n("loading…")
            color: tip.applet.failure !== "" ? Kirigami.Theme.negativeTextColor
                : tip.applet.snap && tip.applet.snap.stale ? Kirigami.Theme.neutralTextColor
                : Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            horizontalAlignment: Text.AlignRight
        }
    }
}
