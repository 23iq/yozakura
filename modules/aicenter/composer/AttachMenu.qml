pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config

// "+" menu: attach selection, clipboard, screen region, whole screen, a file
// or the active window as context.
Popup {
    id: root

    signal picked(string kind)

    padding: Space.s
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
        radius: Look.radius("control")
        enableShadow: true
    }

    contentItem: Column {
        spacing: Space.xs / 2
        Repeater {
            model: root.items
            delegate: StyledRect {
                id: entry
                required property var modelData
                width: 236
                height: 32
                radius: Look.radius("small")
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
                    anchors.leftMargin: Space.s
                    anchors.rightMargin: Space.s
                    spacing: Space.s
                    Icon {
                        role: "caption"
                        tone: "accent"
                        icon: entry.modelData.icon
                    }
                    KitText {
                        role: "secondary"
                        Layout.fillWidth: true
                        text: entry.modelData.label
                        color: Type.text
                    }
                    KitText {
                        role: "caption"
                        visible: entry.modelData.key.length > 0
                        text: "Ctrl+Shift+" + entry.modelData.key
                    }
                }
            }
        }
    }
}
