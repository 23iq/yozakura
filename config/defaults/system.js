.pragma library

var data = {
    "disks": ["/"],
    "language": "auto",
    "updateServiceEnabled": true,
    "idle": {
        "general": {
            "lock_cmd": "yozakura lock",
            "before_sleep_cmd": "loginctl lock-session",
            "after_sleep_cmd": "yozakura screen on"
        },
        "listeners": [
            {
                "timeout": 150,
                "onTimeout": "yozakura brightness 10 -s",
                "onResume": "yozakura brightness -r"
            },
            {
                "timeout": 300,
                "onTimeout": "loginctl lock-session"
            },
            {
                "timeout": 330,
                "onTimeout": "yozakura screen off",
                "onResume": "yozakura screen on"
            },
            {
                "timeout": 1800,
                "onTimeout": "yozakura suspend"
            }
        ]
    },
    "ocr": {
        "eng": true,
        "spa": true,
        "lat": false,
        "jpn": false,
        "chi_sim": false,
        "chi_tra": false,
        "kor": false,
        "rus": false
    },
    "pomodoro": {
        "workTime": 1500,
        "restTime": 300,
        "autoStart": false,
        "syncSpotify": false
    },
    "timers": {
        "notchStyle": "ring",
        "showSeconds": true,
        "pulseOnFinish": true,
        "alarmPanel": true,
        "sound": true,
        "soundFile": "",
        "alarmRepeat": 3,
        "alarmInterval": 4,
        "phaseSound": true,
        "showStopwatch": true,
        "reminderLead": 15,
        "clockClick": "popup",
        "noteTitle": ""
    },
    "focus": {
        "minutes": 50,
        "dnd": true,
        "hideBadges": true,
        "summary": true
    },
    "clipboard": {
        "tmpfs": false
    }
}
