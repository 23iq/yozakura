import QtQuick
import Quickshell.Io
import qs.modules.services
import qs.config

// Non-visual Pomodoro glue owned by the bar clock (alive whether or not the
// panel or its pomodoro tile exists): the `pomodoro` IPC target and
// system.pomodoro.syncSpotify (Spotify plays during work, pauses otherwise).
QtObject {
    id: root

    signal requestPanel

    readonly property var pomo: TimersService.pomodoro
    readonly property bool active: root.pomo !== null
    readonly property bool workPhase: !root.active || (root.pomo.pomodoro && root.pomo.pomodoro.phase === "work")
    readonly property bool sync: Config.system.pomodoro.syncSpotify
    readonly property var spotifyPlayer: MprisController.filteredPlayers.find(p => p.dbusName.toLowerCase().includes("spotify")) || null
    readonly property bool spotifyShouldPlay: root.active && root.pomo.state === "running" && root.workPhase

    onSpotifyShouldPlayChanged: root.updateSpotify()
    onSyncChanged: root.updateSpotify()

    function updateSpotify() {
        const s = root.spotifyPlayer;
        if (!root.sync || !s || !root.active)
            return;
        if (root.spotifyShouldPlay && !s.isPlaying && s.canPlay)
            s.play();
        else if (!root.spotifyShouldPlay && s.isPlaying && s.canPause)
            s.pause();
    }

    property IpcHandler ipc: IpcHandler {
        target: "pomodoro"
        function check() {
            root.requestPanel();
        }
        function stop() {
            if (root.active)
                TimersService.cancel(root.pomo.id);
        }
    }
}
