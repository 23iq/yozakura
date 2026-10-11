pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.signatures
import qs.modules.components.kit

// A segmented pill group (tabs, a few exclusive choices): segments of icon +
// label on one raised track (Look.raisedFill); the current one sits on a
// solid accent pill that slides between segments, with the brush
// signature behind it (theme.signatures.brushHighlight). `model`: an array
// of {name, icon, text}; each segment is named `name` (objectName) and has
// `text` / `active` / `clicked()`. `activated(index)` on click.
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    readonly property int count: Array.isArray(root.model) ? root.model.length : 0
    readonly property Item currentItem: segments.count > root.currentIndex && root.currentIndex >= 0 ? segments.itemAt(root.currentIndex) : null

    signal activated(int index)

    implicitWidth: row.implicitWidth + Space.xs * 2
    implicitHeight: Space.controlM

    Rectangle {
        objectName: "segmentTrack"
        anchors.fill: parent
        radius: Look.bigRadius(height)
        color: Look.raisedFill(false)
        border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
        border.color: Look.controlEdge
    }

    StyledRect {
        id: pill
        objectName: "segmentPill"
        visible: root.currentItem !== null
        variant: "primary"
        backgroundOpacity: 1
        enableBorder: false
        x: row.x + (root.currentItem ? root.currentItem.x : 0)
        y: Space.xs
        width: root.currentItem ? root.currentItem.width : 0
        height: root.height - Space.xs * 2
        radius: Look.bigRadius(height)

        BrushHighlight {
            spread: Space.xs
            strength: 0.45
        }

        Behavior on x {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
                easing.overshoot: Motion.morph.overshoot
            }
        }
        Behavior on width {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    Row {
        id: row
        x: Space.xs
        anchors.verticalCenter: parent.verticalCenter
        height: root.height - Space.xs * 2

        Repeater {
            id: segments
            model: root.model

            Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool active: seg.index === root.currentIndex
                readonly property string text: seg.modelData.text || ""
                readonly property color ink: seg.active ? Type.accentInk : (hover.containsMouse ? Type.text : Type.secondary)

                signal clicked

                objectName: seg.modelData.name || ""
                width: content.implicitWidth + Space.l * 2
                height: row.height
                Accessible.role: Accessible.PageTab
                Accessible.name: seg.text
                Accessible.selected: seg.active
                onClicked: root.activated(seg.index)

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: Space.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: seg.modelData.icon || ""
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("secondary")
                        color: seg.ink
                    }

                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        text: seg.text
                        color: seg.ink
                        font.weight: seg.active ? Font.DemiBold : Look.labelWeight
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.clicked()
                }
            }
        }
    }
}
