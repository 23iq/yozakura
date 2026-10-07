pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.editors
import qs.modules.settings.previews
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "Registry.js" as Registry
import "Ui.js" as Ui

// One schema entry: label (body) and description (caption) on the left,
// the typed control on the right (or stacked full width for rich editors)
// and a quiet reset while the value differs from its default, plus an
// optional live preview below. Hidden entries (visibleWhen) collapse with
// an animation.
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
    readonly property bool stacked: type === "custom" || type === "font" || type === "color-role" || type === "list" || type === "path" || type === "screens" || type === "multiselect" || (type === "selector" && narrow) || (narrow && type === "slider")
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
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
        }
    }

    // Search jump: a short accent wash over the row.
    Rectangle {
        id: flash
        anchors.fill: parent
        radius: Look.chipRadius(Space.rowHeight)
        color: Type.accent
        opacity: row.highlighted ? Look.activeTint : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    Column {
        id: body
        width: parent.width
        topPadding: Space.s
        bottomPadding: Space.s
        spacing: Space.m
        enabled: row.active
        opacity: row.active ? 1 : 0.38

        RowLayout {
            width: parent.width
            spacing: Space.l

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumHeight: Space.rowHeight - body.topPadding - body.bottomPadding
                spacing: Space.xs / 2

                Item {
                    Layout.fillHeight: true
                }
                KitText {
                    Layout.fillWidth: true
                    role: "body"
                    text: I18n.t(row.entry.label)
                    wrapMode: Text.WordWrap
                }
                KitText {
                    Layout.fillWidth: true
                    visible: !!row.entry.description
                    role: "caption"
                    text: row.entry.description ? I18n.t(row.entry.description) : ""
                    wrapMode: Text.WordWrap
                }
                Item {
                    Layout.fillHeight: true
                }
            }

            // Reset to default: a quiet button before the control, there only
            // while modified (controls stay flush right).
            IconButton {
                objectName: "rowReset"
                Layout.alignment: Qt.AlignVCenter
                size: "s"
                icon: Icons.arrowCounterClockwise
                visible: row.resettable
                opacity: row.modified ? 1 : 0
                enabled: row.modified
                onClicked: SettingsStore.reset(row.entry)
                Accessible.name: I18n.t("common.reset_default")
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.enter.duration
                    }
                }
            }
            Loader {
                id: inlineControl
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: row.type === "slider" ? Math.min(Space.px(320), row.width * 0.42) : -1
                active: !row.stacked
                sourceComponent: row.controlComponent()
            }
        }

        Loader {
            id: stackedControl
            width: parent.width
            active: row.stacked
            visible: active
            sourceComponent: row.controlComponent()
        }

        Loader {
            id: previewLoader
            width: parent.width
            active: !!row.entry.preview
            visible: active
            source: active ? Qt.resolvedUrl(Registry.preview(row.entry.preview)) : ""
            onLoaded: Ui.setIfPresent(item, "entry", row.entry)
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
