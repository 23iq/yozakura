import QtQuick
import Quickshell
import qs.config
import qs.modules.bar.panels
import "../notifications/NotificationPolicy.js" as Policy
import "../bar/panels/PanelLayout.js" as PanelLayout

// Notification policy state for Notifications.qml (config notifications.*):
// Do Not Disturb (manual + schedule, re-checked every 30 s), resolved
// presentation and corner, the screens filter, per-notification decisions
// (NotificationPolicy.decide) and the notification sound.
QtObject {
    id: root

    readonly property var cfg: Config.notifications

    // DND: turning it off while the schedule is active skips the rest of
    // that window.
    property bool scheduleActive: false
    property bool scheduleSkipped: false
    readonly property bool silent: !!(cfg && cfg.dnd && cfg.dnd.enabled) || (scheduleActive && !scheduleSkipped)
    onScheduleActiveChanged: if (!scheduleActive)
        scheduleSkipped = false

    function refreshSchedule() {
        root.scheduleActive = Policy.inSchedule(root.cfg && root.cfg.dnd ? root.cfg.dnd.schedule : null, new Date());
    }

    property Timer scheduleTimer: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSchedule()
    }

    property Connections scheduleWatcher: Connections {
        target: root.cfg && root.cfg.dnd ? root.cfg.dnd.schedule : null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root.refreshSchedule();
        }
        function onFromChanged() {
            root.refreshSchedule();
        }
        function onToChanged() {
            root.refreshSchedule();
        }
        function onDaysChanged() {
            root.refreshSchedule();
        }
    }

    function setDnd(on) {
        if (!root.cfg || !root.cfg.dnd)
            return;
        root.cfg.dnd.enabled = !!on;
        if (!on && root.scheduleActive)
            root.scheduleSkipped = true;
        Config.saveNotifications();
    }

    function toggleDnd() {
        root.setDnd(!root.silent);
    }

    // The panel the notch pairs with (bar.panels): its style decides "auto"
    readonly property var primaryPanel: {
        const list = (Panels.all || []).filter(p => p.enabled);
        const i = PanelLayout.primaryIndex(list, Panels.notchEdge);
        return i === -1 ? null : list[i];
    }
    readonly property string presentation: Policy.resolvePresentation(cfg ? cfg.presentation : "auto", {
        "barStyle": primaryPanel ? primaryPanel.style : "",
        "barPosition": primaryPanel ? primaryPanel.edge : Panels.notchEdge,
        "notchPosition": Panels.notchEdge
    })
    readonly property string cornerPosition: Policy.resolvePosition(cfg ? cfg.position : "auto", {
        "barPosition": Panels.primaryEdge
    })

    function showsOnScreen(name) {
        return Policy.showsOnScreen(root.cfg ? root.cfg.screens : [], name);
    }

    // Plain snapshot of the policy config (JsonObject -> JS) for decide().
    function policyConfig() {
        const c = root.cfg;
        if (!c)
            return {};
        return {
            "timeout": c.timeout,
            "rules": JSON.parse(JSON.stringify(c.rules || [])),
            "sound": {
                "enabled": c.sound ? c.sound.enabled : false
            },
            "dnd": {
                "allowCritical": c.dnd ? c.dnd.allowCritical : true
            }
        };
    }

    // {popup, sound, priority, timeout} for a new notification
    // ({appName, desktopEntry, urgency, expireTimeout}).
    function decide(info) {
        return Policy.decide(root.policyConfig(), info, root.silent);
    }

    readonly property string defaultSound: Quickshell.shellDir + "/assets/sound/notification-chime.wav"
    // Honours the app's freedesktop sound hints (Policy.soundRequest):
    // suppress-sound -> silence, sound-name -> sound theme via canberra,
    // sound-file -> that file; otherwise (or when those fail) the shell tone.
    function playSound(hints) {
        const req = Policy.soundRequest(hints);
        if (!req)
            return;
        const tone = root.cfg && root.cfg.sound && root.cfg.sound.file ? root.cfg.sound.file : root.defaultSound;
        Quickshell.execDetached(["sh", "-c", '[ -n "$1" ] && command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i "$1" 2>/dev/null && exit 0; f=$2; [ -r "$f" ] || f=$3; command -v pw-play >/dev/null && exec pw-play "$f"; command -v paplay >/dev/null && exec paplay "$f"', "notify-sound", req.name || "", req.file || "", tone]);
    }
}
