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
    // Waits on its card's switch (SettingsSection / CardGate.js): shown as
    // it would be, dimmed, no note of its own; a press turns the switch on
    // and reaches the control.
    property bool preview: false
    property var previewFix: null
    // the row waits on one switch of its own (a side switch beside the
    // stage): shown dimmed the same way, a press turns that switch on first
    property bool selfGate: false
    readonly property bool dimmed: row.preview || (row.selfGate && row.fixable)
    readonly property var dimFix: row.preview ? row.previewFix : (row.dimmed ? row.note.fix : null)
    // turn on what this dimmed row waits for
    function wake() {
        if (row.dimFix)
            SettingsStore.set(row.dimFix.key, row.dimFix.value);
    }
    readonly property bool shown: (SettingsStore.visible(entry) && (row.usable || row.fixable)) || row.preview
    // The row above in the section: a run of rows waiting for the same
    // switch names it once, on its first row.
    property var previousEntry: null
    // The card's heading names it (a card of one setting): a picture /
    // editor control without the row's own label line, edge to edge.
    property bool bare: false
    // The height a stacked control gets (a card of the page row): picture
    // editors become one horizontal strip of it (their `fillHeight`).
    property real fillHeight: 0
    // in a card of the page row: tighter vertical rhythm
    property bool dense: false
    readonly property bool labelHidden: row.bare && row.stacked
    readonly property bool noteRepeats: {
        if (!row.fixable || !row.previousEntry || SettingsStore.enabled(row.previousEntry) || !SettingsStore.visible(row.previousEntry))
            return false;
        const prev = SettingsStore.disabledNote(row.previousEntry);
        return !!(prev && prev.fix && prev.fix.key === row.note.fix.key);
    }
    readonly property bool modified: SettingsStore.isModified(entry)
    readonly property bool resettable: SchemaUtil.isResettable(entry)
    readonly property bool narrow: width < Space.px(560)
    // how wide an inline segmented of this selector is, measured in the
    // control's font (segments are equal: the longest name sets them all;
    // stack it when it would not fit beside the label)
    // (`iconOnly`: segments of icons, the names in their accessible names)
    readonly property real selectorWidth: type === "selector" ? (entry.iconOnly === true ? (entry.options || []).length * Space.px(44) : (entry.options || []).length * ((entry.options || []).reduce((w, o) => Math.max(w, row.textWidth(I18n.t(o.label))), 0) + Space.px(40))) : 0
    // a dropdown shows its longest option whole; a font row its family
    readonly property real dropdownNeed: type === "selector" ? (entry.options || []).reduce((w, o) => Math.max(w, row.textWidth(I18n.t(o.label))), 0) + Space.px(100) : 0
    readonly property real fontNeed: type === "font" ? row.textWidth(String(row.value || (entry.placeholder ? I18n.t(entry.placeholder) : "") || Type.bodyFont)) + Space.px(72) : 0
    // the longest word of the label (a label wraps between words, never
    // inside one) and the room the inline dropdown / font control takes:
    // when both do not fit on one line the control goes under the label
    readonly property real labelWordNeed: String(I18n.t(entry.label || "")).split(" ").reduce((w, word) => Math.max(w, row.textWidth(word)), 0)
    readonly property real inlineNeed: row.dropdown ? Math.max(row.selectorAsDropdown ? width * 0.48 : 0, Math.min(row.dropdownNeed, width * 0.6)) : (type === "selector" && !row.asCards ? row.selectorWidth : (type === "font" ? width * (entry.sizeKey ? 0.8 : 0.6) : 0))
    // a measured text width with a 10 % margin: the fonts of another machine
    // can run a few percent wider, and a name must still fit whole
    function textWidth(text: string): real {
        return metrics.advanceWidth(text) * 1.1;
    }
    FontMetrics {
        id: metrics
        font: metricsText.font
    }
    KitText {
        id: metricsText
        visible: false
        role: "body"
    }
    // picture cards: the row's own control, or (a card of the page row that
    // holds other rows too) a plain selector: a strip of pictures is a
    // card's one setting (PAGE COMPOSITION)
    // a choice between looks is always pictures (every option visible,
    // wrapped: CardSelector), whatever the card holds
    readonly property bool asCards: entry.display === "cards"
    readonly property bool stacked: (row.usable || row.dimmed) && (type === "custom" || type === "color-role" || type === "list" || type === "path" || type === "screens" || type === "multiselect" || (type === "font" && row.dense && (!!entry.sizeKey ? (width < Space.px(400) || row.fontNeed + Space.px(150) > width * 0.8) : row.fontNeed > width * 0.6)) || (row.dropdown && row.dropdownNeed > width * 0.6) || ((row.dropdown || (type === "selector" && !row.asCards) || (type === "font" && row.dense)) && row.labelWordNeed + row.inlineNeed + Space.l * 4 + Space.xl > width) || (type === "selector" && row.asCards) || ((narrow && (type === "slider" || type === "text" || (type === "macro" && !row.dense))) || (!row.dense && type === "selector" && (entry.options || []).length <= 4 && row.selectorWidth > width - Space.px(170))))
    // a dense row (a card of the page row) keeps a selector inline: a
    // dropdown when its segmented would not fit beside the label
    readonly property bool selectorAsDropdown: row.dense && type === "selector" && entry.iconOnly !== true && row.selectorWidth > width - Space.px(170)
    // the selector is a dropdown (too long for segments, or more options than
    // segments hold): as wide as its longest option, under the label when
    // even that does not fit
    readonly property bool dropdown: type === "selector" && !row.asCards && entry.iconOnly !== true && (row.selectorAsDropdown || (entry.options || []).length > 4)
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
        if (row.fixable && !row.dimmed)
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
            SettingsStore.point(row, row.keys);
        else
            SettingsStore.unpoint(row);
    }
    // a hidden page (kept alive) points at nothing
    onVisibleChanged: if (!visible)
        SettingsStore.unpoint(row)
    Component.onDestruction: SettingsStore.unpoint(row)

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
        opacity: row.dimmed ? 0.45 : 1
        x: row.labelHidden ? 0 : Look.rowInset
        width: parent.width - (row.labelHidden ? 0 : Look.rowInset * 2)
        topPadding: row.dense ? Space.xs : Space.s
        bottomPadding: row.dense ? Space.xs : Space.s
        spacing: row.dense ? Space.xs : Space.m

        RowLayout {
            width: parent.width
            spacing: Space.l
            visible: !row.labelHidden

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
                        // wraps in a narrow place (beside the stage)
                        Layout.maximumWidth: row.stacked ? body.width : Math.max(Space.px(60), body.width - Space.l * 2 - (row.dense && (row.type === "macro" || row.type === "font" || row.dropdown) ? inlineControl.Layout.preferredWidth : inlineControl.implicitWidth))
                        role: "body"
                        wrapMode: Text.WordWrap
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
                objectName: "rowControl"
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: row.type === "slider" ? Math.min(Space.px(320), row.width * 0.42) : (row.type === "macro" ? (row.dense ? body.width * 0.56 : Math.min(Space.px(380), row.width * 0.5)) : (row.type === "font" ? (row.dense ? body.width * (row.entry.sizeKey ? 0.8 : 0.6) : Math.min(Space.px(340), row.width * 0.48)) : (row.dropdown ? Math.max(row.selectorAsDropdown ? body.width * 0.48 : 0, Math.min(row.dropdownNeed, body.width * 0.6)) : -1)))
                focus: !row.stacked
                active: row.built && !row.stacked
                sourceComponent: row.fixable && !row.dimmed ? fixComponent : row.controlComponent()
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

    // a switch row: the whole row is the hit target (under the switch, so a
    // press on the switch itself is the switch's)
    MouseArea {
        objectName: "rowToggleArea"
        anchors.fill: parent
        z: -1
        enabled: row.type === "toggle" && row.usable && !row.dimmed && !!row.entry.key
        visible: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.set(row.entry.key, !row.value)
    }

    // a press on a waiting row turns its card's switch on, then reaches the
    // control under it (picking a clock style turns the clock on)
    MouseArea {
        objectName: "rowPreviewPress"
        anchors.fill: parent
        z: 10
        enabled: row.dimmed && row.dimFix !== null
        visible: enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            row.wake();
            mouse.accepted = false;
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
            return row.asCards ? cardsComponent : selectorComponent;
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
            segmentLimit: row.selectorAsDropdown ? 0 : (row.entry.iconOnly === true ? 6 : 4)
            iconOnly: row.entry.iconOnly === true
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
            fillHeight: row.fillHeight
            options: row.entry.options
            value: row.value
            onSelected: v => SettingsStore.set(row.entry.key, v)
        }
    }

    Component {
        id: macroComponent
        MacroSlider {
            entry: row.entry
            compact: row.dense
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
            readonly property bool waits: row.entry.lazy === true && row.fillHeight > 0
            property bool shown: false
            asynchronous: waits
            Connections {
                target: editorLoader.waits && !editorLoader.shown && editorLoader.visible ? editorLoader.Window.window : null
                function onFrameSwapped() {
                    editorLoader.shown = true;
                }
            }
            source: !waits || shown ? Qt.resolvedUrl(Registry.editor(row.entry.component)) : ""
            height: row.fillHeight > 0 ? Math.max(row.fillHeight, implicitHeight) : implicitHeight
            onLoaded: {
                Ui.setIfPresent(item, "entry", row.entry);
                if (item && "fillHeight" in item)
                    item.fillHeight = Qt.binding(() => row.fillHeight);
            }
        }
    }
}
