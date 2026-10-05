pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/BindModel.js" as BindModel

// Action field: shows the current action; opens an inline, searchable list
// of every catalog action (KeybindActions.js) grouped like the cheatsheet,
// including "Run command" for custom commands.
Column {
    id: root

    property string actionId: ""
    signal picked(string id)

    property bool open: false
    property string query: ""

    readonly property var options: {
        KeybindsStore.revision;
        const all = KeybindsStore.actionOptions();
        const q = query.trim().toLowerCase();
        const hits = q === "" ? all : all.filter(o => (o.text + " " + o.label + " " + o.id + " " + I18n.t(BindModel.group(o.group).title)).toLowerCase().indexOf(q) !== -1);
        // Grouped in display order, keeping the catalog order inside a group.
        return BindModel.GROUPS.reduce((acc, g) => acc.concat(hits.filter(o => o.group === g.id)), []);
    }

    spacing: 6

    function toggle() {
        open = !open;
        if (open) {
            query = "";
            filter.text = "";
            filter.forceActiveFocus();
        }
    }

    Item {
        width: parent.width
        height: 38
        activeFocusOnTab: true
        Keys.onReturnPressed: root.toggle()
        Keys.onSpacePressed: root.toggle()

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Styling.radius(0), height / 2)
            color: Ui.alpha(Colors.overBackground, buttonArea.containsMouse ? 0.1 : 0.06)
            border.width: root.open || parent.activeFocus ? 2 : 1
            border.color: root.open || parent.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
        }
        Text {
            id: groupIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[BindModel.group(KeybindsStore.actionGroup(root.actionId)).icon] ?? ""
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.primary
        }
        Text {
            anchors.left: groupIcon.right
            anchors.leftMargin: 10
            anchors.right: caret.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: BindModel.actionLabel(root.actionId, KeybindsStore.tr)
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
        }
        Text {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.caretDown
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            rotation: root.open ? 180 : 0
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    Rectangle {
        width: parent.width
        height: root.open ? 300 : 0
        visible: height > 0
        clip: true
        radius: Styling.radius(-2)
        color: Ui.alpha(Colors.surfaceContainerHigh, 0.9)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        TextInput {
            id: filter
            objectName: "actionFilter"
            x: 14
            y: 10
            width: parent.width - 28
            height: 26
            verticalAlignment: TextInput.AlignVCenter
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
            clip: true
            onTextEdited: root.query = text
            Keys.onEscapePressed: root.open = false
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: {
                const o = root.options[Math.max(0, list.currentIndex)];
                if (o) {
                    root.picked(o.id);
                    root.open = false;
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: I18n.t("binds.action_search")
                font: parent.font
                color: Colors.outline
            }
        }

        ListView {
            id: list
            anchors.top: filter.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: parent.width
            clip: true
            model: root.options
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            section.property: "group"
            section.delegate: Text {
                required property string section
                leftPadding: 14
                topPadding: 8
                bottomPadding: 2
                text: I18n.t(BindModel.group(section).title).toUpperCase()
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: Colors.overSurfaceVariant
            }
            delegate: Item {
                id: option
                required property var modelData
                required property int index
                width: list.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    radius: Styling.radius(-6)
                    color: option.modelData.id === root.actionId ? Ui.alpha(Colors.primary, 0.18) : Ui.alpha(Colors.overBackground, optionArea.containsMouse || list.currentIndex === option.index ? 0.08 : 0)
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.modelData.text
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                }
                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.picked(option.modelData.id);
                        root.open = false;
                    }
                }
            }
        }
    }
}
