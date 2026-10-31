import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.components.kit
import "PresetStatusModel.js" as PresetStatusModel

// Settings sidebar footer: the active preset and how far the live settings
// drifted from it ("Yozakura Night · 3 changes"), with the one primary
// action while there is something to keep: Save (into the user's own
// preset) or Save as new (a built-in is read-only), and a ⋯ menu (show
// changes, revert, save as new). Compact sidebar: a single icon button.
Item {
    id: root

    property bool compact: false
    readonly property var status: PresetStatusService.status
    readonly property string action: PresetStatusModel.primaryAction(status)
    readonly property bool shown: PresetStatusService.active !== ""

    // "save" | "saveAs" | "changes" | "revert" (SettingsShell.presetAction).
    signal actionRequested(string id)

    function choose(id) {
        root.actionRequested(id);
    }

    function captionText() {
        const kind = PresetStatusService.official ? I18n.t("presets.status.builtin") : I18n.t("presets.status.yours");
        if (PresetStatusService.inSession)
            return I18n.t("presets.status.session");
        const n = PresetStatusService.changed;
        return (n > 0 ? I18n.tn("presets.status.changes", n) : I18n.t("presets.status.in_sync")) + " · " + kind;
    }

    objectName: "presetStatusFooter"
    visible: shown
    implicitHeight: !shown ? 0 : (compact ? Space.controlM + Space.l * 2 : body.implicitHeight + Space.l * 2)

    Divider {
        width: parent.width
    }

    // Full sidebar: name + state, ⋯, and the primary action.
    Column {
        id: body
        visible: !root.compact
        x: Space.l + Space.s
        y: Space.l
        width: parent.width - x - Space.l
        spacing: Space.m

        Item {
            width: parent.width
            height: Math.max(texts.implicitHeight, more.height)

            Column {
                id: texts
                anchors.left: parent.left
                anchors.right: more.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                KitText {
                    width: parent.width
                    role: "label"
                    text: I18n.t("presets.status.label")
                }
                KitText {
                    objectName: "presetStatusName"
                    width: parent.width
                    role: "body"
                    text: PresetStatusService.active
                    elide: Text.ElideRight
                }
                KitText {
                    objectName: "presetStatusCaption"
                    width: parent.width
                    role: "caption"
                    text: root.captionText()
                    elide: Text.ElideRight
                }
            }

            IconButton {
                id: more
                objectName: "presetStatusMore"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.dotsThree
                onClicked: menu.open()

                PresetStatusMenu {
                    id: menu
                    x: more.width - width
                    onChosen: id => root.choose(id)
                }
            }
        }

        PillButton {
            objectName: "presetStatusSave"
            visible: root.action !== ""
            width: parent.width
            kind: "tonal"
            icon: root.action === "save" ? "check" : "plus"
            text: root.action === "save" ? I18n.t("presets.status.save") : I18n.t("presets.status.save_as")
            onClicked: root.choose(root.action)
        }
    }

    // Compact sidebar: the preset glyph (active while there are changes).
    IconButton {
        id: glyph
        visible: root.compact
        anchors.horizontalCenter: parent.horizontalCenter
        y: Space.l
        icon: Icons.magicWand
        active: PresetStatusService.dirty
        onClicked: compactMenu.open()

        PresetStatusMenu {
            id: compactMenu
            x: 0
            onChosen: id => root.choose(id)
        }
    }
}
