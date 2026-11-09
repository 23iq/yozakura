import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.components.kit
import "ExtrasUi.js" as Ui

// One app of the Apps & Extras catalog: icon in a soft tinted disc, name
// (up to two lines), two-line description (the failure reason on a failed
// card) and the state footer (CardFooter: select check, progress, retry).
// The whole card toggles the selection; hovering lifts it a little.
StyledRect {
    id: root

    property var entry: ({})
    property var status: null
    property var progress: null
    // "installed" | "selectable" | "installing" | "failed" | "unavailable"
    property string cardState: "selectable"
    property bool selected: false
    property color accent: Colors.primary
    signal toggled
    signal retry
    signal upgradeRetry
    signal showLog
    signal cancel

    readonly property bool selectable: root.cardState === "selectable"
    readonly property string failReason: (root.progress && root.progress.state === "failed" ? root.progress.reason : (root.status ? root.status.reason : "")) || "error"
    // installed, but a post action (app theming hook) failed
    readonly property string postError: root.progress && root.progress.state === "done" && root.progress.postError ? root.progress.postError : ""
    readonly property bool hovered: hover.hovered

    variant: "pane"
    radius: Look.radius("box")
    enableShadow: root.hovered && root.cardState !== "unavailable"
    implicitHeight: 160
    opacity: root.cardState === "unavailable" ? 0.55 : 1
    scale: root.hovered && root.cardState !== "unavailable" ? 1.02 : 1
    z: root.hovered ? 2 : 0
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.entry.name || ""
    Accessible.checked: root.selected

    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.exit.duration
            easing.type: Motion.morph.easing
        }
    }

    // Selection / hover outline and tint (drawn above the pane fill).
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        z: 10
        color: root.selected ? Ui.alpha(Type.accent, 0.08) : (root.cardState === "failed" ? Ui.alpha(Type.danger, 0.05) : "transparent")
        border.width: root.selected ? Space.stroke - 1 : Space.hairline
        border.color: {
            if (root.selected)
                return Type.accent;
            if (root.cardState === "failed")
                return Ui.alpha(Type.danger, 0.45);
            return Ui.alpha(Colors.outlineVariant, root.hovered ? 0.95 : 0.55);
        }
        Behavior on border.color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: root.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        enabled: root.selectable
        onTapped: root.toggled()
    }

    // The app's glyph on a soft disc tinted with its category hue.
    Rectangle {
        id: badge
        x: Space.l
        y: Space.l
        width: Space.controlM + Space.xs
        height: width
        radius: Look.radius("round", height)
        color: Ui.alpha(root.accent, 0.18)
        border.width: Space.hairline
        border.color: Ui.alpha(root.accent, 0.3)

        Icon {
            anchors.centerIn: parent
            icon: Icons[root.entry.icon] ?? Icons.packageBox
            role: "display"
            size: Math.round(badge.height * 0.5)
            color: root.accent
        }
    }

    KitText {
        objectName: "name"
        anchors.left: badge.right
        anchors.leftMargin: Space.m
        anchors.right: parent.right
        anchors.rightMargin: Space.l
        anchors.verticalCenter: badge.verticalCenter
        role: "title"
        text: root.entry.name || ""
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        lineHeight: 0.95
    }

    KitText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Space.l
        anchors.rightMargin: Space.l
        anchors.top: badge.bottom
        anchors.topMargin: Space.s
        objectName: "description"
        // a failed card says why instead
        text: root.cardState === "failed" ? I18n.t("extras.ui.reason." + root.failReason) : (root.postError !== "" ? I18n.t("extras.ui.post_failed") + ": " + root.postError : I18n.t("extras." + root.entry.id + ".desc"))
        role: "secondary"
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        color: root.cardState === "failed" || root.postError !== "" ? Type.danger : Type.secondary
    }

    CardFooter {
        objectName: "footer"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Space.l
        anchors.rightMargin: Space.l
        anchors.bottomMargin: Space.m
        cardState: root.cardState
        entry: root.entry
        status: root.status
        progress: root.progress
        accent: root.accent
        selected: root.selected
        hovered: root.hovered
        onToggled: root.toggled()
        onRetry: root.retry()
        onUpgradeRetry: root.upgradeRetry()
        onShowLog: root.showLog()
        onCancel: root.cancel()
    }
}
