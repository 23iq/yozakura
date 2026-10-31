pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.notifications
import "StripLayout.js" as StripLayout
import "../ToastModel.js" as ToastModel

// The paper of one strip: a floating kit Surface (so each visual language
// draws it its own way) washed with one palette role, the material texture
// and a punched hole by the edge. Folded it shows the sender's art and the
// summary running along the strip; `open` (0..1) morphs it into the card
// (ToastCard: the full text and the actions). Sized by its parent (Strip).
Item {
    id: root

    property string edge: "top"
    property real open: 0
    property string material: "plain"
    property int seed: 0
    property bool hole: true
    property var notification: null
    property int extra: 0
    property bool critical: false
    property bool hovered: false
    property real foldedWidth: 0
    property real foldedHeight: 0
    property real cardWidth: 0
    readonly property real cardHeight: card.implicitHeight + 2 * root.pad
    readonly property int pad: Look.surfacePadding

    signal dismissRequested
    signal actionInvoked(string identifier)

    readonly property bool row: StripLayout.isRow(root.edge)
    readonly property bool far: root.edge === "bottom" || root.edge === "right"
    readonly property var zones: ({
            "hole": Space.l,
            "art": Space.l + Space.xs,
            "pad": Space.s
        })
    readonly property var folded: StripLayout.lanes(root.edge, root.foldedWidth, root.foldedHeight, root.zones)
    readonly property var current: StripLayout.lanes(root.edge, root.width, root.height, root.zones)
    // One palette role per strip (by its key): a loose, calm set of tones
    readonly property var roles: [Colors.primary, Colors.secondary, Colors.tertiary]
    readonly property color role: root.critical ? Colors.error : root.roles[root.seed % root.roles.length]
    readonly property color ink: root.critical ? Colors.overError : Type.text
    readonly property real radius: Space.clampRadius(StripLayout.lerp(Space.smallRadius, Space.surfaceRadius, root.open), Math.min(root.width, root.height))

    Surface {
        id: paper
        objectName: "stripPaper"
        anchors.fill: parent
        floating: true
        glassSurface: "popups"
        enableShadow: true
        padding: 0
        radius: root.radius
    }

    // The wash: the strip's role, held back (critical: the error container)
    Rectangle {
        objectName: "stripWash"
        anchors.fill: parent
        radius: root.radius
        color: root.role
        opacity: root.critical ? StripLayout.lerp(0.9, StripLayout.WASH, root.open) : StripLayout.lerp(StripLayout.WASH, StripLayout.WASH / 2, root.open)
    }

    StripTexture {
        x: root.far && !root.row ? root.width - width : 0
        y: root.far && root.row ? root.height - height : 0
        width: root.foldedWidth
        height: root.foldedHeight
        radius: Space.clampRadius(Space.smallRadius, Math.min(width, height))
        material: root.material
        seed: root.seed
        ink: root.ink
        accent: root.role
        opacity: 1 - root.open
    }

    // The punched hole the thread ends in
    Rectangle {
        objectName: "stripHole"
        visible: root.hole
        readonly property int size: Space.xs + Space.xs / 2
        x: root.current.hole.x - width / 2
        y: root.current.hole.y - height / 2
        width: size
        height: size
        radius: size / 2
        color: Type.placeholder
        border.width: Space.hairline
        border.color: root.critical ? Colors.error : Type.muted
    }

    // Folded: art + summary along the strip
    Item {
        id: foldedBox
        objectName: "stripFolded"
        anchors.fill: parent
        opacity: Math.max(0, 1 - root.open * 2.5)
        visible: opacity > 0

        Art {
            readonly property int size: root.zones.art
            x: root.folded.art.x - width / 2 + (root.far && !root.row ? root.width - root.foldedWidth : 0)
            y: root.folded.art.y - height / 2 + (root.far && root.row ? root.height - root.foldedHeight : 0)
            width: size
            height: size
            readonly property var pic: ToastModel.artOf(root.notification, name => Quickshell.iconPath(name, true))
            source: pic.source
            radius: width / 2
            icon: root.critical ? Icons.alert : Icons.bell
            placeholderText: ToastModel.initialOf(root.notification)
        }

        Column {
            id: lane
            readonly property real length: root.folded.lane.length
            width: lane.length
            x: root.folded.lane.x - width / 2 + (root.far && !root.row ? root.width - root.foldedWidth : 0)
            y: root.folded.lane.y - height / 2 + (root.far && root.row ? root.height - root.foldedHeight : 0)
            rotation: root.edge === "top" ? 90 : (root.edge === "bottom" ? 270 : 0)
            spacing: 0

            KitText {
                width: lane.length
                role: "body"
                font.weight: Font.DemiBold
                color: root.ink
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.notification ? (root.notification.summary || root.notification.appName || "") : ""
            }
            KitText {
                width: lane.length
                role: "caption"
                color: root.critical ? root.ink : Type.muted
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text !== ""
                text: root.notification ? ToastModel.caption(root.notification.appName, "", root.extra) : ""
            }
        }
    }

    // Open: the card, laid out at its full size and revealed by the morph
    Item {
        anchors.fill: parent
        clip: true
        opacity: Math.max(0, root.open * 2 - 1)
        visible: root.open > 0

        ToastCard {
            id: card
            objectName: "stripCard"
            x: root.pad
            y: root.far && root.row ? root.height - root.cardHeight + root.pad : root.pad
            width: root.cardWidth - 2 * root.pad
            notification: root.notification
            extra: root.extra
            hovered: root.hovered
            onDismissRequested: root.dismissRequested()
            onActionInvoked: identifier => root.actionInvoked(identifier)
        }
    }
}
