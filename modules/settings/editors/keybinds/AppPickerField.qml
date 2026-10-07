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

// The app of an "Open app" bind: shows the chosen app (icon + name) and
// opens a searchable list of the installed apps, the launcher's own index
// (AppSearch: most used first, fuzzy search). Picks a desktop id.
Column {
    id: root

    property string appId: ""
    signal picked(string id)

    property bool open: false
    property string query: ""

    readonly property var info: KeybindsStore.appInfo(appId)
    readonly property var apps: {
        const q = query.trim();
        if (q !== "")
            return AppSearch.fuzzyQuery(q).slice(0, 40);
        return AppSearch.getAllApps ? AppSearch.getAllApps() : [];
    }

    spacing: 6

    // A new "Open app" bind shows the list right away (without taking the
    // focus from the key recorder).
    Component.onCompleted: open = appId === ""

    function toggle() {
        open = !open;
        if (open) {
            query = "";
            filter.text = "";
            filter.forceActiveFocus();
        }
    }

    function choose(id) {
        open = false;
        picked(id);
    }

    Item {
        objectName: "appField"
        width: parent.width
        height: 38
        activeFocusOnTab: true
        Keys.onReturnPressed: root.toggle()
        Keys.onSpacePressed: root.toggle()

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Styling.radius(0), height / 2)
            color: Ui.alpha(Colors.overBackground, fieldArea.containsMouse ? 0.1 : 0.06)
            border.width: root.open || parent.activeFocus ? 2 : 1
            border.color: root.open || parent.activeFocus ? Colors.primary : (root.appId !== "" && !root.info ? Colors.error : Ui.alpha(Colors.outline, 0.35))
        }
        IconImage {
            id: appIcon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 20
            source: Quickshell.iconPath(root.info ? (root.info.icon || root.appId) : "", "application-x-executable")
            asynchronous: true
        }
        Text {
            anchors.left: appIcon.right
            anchors.leftMargin: 10
            anchors.right: caret.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.info ? root.info.name : (root.appId !== "" ? I18n.t("binds.app_missing", root.appId) : I18n.t("binds.app_choose"))
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: root.info ? Colors.overBackground : (root.appId !== "" ? Colors.error : Colors.outline)
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
            id: fieldArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    Rectangle {
        width: parent.width
        height: root.open ? 260 : 0
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
                easing.type: Motion.morph.easing
            }
        }

        Text {
            id: searchGlyph
            x: 14
            y: 10
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: Icons.search
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
        TextInput {
            id: filter
            objectName: "appFilter"
            anchors.left: searchGlyph.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 10
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
                const a = root.apps[Math.max(0, list.currentIndex)];
                if (a)
                    root.choose(a.id);
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: I18n.t("binds.app_search")
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
            model: root.apps
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Item {
                id: option
                required property var modelData
                required property int index
                objectName: "appOption:" + modelData.id
                width: list.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    radius: Styling.radius(-6)
                    color: option.modelData.id === root.appId ? Ui.alpha(Colors.primary, 0.18) : Ui.alpha(Colors.overBackground, optionArea.containsMouse || list.currentIndex === option.index ? 0.08 : 0)
                }
                IconImage {
                    id: optionIcon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 22
                    source: Quickshell.iconPath(option.modelData.icon || "", "application-x-executable")
                    asynchronous: true
                }
                Text {
                    anchors.left: optionIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.modelData.name
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
                    onClicked: root.choose(option.modelData.id)
                }
            }
        }
    }
}
