import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.components.kit

// The season on the bar (theme.weatherFx.seasonal): in spring a petal, in
// autumn a leaf, now and then drifts down onto the bar, rests a moment and
// slides off the nearer end (down the strip on a vertical bar). Colours are
// palette roles (the outline tone, tinted by an accent), never pink. One
// timer; with motion off a single piece rests on the bar.
Item {
    id: root

    property bool leaf: false
    property real strength: 1
    property bool animate: false
    property bool horizontal: true
    property int salt: 0
    property var rand: WeatherFx.rng(root.salt + 59)

    readonly property real size: Space.m + Space.xs * (root.strength > 1.2 ? 2 : 1)
    readonly property color tone: Qt.tint(Colors.outline, Qt.alpha(root.leaf ? Colors.secondary : Colors.tertiary, 0.4))

    function launch(): void {
        if (flight.running)
            return;
        const r = root.rand;
        const along = 0.15 + r() * 0.7;
        if (root.horizontal) {
            piece.restX = root.width * along - root.size / 2;
            piece.restY = (root.height - root.size) * (0.45 + r() * 0.2);
            piece.exitX = along < 0.5 ? -root.size * 2 : root.width + root.size;
            piece.exitY = piece.restY + root.size * 0.3;
        } else {
            piece.restX = (root.width - root.size) * (0.35 + r() * 0.3);
            piece.restY = root.height * along;
            piece.exitX = piece.restX + root.size * 0.4;
            piece.exitY = root.height + root.size * 2;
        }
        piece.spin = (r() - 0.5) * 120;
        flight.restart();
    }

    Component.onCompleted: {
        if (!root.animate) {
            // Motion off: one piece resting near the start of the strip
            piece.x = root.horizontal ? root.width * 0.3 : (root.width - root.size) / 2;
            piece.y = root.horizontal ? (root.height - root.size) / 2 : root.height * 0.3;
            piece.rotation = -24;
            piece.opacity = 1;
        }
    }

    Timer {
        objectName: "seasonalTimer"
        running: root.animate
        repeat: true
        interval: Math.round(WeatherFx.cadence("seasonal", 0) * 0.35)
        onTriggered: {
            interval = Math.round(WeatherFx.cadence("seasonal", 0) * (0.7 + root.rand() * 0.6));
            root.launch();
        }
    }

    SequentialAnimation {
        id: flight
        // Drift down onto the bar
        ParallelAnimation {
            NumberAnimation {
                target: piece
                property: "y"
                from: -root.size * 2
                to: piece.restY
                duration: WeatherFx.ms(1900)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: piece
                property: "x"
                from: piece.restX - root.size * 1.5
                to: piece.restX
                duration: WeatherFx.ms(1900)
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: piece
                property: "rotation"
                from: piece.spin - 70
                to: piece.spin
                duration: WeatherFx.ms(1900)
                easing.type: Easing.OutSine
            }
            NumberAnimation {
                target: piece
                property: "opacity"
                from: 0
                to: 1
                duration: WeatherFx.ms(500)
            }
        }
        PauseAnimation {
            duration: WeatherFx.ms(2600)
        }
        // Slide off the end
        ParallelAnimation {
            NumberAnimation {
                target: piece
                property: "x"
                to: piece.exitX
                duration: WeatherFx.ms(2800)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: piece
                property: "y"
                to: piece.exitY
                duration: WeatherFx.ms(2800)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: piece
                property: "rotation"
                to: piece.spin + (piece.exitX < piece.restX ? -140 : 140)
                duration: WeatherFx.ms(2800)
                easing.type: Easing.InQuad
            }
        }
        PropertyAction {
            target: piece
            property: "opacity"
            value: 0
        }
    }

    Shape {
        id: piece
        objectName: "seasonalPiece"
        property real restX: 0
        property real restY: 0
        property real exitX: 0
        property real exitY: 0
        property real spin: 0
        width: root.size
        height: root.size
        opacity: 0
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: Qt.alpha(root.tone, Math.min(1, 0.72 * root.strength))
            scale: Qt.size(root.size / 24, root.size / 24)
            PathSvg {
                // Petal with its notched tip, or a plain leaf
                path: root.leaf ? "M12 1.5 C18.5 6.5 19.5 15 12 21.5 C4.5 15 5.5 6.5 12 1.5 Z" : "M12 22 C6.5 19 4.5 12 7.5 5.5 L10.6 3.2 L12 5.4 L13.4 3.2 L16.5 5.5 C19.5 12 17.5 19 12 22 Z"
            }
        }
        // Midrib / highlight along the piece
        ShapePath {
            strokeWidth: 1
            strokeColor: Qt.alpha(WeatherFx.glint, Math.min(1, 0.3 * root.strength))
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            scale: Qt.size(root.size / 24, root.size / 24)
            PathSvg {
                path: root.leaf ? "M12 4 L12 23" : "M12 8 L12 18"
            }
        }
    }
}
