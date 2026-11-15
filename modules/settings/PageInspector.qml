pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "ChangesModel.js" as ChangesModel
import "SchemaUtil.js" as SchemaUtil

// The inspector under the sticky stage of a two-pane page (SettingsPage):
// it fills the right column's room under the stage. While a row of the
// page is under the pointer or has the keyboard focus it tells about that
// setting: its name, its value now and its default, and Reset when they
// differ (the row's own reset is the keyboard path; this one keeps its row
// while it has the focus too). The description stays the label's tooltip
// (never printed). The part of the stage the row changes is lit meanwhile
// (StageSpot, also while the pointer is on the inspector itself).
// Otherwise it sums up the tab: how many settings differ from their
// defaults and which (five at most, "+N more"), else the first values of
// the tab. The summary is counted only while it shows, a moment after the
// last change (a slider drag does not recount it every frame), never in a
// hidden kept page. It follows the pointer with a short hold and
// cross-fades, so moving between rows never makes it jitter.
Card {
    id: inspector

    // the page (its category; rows are found under it)
    required property Item page
    required property var category
    // the row it tells about (null: the summary)
    property Item row: null
    // the row being pointed at, after the hold
    property Item wanted: null
    // the pointer is on it, or its Reset has the keyboard focus: the row stays
    readonly property bool held: hover.hovered || resetButton.activeFocus

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
        target: inspector.visible ? SettingsStore : null
        function onFocusKeysChanged() {
            if (SettingsStore.focusOwner !== inspector)
                holdTimer.restart();
        }
    }
    Timer {
        id: holdTimer
        interval: Math.max(150, Motion.micro.duration)
        onTriggered: {
            if (inspector.held)
                return;
            inspector.wanted = inspector.ownRow(SettingsStore.focusOwner);
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
        if (value === undefined || value === null || typeof value === "object")
            return "";
        return ChangesModel.describe(entry, SchemaUtil.plain(value), k => I18n.t(k));
    }

    // ---- the summary (counted while it shows, after changes settle) ------
    // {count, lines: [{label, value}], more}
    property var summary: ({
            "count": 0,
            "lines": [],
            "more": 0
        })
    readonly property bool summarizing: inspector.visible && inspector.row === null
    onSummarizingChanged: if (inspector.summarizing)
        inspector.recount()
    onCategoryChanged: if (inspector.summarizing)
        inspector.recount()
    Connections {
        target: inspector.summarizing ? SettingsStore : null
        function onValueSet(key, value) {
            recountTimer.restart();
        }
    }
    Connections {
        target: inspector.summarizing ? Config : null
        ignoreUnknownSignals: true
        function onDomainReloaded(name) {
            recountTimer.restart();
        }
    }
    Timer {
        id: recountTimer
        interval: 250
        onTriggered: inspector.recount()
    }
    function recount() {
        const items = inspector.category && inspector.category.sections ? SettingsStore.activeItems(inspector.category).filter(it => !!it.entry.label) : [];
        const changed = items.filter(it => SettingsStore.isModified(it.entry));
        const MAX = 5;
        // the changed settings, every one named (a composite value says
        // "changed"); with none, the first plain values of the tab
        const list = changed.length > 0 ? changed : items.filter(it => it.entry.key && inspector.said(it.entry, SettingsStore.get(it.entry.key)) !== "");
        const lines = list.slice(0, MAX).map(it => {
            const v = it.entry.key ? inspector.said(it.entry, SettingsStore.get(it.entry.key)) : "";
            return {
                "label": I18n.t(it.entry.label),
                "value": v !== "" ? v : I18n.t("prefs.inspector.custom")
            };
        });
        inspector.summary = {
            "count": changed.length,
            "lines": lines,
            "more": changed.length > MAX ? changed.length - MAX : 0
        };
    }

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
                id: resetButton
                objectName: "inspectorReset"
                visible: !!inspector.row && inspector.row.resettable && inspector.row.modified
                kind: "ghost"
                icon: "arrowCounterClockwise"
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
                text: inspector.summary.count > 0 ? I18n.tn("prefs.inspector.changed", inspector.summary.count) : I18n.t("prefs.page.reset_none")
            }
            Repeater {
                model: inspector.summary.lines
                delegate: InspectorLine {
                    required property var modelData
                    objectName: "inspectorLine"
                    width: parent.width
                    name: modelData.label
                    value: modelData.value
                }
            }
            KitText {
                objectName: "inspectorMore"
                width: parent.width
                visible: inspector.summary.more > 0
                role: "secondary"
                color: Type.muted
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.inspector.more").arg(inspector.summary.more)
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
