pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import Quickshell

// Shell utility commands (bind actions of the "utilities" group, `<app>
// run <cmd>`), routed from GlobalShortcuts.run():
//   timer-input        notch hub: quick timer input
//   quick-note         notch hub: quick note capture
//   timers             notch hub with the list (also the clock click)
//   stopwatch-toggle   start / pause the stopwatch
//   focus-toggle       focus mode on / off (system.focus.minutes)
//   focus:<minutes>    start (or restart) focus mode; 0 = the default length
//   focus-stop         end focus mode now
//   timer-stop         stop every ringing timer
//   timer:<spec>       quick input line without the UI ("10m tea", "pomo")
//   routine:<id>       backend routines.run (svc/routines, sub-project E)
// run() returns false for commands it does not know.
Singleton {
    id: root

    function run(command) {
        const cmd = String(command || "");
        switch (cmd) {
        case "timer-input":
        case "timers":
            TimersService.toggleHub("timer", "");
            return true;
        case "quick-note":
            TimersService.toggleHub("note", "");
            return true;
        case "stopwatch-toggle":
            TimersService.stopwatchAction("toggle");
            return true;
        case "focus-toggle":
            FocusMode.toggle(0);
            return true;
        case "timer-stop":
            TimersService.dismiss("");
            return true;
        case "focus-stop":
            FocusMode.stop(false);
            return true;
        }
        if (cmd.indexOf("focus:") === 0) {
            const minutes = parseInt(cmd.substring(6), 10);
            FocusMode.start(minutes > 0 ? Math.min(minutes, 480) : 0);
            return true;
        }
        if (cmd.indexOf("timer:") === 0) {
            const spec = cmd.substring(6).trim();
            if (spec !== "")
                TimersService.quick(spec);
            return true;
        }
        if (cmd.indexOf("routine:") === 0) {
            const id = cmd.substring(8).trim();
            if (id !== "")
                BackendService.call("routines.run", {
                    "id": id
                }, (result, error) => {
                    if (error)
                        console.warn("routine", id, "failed:", error.message || error);
                });
            return true;
        }
        return false;
    }
}
