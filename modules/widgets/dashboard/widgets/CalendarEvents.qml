import QtQuick
import Quickshell.Io
import "CalendarModel.js" as CalendarModel

// Upcoming events from the user's calendars through khal (vdirsyncer /
// CalDAV / local .ics). Without khal there is no source: `available` stays
// false and the calendar widget shows the month only. Refreshes every 15
// minutes, only while `active`.
Item {
    id: root

    property bool active: false
    property int days: 14
    property int limit: 4
    property bool available: false
    property var events: []

    function refresh() {
        if (available && active && !list.running)
            list.running = true;
    }

    onActiveChanged: refresh()
    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["sh", "-c", "command -v khal >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                root.refresh();
            }
        }
    }

    Process {
        id: list
        command: ["khal", "list", "today", root.days + "d", "--day-format", "", "--format", "{start-date}\t{start-time}\t{title}"]
        stdout: StdioCollector {
            onStreamFinished: root.events = CalendarModel.parseKhal(text, root.limit)
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.active && root.available
        onTriggered: root.refresh()
    }
}
