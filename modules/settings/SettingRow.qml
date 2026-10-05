pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.editors
import qs.modules.settings.previews
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "Registry.js" as Registry
import "Ui.js" as Ui

// One schema entry: label, description, modified dot, reset button and the
// typed control (inline on the right, or stacked full width for rich
// editors), plus an optional live preview below. Hidden entries
// (visibleWhen) collapse with an animation.
Item {
    id: row

    required property var entry

    readonly property string entryId: SchemaUtil.entryId(entry)
    readonly property string type: entry.type
    readonly property bool shown: SettingsStore.visible(entry)
    readonly property bool active: SettingsStore.enabled(entry)
    readonly property bool modified: SettingsStore.isModified(entry)
    readonly property bool resettable: SchemaUtil.isResettable(entry)
    readonly property bool narrow: width < 600
    readonly property bool stacked: type === "custom" || type === "font" || type === "color-role" || type === "list" || type === "path" || type === "screens" || type === "multiselect" || (type === "selector" && (narrow || (entry.options || []).length > 4)) || (narrow && type === "slider")
    readonly property bool highlighted: SettingsStore.highlightedEntry !== "" && SettingsStore.highlightedEntry === entryId
    readonly property var value: entry.key ? SettingsStore.get(entry.key) : undefined

    objectName: "settingRow:" + entryId
    implicitHeight: shown ? body.implicitHeight : 0
    height: implicitHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0
    clip: true

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
        }
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: Colors.primary
        opacity: row.highlighted ? 0.12 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 450
                easing.type: Easing.OutCubic
            }
        }
    }

    Column {
        id: body
        width: parent.width
        topPadding: 16
        bottomPadding: 16
        spacing: 14
        enabled: row.active
        opacity: row.active ? 1 : 0.5

        RowLayout {
            x: 20
            width: parent.width - 40
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: I18n.t(row.entry.label)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                        wrapMode: Text.WordWrap
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!row.entry.description
                    text: row.entry.description ? I18n.t(row.entry.description) : ""
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
            }

            Loader {
                id: inlineControl
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: row.type === "slider" ? Math.min(320, row.width * 0.42) : -1
                active: !row.stacked
                sourceComponent: row.controlComponent()
            }

            // Reset to default
            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                visible: row.resettable

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: resetArea.containsMouse ? Ui.alpha(Colors.primary, 0.16) : "transparent"
                    opacity: row.modified ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: Icons.arrowCounterClockwise
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: Colors.primary
                    opacity: row.modified ? (resetArea.containsMouse ? 1 : 0.75) : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    enabled: row.modified
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsStore.reset(row.entry)
                }
                Accessible.name: I18n.t("common.reset_default")
            }
        }

        Loader {
            id: stackedControl
            x: 20
            width: parent.width - 40
            active: row.stacked
            visible: active
            sourceComponent: row.controlComponent()
        }

        Loader {
            id: previewLoader
            x: 20
            width: parent.width - 40
            active: !!row.entry.preview
            visible: active
            source: active ? Qt.resolvedUrl(Registry.preview(row.entry.preview)) : ""
            onLoaded: Ui.setIfPresent(item, "entry", row.entry)
        }
    }

    // Small dot left of the card edge marks a value changed from default.
    Rectangle {
        x: 8
        y: body.topPadding + 7
        width: 6
        height: 6
        radius: 3
        color: Colors.primary
        opacity: row.modified ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    function controlComponent() {
        switch (type) {
        case "toggle":
            return toggleComponent;
        case "slider":
            return sliderComponent;
        case "number":
            return numberComponent;
        case "selector":
            return selectorComponent;
        case "text":
            return textComponent;
        case "font":
            return fontComponent;
        case "color-role":
            return colorRoleComponent;
        case "custom":
            return customComponent;
        case "list":
            return listComponent;
        case "path":
            return pathComponent;
        case "screens":
            return screensComponent;
        case "multiselect":
            return multiselectComponent;
        }
        return null;
    }

    Component {
        id: toggleComponent
        ToggleControl {
            checked: !!row.value
            onToggled: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: sliderComponent
        SliderControl {
            value: Number(row.value ?? 0)
            from: row.entry.min
            to: row.entry.max
            stepSize: row.entry.step ?? 1
            unit: row.entry.unit ?? ""
            specialValues: row.entry.specialValues ?? []
            onMoved: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: numberComponent
        NumberControl {
            value: Number(row.value ?? 0)
            from: row.entry.min
            to: row.entry.max
            stepSize: row.entry.step ?? 1
            unit: row.entry.unit ?? ""
            specialValues: row.entry.specialValues ?? []
            onChanged: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: selectorComponent
        SelectorControl {
            options: row.entry.options
            value: row.value
            onSelected: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: textComponent
        TextControl {
            text: row.value ?? ""
            placeholder: row.entry.placeholder ? I18n.t(row.entry.placeholder) : ""
            monospace: !!row.entry.monospace
            invalid: !SchemaUtil.matchesPattern(row.entry, input.text)
            onEdited: t => {
                if (SchemaUtil.matchesPattern(row.entry, t))
                    SettingsStore.set(row.entry.key, t);
            }
        }
    }

    Component {
        id: fontComponent
        FontControl {
            family: row.value ?? ""
            size: Number(SettingsStore.get(row.entry.sizeKey) ?? 14)
            monospace: !!row.entry.monospace
            placeholder: row.entry.placeholder ? I18n.t(row.entry.placeholder) : ""
            sizeUnit: row.entry.sizeUnit ?? "px"
            onFamilyPicked: f => SettingsStore.set(row.entry.key, f)
            onSizeEdited: s => SettingsStore.set(row.entry.sizeKey, s)
        }
    }

    Component {
        id: colorRoleComponent
        ColorRoleControl {
            value: row.value
            gradient: !!row.entry.gradient
            onEdited: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: listComponent
        ListControl {
            entry: row.entry
            items: SchemaUtil.plain(row.value) || []
            onChanged: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: pathComponent
        PathControl {
            path: row.value ?? ""
            pathKind: row.entry.pathKind ?? "file"
            filter: row.entry.filter ?? ""
            placeholder: row.entry.placeholder ? I18n.t(row.entry.placeholder) : ""
            onEdited: p => SettingsStore.set(row.entry.key, p)
        }
    }

    Component {
        id: screensComponent
        ScreensControl {
            values: SchemaUtil.plain(row.value) || []
            onChanged: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: multiselectComponent
        ChipsControl {
            options: row.entry.options
            values: SchemaUtil.plain(row.value) || []
            onChanged: v => SettingsStore.set(row.entry.key, v)
        }
    }

    // Rich editors: modules/settings/editors/<component>.qml, each with
    // `property var entry` and reading/writing through SettingsStore.
    Component {
        id: customComponent
        Loader {
            source: Qt.resolvedUrl(Registry.editor(row.entry.component))
            onLoaded: Ui.setIfPresent(item, "entry", row.entry)
        }
    }
}
