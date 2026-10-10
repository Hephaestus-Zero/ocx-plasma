import QtQuick
import org.kde.kirigami as Kirigami

// One dot per account: filled = usable now, hollow = limited/paused.
Row {
    id: dots
    property int total: 0
    property int usable: 0
    spacing: 3
    visible: total > 1
    Repeater {
        model: dots.total
        delegate: Rectangle {
            required property int index
            width: 5; height: 5; radius: 2.5
            anchors.verticalCenter: parent.verticalCenter
            color: index < dots.usable ? Qt.alpha(Kirigami.Theme.textColor, 0.85) : "transparent"
            border.width: index < dots.usable ? 0 : 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
        }
    }
}
