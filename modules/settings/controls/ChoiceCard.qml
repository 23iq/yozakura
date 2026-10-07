import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// Selectable card: a preview area (default children) above a caption.
// Used by every "pick one of these looks" editor. At rest / hovered it is
// the language's control box (Look); `selected` is the kit's accent tint
// with an accent check (KitStates "active"). Keyboard focus shows the
// hover look.
StyledRect {
    id: card

    property bool selected: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property real previewHeight: 96
    default property alias preview: previewArea.data
    readonly property bool hovered: area.containsMouse || card.activeFocus
    signal clicked

    implicitWidth: 180
    implicitHeight: previewHeight + caption.implicitHeight + Space.s * 2 + Space.s
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    variant: card.selected ? "primary" : (card.hovered ? "focus" : "common")
    backgroundOpacity: card.selected ? (card.hovered ? Look.activeTint * 1.5 : Look.activeTint) : (Look.boxedControls ? 0 : -1)
    enableBorder: !card.selected && !Look.boxedControls
    radius: Look.chipRadius(height)

    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: selected

    ControlBox {
        shown: !card.selected
        radius: card.radius
        hovered: card.hovered
    }

    Item {
        id: previewArea
        x: Space.s
        y: Space.s
        width: parent.width - Space.s * 2
        height: card.previewHeight
        clip: true
    }

    Row {
        id: caption
        x: Space.m
        anchors.top: previewArea.bottom
        anchors.topMargin: Space.s
        width: parent.width - Space.m * 2
        spacing: Space.s

        Text {
            id: lead
            visible: card.icon !== ""
            anchors.verticalCenter: titleCol.verticalCenter
            text: Icons[card.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Type.iconSize("secondary")
            color: card.selected ? Type.accent : Type.secondary
        }
        Column {
            id: titleCol
            width: parent.width - (lead.visible ? lead.width + parent.spacing : 0) - (check.visible ? check.width + parent.spacing : 0)
            KitText {
                width: parent.width
                role: "secondary"
                color: Type.text
                font.weight: card.selected ? Look.activeLabelWeight : Look.labelWeight
                text: card.title
            }
            KitText {
                width: parent.width
                visible: card.subtitle !== ""
                role: "caption"
                text: card.subtitle
            }
        }
        Text {
            id: check
            visible: card.selected
            anchors.verticalCenter: titleCol.verticalCenter
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: Type.iconSize("secondary")
            color: Type.accent
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
