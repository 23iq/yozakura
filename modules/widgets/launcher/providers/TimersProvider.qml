import QtQuick
import qs.modules.theme
import qs.modules.services
import "../../../services/timers/TimerFormat.js" as TimerFormat
import "../../../services/timers/QuickInput.js" as QuickInput

// "t " prefix (prefix.timers): the notch quick input in the launcher.
// Empty: the running timers (Enter opens the timers hub) and a hint;
// "10m tea", "1h30", "18:00 call mom", "sw", "pomo 50 10": live preview
// from timers.parse, Enter runs timers.quick; "focus 50" starts focus
// mode, "note <text>" appends to the notes inbox.
LauncherProvider {
    id: timers

    property string pending: ""

    property Timer debounce: Timer {
        interval: 120
        onTriggered: timers.runParse()
    }

    function hintRow() {
        return {
            "key": "hint",
            "title": I18n.t("launcher.timers.hint"),
            "subtitle": I18n.t("launcher.timers.hint.desc"),
            "icon": Icons.timer,
            "inert": true
        };
    }

    function timerRows() {
        return TimersService.timers.map(t => ({
                    "key": "timer:" + t.id,
                    "title": TimerFormat.timerTitle(t, I18n.t),
                    "subtitle": t.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.clock(t.leftMs) + (t.state === "paused" ? "  ·  " + I18n.t("timers.paused") : ""),
                    "icon": t.ringing ? Icons.alarm : Icons.timer,
                    "badge": I18n.t("launcher.provider.timers"),
                    "hint": I18n.t("launcher.timers.open"),
                    "data": {
                        "action": "open"
                    }
                }));
    }

    function search(text, searchMode) {
        timers.query = text;
        timers.mode = searchMode;
        const q = (text || "").trim();
        const c = QuickInput.classify(q, "timer");
        timers.debounce.stop();
        if (c.kind === "empty") {
            timers.pending = "";
            timers.results = timers.timerRows().concat([timers.hintRow()]);
            return;
        }
        if (c.kind === "focus") {
            const minutes = c.minutes > 0 ? c.minutes : FocusMode.defaultMinutes;
            timers.results = [
                {
                    "key": "focus",
                    "title": FocusMode.active ? I18n.t("focus.stop") : I18n.t("focus.start_for", minutes),
                    "subtitle": I18n.t("focus.desc"),
                    "icon": Icons.brain,
                    "badge": I18n.t("focus.title"),
                    "hint": I18n.t("launcher.timers.start"),
                    "data": {
                        "action": "focus",
                        "minutes": minutes
                    }
                }
            ];
            return;
        }
        if (c.kind === "note") {
            timers.results = [
                {
                    "key": "note",
                    "title": c.text,
                    "subtitle": I18n.t("quicknote.add_to", QuickNote.title),
                    "icon": Icons.notePencil,
                    "badge": I18n.t("quicknote.title"),
                    "hint": I18n.t("quicknote.save"),
                    "data": {
                        "action": "note",
                        "text": c.text
                    }
                }
            ];
            return;
        }
        timers.pending = c.text;
        timers.busy = true;
        timers.debounce.restart();
    }

    function runParse() {
        const q = timers.pending;
        if (q === "")
            return;
        TimersService.parse(q, (intent, error) => {
            if (q !== timers.pending)
                return;
            timers.busy = false;
            const p = TimerFormat.preview(intent, I18n.t, TimersService.use12h);
            timers.results = p ? [
                {
                    "key": "quick",
                    "title": p.text,
                    "subtitle": q,
                    "icon": Icons[p.icon] || Icons.timer,
                    "badge": I18n.t("launcher.provider.timers"),
                    "hint": I18n.t("launcher.timers.start"),
                    "data": {
                        "action": "quick",
                        "text": q
                    }
                }
            ] : [
                {
                    "key": "error",
                    "title": I18n.t("timers.input.invalid"),
                    "subtitle": error || I18n.t("launcher.timers.hint.desc"),
                    "icon": Icons.warning,
                    "inert": true
                }
            ];
        });
    }

    function activate(item, option) {
        if (!item || item.inert || !item.data)
            return false;
        const d = item.data;
        if (d.action === "quick")
            TimersService.quick(d.text);
        else if (d.action === "focus")
            Qt.callLater(() => FocusMode.toggle(d.minutes));
        else if (d.action === "note")
            QuickNote.add(d.text);
        else if (d.action === "open")
            Qt.callLater(() => TimersService.openHub("timer", ""));
        return true;
    }
}
