pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import "PomodoroStyles.js" as PomodoroStyles

// A running Pomodoro on the bar clock, drawn by one style of
// PomodoroStyles.js (indicators/*.qml). The clock places two of these: one
// `inline` next to the face (ring, countdown) and one `overlay` filling the
// button (underline); each shows only when the style's slot matches.
// `island` matches neither: the notch timers activity shows the Pomodoro.
Item {
    id: root

    property string style: "ring"
    property string slot: "inline"
    property bool vertical: false
    property color textColor: Colors.overBackground
    property int fontSize: 14
    property string fontFamily: ""
    // the Pomodoro row (TimersService.pomodoro); tests may pass their own
    property var pomodoro: TimersService.pomodoro

    readonly property var entry: PomodoroStyles.resolve(root.style)
    readonly property var view: PomodoroStyles.state(root.pomodoro)
    readonly property bool shown: root.view.active && root.entry.slot === root.slot
    readonly property color phaseColor: root.view.ringing ? Colors.error : (root.view.phase === "work" ? Colors.primary : Colors.tertiary)

    visible: root.shown
    implicitWidth: root.shown ? ((loader.item as Item)?.implicitWidth ?? 0) : 0
    implicitHeight: root.shown ? ((loader.item as Item)?.implicitHeight ?? 0) : 0

    function reload() {
        if (root.shown && root.entry.url !== "")
            loader.setSource(Qt.resolvedUrl(root.entry.url), {
                "indicator": root
            });
        else
            loader.source = "";
    }

    onShownChanged: root.reload()
    onEntryChanged: root.reload()
    Component.onCompleted: root.reload()

    Loader {
        id: loader
        objectName: "pomodoroIndicatorLoader"
        anchors.fill: root.slot === "overlay" ? parent : undefined
        anchors.centerIn: root.slot === "overlay" ? undefined : parent
    }
}
