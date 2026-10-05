pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// One preset in detail: thumbnail, info, actions and, aspect by aspect,
// what it sets differently from the defaults (or another preset), which
// presets share an aspect, and a jump into the settings page that edits
// it. For a user preset the jump starts an edit session, so the changes
// go into the preset; built-in presets are read-only (duplicate to edit).
Column {
    id: root

    required property string name
    readonly property var preset: PresetStudio.find(name)
    readonly property bool official: preset ? preset.official : true
    readonly property bool editingThis: PresetStudio.edit !== null && PresetStudio.edit.preset === name
    readonly property bool sessionElsewhere: (PresetStudio.edit !== null && !editingThis) || PresetStudio.trial !== null
    property string against: "defaults"
    property var inspection: null
    property bool loading: false
    property string error: ""

    signal back
    signal action(string id)

    spacing: 22

    function reload() {
        loading = true;
        PresetStudio.inspect(name, against, (ins, err) => {
            loading = false;
            inspection = ins;
            error = ins ? "" : err;
        });
    }

    function edit(category, section, entry) {
        const go = () => SettingsStore.navigate(category, section || "", entry || "");
        if (!editingThis)
            PresetStudio.beginEdit(name);
        go();
    }

    Component.onCompleted: reload()
    onAgainstChanged: reload()
    onNameChanged: reload()
    Connections {
        target: PresetStudio
        function onPresetsChanged() {
            if (root.preset)
                root.reload();
        }
    }

    PillButton {
        objectName: "presetBack"
        kind: "ghost"
        icon: "caretLeft"
        text: I18n.t("prefs.presets.back")
        onClicked: root.back()
    }

    // Header: thumbnail + info + actions
    Flow {
        width: parent.width
        spacing: 22

        ClippingRectangle {
            width: Math.min(root.width, Math.max(300, root.width * 0.44))
            height: Math.round(width * 9 / 16)
            radius: Math.min(Styling.radius(4), 20)
            color: Colors.surfaceContainerHigh
            border.width: root.preset && root.preset.active ? 2 : 1
            border.color: root.preset && root.preset.active ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.6)
            PresetThumb {
                anchors.fill: parent
                look: root.preset ? root.preset.look : null
            }
        }

        Column {
            width: Math.max(260, root.width - Math.min(root.width, Math.max(300, root.width * 0.44)) - 22)
            spacing: 10

            Row {
                spacing: 8
                Text {
                    text: root.name
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(8)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                PresetChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.preset && root.preset.active
                    tone: "primary"
                    icon: "checkCircle"
                    text: I18n.t("prefs.presets.badge.active")
                }
                PresetChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.official
                    icon: "lock"
                    text: I18n.t("prefs.presets.badge.builtin")
                }
            }
            Text {
                text: I18n.t("prefs.presets.by", root.preset && root.preset.author && root.preset.author !== "Unknown" ? root.preset.author : I18n.t("presets.unknown_author"))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
            Text {
                visible: root.official
                width: parent.width
                text: root.preset ? (root.preset.description || "") : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                wrapMode: Text.WordWrap
            }
            TextControl {
                visible: !root.official
                objectName: "presetDescription"
                width: parent.width
                text: root.preset ? (root.preset.description || "") : ""
                placeholder: I18n.t("prefs.presets.description.placeholder")
                onEdited: t => PresetStudio.setDescription(root.name, t)
            }
            Flow {
                width: parent.width
                spacing: 5
                Repeater {
                    model: root.preset ? root.preset.tags : []
                    PresetChip {
                        required property string modelData
                        text: I18n.t(PresetModel.tagLabel(modelData))
                    }
                }
            }
            Flow {
                width: parent.width
                spacing: 8
                PillButton {
                    objectName: "editorApply"
                    kind: "filled"
                    icon: "accept"
                    text: I18n.t("prefs.presets.apply")
                    enabled: !PresetStudio.trial && !PresetStudio.edit
                    onClicked: PresetStudio.apply(root.name)
                }
                PillButton {
                    icon: "timer"
                    text: I18n.t("prefs.presets.try", PresetStudio.trialSeconds)
                    visible: !(root.preset && root.preset.active)
                    enabled: !PresetStudio.trial && !PresetStudio.edit
                    onClicked: PresetStudio.tryPreset(root.name)
                }
                PillButton {
                    objectName: "editorEditLive"
                    visible: !root.official
                    icon: "pencil"
                    text: root.editingThis ? I18n.t("prefs.presets.editing_now") : I18n.t("prefs.presets.edit_live")
                    enabled: !root.sessionElsewhere && !root.editingThis
                    onClicked: root.edit("appearance", "", "")
                }
                PillButton {
                    icon: "copy"
                    text: root.official ? I18n.t("prefs.presets.duplicate_to_edit") : I18n.t("prefs.presets.duplicate")
                    kind: root.official ? "filled" : "tonal"
                    visible: !root.official || !(root.preset && root.preset.active)
                    onClicked: root.action("duplicate")
                }
                PillButton {
                    kind: "ghost"
                    icon: "arrowSquareOut"
                    text: I18n.t("prefs.presets.export")
                    onClicked: root.action("export")
                }
                PillButton {
                    visible: !root.official
                    kind: "ghost"
                    icon: "textAa"
                    text: I18n.t("prefs.presets.rename")
                    onClicked: root.action("rename")
                }
                PillButton {
                    visible: !root.official
                    kind: "ghost"
                    icon: "trash"
                    text: I18n.t("prefs.presets.delete")
                    enabled: !root.editingThis
                    onClicked: root.action("delete")
                }
            }
        }
    }

    // Built-in: read-only notice
    Rectangle {
        visible: root.official
        width: parent.width
        height: roRow.implicitHeight + 24
        radius: Math.min(Styling.radius(3), 18)
        color: Ui.alpha(Colors.tertiary, 0.1)
        border.width: 1
        border.color: Ui.alpha(Colors.tertiary, 0.35)
        Row {
            id: roRow
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.lock
                font.family: Icons.font
                font.pixelSize: 18
                color: Colors.tertiary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                text: I18n.t("prefs.presets.readonly")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                wrapMode: Text.WordWrap
            }
        }
    }

    // Comparison
    Row {
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("prefs.presets.compare_with")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        PresetPicker {
            objectName: "editorAgainst"
            width: 240
            value: root.against
            extra: [
                {
                    "value": "defaults",
                    "label": I18n.t("prefs.presets.defaults")
                }
            ]
            onPicked: v => root.against = v
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.inspection !== null
            text: root.inspection ? I18n.t("prefs.presets.total_changes", root.inspection.total) : ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }

    Text {
        visible: root.error !== ""
        width: parent.width
        text: root.error
        color: Colors.error
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        wrapMode: Text.WordWrap
    }

    // Aspects
    Column {
        width: parent.width
        spacing: 12
        opacity: root.loading ? 0.6 : 1

        Repeater {
            model: root.inspection ? root.inspection.aspects : []
            delegate: PresetAspectCard {
                width: parent.width
                official: root.official
                locked: root.sessionElsewhere
                against: root.against
                onEdit: (category, section, entry) => root.edit(category, section, entry)
            }
        }
    }
}
