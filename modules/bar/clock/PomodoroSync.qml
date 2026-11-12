import QtQuick
import Quickshell.Io
import qs.modules.services
import qs.config
import "PomodoroOwner.js" as PomodoroOwner

// Non-visual Pomodoro glue owned by the bar clock (alive whether or not the
// panel or its pomodoro tile exists): the `pomodoro` IPC target and
// system.pomodoro.syncSpotify (Spotify plays during work, pauses otherwise).
// Every bar clock has one; only the owner (PomodoroOwner.js: the first
// alive) registers the IPC target and drives Spotify.
QtObject {
    id: root

    signal requestPanel

    // set by PomodoroOwner.js
    property bool owner: false

    readonly property var pomo: TimersService.pomodoro
    readonly property bool active: root.pomo !== null
    readonly property bool workPhase: !root.active || (root.pomo.pomodoro && root.pomo.pomodoro.phase === "work")
    readonly property bool sync: Config.system.pomodoro.syncSpotify
    readonly property var spotifyPlayer: MprisController.filteredPlayers.find(p => p.dbusName.toLowerCase().includes("spotify")) || null
    readonly property bool spotifyShouldPlay: root.active && root.pomo.state === "running" && root.workPhase

    onSpotifyShouldPlayChanged: root.updateSpotify()
    onSyncChanged: root.updateSpotify()

    Component.onCompleted: PomodoroOwner.claim(root)
    Component.onDestruction: PomodoroOwner.release(root)

    function updateSpotify() {
        const s = root.spotifyPlayer;
        if (!root.owner || !root.sync || !s || !root.active)
            return;
        if (root.spotifyShouldPlay && !s.isPlaying && s.canPlay)
            s.play();
        else if (!root.spotifyShouldPlay && s.isPlaying && s.canPause)
            s.pause();
    }

    property IpcHandler ipc: IpcHandler {
        target: "pomodoro"
        // a disabled handler does not register: no duplicate target warning
        enabled: root.owner
        function check() {
            root.requestPanel();
        }
        function stop() {
            if (root.active)
                TimersService.cancel(root.pomo.id);
        }
    }
}
