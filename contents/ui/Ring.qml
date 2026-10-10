import QtQuick
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Concentric remaining-quota rings: outer = short window (5 h / day), inner =
// long window (week / month / credits). The arc is what is LEFT. Mono by
// default; a ring turns amber/red only when its own window runs low.
Item {
    id: ring

    property real outer: NaN            // 0..100 remaining, NaN = no such window
    property real inner: NaN
    property color outerTone: Kirigami.Theme.textColor
    property color innerTone: Qt.alpha(Kirigami.Theme.textColor, 0.55)
    property int size: Kirigami.Units.gridUnit * 2
    property real stroke: Math.max(2, Math.round(size * 0.075))
    property real gap: Math.max(1.5, size * 0.04)
    property string centerText: ""
    property real centerScale: 0.30

    readonly property bool hasInner: !isNaN(inner)
    readonly property real r1: size / 2 - stroke / 2
    readonly property real r2: r1 - stroke - gap

    implicitWidth: size
    implicitHeight: size

    component Arc: ShapePath {
        id: arc
        property real radius
        property real value: NaN
        property bool track: false
        strokeWidth: ring.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: ring.size / 2; centerY: ring.size / 2
            radiusX: arc.radius; radiusY: arc.radius
            startAngle: -90
            sweepAngle: arc.track ? 360 : (isNaN(arc.value) ? 0 : 360 * Math.max(0, Math.min(100, arc.value)) / 100)
            Behavior on sweepAngle { NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.OutCubic } }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Arc { radius: ring.r1; track: true; strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.09) }
        Arc { radius: ring.r1; value: ring.outer; strokeColor: ring.outerTone }
        Arc { radius: ring.r2; track: true; strokeColor: ring.hasInner ? Qt.alpha(Kirigami.Theme.textColor, 0.07) : "transparent" }
        Arc { radius: ring.r2; value: ring.inner; strokeColor: ring.innerTone }
    }

    PlasmaComponents.Label {
        visible: ring.centerText !== ""
        anchors.centerIn: parent
        text: ring.centerText
        font.pixelSize: Math.max(8, Math.round(ring.size * ring.centerScale * (ring.centerText.length > 2 ? 0.82 : 1)))
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: Kirigami.Theme.textColor
    }
}
