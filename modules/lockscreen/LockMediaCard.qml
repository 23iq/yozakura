import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.modules.components.kit

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
    readonly property int pad: Space.m
    readonly property int artSize: Space.controlXL - Space.m
    readonly property real radius: Space.clampRadius(Space.surfaceRadius + Space.s, root.implicitHeight)

    implicitWidth: Space.controlXL * 4 + Space.xl
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
        spacing: Space.l

        // Artwork
        Art {
            Layout.preferredWidth: root.artSize
            Layout.preferredHeight: root.artSize
            Layout.alignment: Qt.AlignVCenter
            source: root.artUrl
            icon: Icons.player
            radius: Space.clampRadius(Math.max(0, root.radius - root.pad), root.artSize)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            KitText {
                Layout.fillWidth: true
                role: "body"
                font.weight: Font.Medium
                text: root.title
                color: root.textColor
                maximumLineCount: 1
            }

            KitText {
                Layout.fillWidth: true
                role: "caption"
                text: root.artist
                color: root.textColor
                opacity: 0.62
                maximumLineCount: 1
                visible: text !== ""
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Space.xs

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
                    Layout.preferredWidth: Space.xs
                }

                // Accent spectrum from the shared cava service.
                NotchVisualizer {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Space.xl
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.visualizerEnabled && CavaService.available
                    configEnabled: root.visualizerEnabled
                    startColor: root.accent
                    endColor: root.spectrumEnd
                    barCount: 18
                    spacing: Space.stroke
                    centered: false
                    idleOpacity: 0.25
                    playing: root.playing
                    shown: root.visualizerShown
                }
            }

            Item {
                Layout.preferredHeight: Space.s
            }

            // Thin progress line
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Space.stroke
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
                        enabled: Motion.morph.duration > 0
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
