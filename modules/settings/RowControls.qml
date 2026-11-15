pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "Registry.js" as Registry
import "Ui.js" as Ui

// The typed controls of a SettingRow, one Component per schema entry type
// (`forType`): each reads the row's value and writes through SettingsStore.
// Rich `custom` editors load modules/settings/editors/<component>.qml.
Item {
    id: controls

    // the SettingRow (entry, value, readout, column, fillHeight, ...)
    required property var row

    visible: false

    function forType(type, asCards) {
        switch (type) {
        case "toggle":
            return toggleComponent;
        case "slider":
            return sliderComponent;
        case "number":
            return numberComponent;
        case "selector":
            return asCards ? cardsComponent : selectorComponent;
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
        case "macro":
            return macroComponent;
        }
        return null;
    }

    Component {
        id: toggleComponent
        ToggleControl {
            checked: controls.row.entry.invert ? !controls.row.value : !!controls.row.value
            onToggled: v => SettingsStore.set(controls.row.entry.key, controls.row.entry.invert ? !v : v)
        }
    }

    Component {
        id: sliderComponent
        SliderControl {
            value: Ui.finite(controls.row.value, controls.row.entry.min ?? 0)
            from: controls.row.entry.min
            to: controls.row.entry.max
            stepSize: controls.row.entry.step ?? 1
            unit: controls.row.entry.unit ?? ""
            specialValues: controls.row.entry.specialValues ?? []
            onMoved: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: numberComponent
        NumberControl {
            readoutMin: controls.row.readout
            value: Ui.finite(controls.row.value, controls.row.entry.min ?? 0)
            from: controls.row.entry.min
            to: controls.row.entry.max
            stepSize: controls.row.entry.step ?? 1
            unit: controls.row.entry.unit ?? ""
            specialValues: controls.row.entry.specialValues ?? []
            onChanged: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: selectorComponent
        SelectorControl {
            segmentLimit: controls.row.selectorAsDropdown ? 0 : (controls.row.entry.iconOnly === true ? 6 : 4)
            stretch: controls.row.columnar
            iconOnly: controls.row.entry.iconOnly === true
            options: controls.row.entry.options
            value: controls.row.value
            onSelected: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: textComponent
        TextControl {
            text: controls.row.value ?? ""
            placeholder: controls.row.entry.placeholder ? I18n.t(controls.row.entry.placeholder) : ""
            monospace: !!controls.row.entry.monospace
            multiline: controls.row.entry.multiline === true
            invalid: !SchemaUtil.matchesPattern(controls.row.entry, input.text)
            onEdited: t => {
                if (SchemaUtil.matchesPattern(controls.row.entry, t))
                    SettingsStore.set(controls.row.entry.key, t);
                else
                    input.text = controls.row.value ?? "";
            }
        }
    }

    Component {
        id: fontComponent
        FontControl {
            family: controls.row.value ?? ""
            size: Number(SettingsStore.get(controls.row.entry.sizeKey) ?? 14)
            monospace: !!controls.row.entry.monospace
            showSize: !!controls.row.entry.sizeKey
            showSample: false
            placeholder: controls.row.entry.placeholder ? I18n.t(controls.row.entry.placeholder) : ""
            sizeUnit: controls.row.entry.sizeUnit ?? "px"
            onFamilyPicked: f => SettingsStore.set(controls.row.entry.key, f)
            onSizeEdited: s => SettingsStore.set(controls.row.entry.sizeKey, s)
        }
    }

    Component {
        id: colorRoleComponent
        ColorRoleControl {
            value: controls.row.value
            gradient: !!controls.row.entry.gradient
            onEdited: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: listComponent
        ListControl {
            entry: controls.row.entry
            items: SchemaUtil.plain(controls.row.value) || []
            onChanged: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: pathComponent
        PathControl {
            path: controls.row.value ?? ""
            pathKind: controls.row.entry.pathKind ?? "file"
            filter: controls.row.entry.filter ?? ""
            placeholder: controls.row.entry.placeholder ? I18n.t(controls.row.entry.placeholder) : ""
            onEdited: p => SettingsStore.set(controls.row.entry.key, p)
        }
    }

    Component {
        id: screensComponent
        ScreensControl {
            values: SchemaUtil.plain(controls.row.value) || []
            onChanged: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: multiselectComponent
        ChipsControl {
            options: controls.row.entry.options
            values: SchemaUtil.plain(controls.row.value) || []
            onChanged: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: cardsComponent
        CardSelector {
            sharedColumns: controls.row.pictureColumns
            entry: controls.row.entry
            fillHeight: controls.row.fillHeight
            options: controls.row.entry.options
            value: controls.row.value
            onSelected: v => SettingsStore.set(controls.row.entry.key, v)
        }
    }

    Component {
        id: macroComponent
        MacroSlider {
            entry: controls.row.entry
            compact: controls.row.dense
        }
    }

    // Rich editors: modules/settings/editors/<component>.qml, each with
    // `property var entry` and reading/writing through SettingsStore.
    Component {
        id: customComponent
        Loader {
            id: editorLoader
            // `lazy` (a heavy editor in a card of the page row, whose height
            // is fixed): compiled and built once the page shows, not
            // before its first frame
            readonly property bool waits: controls.row.entry.lazy === true && controls.row.fillHeight > 0
            property bool shown: false
            asynchronous: waits
            Connections {
                target: editorLoader.waits && !editorLoader.shown && editorLoader.visible ? editorLoader.Window.window : null
                function onFrameSwapped() {
                    editorLoader.shown = true;
                }
            }
            source: !editorLoader.waits || editorLoader.shown ? Qt.resolvedUrl(Registry.editor(controls.row.entry.component)) : ""
            // a lazy editor fades in once built (it never pops in)
            opacity: !editorLoader.waits || editorLoader.status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                enabled: editorLoader.waits && Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            height: controls.row.fillHeight > 0 ? Math.max(controls.row.fillHeight, implicitHeight) : implicitHeight
            onLoaded: {
                Ui.setIfPresent(item, "entry", controls.row.entry);
                if (item && "fillHeight" in item)
                    item.fillHeight = Qt.binding(() => controls.row.fillHeight);
                if (item && "sharedColumns" in item)
                    item.sharedColumns = Qt.binding(() => controls.row.pictureColumns);
            }
        }
    }
}
