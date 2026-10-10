pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// Click popup: pool rows in the user's order. Hover shows a grip on the right;
// drag it to reorder (saved to poolOrder, which also decides the panel rings).
// A click elsewhere on a row lists its accounts.
PlasmaExtras.Representation {
    id: full

    required property var applet

    // Drag state: index being moved, insertion slot (0..n), pointer offset.
    property int dragFrom: -1
    property int dropSlot: -1
    property real dragDy: 0

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    // Size to the content (no empty tail), capped so a long list scrolls.
    Layout.preferredHeight: Math.min(pad.implicitHeight + (header ? header.implicitHeight : 0) + 2,
                                     Kirigami.Units.gridUnit * 34)
    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Quotas")
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: full.applet.failure !== "" ? i18n("error")
                    : full.applet.snap && full.applet.snap.stale ? i18n("offline · %1", full.applet.ageText())
                    : full.applet.ageText()
                color: full.applet.failure !== "" ? Kirigami.Theme.negativeTextColor
                    : full.applet.snap && full.applet.snap.stale ? Kirigami.Theme.neutralTextColor
                    : Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh now")
                onClicked: full.applet.refresh(true)
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }
        }
    }

    PlasmaComponents.ScrollView {
        id: scroll
        anchors.fill: parent

        Item {
            id: pad
            readonly property real m: Kirigami.Units.gridUnit * 0.5
            width: scroll.availableWidth
            implicitHeight: list.implicitHeight + m * 2

            Column {
                id: list
                x: pad.m
                y: pad.m
                width: pad.width - pad.m * 2
                spacing: 2

                Repeater {
                    id: rows
                    objectName: "poolRows"
                    model: full.applet.pools

                    delegate: Item {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property bool dragging: full.dragFrom === index

                        readonly property bool isHero: index === 0
                        width: list.width
                        height: card.implicitHeight + (isHero ? Kirigami.Units.gridUnit * 1.6 : Kirigami.Units.largeSpacing * 1.8)
                                + (isHero ? Kirigami.Units.smallSpacing * 2 : 0)
                        z: dragging ? 10 : 0

                        // Hero: a soft card. Rows: hover/drag highlight only.
                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: slot.isHero ? Kirigami.Units.smallSpacing * 2 : 0
                            radius: Kirigami.Units.cornerRadius * 2
                            color: Qt.alpha(Kirigami.Theme.textColor,
                                slot.dragging ? 0.10 : slot.isHero ? (hover.hovered ? 0.075 : 0.05) : hover.hovered ? 0.045 : 0)
                            border.width: slot.isHero ? 1 : 0
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                            transform: Translate { y: slot.dragging ? full.dragDy : 0 }
                        }

                        Loader {
                            id: card
                            anchors.left: parent.left
                            anchors.right: grip.left
                            anchors.leftMargin: slot.isHero ? Kirigami.Units.gridUnit * 0.8 : Kirigami.Units.largeSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: slot.isHero ? -Kirigami.Units.smallSpacing : 0
                            sourceComponent: slot.isHero ? heroComp : rowComp
                            transform: Translate { y: slot.dragging ? full.dragDy : 0 }

                            Component {
                                id: heroComp
                                HeroCard { applet: full.applet; pool: slot.modelData; expandable: true }
                            }
                            Component {
                                id: rowComp
                                PoolRow { applet: full.applet; pool: slot.modelData; expandable: true }
                            }
                        }

                        HoverHandler { id: hover }

                        TapHandler {
                            onTapped: full.applet.toggleExpanded(slot.modelData.key)
                        }

                        // Grip: visible on hover, drag to reorder.
                        Kirigami.Icon {
                            id: grip
                            source: "drag-handle-symbolic"
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: slot.dragging ? 0.9 : hover.hovered ? 0.45 : 0
                            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                            transform: Translate { y: slot.dragging ? full.dragDy : 0 }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Kirigami.Units.smallSpacing * 2
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                preventStealing: true
                                property real startY: 0

                                onPressed: mouse => {
                                    startY = mapToItem(list, mouse.x, mouse.y).y;
                                    full.dragFrom = slot.index;
                                    full.dropSlot = slot.index;
                                    full.dragDy = 0;
                                }
                                onPositionChanged: mouse => {
                                    if (full.dragFrom < 0)
                                        return;
                                    const y = mapToItem(list, mouse.x, mouse.y).y;
                                    full.dragDy = y - startY;
                                    full.dropSlot = full.slotAt(y);
                                }
                                onReleased: full.finishDrag()
                                onCanceled: {
                                    full.dragFrom = -1;
                                    full.dropSlot = -1;
                                    full.dragDy = 0;
                                }
                            }
                        }
                    }
                }
            }

            // Insertion marker between rows while dragging.
            Rectangle {
                visible: full.dragFrom >= 0 && full.dropSlot >= 0
                    && full.dropSlot !== full.dragFrom && full.dropSlot !== full.dragFrom + 1
                x: list.x + Kirigami.Units.largeSpacing
                width: list.width - Kirigami.Units.largeSpacing * 2
                height: 2
                radius: 1
                color: Kirigami.Theme.highlightColor
                y: list.y + full.slotY(full.dropSlot) - 1
            }

            PlasmaComponents.Label {
                id: statusLabel
                visible: text !== ""
                anchors.top: list.bottom
                anchors.topMargin: Kirigami.Units.largeSpacing
                x: pad.m + Kirigami.Units.largeSpacing
                width: list.width - Kirigami.Units.largeSpacing * 2
                text: full.applet.failure !== "" ? full.applet.failure
                    : !full.applet.snap ? i18n("Loading…")
                    : full.applet.pools.length === 0
                        ? i18n("No accounts found. Add one with 'ocx account add', or unhide providers in the settings.")
                        : ""
                color: full.applet.failure !== "" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.Wrap
            }
        }
    }

    // Insertion slot for a y inside `list`: before the first row whose middle is below y.
    function slotAt(y) {
        for (let i = 0; i < rows.count; i++) {
            const it = rows.itemAt(i);
            if (it && y < it.y + it.height / 2)
                return i;
        }
        return rows.count;
    }

    function slotY(s) {
        if (s <= 0)
            return 0;
        const it = rows.itemAt(Math.min(s, rows.count) - 1);
        return it ? it.y + it.height + list.spacing / 2 : 0;
    }

    function finishDrag() {
        const from = full.dragFrom;
        let to = full.dropSlot;
        full.dragFrom = -1;
        full.dropSlot = -1;
        full.dragDy = 0;
        if (from < 0 || to < 0)
            return;
        if (to > from)
            to -= 1;
        full.applet.movePool(from, to);
    }
}
