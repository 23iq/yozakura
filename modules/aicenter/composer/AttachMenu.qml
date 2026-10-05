pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// "+" menu: attach selection, clipboard, screen region, whole screen, a file
// or the active window as context.
Popup {
    id: root

    signal picked(string kind)

    padding: 6
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    readonly property var items: [
        {
            kind: "selection",
            icon: Icons.cursorText,
            label: I18n.t("ai.ctx_selection"),
            key: "S"
        },
        {
            kind: "clipboard",
            icon: Icons.clipboardText,
            label: I18n.t("ai.ctx_clipboard"),
            key: "V"
        },
        {
            kind: "region",
            icon: Icons.selection,
            label: I18n.t("ai.ctx_region"),
            key: "R"
        },
        {
            kind: "screen",
            icon: Icons.monitor,
            label: I18n.t("ai.ctx_screen"),
            key: ""
        },
        {
            kind: "file",
            icon: Icons.fileText,
            label: I18n.t("ai.ctx_file"),
            key: "O"
        },
        {
            kind: "window",
            icon: Icons.appWindow,
            label: I18n.t("ai.ctx_window"),
            key: "W"
        }
    ]

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(-2)
        enableShadow: true
    }

    contentItem: Column {
        spacing: 2
        Repeater {
            model: root.items
            delegate: StyledRect {
                id: entry
                required property var modelData
                width: 236
                height: 32
                radius: Styling.radius(-6)
                variant: hov.hovered ? "focus" : "transparent"
                HoverHandler {
                    id: hov
                }
                TapHandler {
                    onTapped: {
                        root.close();
                        root.picked(entry.modelData.kind);
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    Text {
                        text: entry.modelData.icon
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: Colors.primary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurface
                    }
                    Text {
                        visible: entry.modelData.key.length > 0
                        text: "Ctrl+Shift+" + entry.modelData.key
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-4)
                        color: Colors.outline
                    }
                }
            }
        }
    }
}
