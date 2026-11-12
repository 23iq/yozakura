.pragma library

// Catalog metadata of config/defaults/system.js (format: config/meta/Meta.js).

var description = "System integration: disks shown in metrics, UI language, update checks, idle/lock/sleep commands, OCR languages, pomodoro, timers/alarms/focus mode, clipboard storage and the file converter.";

var keys = {
    "disks": {
        "items": {
            "type": "string",
            "format": "path"
        },
        "description": "Mount points shown in the system metrics."
    },
    "language": {
        "description": "UI language code (en, es, ru, ...) or \"auto\" for the system locale."
    },
    "updateServiceEnabled": {
        "description": "Check for updates in the background."
    },
    "updateChannel": {
        "enum": ["stable", "beta", "git"],
        "description": "What `yozakura update` and the update notice follow: stable = X.Y.Z releases, beta = X.Y.Z-beta.N pre-releases and newer stable releases, git = every commit on main. Not used by Nix installs."
    },
    "idle": {
        "description": "Idle handling (hypridle-like): lock/sleep commands and timed listeners."
    },
    "idle.general.lock_cmd": {
        "format": "command",
        "description": "Command that locks the session."
    },
    "idle.general.before_sleep_cmd": {
        "format": "command",
        "description": "Command run before the system sleeps."
    },
    "idle.general.after_sleep_cmd": {
        "format": "command",
        "description": "Command run after the system wakes up."
    },
    "idle.listeners": {
        "description": "Idle listeners: [{timeout (s), onTimeout (command), onResume (command)}]."
    },
    "ocr.*": {
        "description": "Enable this OCR (tesseract) language."
    },
    "pomodoro.workTime": {
        "min": 60,
        "max": 14400,
        "unit": "s",
        "description": "Pomodoro work period."
    },
    "pomodoro.restTime": {
        "min": 60,
        "max": 7200,
        "unit": "s",
        "description": "Pomodoro rest period."
    },
    "pomodoro.autoStart": {
        "description": "Start the next pomodoro period automatically."
    },
    "pomodoro.syncSpotify": {
        "description": "Pause/resume Spotify with the pomodoro periods."
    },
    "timers.soundFile": {
        "format": "path",
        "description": "Alarm sound file for finished timers (empty: the built-in tone)."
    },
    "timers.noteTitle": {
        "description": "Title of the Notes inbox note the quick note bind appends to (empty: \"Inbox\" in the UI language)."
    },
    "clipboard.tmpfs": {
        "description": "Keep unpinned clipboard history in RAM (wiped on reboot)."
    },
    "converter.outputDir": {
        "format": "path",
        "description": "Folder the file converter writes results to (empty: next to each source file; ~ is expanded)."
    }
};
