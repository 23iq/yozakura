import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// A chunky toggle tile (quick settings): an icon with a label and an
// optional state line. Off: a raised surface (Look.raisedFill); `active`:
// a solid accent fill with on-accent icon and text, the statement of a
// tile. `vertical` stacks the icon over the label (a square tile);
// otherwise the icon leads and, with `hasMore`, a caret zone at the end
// opens the feature's detail (`more()`, also right-click / press-and-hold).
// Presses spring back, hover lifts the tile a little; `tooltipText` shows
// on hover. Height: controlM + l.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string subtext: ""
    property bool active: false
    property bool hasMore: false
    property bool vertical: false
    // Vertical tiles: false leaves the icon alone (crowded rows; set a tooltip).
    property bool showLabel: true
    property bool highlighted: false
    property string tooltipText: ""
    readonly property bool hovered: area.containsMouse || moreArea.containsMouse || root.highlighted
    readonly property bool pressed: area.pressed || moreArea.pressed
    readonly property color ink: root.active ? Type.accentInk : Type.text
    readonly property color quietInk: root.active ? Qt.alpha(Type.accentInk, 0.78) : Type.secondary
    readonly property real moreW: root.hasMore && !root.vertical ? Space.controlS : 0

    signal clicked
    signal more

    implicitWidth: root.vertical ? Space.controlL + Space.m : Space.controlL * 2 + Space.xl
    implicitHeight: Space.controlM + Space.l
    opacity: root.enabled ? 1 : 0.38
    scale: root.pressed ? 0.95 : 1

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.active

    Behavior on scale {
        enabled: Motion.spring.duration > 0
        NumberAnimation {
            duration: Motion.spring.duration
            easing.type: Motion.spring.easing
            easing.overshoot: Motion.spring.overshoot
        }
    }

    Item {
        id: face
        anchors.fill: parent
        transform: Translate {
            y: root.hovered && !root.pressed ? -Space.hairline : 0
            Behavior on y {
                enabled: Motion.spring.duration > 0
                NumberAnimation {
                    duration: Motion.exit.duration / 2
                }
            }
        }

        // Raised surface while off.
        Rectangle {
            objectName: "tileRest"
            anchors.fill: parent
            radius: Look.bigRadius(root.height)
            visible: !root.active
            color: Look.raisedFill(root.hovered)
            border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
            border.color: Look.controlEdge
        }

        // Solid accent while on.
        StyledRect {
            objectName: "tileOn"
            anchors.fill: parent
            variant: "primary"
            enableBorder: false
            radius: Look.bigRadius(root.height)
            visible: root.active
            backgroundOpacity: root.hovered ? 0.9 : 1
        }

        // Row: icon, label + state, caret zone.
        Row {
            visible: !root.vertical
            x: Space.m
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Space.m - root.moreW - (root.moreW > 0 ? 0 : Space.m)
            spacing: Space.m

            Text {
                id: rowGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                font.family: Icons.font
                font.pixelSize: Type.iconSize("title")
                color: root.ink
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - rowGlyph.width - parent.spacing
                spacing: 0

                KitText {
                    width: parent.width
                    text: root.text
                    color: root.ink
                    font.weight: Font.DemiBold
                }

                KitText {
                    width: parent.width
                    visible: root.subtext !== ""
                    role: "caption"
                    color: root.quietInk
                    text: root.subtext
                }
            }
        }

        // Vertical: the icon over the label.
        Column {
            visible: root.vertical
            anchors.centerIn: parent
            width: parent.width - Space.xs * 2
            spacing: Space.xs

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.icon
                font.family: Icons.font
                font.pixelSize: Type.iconSize("title")
                color: root.ink
            }

            KitText {
                width: parent.width
                visible: root.showLabel
                horizontalAlignment: Text.AlignHCenter
                role: "caption"
                text: root.text
                color: root.ink
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.rightMargin: root.moreW
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            enabled: root.enabled
            pressAndHoldInterval: 600
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.more();
                else
                    root.clicked();
            }
            onPressAndHold: root.more()
        }

        // The detail zone: a caret behind a short divider.
        Item {
            objectName: "tileMore"
            visible: root.moreW > 0
            anchors.right: parent.right
            width: root.moreW
            height: parent.height

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Space.hairline
                height: parent.height * 0.44
                color: root.active ? Qt.alpha(Type.accentInk, 0.3) : Type.hairline
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -Space.hairline * 2
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: moreArea.containsMouse ? root.ink : root.quietInk
            }

            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more()
            }
        }
    }

    StyledToolTip {
        show: area.containsMouse && root.tooltipText !== ""
        tooltipText: root.tooltipText
    }
}
