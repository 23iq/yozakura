import QtQuick
import qs.modules.theme
import qs.config

// Base interface of every desktop widget type (see WidgetRegistry.js).
//
// WidgetFrame loads the type into a StyledRect surface and passes:
//   widget   the placed entry {id, type, monitor, x, y, w, h, options}
//   options  its options with registry defaults filled in
//   ink      text colour of the surface variant (sr* itemColor)
//   active   on screen and not hidden by windows: poll/animate only then
//   preview  drawn in settings (no side effects, no persistence)
//   editing  edit desktop mode (content does not take input)
//   k        scale factor: the widget's size vs its registry default, so
//            text grows when the widget is resized
// and listens to optionChanged() to persist an option (e.g. the note text).
Item {
    id: root

    property var widget: null
    property var options: ({})
    property color ink: Colors.overBackground
    readonly property color inkSoft: Qt.rgba(ink.r, ink.g, ink.b, 0.68)
    readonly property color inkFaint: Qt.rgba(ink.r, ink.g, ink.b, 0.14)
    property bool active: true
    property bool preview: false
    property bool editing: false
    property real k: 1

    // Padding inside the surface, scaled with the widget.
    readonly property real pad: Math.round(16 * k)
    readonly property string font: Config.theme.font

    signal optionChanged(string key, var value)

    // Font size: the theme size (offset like Styling.fontSize) a bit larger
    // than in panels, since widgets are read from further away, times k.
    function px(offset) {
        return Math.max(8, Math.round(Styling.fontSize(offset) * 1.2 * k));
    }

    anchors.fill: parent
}
