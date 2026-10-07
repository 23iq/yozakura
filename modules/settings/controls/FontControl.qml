pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import "../Ui.js" as Ui

// Font family picker (searchable list, each family drawn in itself) +
// size stepper + a live sample in the chosen font.
Item {
    id: root

    property string family: ""
    property int size: 14
    property bool monospace: false
    // Shown when no family is set (e.g. "keep the app's own font")
    property string placeholder: ""
    property string sizeUnit: "px"
    signal familyPicked(string family)
    signal sizeEdited(int size)

    implicitWidth: 480
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: Space.m

        Row {
            width: parent.width
            spacing: Space.s

            Item {
                id: pickButton
                width: parent.width - sizeStepper.width - parent.spacing
                height: Space.controlS
                activeFocusOnTab: true
                Keys.onReturnPressed: picker.open()
                Keys.onSpacePressed: picker.open()

                FieldBox {
                    anchors.fill: parent
                    hovered: buttonArea.containsMouse || pickButton.activeFocus
                    focused: picker.opened
                }
                KitText {
                    anchors.left: parent.left
                    anchors.leftMargin: Space.m
                    anchors.right: caret.left
                    anchors.rightMargin: Space.s
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    text: root.family !== "" ? root.family : root.placeholder
                    font.family: root.family !== "" ? root.family : Type.bodyFont
                    font.italic: root.family === ""
                    color: root.family !== "" ? Type.text : Type.muted
                }
                Text {
                    id: caret
                    anchors.right: parent.right
                    anchors.rightMargin: Space.m
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: Type.muted
                }
                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.opened ? picker.close() : picker.open()
                }
            }

            NumberControl {
                id: sizeStepper
                anchors.verticalCenter: parent.verticalCenter
                value: root.size
                from: 8
                to: 32
                unit: root.sizeUnit
                onChanged: v => root.sizeEdited(Math.round(v))
            }
        }

        // Live sample, in the language's control box.
        Item {
            width: parent.width
            height: sample.implicitHeight + Space.l * 2
            clip: true

            ControlBox {
                radius: Look.chipRadius(Space.chip)
            }

            Column {
                id: sample
                x: Space.l
                y: Space.l
                width: parent.width - Space.l * 2
                spacing: Space.xs

                Text {
                    visible: !root.monospace
                    width: parent.width
                    text: "夜桜 Yozakura"
                    font.family: root.family
                    font.pixelSize: root.size * 1.9
                    font.weight: Font.Bold
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
                Text {
                    visible: !root.monospace
                    width: parent.width
                    text: "The quick brown fox jumps over the lazy dog — 0123456789"
                    font.family: root.family
                    font.pixelSize: root.size
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: root.monospace
                    width: parent.width
                    textFormat: Text.StyledText
                    text: "<font color='" + Colors.tertiary + "'>fn</font> <font color='" + Colors.primary + "'>bloom</font>(petals: <font color='" + Colors.secondary + "'>u8</font>) -&gt; Sakura {<br>&nbsp;&nbsp;&nbsp;&nbsp;<font color='" + Colors.outline + "'>// 夜桜 0x2A != O0 il1 {}[]</font><br>}"
                    font.family: root.family
                    font.pixelSize: root.size
                    color: Colors.overBackground
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Popup {
        id: picker
        parent: pickButton
        y: pickButton.height + 6
        width: pickButton.width
        height: Math.min(360, list.contentHeight + 64)
        padding: 8
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string query: ""
        property bool monoOnly: root.monospace
        readonly property var families: {
            const q = query.trim().toLowerCase();
            const all = Qt.fontFamilies();
            return all.filter(f => (!monoOnly || Ui.looksMonospace(f)) && (q === "" || f.toLowerCase().indexOf(q) !== -1));
        }

        onOpened: {
            query = "";
            searchField.text = "";
            searchField.forceActiveFocus();
            const i = families.indexOf(root.family);
            if (i >= 0)
                list.positionViewAtIndex(i, ListView.Center);
        }

        background: Rectangle {
            radius: Math.min(Styling.radius(2), 18)
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Ui.alpha(Colors.outline, 0.4)
        }

        contentItem: Column {
            spacing: 6

            Row {
                width: parent.width
                spacing: 6

                TextInput {
                    id: searchField
                    width: parent.width - monoChip.width - 6
                    height: 36
                    leftPadding: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    onTextChanged: picker.query = text
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onReturnPressed: {
                        if (list.currentIndex >= 0 && list.currentIndex < picker.families.length) {
                            root.familyPicked(picker.families[list.currentIndex]);
                            picker.close();
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: height / 2
                        color: Ui.alpha(Colors.overBackground, 0.06)
                    }
                    Text {
                        anchors.fill: parent
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                        text: I18n.t("prefs.font.search")
                        font: searchField.font
                        color: Ui.alpha(Colors.overSurfaceVariant, 0.7)
                        visible: searchField.text === ""
                    }
                }

                Rectangle {
                    id: monoChip
                    width: monoText.implicitWidth + 24
                    height: 36
                    radius: height / 2
                    color: picker.monoOnly ? Colors.primary : Ui.alpha(Colors.overBackground, 0.06)
                    Text {
                        id: monoText
                        anchors.centerIn: parent
                        text: I18n.t("prefs.font.mono_only")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: picker.monoOnly ? Colors.overPrimary : Colors.overBackground
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.monoOnly = !picker.monoOnly
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: picker.height - 64
                clip: true
                model: picker.families
                cacheBuffer: 200
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                currentIndex: picker.families.indexOf(root.family)

                delegate: Item {
                    id: fontItem
                    required property string modelData
                    required property int index
                    width: list.width
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Math.min(Styling.radius(-2), 12)
                        color: fontItem.modelData === root.family ? Ui.alpha(Colors.primary, 0.18) : (rowArea.containsMouse || list.currentIndex === fontItem.index ? Ui.alpha(Colors.overBackground, 0.1) : "transparent")
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: check.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: fontItem.modelData
                        font.family: fontItem.modelData
                        font.pixelSize: Styling.fontSize(1)
                        color: Colors.overBackground
                        elide: Text.ElideRight
                    }
                    Text {
                        id: check
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: Colors.primary
                        visible: fontItem.modelData === root.family
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.familyPicked(fontItem.modelData);
                            picker.close();
                        }
                    }
                }
            }
        }
    }
}
