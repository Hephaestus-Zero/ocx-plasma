import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// Provider mark tinted to the theme text colour. The SVGs (from CodexBar) are white;
// MultiEffect colorization recolours them, so the mark follows light/dark themes.
Item {
    id: logo
    property string provider: ""
    readonly property var files: ({
        "anthropic": "claude", "openai": "codex", "google-antigravity": "antigravity",
        "devin": "devin", "command-code": "commandcode", "gemini": "gemini", "google": "gemini"
    })
    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: implicitWidth

    Image {
        id: img
        anchors.fill: parent
        source: logo.files[logo.provider] ? Qt.resolvedUrl("../icons/" + logo.files[logo.provider] + ".svg") : ""
        sourceSize: Qt.size(Math.ceil(logo.width * 2), Math.ceil(logo.height * 2))
        smooth: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        colorization: 1.0
        colorizationColor: Kirigami.Theme.textColor
        visible: img.status === Image.Ready
    }
    // Unknown provider: a monogram.
    Text {
        anchors.centerIn: parent
        visible: !logo.files[logo.provider]
        text: logo.provider.charAt(0).toUpperCase()
        color: Kirigami.Theme.textColor
        font.pixelSize: logo.height * 0.8
        font.weight: Font.DemiBold
    }
}
