import QtQuick
import Quickshell
import qs.config

// Timer alarm sound (system.timers.sound*): rings the tone now and then
// every `soundInterval` seconds, `alarmRepeat` times in all (0 = until
// stop()). cue() plays the soft notification chime once (Pomodoro phase
// changes). Plays through pw-play or paplay; the file is argv data.
QtObject {
    id: player

    readonly property var cfg: Config.system ? Config.system.timers : null
    readonly property bool enabled: player.cfg ? player.cfg.sound !== false : true
    readonly property string defaultTone: Quickshell.shellDir + "/assets/sound/polite-warning-tone.wav"
    readonly property string chime: Quickshell.shellDir + "/assets/sound/notification-chime.wav"
    readonly property string tone: player.cfg && player.cfg.soundFile ? player.cfg.soundFile : player.defaultTone
    readonly property int repeat: player.cfg ? Math.max(0, player.cfg.alarmRepeat) : 3
    readonly property int interval: player.cfg ? Math.max(1, player.cfg.alarmInterval) : 4

    property bool ringing: false
    property int played: 0

    function play(file) {
        Quickshell.execDetached(["sh", "-c", 'f=$1; [ -r "$f" ] || f=$2; command -v pw-play >/dev/null && exec pw-play "$f"; command -v paplay >/dev/null && exec paplay "$f"', "timer-alarm", file, player.defaultTone]);
    }

    function start() {
        if (!player.enabled)
            return;
        player.ringing = true;
        player.played = 1;
        player.play(player.tone);
        player.repeater.restart();
    }

    function stop() {
        player.ringing = false;
        player.repeater.stop();
    }

    function cue() {
        if (player.enabled && (player.cfg ? player.cfg.phaseSound !== false : true))
            player.play(player.chime);
    }

    property Timer repeater: Timer {
        interval: player.interval * 1000
        repeat: true
        onTriggered: {
            if (!player.ringing || (player.repeat > 0 && player.played >= player.repeat)) {
                player.stop();
                return;
            }
            player.played++;
            player.play(player.tone);
        }
    }
}
