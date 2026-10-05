pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView

// Visible content of a history row: type icon / favicon with pin badge,
// the text (or the alias editor in alias mode) and the relative time.
RowLayout {
    id: content

    required property ClipboardTabBase tab
    required property var entry
    property bool isInDeleteMode: false
    property bool isInAliasMode: false
    property bool isExpanded: false
    property bool isSelected: false
    property string displayText: ""
    property color textColor

    anchors.rightMargin: content.isInDeleteMode || content.isInAliasMode ? 84 : 8
    height: 32
    spacing: 8

    Behavior on anchors.rightMargin {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    ClipboardItemIcon {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        Layout.alignment: Qt.AlignTop
        tab: content.tab
        entry: content.entry
        isInDeleteMode: content.isInDeleteMode
        isInAliasMode: content.isInAliasMode
        isExpanded: content.isExpanded
        isSelected: content.isSelected
    }

    Column {
        Layout.fillWidth: true
        spacing: 0

        Loader {
            width: parent.width
            sourceComponent: content.tab.aliasMode && content.entry.id === content.tab.itemToAlias ? aliasTextInput : normalText
        }

        Component {
            id: normalText
            Text {
                width: parent.width
                text: content.displayText
                color: content.textColor
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }

        Component {
            id: aliasTextInput
            TextField {
                id: aliasField
                text: content.tab.newAlias
                color: Colors.overSecondary
                selectionColor: Colors.overSecondary
                selectedTextColor: Colors.secondary
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                background: Rectangle {
                    color: "transparent"
                    border.width: 0
                }
                selectByMouse: true

                onTextChanged: {
                    content.tab.newAlias = text;
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        aliasField.forceActiveFocus();
                        aliasField.selectAll();
                    });
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        content.tab.confirmAliasItem();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        content.tab.cancelAliasMode();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        content.tab.aliasButtonIndex = 0;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        content.tab.aliasButtonIndex = 1;
                        event.accepted = true;
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: ClipboardView.relativeTime(content.entry.createdAt, new Date(), (key, n) => n === undefined ? I18n.t(key) : I18n.t(key, n))
            color: {
                if (content.isInDeleteMode) {
                    return Colors.overError;
                } else if (content.isExpanded) {
                    return Colors.overBackground;
                } else if (content.isSelected) {
                    return Styling.srItem("primary");
                } else {
                    return Colors.outline;
                }
            }
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            opacity: 0.8

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }
    }
}
