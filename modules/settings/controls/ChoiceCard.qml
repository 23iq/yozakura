import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit

// A picture card: one look to pick, shown as a picture (default children,
// clipped to the card's rounded corners) over a short title. Used by every
// "pick one of these looks" row. At rest the picture has a hairline edge;
// hovered it lifts a little and the edge firms up; `selected` rings it in
// the accent and the title takes the active weight and a check. Keyboard:
// Tab focus with the kit FocusRing, Space / Enter pick. The same in every
// visual language (the picture is the box). `subtitle` is a second caption
// line for the rare card whose picture cannot say it.
Item {
    id: card

    property bool selected: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property real previewHeight: 96
    default property alias preview: previewArea.data
    readonly property bool hovered: area.containsMouse
    readonly property real radius: Look.radius("control", Space.controlL)
    signal clicked

    implicitWidth: Space.px(180)
    implicitHeight: card.previewHeight + Space.s + caption.implicitHeight
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: selected

    Item {
        id: frame
        width: parent.width
        height: card.previewHeight
        y: card.hovered && !card.selected ? -Space.hairline * 2 : 0
        Behavior on y {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }

        Item {
            id: previewArea
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        Mark {
            id: mask
            anchors.fill: parent
            radius: card.radius
            visible: false
            layer.enabled: true
            layer.smooth: true
        }

        // The edge: a hairline at rest, the accent ring when selected.
        Mark {
            anchors.fill: parent
            anchors.margins: card.selected ? -Space.xs : 0
            radius: card.radius + (card.selected ? Space.xs : 0)
            color: "transparent"
            border.width: card.selected ? Space.stroke - 1 : Space.hairline
            border.color: card.selected ? Type.accent : (card.hovered ? Type.track : Type.hairline)
            Behavior on anchors.margins {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
        }

        FocusRing {
            shown: card.activeFocus
            anchors.margins: -Space.stroke * 2
            radius: card.radius + Space.stroke * 2
        }
    }

    Row {
        id: caption
        anchors.top: frame.bottom
        anchors.topMargin: Space.s
        x: Space.xs
        width: parent.width - Space.xs * 2
        spacing: Space.s

        Icon {
            id: lead
            visible: card.icon !== ""
            anchors.verticalCenter: titleCol.verticalCenter
            icon: Icons[card.icon] ?? ""
            role: "secondary"
            tone: card.selected ? "accent" : "secondary"
        }
        Column {
            id: titleCol
            width: parent.width - (lead.visible ? lead.width + parent.spacing : 0) - (check.visible ? check.width + parent.spacing : 0)
            KitText {
                width: parent.width
                role: "secondary"
                color: card.selected ? Type.text : Type.secondary
                font.weight: card.selected ? Look.activeLabelWeight : Look.labelWeight
                text: card.title
                elide: Text.ElideRight
            }
            KitText {
                width: parent.width
                visible: card.subtitle !== ""
                role: "caption"
                text: card.subtitle
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        Icon {
            id: check
            visible: card.selected
            anchors.verticalCenter: titleCol.verticalCenter
            icon: Icons.accept
            role: "secondary"
            tone: "accent"
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            card.forceActiveFocus();
            card.clicked();
        }
    }
}
