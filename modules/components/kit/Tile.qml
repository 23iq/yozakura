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
// on hover. A vertical tile with `hasMore` marks its detail with a small
// caret in the top corner (also a click zone). The on fill cross-fades, the
// icon pops in on change; keyboard: Enter / Space toggle, Menu or
// Shift+Enter open the detail, the focus ring fades in. Height: controlM + l.
// Where the language lights LEDs (Look.ledIndicator) an active tile stays
// matte: an accent LED in its corner and an accent icon mark the state.
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
    readonly property bool filled: root.active && !Look.ledIndicator
    property color ink: root.filled ? Type.accentInk : Type.text
    property color quietInk: root.filled ? Qt.alpha(Type.accentInk, 0.78) : Type.secondary
    readonly property color glyphInk: root.active && !root.filled ? Type.accent : root.ink
    readonly property real moreW: root.hasMore && !root.vertical ? Space.controlS : 0
    readonly property real radius: Look.bigRadius(root.height)
    property real glyphScale: 1

    signal clicked
    signal more

    implicitWidth: root.vertical ? Space.controlL + Space.m : Space.controlL * 2 + Space.xl
    implicitHeight: Space.controlM + Space.l
    opacity: root.enabled ? 1 : 0.38
    scale: root.pressed ? 0.95 : 1
    activeFocusOnTab: root.enabled

    Keys.onPressed: event => {
        const more = event.key === Qt.Key_Menu || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier));
        if (more && root.hasMore) {
            root.more();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    // The icon pops in when it changes (state flips).
    onIconChanged: if (Motion.spring.duration > 0)
        pop.restart()

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
        }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.active

    Behavior on ink {
        enabled: Motion.micro.duration > 0
        ColorAnimation {
            duration: Motion.micro.duration
        }
    }

    Behavior on quietInk {
        enabled: Motion.micro.duration > 0
        ColorAnimation {
            duration: Motion.micro.duration
        }
    }

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
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
        }

        // Raised surface (under the accent, which fades over it).
        Rectangle {
            objectName: "tileRest"
            anchors.fill: parent
            radius: root.radius
            visible: tileOn.opacity < 1
            color: Look.raisedFill(root.hovered)
            border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
            border.color: Look.controlEdge
        }

        // Solid accent while on, cross-faded.
        StyledRect {
            id: tileOn
            objectName: "tileOn"
            anchors.fill: parent
            variant: "primary"
            enableBorder: false
            radius: root.radius
            opacity: root.filled ? 1 : 0
            visible: opacity > 0
            backgroundOpacity: root.hovered ? 0.9 : 1

            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
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
                color: root.glyphInk
                scale: root.glyphScale
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
                color: root.glyphInk
                scale: root.glyphScale
            }

            KitText {
                width: root.width - Space.hairline * 2
                anchors.horizontalCenter: parent.horizontalCenter
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
                color: root.filled ? Qt.alpha(Type.accentInk, 0.3) : Type.hairline
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

    SequentialAnimation {
        id: pop
        NumberAnimation {
            target: root
            property: "glyphScale"
            to: 0.7
            duration: Motion.micro.duration / 2
        }
        NumberAnimation {
            target: root
            property: "glyphScale"
            to: 1
            duration: Motion.spring.duration
            easing.type: Motion.spring.easing
            easing.overshoot: Motion.spring.overshoot
        }
    }

    // Vertical tiles: the detail caret in the top corner.
    Item {
        objectName: "tileCorner"
        visible: root.hasMore && root.vertical
        anchors.top: parent.top
        anchors.right: parent.right
        width: Space.l + Space.xs
        height: width

        Text {
            anchors.centerIn: parent
            text: Icons.caretRight
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption") - Space.hairline * 2
            color: cornerArea.containsMouse ? root.ink : root.quietInk
        }

        MouseArea {
            id: cornerArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.more()
        }
    }

    // The state LED (Look.ledIndicator): top left on a square tile, top
    // right (before the detail zone) on a wide one.
    Rectangle {
        objectName: "tileLed"
        visible: Look.ledIndicator
        x: root.vertical ? Space.s : root.width - root.moreW - Space.s - width
        y: Space.s
        width: Space.s + Space.xs
        height: Math.max(2, Space.xs - 1)
        radius: height / 2
        color: root.active ? Type.accent : Type.track

        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
            }
        }
    }

    FocusRing {
        radius: root.radius + Space.stroke
        shown: root.activeFocus
    }

    StyledToolTip {
        show: area.containsMouse && root.tooltipText !== ""
        tooltipText: root.tooltipText
    }
}
