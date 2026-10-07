import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
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
    readonly property bool hovered: hover.hovered

    variant: "pane"
    radius: Styling.radius(4)
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
            duration: Config.animDuration / 2
            easing.type: Motion.morph.easing
        }
    }

    // Selection / hover outline and tint (drawn above the pane fill).
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        z: 10
        color: root.selected ? Ui.alpha(Colors.primary, 0.08) : (root.cardState === "failed" ? Ui.alpha(Colors.error, 0.05) : "transparent")
        border.width: root.selected ? 1.5 : 1
        border.color: {
            if (root.selected)
                return Colors.primary;
            if (root.cardState === "failed")
                return Ui.alpha(Colors.error, 0.45);
            return Ui.alpha(Colors.outlineVariant, root.hovered ? 0.95 : 0.55);
        }
        Behavior on border.color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
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

    Rectangle {
        id: badge
        x: 16
        y: 16
        width: 46
        height: 46
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ui.alpha(root.accent, 0.26)
            }
            GradientStop {
                position: 1
                color: Ui.alpha(root.accent, 0.1)
            }
        }
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.3)

        Text {
            anchors.centerIn: parent
            text: Icons[root.entry.icon] ?? Icons.packageBox
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(5)
            color: root.accent
        }
    }

    Text {
        objectName: "name"
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: badge.verticalCenter
        text: root.entry.name || ""
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 0.95
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(1)
        font.weight: Font.Bold
        color: Colors.overBackground
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: badge.bottom
        anchors.topMargin: 10
        objectName: "description"
        // a failed card says why instead
        text: root.cardState === "failed" ? I18n.t("extras.ui.reason." + root.failReason) : I18n.t("extras." + root.entry.id + ".desc")
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: root.cardState === "failed" ? Colors.error : Colors.overSurfaceVariant
    }

    CardFooter {
        objectName: "footer"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14
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
