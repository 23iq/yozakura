pragma Singleton

import QtQuick
import qs.config

QtObject {
    // Icon font: the family of theme.icons.weight (all weights share codepoints)
    readonly property string font: families[Config.theme && Config.theme.icons ? Config.theme.icons.weight : ""] || "Phosphor-Bold"
    // Kept in sync with IconWeights.js (tests/icons-type.test.cjs); inline so harness copies of Icons.qml stay standalone.
    readonly property var families: ({
            "regular": "Phosphor",
            "fill": "Phosphor-Fill"
        })

    // Overview button
    readonly property string overview: ""

    // Layouts
    readonly property string layout: ""
    readonly property string dwindle: ""
    readonly property string master: ""
    readonly property string scrolling: ""
    readonly property string monocle: ""

    // Powermenu
    readonly property string lock: ""
    readonly property string suspend: ""
    readonly property string logout: ""
    readonly property string reboot: ""
    readonly property string shutdown: ""
    readonly property string hibernate: ""

    // Caret
    readonly property string caretLeft: ""
    readonly property string caretRight: ""
    readonly property string caretUp: ""
    readonly property string caretDown: ""
    readonly property string chartBar: "\ue150"

    readonly property string caretDoubleLeft: ""
    readonly property string caretDoubleRight: ""
    readonly property string caretDoubleUp: ""
    readonly property string caretDoubleDown: ""

    readonly property string caretLineLeft: ""
    readonly property string caretLineRight: ""
    readonly property string caretLineUp: ""
    readonly property string caretLineDown: ""

    // Dashboard
    readonly property string widgets: ""
    readonly property string kanban: ""
    readonly property string wallpapers: ""
    readonly property string assistant: ""
    readonly property string apps: ""
    readonly property string terminal: ""
    readonly property string terminalWindow: ""
    readonly property string clipboard: ""
    readonly property string emoji: ""
    readonly property string shortcut: ""
    readonly property string launch: ""
    readonly property string pin: ""
    readonly property string unpin: ""
    readonly property string popOpen: ""
    readonly property string hand: ""
    readonly property string handGrab: ""
    readonly property string heartbeat: ""
    readonly property string cpu: ""
    readonly property string gpu: ""
    readonly property string ram: ""
    readonly property string disk: ""
    readonly property string ssd: ""
    readonly property string hdd: ""
    readonly property string temperature: ""
    readonly property string at: ""
    readonly property string gear: ""
    readonly property string glassMinus: ""
    readonly property string glassPlus: ""
    readonly property string circuitry: ""
    readonly property string robot: ""
    readonly property string minusCircle: ""

    // Wi-Fi
    readonly property string wifiOff: ""
    readonly property string wifiNone: ""
    readonly property string wifiLow: ""
    readonly property string wifiMedium: ""
    readonly property string wifiHigh: ""
    readonly property string wifiX: ""

    // Bluetooth
    readonly property string bluetooth: ""
    readonly property string bluetoothConnected: ""
    readonly property string bluetoothOff: ""
    readonly property string bluetoothX: ""

    // Other Toggles
    readonly property string nightLight: ""
    readonly property string caffeine: ""
    readonly property string gameMode: ""

    // Toolbox
    readonly property string toolbox: ""
    readonly property string regionScreenshot: ""
    readonly property string windowScreenshot: ""
    readonly property string fullScreenshot: ""
    readonly property string screenshots: ""

    readonly property string recordScreen: ""
    readonly property string recordings: ""

    // Notifications
    readonly property string bell: ""
    readonly property string bellRinging: ""
    readonly property string bellSlash: ""
    readonly property string bellZ: ""

    // Player
    readonly property string play: ""
    readonly property string pause: ""
    readonly property string stop: ""
    readonly property string previous: ""
    readonly property string rewind: ""
    readonly property string forward: ""
    readonly property string next: ""
    readonly property string shuffle: ""
    readonly property string repeat: ""
    readonly property string repeatOnce: ""
    readonly property string player: ""
    readonly property string spotify: "<font face='Symbols Nerd Font Mono'>󰓇</font>"
    readonly property string firefox: "<font face='Symbols Nerd Font Mono'>󰈹</font>"
    readonly property string chromium: "<font face='Symbols Nerd Font Mono'></font>"
    readonly property string telegram: "<font face='Symbols Nerd Font Mono'></font>"

    // Clock
    readonly property string clock: ""
    readonly property string alarm: ""
    readonly property string timer: ""

    // Volume
    readonly property string speakerSlash: ""
    readonly property string speakerX: ""
    readonly property string speakerNone: ""
    readonly property string speakerLow: ""
    readonly property string speakerHigh: ""

    readonly property string mic: ""
    readonly property string micSlash: ""

    // Battery
    readonly property string lightning: ""
    readonly property string plug: ""

    // Power-profiles
    readonly property string powerSave: ""
    readonly property string power: ""
    readonly property string balanced: ""
    readonly property string performance: ""

    // Keyboard
    readonly property string keyboard: ""
    readonly property string backspace: ""
    readonly property string enter: ""
    readonly property string shift: ""
    readonly property string capsLock: ""
    readonly property string arrowUp: ""
    readonly property string arrowDown: ""
    readonly property string arrowLeft: ""
    readonly property string arrowRight: ""

    // Misc
    readonly property string accept: ""
    readonly property string cancel: ""
    readonly property string plus: ""
    readonly property string minus: ""
    readonly property string alert: ""
    readonly property string edit: ""
    readonly property string trash: ""
    readonly property string clip: ""
    readonly property string copy: ""
    readonly property string image: ""
    readonly property string broom: ""
    readonly property string xeyes: ""
    readonly property string seal: ""
    readonly property string info: ""
    readonly property string help: ""
    readonly property string sun: ""
    readonly property string sunDim: ""
    readonly property string moon: ""
    readonly property string user: ""
    readonly property string spinnerGap: ""
    readonly property string circleNotch: ""
    readonly property string file: ""
    readonly property string note: ""
    readonly property string notepad: ""
    readonly property string link: ""
    readonly property string globe: ""
    readonly property string folder: ""
    readonly property string cactus: ""
    readonly property string countdown: ""
    readonly property string sync: ""
    readonly property string cube: ""
    readonly property string picker: ""
    readonly property string textT: ""
    readonly property string qrCode: ""
    readonly property string webcam: ""
    readonly property string webcamSlash: ""
    readonly property string flipX: ""
    readonly property string crop: ""
    readonly property string arrowsOut: ""
    readonly property string alignLeft: ""
    readonly property string alignCenter: ""
    readonly property string alignRight: ""
    readonly property string alignJustify: ""
    readonly property string markdown: ""
    readonly property string faders: ""
    readonly property string paintBrush: ""
    readonly property string arrowCounterClockwise: ""
    readonly property string arrowFatLinesDown: ""
    readonly property string arrowsOutCardinal: ""
    readonly property string dotsThree: ""
    readonly property string dotsNine: ""
    readonly property string heart: "\ue2a8"
    readonly property string arrowSquareOut: "\ue5de"
    readonly property string circleHalf: ""

    readonly property string circle: ""
    readonly property string range: ""
    readonly property string cursor: ""

    readonly property string headphones: ""
    readonly property string mouse: ""
    readonly property string mouseLeftClick: "\uE334"
    readonly property string mouseRightClick: "\uE336"
    readonly property string mouseMiddleClick: "\uE338"
    readonly property string mouseScroll: "\uE332"
    readonly property string keyReturn: "\uE782"
    readonly property string calculator: "\uE538"
    readonly property string record: "\uE3EE"
    readonly property string musicNotes: "\uE340"
    readonly property string phone: ""
    readonly property string watch: ""
    readonly property string gamepad: ""
    readonly property string printer: ""
    readonly property string camera: ""
    readonly property string speaker: ""

    readonly property string batteryFull: ""
    readonly property string batteryHigh: ""
    readonly property string batteryMedium: ""
    readonly property string batteryLow: ""
    readonly property string batteryEmpty: ""
    readonly property string batteryCharging: ""

    readonly property string waveform: ""
    readonly property string sparkle: ""

    readonly property string ethernet: ""
    readonly property string router: ""
    readonly property string signalNone: ""
    readonly property string vpn: ""

    readonly property string shieldCheck: ""
    readonly property string shield: ""

    readonly property string list: ""
    readonly property string paperPlane: ""
    readonly property string compositor: ""
    readonly property string aperture: ""
    readonly property string magicWand: ""
    readonly property string google: ""

    readonly property string puzzlePiece: ""

    // Aliases for missing icons
    readonly property string palette: paintBrush
    readonly property string cornersOut: arrowsOut
    readonly property string drop: sparkle
    readonly property string arrowsOutSimple: arrowsOut
    readonly property string squaresFour: layout
    readonly property string mapPin: globe
    readonly property string thermometer: temperature
    readonly property string windowsLogo: terminalWindow
    readonly property string frameCorners: crop

    // Live activities
    readonly property string screencast: ""
    readonly property string downloadSimple: ""
    readonly property string monitor: ""

    // AI center
    readonly property string brain: "\uE74E"
    readonly property string gitDiff: "\uE27C"
    readonly property string folderOpen: "\uE256"
    readonly property string stopCircle: "\uE46E"
    readonly property string chatDots: "\uE16C"
    readonly property string checkCircle: "\uE184"
    readonly property string check: "\uE182"
    readonly property string packageBox: "\uE390"
    readonly property string wifiSlash: "\uE4F2"
    readonly property string xCircle: "\uE4F8"
    readonly property string warning: "\uE4E0"
    readonly property string code: "\uE1BC"
    readonly property string fileCode: "\uE914"
    readonly property string fileText: "\uE23A"
    readonly property string magnifyingGlass: "\uE30C"
    readonly property string translate: "\uE4A2"
    readonly property string wrench: "\uE5D4"
    readonly property string sidebarSimple: "\uEC24"
    readonly property string columns: "\uE546"
    readonly property string clockCounterClockwise: "\uE1A0"
    readonly property string arrowsInSimple: "\uE09E"
    readonly property string selection: "\uE69A"
    readonly property string cursorText: "\uE7D8"
    readonly property string eye: "\uE220"
    readonly property string pencil: "\uE3B4"
    readonly property string hourglass: "\uE2B2"
    readonly property string listChecks: "\uEADC"
    readonly property string plugsConnected: "\uEB5A"
    readonly property string calendar: "\uE108"
    readonly property string lightbulb: "\uE2DC"
    readonly property string bug: "\uE5F4"
    readonly property string paperPlaneRight: "\uE396"
    readonly property string appWindow: "\uE5DA"
    readonly property string gitBranch: "\uE278"
    readonly property string command: "\uE1C4"
    readonly property string clipboardText: "\uE198"
    readonly property string imageSquare: "\uE2CC"
    readonly property string shieldWarning: "\uE412"
    readonly property string lightningBolt: "\uE2DE"
    readonly property string notePencil: "\uE34C"
    readonly property string arrowElbowDownLeft: "\uE044"
    readonly property string scroll: "\uEB7A"
    readonly property string chatTeardrop: "\uE178"
    readonly property string arrowsClockwise: "\uE094"
    readonly property string flowArrow: "\uE6EC"
    readonly property string treeStructure: "\uE67C"
    readonly property string starIcon: "\uE46A"
    readonly property string caretUpDown: "\uE140"
    // Settings
    readonly property string search: ""
    readonly property string stack: ""
    readonly property string sidebar: ""
    readonly property string dock: ""
    readonly property string textAa: ""
}
