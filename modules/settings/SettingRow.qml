pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "Registry.js" as Registry
import "Macros.js" as Macros
import "Ui.js" as Ui
import "../components/kit/KitStates.js" as KitStates
import "../shell/hosts/HostResolve.js" as HostResolve

// One schema entry: a short label on the left and its control on the right
// (or under it, full width, for picture cards and rich editors). The
// entry's description is not printed: it is the label's tooltip (hover or
// keyboard focus). A one-line `hint` (i18n key) shows under the label where
// the effect cannot be seen on the stage. While the value differs from its
// default a reset button sits after the label (one undo step). Under the
// pointer or focus the row lights up the part of the page's stage its keys
// change (SettingsStore.focusKeys -> StageSpot).
//
// A row that cannot be used right now (enabledWhen false) is never a grey
// dead end: when one switch decides it, the row says what it needs and
// offers [Turn on] in place of its control; otherwise it is hidden.
// A toggle with `invert: true` shows on for a false value (a positive name
// for a double-negative key such as notch.disableHoverExpansion).
FocusScope {
    id: row

    required property var entry

    readonly property string entryId: SchemaUtil.entryId(entry)
    readonly property string type: entry.type
    // The keys the row changes (a macro slider: the keys of its macro).
    readonly property var keys: type === "macro" ? (Macros.byId(entry.macro) || {
            "keys": []
        }).keys.map(k => k.key) : SchemaUtil.entryKeys(entry)
    readonly property bool usable: SettingsStore.enabled(entry)
    readonly property var note: row.usable ? null : SettingsStore.disabledNote(entry)
    readonly property bool fixable: !!(row.note && row.note.fix)
    readonly property bool shown: SettingsStore.visible(entry) && (row.usable || row.fixable)
    // The row above in the section: a run of rows waiting for the same
    // switch names it once, on its first row.
    property var previousEntry: null
    readonly property bool noteRepeats: {
        if (!row.fixable || !row.previousEntry || SettingsStore.enabled(row.previousEntry) || !SettingsStore.visible(row.previousEntry))
            return false;
        const prev = SettingsStore.disabledNote(row.previousEntry);
        return !!(prev && prev.fix && prev.fix.key === row.note.fix.key);
    }
    readonly property bool modified: SettingsStore.isModified(entry)
    readonly property bool resettable: SchemaUtil.isResettable(entry)
    readonly property bool narrow: width < Space.px(560)
    readonly property bool stacked: row.usable && (type === "custom" || type === "color-role" || type === "list" || type === "path" || type === "screens" || type === "multiselect" || (type === "selector" && entry.display === "cards") || (narrow && (type === "slider" || type === "macro" || type === "selector")))
    readonly property bool highlighted: SettingsStore.highlightedEntry !== "" && SettingsStore.highlightedEntry === entryId
    readonly property bool hovered: hover.hovered
    readonly property var value: entry.key ? SettingsStore.get(entry.key) : undefined
    readonly property string description: entry.description ? I18n.t(entry.description) : ""
    // A host/style picker (entry.surface) while the notch is off: the
    // option it shows as instead of the chosen one ("" otherwise)
    readonly property string shownAs: {
        if (!entry.surface)
            return "";
        const host = HostResolve.shownInstead(HostResolve.layoutWith(entry.surface, row.value), entry.surface, {
            "notchEnabled": SettingsStore.get("notch.enabled") !== false
        });
        const opt = host ? (entry.options || []).find(o => o.value === host) : null;
        return opt ? I18n.t(opt.label) : host;
    }
    // The caption under the label: what a waiting row needs, where the
    // choice shows instead, or the entry's own short hint.
    readonly property string caption: {
        if (row.fixable)
            return row.noteRepeats ? "" : row.note.text;
        if (row.shownAs !== "")
            return I18n.t("prefs.layout.island_off").arg(row.shownAs);
        return entry.hint ? I18n.t(entry.hint) : "";
    }

    objectName: "settingRow:" + entryId
    // visibleWhen folds the row open or shut; its own content changes
    // (wrapping on a resize) apply at once.
    property real unfolded: shown ? 1 : 0
    implicitHeight: body.implicitHeight * unfolded
    height: implicitHeight
    opacity: unfolded
    visible: opacity > 0
    clip: unfolded < 1

    Behavior on unfolded {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: row.shown ? Motion.glide.duration : Motion.exit.duration
            easing.type: row.shown ? Motion.glide.easing : Motion.exit.easing
        }
    }

    // The control is created once the row is first shown.
    property bool built: shown
    onShownChanged: if (shown)
        built = true

    // Under the pointer or keyboard focus: light up the stage part.
    readonly property bool pointed: row.shown && (row.hovered || row.activeFocus)
    onPointedChanged: {
        if (row.pointed)
            SettingsStore.focusKeys = row.keys;
        else if (SettingsStore.focusKeys === row.keys)
            SettingsStore.focusKeys = [];
    }
    Component.onDestruction: if (SettingsStore.focusKeys === row.keys)
        SettingsStore.focusKeys = []

    HoverHandler {
        id: hover
    }

    // Hover box of a one-line row (picture cards and editors carry their
    // own hover states), and the accent wash of a search jump.
    StyledRect {
        anchors.fill: parent
        visible: !row.stacked && (row.hovered || row.activeFocus)
        variant: "focus"
        backgroundOpacity: KitStates.opacity("hover", true)
        enableBorder: false
        enableShadow: false
        radius: Look.chipRadius(Space.rowHeight)
    }
    Rectangle {
        anchors.fill: parent
        radius: Look.chipRadius(Space.rowHeight)
        color: Type.accent
        opacity: row.highlighted ? Look.activeTint * 1.5 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    // Row content sits at the kit's row inset, on the line of the section
    // label above it (SectionLabel.inset).
    Column {
        id: body
        x: Look.rowInset
        width: parent.width - Look.rowInset * 2
        topPadding: Space.s
        bottomPadding: Space.s
        spacing: Space.m

        RowLayout {
            width: parent.width
            spacing: Space.l

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumHeight: Space.rowHeight - body.topPadding - body.bottomPadding
                spacing: Space.hairline

                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Space.s
                    KitText {
                        id: label
                        objectName: "rowLabel"
                        Layout.alignment: Qt.AlignVCenter
                        role: "body"
                        text: I18n.t(row.entry.label)

                        Tooltip {
                            objectName: "rowTooltip"
                            text: row.description
                            shown: row.pointed && !row.stacked || labelHover.hovered
                        }
                        HoverHandler {
                            id: labelHover
                        }
                    }
                    // Back to the default: there only while the value differs.
                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        active: row.resettable && row.modified
                        visible: active
                        sourceComponent: IconButton {
                            objectName: "rowReset"
                            size: "xs"
                            icon: Icons.arrowCounterClockwise
                            tooltip: I18n.t("common.reset_default")
                            onClicked: SettingsStore.reset(row.entry)
                            Accessible.name: I18n.t("common.reset_default")
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
                KitText {
                    objectName: "rowCaption"
                    Layout.fillWidth: true
                    visible: row.caption !== ""
                    role: "caption"
                    text: row.caption
                    wrapMode: Text.WordWrap
                }
                Item {
                    Layout.fillHeight: true
                }
            }

            Loader {
                id: inlineControl
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: row.type === "slider" ? Math.min(Space.px(320), row.width * 0.42) : (row.type === "macro" ? Math.min(Space.px(380), row.width * 0.5) : (row.type === "font" ? Math.min(Space.px(340), row.width * 0.48) : -1))
                focus: !row.stacked
                active: row.built && !row.stacked
                sourceComponent: row.fixable ? fixComponent : row.controlComponent()
            }
        }

        Loader {
            id: stackedControl
            width: parent.width
            focus: row.stacked
            active: row.built && row.stacked
            visible: active
            sourceComponent: row.controlComponent()
        }

        // A page not converted yet may still show a live preview under a
        // row (`preview`); a converted page shows its stage instead.
        Loader {
            width: parent.width
            active: row.built && !!row.entry.preview
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
            return entry.display === "cards" ? cardsComponent : selectorComponent;
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

    // In place of the control of a waiting row: the one switch it needs.
    Component {
        id: fixComponent
        Chip {
            objectName: "disabledFix"
            icon: Icons.power
            text: I18n.t(row.note.fix.on ? "prefs.disabled.turn_on" : "prefs.disabled.turn_off")
            onClicked: SettingsStore.set(row.note.fix.key, row.note.fix.value)
        }
    }

    Component {
        id: toggleComponent
        ToggleControl {
            checked: row.entry.invert ? !row.value : !!row.value
            onToggled: v => SettingsStore.set(row.entry.key, row.entry.invert ? !v : v)
        }
    }

    Component {
        id: sliderComponent
        SliderControl {
            value: Ui.finite(row.value, row.entry.min ?? 0)
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
            value: Ui.finite(row.value, row.entry.min ?? 0)
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
                else
                    input.text = row.value ?? "";
            }
        }
    }

    Component {
        id: fontComponent
        FontControl {
            family: row.value ?? ""
            size: Number(SettingsStore.get(row.entry.sizeKey) ?? 14)
            monospace: !!row.entry.monospace
            showSize: !!row.entry.sizeKey
            showSample: false
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

    Component {
        id: cardsComponent
        CardSelector {
            entry: row.entry
            options: row.entry.options
            value: row.value
            onSelected: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: macroComponent
        MacroSlider {
            entry: row.entry
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
