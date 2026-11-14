pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.signatures
import qs.modules.components.kit

// A segmented pill group (tabs, a few exclusive choices): segments of icon +
// label on one raised track (Look.raisedFill); the current one sits on a
// solid accent pill that glides between segments, with the brush
// signature behind it (theme.signatures.brushHighlight). As `navigation`
// (a destination's tabs) the pill is neutral and raised: the accent marks
// values, not where you are. Segments are as wide as their label in the
// active weight, so nothing but the pill moves when the current one
// changes. `model`: an array of {name, icon, text}; each segment is named
// `name` (objectName) and has `text` / `active` / `clicked()`.
// `activated(index)` on click.
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    // tabs (a destination's pages), not a value: a neutral raised pill and
    // the text ink on the current one
    property bool navigation: false
    readonly property int count: Array.isArray(root.model) ? root.model.length : 0
    readonly property Item currentItem: segments.count > root.currentIndex && root.currentIndex >= 0 ? segments.itemAt(root.currentIndex) : null

    signal activated(int index)

    implicitWidth: row.implicitWidth + Space.xs * 2
    implicitHeight: Space.controlM

    // Keyboard: `focusable` takes Tab focus (ring around the track) and
    // Left / Right move to the neighbouring segment.
    property bool focusable: false
    activeFocusOnTab: root.focusable
    Keys.onLeftPressed: if (root.currentIndex > 0)
        root.activated(root.currentIndex - 1)
    Keys.onRightPressed: if (root.currentIndex < root.count - 1)
        root.activated(root.currentIndex + 1)

    Rectangle {
        objectName: "segmentTrack"
        anchors.fill: parent
        radius: Look.bigRadius(height)
        color: Look.raisedFill(false)
        border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
        border.color: Look.controlEdge

        FocusRing {
            shown: root.activeFocus
            radius: parent.radius + Space.stroke
        }
    }

    // Where the current segment is: the pill glides there (off until the
    // first layout, so nothing slides in from the start).
    Item {
        id: pill
        objectName: "segmentPill"
        property bool ready: false
        Timer {
            running: true
            interval: 0
            onTriggered: pill.ready = true
        }
        visible: root.currentItem !== null
        x: row.x + (root.currentItem ? root.currentItem.x : 0)
        y: Space.xs
        width: root.currentItem ? root.currentItem.width : 0
        height: root.height - Space.xs * 2

        Behavior on x {
            enabled: pill.ready && Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Behavior on width {
            enabled: pill.ready && Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        // a value: the solid accent pill with the brush signature
        StyledRect {
            anchors.fill: parent
            visible: !root.navigation
            variant: "primary"
            backgroundOpacity: 1
            enableBorder: false
            radius: Look.bigRadius(height)

            BrushHighlight {
                spread: Space.xs
                strength: 0.45
            }
        }
        // navigation: neutral and raised
        Rectangle {
            objectName: "segmentNavPill"
            anchors.fill: parent
            visible: root.navigation
            radius: Look.bigRadius(height)
            color: Qt.tint(Look.raisedFill(true), Qt.alpha(Type.text, 0.1))
            border.width: Space.hairline
            border.color: Type.hairline
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
                readonly property color ink: seg.active ? (root.navigation ? Type.text : Type.accentInk) : (hover.containsMouse ? Type.text : Type.secondary)

                signal clicked

                objectName: seg.modelData.name || ""
                // the label's room in its active weight, whichever is current
                width: content.implicitWidth - label.implicitWidth + Math.max(label.implicitWidth, boldProbe.implicitWidth) + Space.l * 2
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
                        Behavior on color {
                            enabled: Motion.micro.duration > 0
                            ColorAnimation {
                                duration: Motion.micro.duration
                            }
                        }
                    }

                    KitText {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        text: seg.text
                        color: seg.ink
                        font.weight: seg.active ? Font.DemiBold : Look.labelWeight
                        Behavior on color {
                            enabled: Motion.micro.duration > 0
                            ColorAnimation {
                                duration: Motion.micro.duration
                            }
                        }
                    }
                }

                // the label in the active weight, measured, never drawn
                KitText {
                    id: boldProbe
                    visible: false
                    role: "secondary"
                    text: seg.text
                    font.weight: Font.DemiBold
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
