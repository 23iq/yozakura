import "../Ui.js" as Ui
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings
import qs.modules.theme

// Path field + "Browse" (zenity / kdialog file or folder chooser) + clear.
// `pathKind`: "file" or "dir"; `filter`: chooser name filter, e.g.
// "Audio | *.wav *.ogg *.oga *.mp3 *.flac". `edited(path)` on Enter, focus
// loss, pick or clear; "~" is expanded.
Item {
    id: root

    property string path: ""
    property string pathKind: "file"
    property string filter: ""
    property string placeholder: ""
    property bool clearable: true
    property string message: ""

    signal edited(string path)

    function expand(p) {
        const t = String(p || "").trim();
        if (t === "~" || t.indexOf("~/") === 0)
            return Quickshell.env("HOME") + t.substring(1);

        return t;
    }

    function submit(p) {
        const v = root.expand(p);
        if (v !== root.path)
            root.edited(v);
    }

    implicitWidth: 420
    implicitHeight: column.implicitHeight

    Process {
        id: chooser

        command: ["sh", "-c", "kind=\"$1\"; title=\"$2\"; filter=\"$3\"; if command -v zenity >/dev/null; then if [ \"$kind\" = dir ]; then exec zenity --file-selection --directory --title=\"$title\"; elif [ -n \"$filter\" ]; then exec zenity --file-selection --title=\"$title\" --file-filter=\"$filter\"; else exec zenity --file-selection --title=\"$title\"; fi; elif command -v kdialog >/dev/null; then if [ \"$kind\" = dir ]; then exec kdialog --getexistingdirectory \"$HOME\" --title \"$title\"; else exec kdialog --getopenfilename \"$HOME\" --title \"$title\"; fi; else exit 127; fi", "sh", root.pathKind, I18n.t(root.pathKind === "dir" ? "prefs.common.choose_folder" : "prefs.common.choose_file"), root.filter]
        onExited: code => {
            if (code === 127) {
                root.message = I18n.t("prefs.wall.no_chooser");
                field.input.forceActiveFocus();
            } else if (code === 0 && chooserOut.text.trim() !== "") {
                root.message = "";
                root.submit(chooserOut.text.trim());
            }
        }

        stdout: StdioCollector {
            id: chooserOut
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: Space.xs

        Row {
            width: parent.width
            spacing: Space.s

            TextControl {
                id: field

                width: parent.width - browse.width - (clear.visible ? clear.width + parent.spacing : 0) - parent.spacing
                text: root.path
                monospace: true
                placeholder: root.placeholder
                onEdited: t => {
                    return root.submit(t);
                }
            }

            PillButton {
                id: browse

                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                icon: root.pathKind === "dir" ? "folderOpen" : "file"
                text: I18n.t("prefs.wall.browse")
                onClicked: {
                    root.message = "";
                    chooser.running = true;
                }
            }

            IconButton {
                id: clear

                anchors.verticalCenter: parent.verticalCenter
                visible: root.clearable && root.path !== ""
                size: "s"
                icon: Icons.cancel
                onClicked: root.edited("")
                Accessible.name: I18n.t("prefs.common.clear")
            }
        }

        KitText {
            width: parent.width
            visible: root.message !== ""
            role: "caption"
            text: root.message
            wrapMode: Text.WordWrap
            color: Colors.error
        }
    }
}
