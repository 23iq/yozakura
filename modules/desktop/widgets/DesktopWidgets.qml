pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import "WidgetRegistry.js" as Registry
import "WidgetGeometry.js" as Geometry

// Desktop widgets state: the placed widgets (desktop.widgets, normalized),
// edit mode, the depth clock area per screen (published by DepthClock) and
// the list edits used by the desktop (drag/resize/remove) and by settings.
//
// List builders (withAdded, withUpdated, ...) return a new list and never
// write; commit() writes Config.desktop.widgets (auto-saved, or staged with
// the other shell settings while the settings window holds changes).
Singleton {
    id: root

    property bool editMode: false
    // screen name -> {x, y, w, h} in screen pixels (null = no clock there).
    property var clockAreas: ({})

    readonly property bool enabled: Config.desktop.widgetsEnabled ?? true
    readonly property var widgets: Registry.normalizeList(Config.desktop.widgets)
    // The desktop layer must exist: widgets to show, or edit mode.
    readonly property bool wanted: enabled && (widgets.length > 0 || editMode)
    readonly property var screenNames: (Quickshell.screens || []).map(s => s.name)

    function toggleEditMode() {
        // A separate Settings window (ProcessRole): edit mode is the main
        // shell's desktop; it is asked, and tells the state back.
        if (ProcessRole.secondary) {
            BackendService.call("windows.relay", {
                "to": "shell",
                "topic": "desktop.editMode",
                "data": {
                    "on": !editMode
                }
            });
            return;
        }
        editMode = !editMode;
    }

    // performance.separateWindows: the main shell keeps a separate Settings
    // window told about edit mode and the depth clock areas (its layout
    // map), and takes edit-mode requests from it (SeparateWindows.relayed).
    function _tellSettings() {
        if (ProcessRole.primary && SeparateWindows.settingsRunning)
            BackendService.call("windows.relay", {
                "to": "settings",
                "topic": "desktop.state",
                "data": {
                    "editMode": root.editMode,
                    "clockAreas": root.clockAreas
                }
            });
    }
    onEditModeChanged: root._tellSettings()
    onClockAreasChanged: root._tellSettings()
    property Connections _windows: Connections {
        target: ProcessRole.primary ? SeparateWindows : null
        function onRelayed(topic, data) {
            if (topic === "desktop.editMode")
                root.editMode = data.on === true;
        }
        function onSettingsStateChanged() {
            if (SeparateWindows.settingsState === "open")
                root._tellSettings();
        }
    }
    Component.onCompleted: {
        if (ProcessRole.settings)
            BackendService.addSubscription(["windows"], (service, data) => {
                if (service === "windows.relay" && data && data.to === ProcessRole.role && data.topic === "desktop.state") {
                    root.editMode = data.data.editMode === true;
                    root.clockAreas = data.data.clockAreas || {};
                }
            });
    }

    function setClockArea(key, area) {
        const next = Object.assign({}, clockAreas);
        if (area)
            next[key] = {
                x: area.x,
                y: area.y,
                w: area.w,
                h: area.h
            };
        else
            delete next[key];
        clockAreas = next;
    }

    function clockArea(screenName) {
        return clockAreas[screenName] ?? null;
    }

    function forScreen(screenName) {
        return Geometry.forScreen(widgets, screenName, screenNames);
    }

    function copy() {
        return JSON.parse(JSON.stringify(widgets));
    }

    // A new widget of `type` on `screenName` ({w, h} = that screen's size),
    // placed in the first spot clear of the other widgets, the clock and
    // the `avoid` rects (e.g. the edit toolbar), inside `bounds`.
    function withAdded(list, type, screenName, screenW, screenH, bounds, avoid) {
        if (!Registry.has(type))
            return list;
        const size = Registry.sizeFraction(type, screenW, screenH);
        const px = {
            w: Math.round(size.w * screenW),
            h: Math.round(size.h * screenH)
        };
        const area = bounds ?? {
            x: 0,
            y: 0,
            w: screenW,
            h: screenH
        };
        const taken = Geometry.forScreen(list, screenName, screenNames).map(w => Geometry.toPixels(w, screenW, screenH));
        const clock = clockArea(screenName);
        if (clock)
            taken.push(clock);
        (avoid ?? []).forEach(r => taken.push(r));
        const grid = Config.desktop.widgetGrid ?? 24;
        const spot = Geometry.freeSpot(px, area, taken, grid, grid > 0 ? grid : 16);
        const rel = Geometry.toRelative(spot, screenW, screenH);
        const out = list.slice();
        out.push({
            id: Registry.newId(type),
            type: type,
            monitor: screenName,
            x: rel.x,
            y: rel.y,
            w: rel.w,
            h: rel.h,
            options: Registry.defaultOptions(type)
        });
        return out;
    }

    function withUpdated(list, id, fields) {
        return list.map(w => w.id === id ? Object.assign({}, w, fields) : w);
    }

    function withOption(list, id, key, value) {
        return list.map(w => {
            if (w.id !== id)
                return w;
            const options = Object.assign({}, w.options);
            options[key] = value;
            return Object.assign({}, w, {
                options: options
            });
        });
    }

    function withRemoved(list, id) {
        return list.filter(w => w.id !== id);
    }

    function commit(list) {
        Config.desktop.widgets = list;
    }

    function add(type, screenName, screenW, screenH, bounds, avoid) {
        commit(withAdded(copy(), type, screenName, screenW, screenH, bounds, avoid));
    }

    function update(id, fields) {
        commit(withUpdated(copy(), id, fields));
    }

    function setOption(id, key, value) {
        commit(withOption(copy(), id, key, value));
    }

    function remove(id) {
        commit(withRemoved(copy(), id));
    }
}
