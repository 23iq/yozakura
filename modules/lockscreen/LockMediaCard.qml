import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.config

// Glass style now-playing card: artwork, title/artist, transport controls,
// a thin progress line and the shared cava spectrum.
LockMediaBase {
    id: root

    property color textColor: Colors.secondaryFixed
    property color accent: Colors.primaryFixedDim
    property color overAccent: Colors.overPrimaryFixed
    property color fill: Colors.shadow
    // Accent -> this colour across the spectrum.
    property color spectrumEnd: Colors.tertiaryFixedDim
    readonly property int pad: 14
    readonly property int artSize: 84
    readonly property real radius: Config.roundness > 0 ? Math.min(Styling.radius(10), 28) : 0

    implicitWidth: 440
    implicitHeight: artSize + pad * 2

    LockGlass {
        anchors.fill: parent
        radius: root.radius
        fill: root.fill
        ink: root.textColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 16

        // Artwork
        ClippingRectangle {
            Layout.preferredWidth: root.artSize
            Layout.preferredHeight: root.artSize
            Layout.alignment: Qt.AlignVCenter
            radius: Config.roundness > 0 ? Math.max(6, root.radius - root.pad) : 0
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)

            Image {
                id: art
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                        easing.type: Motion.enter.easing
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: Icons.player
                font.family: Icons.font
                font.pixelSize: 30
                color: root.textColor
                opacity: 0.6
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                textFormat: Text.PlainText
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.Bold
                color: root.textColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                text: root.artist
                textFormat: Text.PlainText
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: root.textColor
                opacity: 0.62
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text !== ""
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                LockMediaButton {
                    icon: Icons.previous
                    glyphColor: root.textColor
                    enabled: MprisController.canGoPrevious
                    onClicked: root.previous()
                }

                LockMediaButton {
                    icon: root.playing ? Icons.pause : Icons.play
                    filled: true
                    glyphColor: root.textColor
                    accent: root.accent
                    overAccent: root.overAccent
                    enabled: MprisController.canTogglePlaying
                    onClicked: root.toggle()
                }

                LockMediaButton {
                    icon: Icons.next
                    glyphColor: root.textColor
                    enabled: MprisController.canGoNext
                    onClicked: root.next()
                }

                Item {
                    Layout.preferredWidth: 6
                }

                // Accent spectrum from the shared cava service.
                NotchVisualizer {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.visualizerEnabled && CavaService.available
                    configEnabled: root.visualizerEnabled
                    startColor: root.accent
                    endColor: root.spectrumEnd
                    barCount: 18
                    spacing: 3
                    centered: false
                    idleOpacity: 0.25
                    playing: root.playing
                    shown: root.visualizerShown
                }
            }

            Item {
                Layout.preferredHeight: 8
            }

            // Thin progress line
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                visible: root.length > 0

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14)
                }
                Rectangle {
                    width: Math.max(height, parent.width * root.progress)
                    height: parent.height
                    radius: height / 2
                    color: root.accent

                    Behavior on width {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Motion.morph.duration
                            easing.type: Motion.morph.easing
                        }
                    }
                }
            }
        }
    }
}
