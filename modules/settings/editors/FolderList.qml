pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../widgets/dashboard/wallpapers/WallpaperFolders.js" as WallFolders
import "../Ui.js" as Ui

// Wallpaper folders: the primary one (wallPath, wallpapers.json, applied
// immediately) and extra ones (desktop.wallpaperFolders, staged with the
// other shell settings). Folders come from a directory chooser (zenity or
// kdialog) or a typed path, validated with `test -d`.
Item {
    id: root

    property var entry
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string primary: WallFolders.normalize(SettingsStore.get("wallpaper.wallPath") || "")
    readonly property var extraList: (SettingsStore.get("desktop.wallpaperFolders") || []).map(p => WallFolders.normalize(p))
    readonly property var folders: WallFolders.effective(primary, extraList)
    readonly property var paths: manager ? (manager.wallpaperPaths || []) : []
    property string message: ""
    property bool messageIsError: false
    // "add" | "primary": what the chooser / validated path is for.
    property string pendingAction: "add"

    implicitHeight: column.implicitHeight

    function expand(path) {
        const p = String(path || "").trim();
        if (p === "~" || p.indexOf("~/") === 0)
            return Quickshell.env("HOME") + p.substring(1);
        return p;
    }

    function setExtras(list) {
        SettingsStore.set("desktop.wallpaperFolders", WallFolders.extras(primary, list));
    }

    function applyFolder(path, action) {
        const dir = WallFolders.normalize(expand(path));
        if (!dir)
            return;
        if (action === "primary") {
            const old = primary;
            SettingsStore.set("wallpaper.wallPath", dir);
            setExtras(extraList.filter(p => p !== dir).concat(old && old !== dir ? [old] : []));
            message = I18n.t("prefs.wall.folder_primary_set", dir);
        } else if (folders.indexOf(dir) !== -1) {
            message = I18n.t("prefs.wall.folder_exists");
        } else {
            setExtras(extraList.concat([dir]));
            message = I18n.t("prefs.wall.folder_added", dir);
        }
        messageIsError = false;
        pathInput.text = "";
    }

    function requestPath(path, action) {
        const dir = expand(path);
        if (!dir)
            return;
        pendingAction = action;
        validator.path = dir;
        validator.command = ["test", "-d", dir];
        validator.running = true;
    }

    function browse(action) {
        pendingAction = action;
        message = "";
        chooser.running = true;
    }

    Process {
        id: validator
        property string path: ""
        onExited: code => {
            if (code === 0)
                root.applyFolder(validator.path, root.pendingAction);
            else {
                root.message = I18n.t("prefs.wall.folder_invalid", validator.path);
                root.messageIsError = true;
            }
        }
    }

    Process {
        id: chooser
        command: ["sh", "-c", "if command -v zenity >/dev/null; then exec zenity --file-selection --directory --title=\"$1\"; elif command -v kdialog >/dev/null; then exec kdialog --getexistingdirectory \"$HOME\" --title \"$1\"; else exit 127; fi", "sh", I18n.t("prefs.wall.choose_folder")]
        stdout: StdioCollector {
            id: chooserOut
        }
        onExited: code => {
            if (code === 127) {
                root.message = I18n.t("prefs.wall.no_chooser");
                root.messageIsError = true;
                pathInput.input.forceActiveFocus();
            } else if (code === 0 && chooserOut.text.trim() !== "") {
                root.requestPath(chooserOut.text.trim(), root.pendingAction);
            }
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: root.folders

            delegate: Item {
                id: folderRow
                required property string modelData
                required property int index
                readonly property bool isPrimary: index === 0 && modelData === root.primary
                readonly property int count: WallFolders.countIn(root.paths, modelData)
                width: column.width
                height: 56

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(Styling.radius(2), 18)
                    color: Ui.alpha(Colors.overBackground, folderRow.isPrimary ? 0.07 : 0.045)
                    border.width: 1
                    border.color: folderRow.isPrimary ? Ui.alpha(Colors.primary, 0.45) : Ui.alpha(Colors.outlineVariant, 0.6)
                }
                Rectangle {
                    id: folderIcon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 12
                    color: folderRow.isPrimary ? Ui.alpha(Colors.primary, 0.18) : Ui.alpha(Colors.overBackground, 0.1)
                    Text {
                        anchors.centerIn: parent
                        text: Icons.folder
                        font.family: Icons.font
                        font.pixelSize: 17
                        color: folderRow.isPrimary ? Colors.primary : Colors.overSurfaceVariant
                    }
                }
                Column {
                    anchors.left: folderIcon.right
                    anchors.leftMargin: 12
                    anchors.right: actions.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: folderRow.modelData
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-2)
                        color: Colors.overBackground
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: (folderRow.isPrimary ? I18n.t("prefs.wall.primary") + " · " : "") + I18n.t("prefs.wall.folder_count", folderRow.count)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: folderRow.isPrimary ? Colors.primary : Colors.overSurfaceVariant
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    PillButton {
                        visible: folderRow.isPrimary
                        kind: "ghost"
                        icon: "edit"
                        text: I18n.t("prefs.wall.change")
                        onClicked: root.browse("primary")
                    }
                    PillButton {
                        visible: !folderRow.isPrimary
                        kind: "ghost"
                        text: I18n.t("prefs.wall.make_primary")
                        onClicked: root.applyFolder(folderRow.modelData, "primary")
                    }
                    PillButton {
                        visible: !folderRow.isPrimary
                        kind: "ghost"
                        icon: "trash"
                        text: ""
                        implicitWidth: 34
                        onClicked: root.setExtras(root.extraList.filter(p => p !== folderRow.modelData))
                    }
                }
            }
        }

        // Add a folder
        Row {
            width: parent.width
            spacing: 8

            TextControl {
                id: pathInput
                width: parent.width - browseBtn.width - addBtn.width - parent.spacing * 2
                height: 36
                monospace: true
                placeholder: I18n.t("prefs.wall.path_placeholder")
                invalid: root.messageIsError
                onEdited: t => {
                    if (t.trim() !== "")
                        root.requestPath(t, "add");
                }
            }
            PillButton {
                id: browseBtn
                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                icon: "folder"
                text: I18n.t("prefs.wall.browse")
                onClicked: root.browse("add")
            }
            PillButton {
                id: addBtn
                anchors.verticalCenter: parent.verticalCenter
                icon: "plus"
                text: I18n.t("common.add")
                enabled: pathInput.input.text.trim() !== ""
                onClicked: root.requestPath(pathInput.input.text, "add")
            }
        }

        Text {
            width: parent.width
            visible: root.message !== ""
            text: root.message
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: root.messageIsError ? Colors.error : Colors.overSurfaceVariant
        }
    }
}
