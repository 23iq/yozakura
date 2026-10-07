import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.components.kit

// The player badge keeps a stable place in the capsule; hover only changes tint.
Item {
    id: root
    required property var player
    property bool mediaExpanded: false
    // False while the island is slid off screen; stops the visualizer.
    property bool revealed: true
    readonly property bool selectorOpen: selector.isOpen
    readonly property bool selectorHovered: badgeHover.hovered

    AlbumBackdrop {
        anchors.fill: parent
        artwork: root.player?.trackArtUrl ?? ""
        strength: root.mediaExpanded ? 0 : 0.2
        Behavior on strength {
            NumberAnimation { duration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration)); easing.type: Motion.morph.easing }
        }
    }
    KitText {
        anchors.left: parent.left
        anchors.right: visualizerSlot.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 6
        text: root.player ? (root.player.trackTitle || I18n.t("player.unknown")) : (Config.notch.customText || "Yozakura")
        role: "body"
        font.weight: Look.activeLabelWeight
        horizontalAlignment: Text.AlignHCenter
    }
    // Mini spectrum beside the title; the slot only opens while playing and
    // clips the bars, so their motion never changes the capsule size.
    Item {
        id: visualizerSlot
        readonly property bool open: (Config.notch.visualizer ?? true) && (root.player?.isPlaying ?? false) && CavaService.available
        anchors.right: playerBadge.left
        anchors.rightMargin: open ? 6 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: open ? miniVisualizer.implicitWidth : 0
        height: miniVisualizer.height
        clip: true
        Behavior on width {
            NumberAnimation { duration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration)); easing.type: Motion.morph.easing }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration)); easing.type: Motion.morph.easing }
        }
        NotchVisualizer {
            id: miniVisualizer
            anchors.right: parent.right
            width: implicitWidth
            height: 14
            barCount: 5
            startColor: Type.secondary
            endColor: Type.secondary
            preferredBarWidth: 3
            spacing: 2
            playing: root.player?.isPlaying ?? false
            // The expanded card shows the wide spectrum instead.
            shown: root.revealed && !root.mediaExpanded
            opacity: root.mediaExpanded ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration)) }
            }
        }
    }
    Item {
        id: playerBadge
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.player ? 24 : 0
        height: 24
        visible: !!root.player
        Text {
            anchors.centerIn: parent
            text: /spotify/i.test((root.player?.dbusName ?? "") + (root.player?.identity ?? "") + (root.player?.desktopEntry ?? "")) ? Icons.spotify : Icons.player
            color: Type.secondary
            font.family: Icons.font
            font.pixelSize: Type.iconSize("title")
            opacity: badgeHover.hovered ? 1 : 0.65
            Behavior on opacity {
                NumberAnimation { duration: Math.min(Config.animDuration, 120) }
            }
        }
        HoverHandler { id: badgeHover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: selector.toggle()
        }
        ToolTip.visible: badgeHover.hovered
        ToolTip.delay: 700
        ToolTip.text: root.player?.identity || I18n.t("player.unknown_player")
    }
    MouseArea {
        anchors.left: parent.left
        anchors.right: playerBadge.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        enabled: !!root.player
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: selector.toggle()
    }
    BarPopup {
        id: selector
        anchorItem: root
        bar: ({ barPosition: Config.notchPosition })
        contentWidth: Math.max(220, root.width)
        contentHeight: players.implicitHeight + popupPadding * 2
        ColumnLayout {
            id: players
            anchors.fill: parent
            spacing: 4
            Repeater {
                model: MprisController.filteredPlayers
                delegate: StyledRect {
                    id: choice
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    variant: root.player === modelData ? "focus" : "common"
                    radius: Styling.radius(-4)
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: choice.modelData.identity || choice.modelData.trackTitle || I18n.t("player.unknown_player")
                        textFormat: Text.PlainText
                        color: choice.item
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.setActivePlayer(choice.modelData)
                    }
                }
            }
        }
    }
}
