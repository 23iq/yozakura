import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import "ModsModel.js" as ModsModel

// One field a mod declares in its manifest: boolean (switch), enum
// (choices), string / integer / number (text + Save). Values are written
// through ModsService.setSetting; a number that does not parse is
// reported instead of saved.
ColumnLayout {
    id: field

    required property var spec
    required property string modId

    readonly property var value: ModsService.settingsValues[field.spec.key]
    readonly property bool idle: !ModsService.busy && !ModsService.settingsBusy
    readonly property bool textual: ModsModel.isTextSetting(field.spec.type)

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing - 4

    function save(value) {
        ModsService.setSetting(field.modId, field.spec.key, value);
    }

    function saveText(text) {
        const parsed = ModsModel.parseSettingValue(field.spec.type, text);
        if (!parsed.ok) {
            ModsService.errorMessage = I18n.t("mods.invalid_number");
            return;
        }
        field.save(parsed.value);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: field.spec.label ?? field.spec.key
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Colors.overBackground
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: (field.spec.description ?? "") !== ""
                text: field.spec.description ?? ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                wrapMode: Text.Wrap
            }
        }

        ToggleControl {
            visible: field.spec.type === "boolean"
            checked: !!field.value
            enabled: field.idle
            Accessible.name: field.spec.label ?? field.spec.key
            onToggled: v => field.save(v)
        }
    }

    // Enum: every option as a chip; a value outside the options shows as
    // its raw text (or "Select") above them.
    Text {
        visible: field.spec.type === "enum" && ModsModel.enumLabel(field.spec.options, field.value) === null
        text: field.value === undefined || field.value === null ? I18n.t("mods.select") : String(field.value)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }

    SelectorControl {
        Layout.fillWidth: true
        visible: field.spec.type === "enum"
        enabled: field.idle
        translate: false
        options: ModsModel.enumChoices(field.spec.options)
        value: field.value
        onSelected: v => field.save(v)
    }

    RowLayout {
        Layout.fillWidth: true
        visible: field.textual
        spacing: Metrics.spacing - 2

        TextControl {
            id: textField
            Layout.fillWidth: true
            text: field.textual ? String(field.value ?? "") : ""
            input.inputMethodHints: field.spec.type === "string" ? Qt.ImhNone : Qt.ImhFormattedNumbersOnly
            Accessible.name: field.spec.label ?? field.spec.key
            Accessible.description: field.spec.description ?? ""
        }

        PillButton {
            text: I18n.t("common.save")
            enabled: field.idle
            onClicked: field.saveText(textField.input.text)
        }
    }

    Connections {
        target: textField.input
        function onAccepted() {
            field.saveText(textField.input.text);
        }
    }
}
