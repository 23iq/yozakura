pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.keyboard
import qs.modules.components.kit
import qs.config
import "../services/KeyboardModel.js" as KeyboardModel

// Keyboard in the Displays step: the layouts as chips (remove, add from the
// searchable catalog), how to switch between them and a field to try it.
// Shows the layouts in effect (the compositor's own until Yozakura manages
// the keyboard) or the locale suggestion (wizard.choices.keyboardDraft,
// seeded by StepDisplays), which is only a draft: nothing is written or
// applied until the user confirms or edits it (KeyboardService.edit).
Group {
    id: root

    property OnboardingState wizard
    property bool picking: false

    readonly property var draftCodes: wizard && wizard.choices.keyboardDraft ? wizard.choices.keyboardDraft : null
    readonly property var layouts: draftCodes ? draftCodes.map(c => ({
                "layout": c,
                "variant": ""
            })) : KeyboardService.effective.layouts
    readonly property var bindChoices: ["alt_shift", "super_space", "caps", "ctrl_shift"]

    // Any edit commits what the card shows (a pending suggestion included).
    function commit(patch) {
        if (!Config.keyboardReady)
            return;
        if (root.draftCodes && patch.layouts === undefined)
            patch.layouts = root.layouts;
        KeyboardService.edit(patch);
        if (root.draftCodes)
            wizard.remember("keyboardDraft", null);
        if (patch.layouts !== undefined)
            wizard.remember("keyboard", patch.layouts.map(l => l.layout));
        if (patch.switchBind !== undefined)
            wizard.remember("switchBind", patch.switchBind);
    }

    function setLayouts(list) {
        root.commit({
            "layouts": list
        });
    }

    function setBind(bind) {
        root.commit({
            "switchBind": bind
        });
    }

    function description(code) {
        const info = KeyboardModel.layoutInfo(KeyboardService.catalog, code);
        return info ? info.description : code;
    }

    label: I18n.t("onboarding.keyboard.title")

    Component.onCompleted: {
        KeyboardService.loadCatalog();
        KeyboardService.refreshCurrent();
    }

    KitText {
        width: parent.width
        role: "secondary"
        wrapMode: Text.WordWrap
        text: I18n.t("onboarding.keyboard.desc")
    }

    UnmanagedNote {
        objectName: "unmanagedNote"
        width: parent.width
        visible: !root.draftCodes && Config.keyboardReady && !KeyboardService.managed
    }

    // edits build on the layouts shown: wait until they are known (the
    // note's takeover button stays usable when they cannot be read)
    Column {
        width: parent.width
        spacing: Space.m
        enabled: KeyboardService.known

        Row {
            objectName: "draftRow"
            enabled: !KeyboardService.unreadable
            visible: !!root.draftCodes
            width: parent.width
            spacing: Space.m
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - useDraft.width - parent.spacing
                role: "secondary"
                wrapMode: Text.WordWrap
                text: I18n.t("onboarding.keyboard.suggested")
            }
            FocusChip {
                id: useDraft
                objectName: "useDraft"
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.accept
                text: I18n.t("onboarding.keyboard.use")
                onClicked: root.setLayouts(root.layouts)
            }
        }

        Flow {
            objectName: "layoutChips"
            enabled: !KeyboardService.unreadable
            width: parent.width
            spacing: Space.s

            Repeater {
                model: root.layouts

                // A layout: its name (lit while in use) and a remove button.
                delegate: Row {
                    id: chip
                    required property var modelData
                    required property int index

                    objectName: "layoutChip:" + chip.modelData.layout
                    spacing: Space.xs

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.description(chip.modelData.layout)
                        active: chip.index === KeyboardService.active.index && root.layouts.length > 1
                    }
                    IconButton {
                        objectName: "removeLayout"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.layouts.length > 1
                        focusable: true
                        size: "s"
                        width: Space.chip
                        height: Space.chip
                        icon: Icons.cancel
                        onClicked: root.setLayouts(KeyboardModel.removeLayout(root.layouts, chip.index))
                    }
                }
            }

            FocusChip {
                objectName: "addLayout"
                icon: root.picking ? Icons.cancel : Icons.plus
                text: root.picking ? I18n.t("prefs.keyboard.close_picker") : I18n.t("prefs.keyboard.add")
                onClicked: {
                    root.picking = !root.picking;
                    if (root.picking)
                        picker.focusSearch();
                }
            }
        }

        LayoutPicker {
            id: picker
            objectName: "layoutPicker"
            enabled: !KeyboardService.unreadable
            width: parent.width
            visible: root.picking
            height: root.picking ? implicitHeight : 0
            catalog: KeyboardService.catalog
            skip: root.layouts.map(l => l.layout)
            onPicked: code => {
                root.picking = false;
                root.setLayouts(KeyboardModel.addLayout(root.layouts, code, ""));
            }
        }

        Row {
            visible: root.layouts.length > 1
            enabled: !KeyboardService.unreadable
            width: parent.width
            spacing: Space.m
            KitText {
                id: switchLabel
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: I18n.t("prefs.keyboard.switch")
            }
            Flow {
                objectName: "switchChips"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - switchLabel.width - parent.spacing
                spacing: Space.s
                Repeater {
                    model: root.bindChoices
                    delegate: FocusChip {
                        required property string modelData
                        text: I18n.t("prefs.keyboard.bind." + modelData)
                        active: KeyboardService.effective.switchBind === modelData
                        onClicked: root.setBind(modelData)
                    }
                }
            }
        }

        TryTypingField {
            width: parent.width
        }
    }
}
