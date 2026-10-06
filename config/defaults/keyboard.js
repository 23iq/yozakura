.pragma library

// Keyboard layouts, layout switching and key repeat. Rendered into the
// compositor config by the backend and applied live by KeyboardService, but
// only once `managed` is set: until the user changes the keyboard in
// Yozakura, the compositor's own settings stay in effect (the first change
// copies them in first). Personal: presets never carry it.
var data = {
    "managed": false,
    "layouts": [
        {
            "layout": "us",
            "variant": ""
        }
    ],
    "switchBind": "alt_shift",
    "options": [],
    "repeatRate": 25,
    "repeatDelay": 600,
    "showIndicator": true
}
