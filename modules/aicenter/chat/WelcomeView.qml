pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Empty-conversation state: greeting and mode-specific suggestions.
ColumnLayout {
    id: root

    property string mode: "chat"
    signal suggestion(string text, string context)

    spacing: 14

    readonly property string userName: {
        const u = Quickshell.env("USER") || "";
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }
    readonly property string greeting: {
        const h = new Date().getHours();
        return I18n.t(h < 5 ? "ai.greet_night" : (h < 12 ? "ai.greet_morning" : (h < 18 ? "ai.greet_afternoon" : "ai.greet_evening")));
    }
    readonly property var suggestions: mode === "shell" ? [
        {
            icon: Icons.sun,
            text: I18n.t("ai.sug_light"),
            context: ""
        },
        {
            icon: Icons.wallpapers,
            text: I18n.t("ai.sug_wallpaper"),
            context: ""
        },
        {
            icon: Icons.bellSlash,
            text: I18n.t("ai.sug_dnd"),
            context: ""
        },
        {
            icon: Icons.appWindow,
            text: I18n.t("ai.sug_move_window"),
            context: ""
        }
    ] : [
        {
            icon: Icons.clipboardText,
            text: I18n.t("ai.sug_explain_clipboard"),
            context: "clipboard"
        },
        {
            icon: Icons.cursorText,
            text: I18n.t("ai.sug_summarize_selection"),
            context: "selection"
        },
        {
            icon: Icons.selection,
            text: I18n.t("ai.sug_region"),
            context: "region"
        },
        {
            icon: Icons.gitBranch,
            text: I18n.t("ai.sug_commit"),
            context: "clipboard"
        }
    ]

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.mode === "shell" ? Icons.command : Icons.sparkle
        font.family: Icons.font
        font.pixelSize: 34
        color: Colors.primary
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.greeting + (root.userName ? ", " + root.userName : "")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(10)
        font.weight: Font.Bold
        color: Colors.overBackground
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.width - 32
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.mode === "shell" ? I18n.t("ai.shell_hint") : I18n.t("ai.chat_hint")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.outline
    }
    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        spacing: 8
        Repeater {
            model: root.suggestions
            delegate: Chip {
                id: entry
                required property var modelData
                glyph: entry.modelData.icon
                label: entry.modelData.text
                maxLabelWidth: 300
                onClicked: root.suggestion(entry.modelData.text, entry.modelData.context)
            }
        }
    }
}
