import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Now playing on the composed dashboard, its one rich element: a pane tinted
// by the blurred artwork, the art, title, "artist · album", the shell's
// media timeline (PositionSlider) and prev / play / next, where only play
// carries the accent.
StyledRect {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(0)
    implicitHeight: row.implicitHeight + Metrics.padding * 1.5

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
        const mm = h > 0 && m < 10 ? "0" + m : "" + m;
        return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec;
    }

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // Artwork tint: the cover, blurred and faint, under everything.
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: tint.opacity > 0

        Image {
            id: blurSource
            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }

        MultiEffect {
            id: tint
            anchors.fill: parent
            source: blurSource
            blurEnabled: true
            blurMax: 64
            blur: 1
            opacity: root.artUrl !== "" && blurSource.status === Image.Ready ? 0.3 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Metrics.padding * 0.75
        spacing: Metrics.padding * 0.75

        ClippingRectangle {
            readonly property int side: Metrics.rowHeight + Metrics.padding
            Layout.preferredWidth: side
            Layout.preferredHeight: side
            radius: Styling.radius(-4)
            color: Qt.alpha(Colors.overBackground, 0.06)

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: Icons.musicNotes
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(8)
                color: Colors.outline
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                objectName: "title"
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player.trackTitle || root.player.identity || "") : I18n.t("player.nothing_playing")
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.Bold
                color: Colors.overBackground
            }

            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? [root.player.trackArtist, root.player.trackAlbum].filter(s => s && s !== "").join(" · ") : I18n.t("player.enjoy_silence")
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing
                visible: root.hasPlayer

                PositionSlider {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: Metrics.badgeHeight
                    player: root.player
                    useCustomColors: true
                    customProgressColor: Colors.overSurfaceVariant
                    customBackgroundColor: Qt.alpha(Colors.overBackground, 0.12)
                }

                Text {
                    text: root.formatTime(root.position) + " / " + (root.length > 0 ? root.formatTime(root.length) : "--:--")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.features: {
                        "tnum": 1
                    }
                    color: Colors.outline
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Metrics.spacing / 2

            HomeIconButton {
                icon: Icons.previous
                enabled: MprisController.canGoPrevious
                onClicked: MprisController.previous()
            }

            HomeIconButton {
                objectName: "playButton"
                icon: MprisController.isPlaying ? Icons.pause : Icons.play
                accent: true
                enabled: MprisController.canTogglePlaying
                onClicked: MprisController.togglePlaying()
            }

            HomeIconButton {
                icon: Icons.next
                enabled: MprisController.canGoNext
                onClicked: MprisController.next()
            }
        }
    }
}
