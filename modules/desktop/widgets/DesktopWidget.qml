import QtQuick
import qs.modules.widgets.dashboard.widgets

// Base interface of the desktop-only widget types (see WidgetRegistry.js);
// types shared with the dashboard extend HostWidget directly and are loaded
// from the shared registry instead.
//
// WidgetFrame loads the type into a StyledRect surface (so `framed` is off)
// and passes:
//   widget   the placed entry {id, type, monitor, x, y, w, h, options}
//   options, ink, active, preview, k   see HostWidget
//   editing  edit desktop mode (content does not take input)
// and listens to optionChanged() to persist an option (e.g. the note text).
HostWidget {
    id: root

    property var widget: null
    property bool editing: false

    framed: false

    signal optionChanged(string key, var value)

    anchors.fill: parent
}
