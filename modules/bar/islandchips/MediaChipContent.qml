import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.defaultview

// What the idle island shows of the playing media, as a compact chip:
// the album art (a music glyph while there is none), the title and, while
// playing, a mini visualizer (NotchVisualizer: CavaService only while on
// screen and playing). Vertical: the art alone with the visualizer under
// it. No player: the muted glyph. Used by the bar's media module and the
// corner pills.
Item {
    id: root

    property var player: MprisController.activePlayer
    property bool vertical: false
    // Cross size of the bar's modules, the module glyph and text sizes
    property real moduleSize: 32
    property real glyphSize: 16
    property int textSize: Type.size("body")
    property int textWeight: Font.Medium
    property string textFont: Type.bodyFont
    property color ink: Type.text
    property bool showTitle: true
    property bool visualizer: true
    // Off screen (hidden bar, fullscreen): the visualizer stops
    property bool shown: true

    readonly property bool hasPlayer: !!root.player
    readonly property bool playing: root.hasPlayer && root.player.isPlaying === true
    readonly property string title: root.hasPlayer ? (root.player.trackTitle || root.player.identity || "") : ""
    readonly property string artist: root.hasPlayer ? (root.player.trackArtist || "") : ""
    readonly property string artUrl: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
    readonly property bool titleShown: !root.vertical && root.showTitle && root.title !== ""
    readonly property bool barsShown: root.visualizer && root.hasPlayer
    readonly property real artSize: Math.round(Math.min(root.moduleSize - Space.s * 2, root.glyphSize * 1.5))
    readonly property real maxTitleWidth: root.moduleSize * 5

    implicitWidth: root.vertical ? root.moduleSize : content.implicitWidth
    implicitHeight: root.vertical ? content.implicitHeight : root.moduleSize

    Grid {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 3
        spacing: root.vertical ? Space.xs : Space.s
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Item {
            objectName: "mediaArt"
            width: root.artSize
            height: root.artSize

            Art {
                anchors.fill: parent
                visible: root.artUrl !== ""
                source: root.artUrl
                icon: Icons.musicNotes
                radius: Space.clampRadius(Space.smallRadius, root.artSize)
            }
            Text {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: Icons.musicNotes
                font.family: Icons.font
                font.pixelSize: root.glyphSize
                color: root.ink
                opacity: root.hasPlayer ? 1 : 0.5
            }
        }

        Text {
            objectName: "mediaTitle"
            visible: root.titleShown
            width: Math.min(implicitWidth, root.maxTitleWidth)
            text: root.title
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: root.textFont
            font.pixelSize: root.textSize
            font.weight: root.textWeight
            color: root.ink
            opacity: root.playing ? 1 : 0.7
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
        }

        NotchVisualizer {
            objectName: "mediaBars"
            visible: root.barsShown
            barCount: 4
            spacing: Math.max(1, Math.round(root.glyphSize / 8))
            preferredBarWidth: Math.max(2, Math.round(root.glyphSize / 6))
            width: implicitWidth
            height: Math.round(root.glyphSize * (root.vertical ? 0.6 : 0.85))
            configEnabled: root.visualizer
            playing: root.playing
            shown: root.shown
            idleOpacity: 0.4
        }
    }
}
