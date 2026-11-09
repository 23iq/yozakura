pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/BindModel.js" as BindModel
import qs.modules.components.kit

// Action field: shows the current action ("Choose an action" while there is
// none); opens an inline, searchable list of every catalog action
// (KeybindActions.js) grouped like the cheatsheet, including "Run command"
// and "Open app". Typing also lists matching installed apps first: picking
// one is "Open app" with that app. Matching: BindModel.pickerOptions.
Column {
    id: root

    property string actionId: ""
    // Also offer the raw dispatcher (the editor's "Advanced" part).
    property bool withHidden: false
    // `args` is set for an app hit ({app: <desktop id>}), else null.
    signal picked(string id, var args)

    property bool open: false
    property string query: ""

    readonly property var options: {
        KeybindsStore.revision;
        const q = query.trim();
        const apps = q === "" ? [] : AppSearch.fuzzyQuery(q).slice(0, 5).map(a => ({
                    "id": "apps.launch",
                    "app": a.id,
                    "icon": a.icon || "",
                    "text": I18n.t("binds.open_app", a.name),
                    "group": "_apps"
                }));
        // Apps first, then grouped in display order, keeping the catalog
        // order inside a group.
        return BindModel.pickerOptions(KeybindsStore.actionOptions(root.withHidden), apps, q, KeybindsStore.tr);
    }

    spacing: Space.s

    function choose(o) {
        root.picked(o.id, o.app !== undefined ? {
            "app": o.app
        } : null);
        root.open = false;
    }

    function toggle() {
        if (open)
            open = false;
        else
            openList();
    }

    // Opens the list with an empty search, ready to type.
    function openList() {
        open = true;
        query = "";
        filter.text = "";
        list.currentIndex = 0;
        filter.forceActiveFocus();
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
        Icon {
            id: groupIcon
            role: "secondary"
            tone: "accent"
            anchors.left: parent.left
            anchors.leftMargin: Space.l
            anchors.verticalCenter: parent.verticalCenter
            icon: root.actionId === "" ? Icons.magnifyingGlass : (Icons[BindModel.group(KeybindsStore.actionGroup(root.actionId)).icon] ?? "")
        }
        KitText {
            role: "secondary"
            anchors.left: groupIcon.right
            anchors.leftMargin: Space.m
            anchors.right: caret.left
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            text: root.actionId === "" ? I18n.t("binds.choose_action") : BindModel.actionLabel(root.actionId, KeybindsStore.tr)
            elide: Text.ElideRight
            color: root.actionId === "" ? Colors.outline : Colors.overBackground
        }
        Icon {
            id: caret
            role: "caption"
            tone: "secondary"
            anchors.right: parent.right
            anchors.rightMargin: Space.l
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.caretDown
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
        radius: Look.radius("control")
        color: Ui.alpha(Colors.surfaceContainerHigh, 0.9)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
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
            onTextEdited: {
                root.query = text;
                list.currentIndex = 0;
            }
            Keys.onEscapePressed: root.open = false
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: {
                const o = root.options[Math.max(0, list.currentIndex)];
                if (o)
                    root.choose(o);
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: I18n.t("binds.action_search")
                font: parent.font
                color: Colors.outline
            }
        }

        KitText {
            objectName: "actionNone"
            role: "caption"
            anchors.horizontalCenter: parent.horizontalCenter
            y: filter.y + filter.height + 24
            width: parent.width - 28
            visible: root.options.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.t("binds.action_none", root.query.trim())
            color: Colors.overSurfaceVariant
        }

        ListView {
            id: list
            anchors.top: filter.bottom
            anchors.topMargin: Space.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Space.s
            width: parent.width
            clip: true
            model: root.options
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            section.property: "group"
            section.delegate: KitText {
                role: "caption"
                required property string section
                leftPadding: Space.l
                topPadding: Space.s
                bottomPadding: Space.xs / 2
                text: (section === "_apps" ? I18n.t("binds.apps_section") : I18n.t(BindModel.group(section).title)).toUpperCase()
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: Colors.overSurfaceVariant
            }
            delegate: Item {
                id: option
                required property var modelData
                required property int index
                objectName: "actionOption:" + (modelData.app !== undefined ? "app:" + modelData.app : modelData.id)
                width: list.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Space.s
                    anchors.rightMargin: Space.s
                    radius: Look.radius("small")
                    color: option.modelData.id === root.actionId && option.modelData.app === undefined ? Ui.alpha(Colors.primary, 0.18) : Ui.alpha(Colors.overBackground, optionArea.containsMouse || list.currentIndex === option.index ? 0.08 : 0)
                }
                IconImage {
                    id: optionIcon
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    visible: option.modelData.app !== undefined
                    implicitSize: visible ? 18 : 0
                    source: visible ? Quickshell.iconPath(option.modelData.icon || "", "application-x-executable") : ""
                    asynchronous: true
                }
                KitText {
                    role: "secondary"
                    anchors.left: optionIcon.right
                    anchors.leftMargin: optionIcon.visible ? 8 : 0
                    anchors.right: parent.right
                    anchors.rightMargin: Space.l
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.modelData.text
                    elide: Text.ElideRight
                    color: Colors.overBackground
                }
                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(option.modelData)
                }
            }
        }
    }
}
