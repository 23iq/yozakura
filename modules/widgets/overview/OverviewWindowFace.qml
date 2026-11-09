import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.config

// What a window thumbnail of the overview draws (grid and scrolling): the
// live preview (performance.windowPreview), or a plain box with the app
// icon; the accent outline while hovered / a search match, the tertiary one
// on the selected match (`glow`: a soft ring around it); the app icon in a
// corner, a dot on XWayland windows and the title / class tooltip.
// Fills its parent; the parent owns position, drag and clicks.
Item {
    id: root

    property var toplevel: null
    property var windowData: null
    property string iconPath: ""
    property bool hovered: false
    property bool pressed: false
    property bool matched: false
    property bool selected: false
    property bool compact: false
    property bool glow: false
    property bool tooltipShown: false
    // Draw the plain box while the live preview has no frame yet (grid);
    // false keeps the preview layer alone (scrolling).
    property bool fallbackOnEmpty: true

    readonly property bool previewOn: Config.performance.windowPreview
    readonly property bool hasContent: preview.hasContent
    readonly property bool showFallback: !root.previewOn || (root.fallbackOnEmpty && !preview.hasContent)
    readonly property real boxRadius: Look.radius("small", Math.min(width, height))
    readonly property real ringWidth: root.selected ? Space.stroke : (root.matched || root.hovered ? Space.hairline * 2 : 0)
    readonly property color ringColor: root.selected ? Colors.tertiary : Type.accent

    anchors.fill: parent

    ClippingRectangle {
        anchors.fill: parent
        radius: root.boxRadius
        antialiasing: true
        color: "transparent"

        ScreencopyView {
            id: preview
            anchors.fill: parent
            captureSource: root.previewOn && GlobalStates.overviewOpen ? root.toplevel : null
            live: GlobalStates.overviewOpen
            visible: root.previewOn
        }
    }

    // The plain box without a preview
    Mark {
        anchors.fill: parent
        radius: root.boxRadius
        color: root.pressed ? Colors.surfaceBright : root.hovered ? Colors.surface : Colors.background
        border.color: root.ringColor
        border.width: root.ringWidth
        visible: root.showFallback

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
        Behavior on border.width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    Image {
        readonly property real iconSize: Math.round(Math.min(root.width, root.height) * (root.compact ? 0.6 : 0.35))
        anchors.centerIn: parent
        width: iconSize
        height: iconSize
        mipmap: true
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(iconSize, iconSize)
        asynchronous: true
        visible: root.showFallback
        z: 10
    }

    // Outline and press wash over the live preview
    Mark {
        anchors.fill: parent
        radius: root.boxRadius
        color: root.pressed ? Qt.alpha(Colors.surfaceContainerHighest, 0.5) : root.hovered ? Qt.alpha(Colors.surfaceContainer, 0.2) : "transparent"
        border.color: root.ringColor
        border.width: root.ringWidth
        visible: !root.showFallback && (root.fallbackOnEmpty || root.hovered || root.pressed || root.matched || root.selected)
        z: 5

        Behavior on border.width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    // Soft ring around the selected search match
    Mark {
        visible: root.glow
        anchors.fill: parent
        anchors.margins: -Space.xs
        radius: root.boxRadius + Space.xs
        color: "transparent"
        border.color: Colors.tertiary
        border.width: Space.hairline * 2
        opacity: 0.6
        z: -1
    }

    // App icon in the corner of a live preview
    Image {
        readonly property int iconSize: Type.iconSize("body")
        visible: root.hasContent && !root.compact && root.previewOn
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Space.xs
        width: iconSize
        height: iconSize
        mipmap: true
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(iconSize, iconSize)
        asynchronous: true
        opacity: 0.8
        z: 10
    }

    // XWayland indicator
    Mark {
        visible: !!(root.windowData && root.windowData.xwayland)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Space.xs / 2
        width: Space.xs + Space.xs / 2
        height: width
        color: Colors.error
        z: 10
    }

    StyledRect {
        visible: root.tooltipShown && !!root.windowData
        anchors.bottom: parent.top
        anchors.bottomMargin: Space.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltipText.implicitWidth + Space.l
        height: tooltipText.implicitHeight + Space.s
        variant: "popup"
        radius: Look.radius("small", height)
        z: 1000

        KitText {
            id: tooltipText
            anchors.centerIn: parent
            role: "caption"
            color: Type.text
            horizontalAlignment: Text.AlignHCenter
            text: {
                const w = root.windowData || {};
                return `${w.title || ""}\n[${w.class || ""}]${w.xwayland ? " [XWayland]" : ""}`;
            }
        }
    }
}
