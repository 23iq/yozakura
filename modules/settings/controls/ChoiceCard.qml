import QtQuick
import qs.modules.theme
import qs.config
import "../Ui.js" as Ui

// Selectable card: a preview area (default children) above a caption.
// Used by every "pick one of these looks" editor.
Item {
    id: card

    property bool selected: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property real previewHeight: 96
    default property alias preview: previewArea.data
    signal clicked

    implicitWidth: 180
    implicitHeight: previewHeight + caption.implicitHeight + 22
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: selected

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Math.min(Styling.radius(4), 22)
        color: card.selected ? Ui.alpha(Colors.primary, 0.1) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : Ui.alpha(Colors.overBackground, 0.035))
        border.width: card.selected || card.activeFocus ? 2 : 1
        border.color: card.selected || card.activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.8)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    Item {
        id: previewArea
        x: 8
        y: 8
        width: parent.width - 16
        height: card.previewHeight
        clip: true
    }

    Row {
        id: caption
        x: 14
        anchors.top: previewArea.bottom
        anchors.topMargin: 8
        width: parent.width - 28
        spacing: 7

        Text {
            visible: card.icon !== ""
            anchors.verticalCenter: titleCol.verticalCenter
            text: Icons[card.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 14
            color: card.selected ? Colors.primary : Colors.overSurfaceVariant
        }
        Column {
            id: titleCol
            width: parent.width - (card.icon !== "" ? 21 : 0) - (card.selected ? 22 : 0)
            Text {
                width: parent.width
                text: card.title
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.overBackground
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: card.subtitle !== ""
                text: card.subtitle
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }

    // Check badge
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: caption.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: Colors.primary
        scale: card.selected ? 1 : 0
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutBack
            }
        }
        Text {
            anchors.centerIn: parent
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: 11
            color: Colors.overPrimary
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
