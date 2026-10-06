import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import "PowerActions.js" as PowerActions

// The power actions for a style: `items` ({id, icon, label, hold, argv,
// confirm}), run(index), which starts the command detached and emits done(),
// and `caption` ("up 2h 05m · user@host", "" when unreadable; refresh()
// re-reads it when a menu opens).
Item {
    id: root

    readonly property var items: PowerActions.build(Brand.daemonArgs(["system", "exit"]), k => I18n.t(k), Icons)
    property string session: ""
    readonly property string caption: PowerActions.caption(root.session, Quickshell.env("USER") || "", I18n.t("powermenu.uptime"))

    signal done

    function run(index) {
        const item = root.items[index];
        if (!item || !item.argv || item.argv.length === 0)
            return;
        Quickshell.execDetached(item.argv);
        root.done();
    }

    function refresh() {
        info.running = true;
    }

    visible: false

    Process {
        id: info
        command: ["cat", "/proc/uptime", "/proc/sys/kernel/hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.session = text
        }
    }
}
