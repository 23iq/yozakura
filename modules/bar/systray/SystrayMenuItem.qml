pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One entry of a tray item's menu: a kit ListRow (check / radio mark or the
// entry's icon, its label, a caret for submenus) or a Divider.
Item {
    id: root

    property string textStr: ""

    // Labels may carry a ":/// " prefix from some SNI implementations
    readonly property string cleanText: {
        let t = textStr;
        if (!t)
            return "";
        t = String(t);
        if (t.startsWith(":/// "))
            t = t.substring(5);
        return t.trim();
    }

    property var iconSource: ""
    property bool isImageIcon: false
    property bool isSeparator: false
    property bool hasSubmenu: false
    property bool expanded: false
    property int depth: 0
    // 0 = None, 1 = CheckBox, 2 = RadioButton
    property int buttonType: 0
    // Qt.Unchecked = 0, Qt.PartiallyChecked = 1, Qt.Checked = 2
    property int checkState: 0
    readonly property bool checked: root.buttonType > 0 && root.checkState !== Qt.Unchecked

    signal clicked

    implicitWidth: 200
    implicitHeight: root.isSeparator ? Space.s * 2 + Space.hairline : Space.controlS

    Divider {
        visible: root.isSeparator && Look.dividers
        anchors.verticalCenter: parent.verticalCenter
        x: Space.s
        width: parent.width - Space.s * 2
    }

    ListRow {
        anchors.fill: parent
        anchors.leftMargin: root.depth * Space.m
        visible: !root.isSeparator
        enabled: !root.isSeparator
        title: root.cleanText
        onClicked: root.clicked()

        leading: root.buttonType > 0 || root.iconSource !== "" ? markComponent : null
        trailing: root.hasSubmenu ? caretComponent : null
    }

    Component {
        id: markComponent

        Item {
            implicitWidth: Type.iconSize("body")
            implicitHeight: implicitWidth

            // Check / radio: an accent mark when on, a quiet outline when off
            Text {
                anchors.centerIn: parent
                visible: root.buttonType > 0
                text: root.checked ? (root.buttonType === 2 ? Icons.circle : (root.checkState === Qt.PartiallyChecked ? Icons.minus : Icons.check)) : ""
                font.family: Icons.font
                font.pixelSize: Type.iconSize("secondary")
                color: Type.accent
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.buttonType > 0 && !root.checked
                width: Type.size("secondary")
                height: width
                radius: root.buttonType === 2 ? width / 2 : Space.smallRadius / 2
                color: "transparent"
                border.width: Space.hairline
                border.color: Type.muted
            }

            Text {
                anchors.centerIn: parent
                visible: root.buttonType === 0 && !root.isImageIcon && root.iconSource !== ""
                text: visible ? root.iconSource : ""
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: Type.secondary
            }

            Image {
                anchors.fill: parent
                visible: root.buttonType === 0 && root.isImageIcon
                source: visible ? root.iconSource : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
        }
    }

    Component {
        id: caretComponent

        Text {
            text: root.expanded ? Icons.caretDown : Icons.caretRight
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: Type.muted
        }
    }
}
