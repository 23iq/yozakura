pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "ChangesModel.js" as ChangesModel
import "SchemaUtil.js" as SchemaUtil

// The inspector under the sticky stage of a two-pane page (SettingsPage):
// it fills the right column's room under the stage. While a row of the
// page is under the pointer or has the keyboard focus it tells about that
// setting: its name, what it does (the entry's description), its value now
// and its default, and Reset when they differ; the part of the stage the
// row changes is lit meanwhile (StageSpot, also while the pointer is on the
// inspector itself). Otherwise it sums up the tab: how many settings
// differ from their defaults and which (else the first values of the tab).
// It follows the pointer with a short hold and cross-fades, so moving
// between rows never makes it jitter.
Card {
    id: inspector

    // the page (its category; rows are found under it)
    required property Item page
    required property var category
    // the row it tells about (null: the summary)
    property Item row: null
    // the row being pointed at, after the hold
    property Item wanted: null
    readonly property bool held: hover.hovered

    objectName: "pageInspector"
    shadow: false
    spacing: Space.s

    HoverHandler {
        id: hover
    }

    // a row of this page, or nothing
    function ownRow(owner) {
        if (!owner || !owner.entry)
            return null;
        for (let x = owner; x; x = x.parent) {
            if (x === inspector.page)
                return owner;
        }
        return null;
    }

    Connections {
        target: SettingsStore
        function onFocusKeysChanged() {
            if (SettingsStore._focusOwner !== inspector)
                holdTimer.restart();
        }
    }
    Timer {
        id: holdTimer
        interval: Math.max(150, Motion.micro.duration)
        onTriggered: {
            if (inspector.held)
                return;
            inspector.wanted = inspector.ownRow(SettingsStore._focusOwner);
        }
    }
    onHeldChanged: {
        // on the inspector: its setting stays lit; off it: back to the rows
        if (inspector.held && inspector.row)
            SettingsStore.point(inspector, inspector.row.keys);
        else
            SettingsStore.unpoint(inspector);
        if (!inspector.held)
            holdTimer.restart();
    }
    Component.onDestruction: SettingsStore.unpoint(inspector)

    // the shown content changes behind a quick fade (never a jump)
    onWantedChanged: {
        if (Motion.micro.duration <= 0 || !inspector.visible) {
            inspector.row = inspector.wanted;
            return;
        }
        swap.restart();
    }
    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0
            duration: Motion.micro.duration
            easing.type: Motion.exit.easing
        }
        ScriptAction {
            script: inspector.row = inspector.wanted
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 1
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }

    // a value as a short text ("" for a composite one)
    function said(entry, value) {
        if (value === undefined || value === null || (typeof value === "object" && !Array.isArray(value)))
            return "";
        if (Array.isArray(value))
            return "";
        return ChangesModel.describe(entry, SchemaUtil.plain(value), k => I18n.t(k));
    }

    // the summary: the tab's changed settings, or its first values
    readonly property var items: inspector.category && inspector.category.sections ? SettingsStore.activeItems(inspector.category) : []
    readonly property var changed: inspector.items.filter(it => SettingsStore.isModified(it.entry))
    readonly property var lines: (inspector.changed.length > 0 ? inspector.changed : inspector.items).filter(it => it.entry.key && it.entry.label && inspector.said(it.entry, SettingsStore.get(it.entry.key)) !== "").slice(0, 5)

    Column {
        id: content
        width: inspector.contentWidth
        spacing: Space.s

        // ---- one setting ----------------------------------------------
        Column {
            width: parent.width
            spacing: Space.s
            visible: inspector.row !== null
            readonly property var entry: inspector.row ? inspector.row.entry : null
            readonly property string key: entry && entry.key ? entry.key : ""
            readonly property string now: key ? inspector.said(entry, SettingsStore.get(key)) : ""
            readonly property string was: key ? inspector.said(entry, SettingsStore.defaultValue(key)) : ""

            KitText {
                objectName: "inspectorTitle"
                width: parent.width
                role: "body"
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                text: parent.entry ? I18n.t(parent.entry.label) : ""
            }
            KitText {
                width: parent.width
                visible: text !== ""
                role: "secondary"
                color: Type.secondary
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                text: inspector.row ? inspector.row.description : ""
            }
            InspectorLine {
                width: parent.width
                visible: parent.now !== ""
                name: I18n.t("prefs.inspector.now")
                value: parent.now
                strong: true
            }
            InspectorLine {
                width: parent.width
                visible: parent.was !== "" && parent.was !== parent.now
                name: I18n.t("prefs.inspector.default")
                value: parent.was
            }
            PillButton {
                objectName: "inspectorReset"
                visible: !!inspector.row && inspector.row.resettable && inspector.row.modified
                kind: "ghost"
                icon: Icons.arrowCounterClockwise
                text: I18n.t("common.reset_default")
                onClicked: SettingsStore.reset(inspector.row.entry)
            }
        }

        // ---- the tab -------------------------------------------------
        Column {
            width: parent.width
            spacing: Space.s
            visible: inspector.row === null

            KitText {
                objectName: "inspectorSummary"
                width: parent.width
                role: "body"
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                text: inspector.changed.length > 0 ? I18n.tn("prefs.inspector.changed", inspector.changed.length) : I18n.t("prefs.page.reset_none")
            }
            Repeater {
                model: inspector.lines
                delegate: InspectorLine {
                    required property var modelData
                    width: parent.width
                    name: I18n.t(modelData.entry.label)
                    value: inspector.said(modelData.entry, SettingsStore.get(modelData.entry.key))
                }
            }
            KitText {
                width: parent.width
                role: "caption"
                color: Type.muted
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.inspector.hint")
            }
        }
    }
}
