pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Settings page (Configuration > General).
Kirigami.FormLayout {
    id: page

    property alias cfg_ocxCommand: ocxCommand.text
    property alias cfg_refreshSeconds: refreshSeconds.value
    property alias cfg_panelRings: panelRings.value
    property alias cfg_hiddenProviders: hiddenProviders.text
    property alias cfg_warnPercent: warnPercent.value
    property alias cfg_critPercent: critPercent.value

    QQC2.TextField {
        id: ocxCommand
        Kirigami.FormData.label: i18n("opencodex command:")
        placeholderText: "ocx"
    }

    QQC2.SpinBox {
        id: refreshSeconds
        Kirigami.FormData.label: i18n("Refresh interval (s):")
        from: 10
        to: 3600
        stepSize: 10
    }

    QQC2.SpinBox {
        id: panelRings
        Kirigami.FormData.label: i18n("Panel rings:")
        from: 1
        to: 6
    }

    QQC2.TextField {
        id: hiddenProviders
        Kirigami.FormData.label: i18n("Hidden providers:")
        placeholderText: "deepseek,kimi,openrouter"
    }
    QQC2.Label {
        text: i18n("Comma-separated provider ids. The defaults are API-key providers without a quota window.")
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    QQC2.SpinBox {
        id: warnPercent
        Kirigami.FormData.label: i18n("Warn below (%):")
        from: 1
        to: 100
    }

    QQC2.SpinBox {
        id: critPercent
        Kirigami.FormData.label: i18n("Critical below (%):")
        from: 0
        to: 100
    }
}
