pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.keyboard
import qs.config
import "../settings/Ui.js" as Ui
import "../services/KeyboardModel.js" as KeyboardModel

// Keyboard in the Displays step: the layouts as chips (remove, add from the
// searchable catalog), how to switch between them and a field to try it.
// Shows the layouts in effect (the compositor's own until Yozakura manages
// the keyboard) or the locale suggestion (wizard.choices.keyboardDraft,
// seeded by StepDisplays), which is only a draft: nothing is written or
// applied until the user confirms or edits it (KeyboardService.edit).
StyledRect {
    id: root

    property OnboardingState wizard
    property bool picking: false

    readonly property var draftCodes: wizard && wizard.choices.keyboardDraft ? wizard.choices.keyboardDraft : null
    readonly property var layouts: draftCodes ? draftCodes.map(c => ({
                "layout": c,
                "variant": ""
            })) : KeyboardService.effective.layouts
    readonly property int pad: Math.round(Styling.fontSize(0) * 1.2)
    readonly property var bindChoices: ["alt_shift", "super_space", "caps", "ctrl_shift"].map(b => ({
                "value": b,
                "label": I18n.t("prefs.keyboard.bind." + b)
            }))

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

    variant: "pane"
    enableShadow: false
    radius: Styling.radius(4)
    implicitHeight: column.implicitHeight + pad * 2

    Component.onCompleted: {
        KeyboardService.loadCatalog();
        KeyboardService.refreshCurrent();
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.55)
        z: 10
    }

    Column {
        id: column
        // edits build on the layouts shown: wait until they are known (the
        // note's takeover button stays usable when they cannot be read)
        enabled: KeyboardService.known
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: Math.round(Styling.fontSize(0) * 0.9)

        SectionLabel {
            width: parent.width
            icon: "keyboard"
            text: I18n.t("onboarding.keyboard.title")
            hint: I18n.t("onboarding.keyboard.desc")
        }

        UnmanagedNote {
            objectName: "unmanagedNote"
            width: parent.width
            visible: !root.draftCodes && Config.keyboardReady && !KeyboardService.managed
        }

        Row {
            objectName: "draftRow"
            enabled: !KeyboardService.unreadable
            visible: !!root.draftCodes
            width: parent.width
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - useDraft.width - parent.spacing
                text: I18n.t("onboarding.keyboard.suggested")
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
            NavButton {
                id: useDraft
                objectName: "useDraft"
                kind: "tonal"
                height: 36
                icon: "check"
                text: I18n.t("onboarding.keyboard.use")
                onClicked: root.setLayouts(root.layouts)
            }
        }

        Flow {
            id: chips
            objectName: "layoutChips"
            enabled: !KeyboardService.unreadable
            width: parent.width
            spacing: 8

            Repeater {
                model: root.layouts

                delegate: StyledRect {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool active: chip.index === KeyboardService.active.index && root.layouts.length > 1

                    objectName: "layoutChip:" + chip.modelData.layout
                    variant: chip.index === 0 ? "focus" : "common"
                    enableShadow: false
                    width: chipRow.implicitWidth + 16
                    height: 40
                    radius: height / 2

                    Row {
                        id: chipRow
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        LayoutBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 30
                            radius: 15
                            code: chip.modelData.layout
                            lit: chip.active
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.description(chip.modelData.layout)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                        Text {
                            objectName: "removeLayout"
                            visible: root.layouts.length > 1
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.cancel
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: removeArea.containsMouse ? Colors.error : Colors.overSurfaceVariant
                            MouseArea {
                                id: removeArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setLayouts(KeyboardModel.removeLayout(root.layouts, chip.index))
                            }
                        }
                    }
                }
            }

            NavButton {
                objectName: "addLayout"
                kind: root.picking ? "ghost" : "tonal"
                height: 40
                icon: root.picking ? "cancel" : "plus"
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
            x: -20
            width: parent.width + 40
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
            spacing: 12
            Text {
                id: switchLabel
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("prefs.keyboard.switch")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
            KeyChips {
                objectName: "switchChips"
                width: parent.width - switchLabel.width - parent.spacing
                options: root.bindChoices
                value: KeyboardService.effective.switchBind
                onSelected: bind => root.setBind(bind)
            }
        }

        TryTypingField {
            width: parent.width
        }
    }
}
