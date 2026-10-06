import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import "PowerActions.js" as PowerActions

// The power actions for a style: `items` ({id, icon, label, argv, confirm})
// and run(index), which starts the command detached and emits done().
QtObject {
    id: root

    readonly property var items: PowerActions.build(Brand.daemonArgs(["system", "exit"]), k => I18n.t(k), Icons)

    signal done

    function run(index) {
        const item = root.items[index];
        if (!item || !item.argv || item.argv.length === 0)
            return;
        Quickshell.execDetached(item.argv);
        root.done();
    }
}
