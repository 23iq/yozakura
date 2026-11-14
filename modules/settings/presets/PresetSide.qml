pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel

// The info panel beside the preset studio's stage, one left edge for all:
// the preset's name (the ⋯ of the rarer studio actions on its line: Mixer,
// Browse, Import), author and tags (outlined pills); the one primary action
// (Apply, or the quiet "In use" state); the secondary actions in one group
// (Try, Edit, Save the current look); the studio's setting (save changes
// into my preset) at the foot, beside the save action it is about.
Column {
    id: root

    property var shown: null
    property bool locked: false
    // the studio's setting (presets.js: general.autoSavePreset)
    property var autoSaveEntry: ({})

    signal action(string name, string id)
    signal openPreset(string name)
    signal saveRequested
    signal mixRequested
    signal importRequested
    signal browseRequested

    readonly property bool inUse: !!root.shown && !!root.shown.active

    spacing: Space.s

    // name, author, tags: on the rows' text edge
    // (no preset to show, the list still loading or failed: only what
    // works without one, never a nameless disabled Apply)
    Column {
        x: Look.rowInset
        width: parent.width - Look.rowInset
        spacing: Space.xs
        visible: !!root.shown

        Item {
            width: parent.width
            height: Math.max(name.implicitHeight, more.height)
            KitText {
                id: name
                objectName: "presetName"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - more.width - Space.s
                role: "title"
                text: root.shown ? root.shown.name : ""
                elide: Text.ElideRight
            }
            IconButton {
                id: more
                objectName: "presetMore"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.dotsThree
                tooltip: I18n.t("prefs.presets.more_actions")
                Accessible.name: I18n.t("prefs.presets.more_actions")
                onClicked: menu.open()

                PresetMoreMenu {
                    id: menu
                    items: [
                        {
                            "id": "mix",
                            "icon": "faders",
                            "text": I18n.t("prefs.presets.tab.mixer")
                        },
                        {
                            "id": "browse",
                            "icon": "squaresFour",
                            "text": I18n.t("prefs.presets.browse")
                        },
                        {
                            "id": "import",
                            "icon": "downloadSimple",
                            "text": I18n.t("prefs.presets.import")
                        }
                    ]
                    onChosen: id => id === "mix" ? root.mixRequested() : (id === "browse" ? root.browseRequested() : root.importRequested())
                }
            }
        }
        KitText {
            width: parent.width
            visible: text !== ""
            role: "secondary"
            text: root.shown && root.shown.author ? root.shown.author : ""
            elide: Text.ElideRight
        }
        Flow {
            objectName: "presetTags"
            width: parent.width
            visible: tags.count > 0
            topPadding: Space.xs
            spacing: Space.xs
            Repeater {
                id: tags
                model: root.shown ? (root.shown.tags || []).slice(0, 4) : []
                delegate: PresetTag {
                    required property string modelData
                    text: I18n.t(PresetModel.tagLabel(modelData))
                }
            }
        }
    }

    // the one primary action: apply it (or: it is the one in use, the
    // accent tint of an active state, not a disabled primary)
    Chip {
        objectName: "presetApply"
        visible: !!root.shown
        width: parent.width
        primary: !root.inUse
        active: root.inUse
        icon: root.inUse ? Icons.check : Icons.magicWand
        text: root.inUse ? I18n.t("prefs.presets.in_use") : I18n.t("prefs.presets.apply")
        enabled: !!root.shown && !root.inUse && !root.locked
        opacity: root.inUse || enabled ? 1 : 0.38
        Accessible.role: Accessible.Button
        onClicked: root.action(root.shown.name, "apply")
    }

    // the secondary actions, one group of rows on the text's edge: try it,
    // change it, save what is on screen now as a new preset
    Column {
        objectName: "presetSecondary"
        width: parent.width

        Repeater {
            model: [
                {
                    "id": "try",
                    "icon": "clock",
                    "text": I18n.t("prefs.presets.try", PresetStudio.trialSeconds),
                    "enabled": !!root.shown && !root.inUse && !root.locked
                },
                {
                    "id": "edit",
                    "icon": "pencil",
                    "text": I18n.t("prefs.presets.edit"),
                    "enabled": !!root.shown
                },
                {
                    "id": "save",
                    "icon": "plus",
                    "text": I18n.t("prefs.presets.save_current"),
                    "enabled": true
                }
            ].filter(a => !!root.shown || a.id === "save")
            delegate: ListRow {
                id: act
                required property var modelData
                objectName: act.modelData.id === "save" ? "saveCurrentLook" : (act.modelData.id === "try" ? "presetTry" : "presetEdit")
                width: parent ? parent.width : 0
                // compact: three actions, not a list of records
                height: Space.controlM
                enabled: act.modelData.enabled
                opacity: enabled ? 1 : 0.5
                title: act.modelData.text
                Accessible.role: Accessible.Button
                onClicked: {
                    if (act.modelData.id === "try")
                        root.action(root.shown.name, "try");
                    else if (act.modelData.id === "edit")
                        root.openPreset(root.shown.name);
                    else
                        root.saveRequested();
                }
                leading: Component {
                    Icon {
                        icon: Icons[act.modelData.icon] ?? ""
                        tone: "secondary"
                    }
                }
            }
        }
    }

    Divider {
        width: parent.width
    }
    SettingRow {
        objectName: "presetsAutoSave"
        width: parent.width
        dense: true
        entry: root.autoSaveEntry
    }
}
