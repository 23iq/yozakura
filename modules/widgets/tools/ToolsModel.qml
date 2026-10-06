import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.config

// The tools menu's actions for every style: `items` ({id, icon, label,
// tooltip, active, text} plus {type: "separator"} rows for the notch strip)
// and run(id). Screen tools start after the menu has closed (`done` first).
Item {
    id: root

    readonly property bool recording: ScreenRecorder.isRecording
    readonly property var items: [root.entry("screenshot", Icons.camera, "tools.screenshot"), root.entry("screenshots", Icons.screenshots, "tools.screenshot_directory"),
        {
            "type": "separator"
        },
        Object.assign(root.entry("record", root.recording ? Icons.stop : Icons.recordScreen, root.recording ? "tools.screenrecord_stop" : "tools.screenrecord_start"), {
            "text": root.recording ? ScreenRecorder.duration : "",
            "active": root.recording
        }), root.entry("recordings", Icons.recordings, "tools.screenrecord_directory"),
        {
            "type": "separator"
        },
        root.entry("picker", Icons.picker, "tools.color_picker"), root.entry("ocr", Icons.textT, "tools.ocr"), root.entry("qr", Icons.qrCode, "tools.qr"), root.entry("lens", Icons.google, "tools.google_lens"), root.entry("mirror", GlobalStates.mirrorWindowVisible ? Icons.webcamSlash : Icons.webcam, "tools.mirror")]
    readonly property var actions: root.items.filter(i => i.type !== "separator")

    signal done

    function entry(id, icon, key) {
        return {
            "id": id,
            "icon": icon,
            "label": I18n.t(key),
            "tooltip": I18n.t(key),
            "command": ""
        };
    }

    function openFolder(dir) {
        Quickshell.execDetached(["xdg-open", dir]);
    }

    function capture(mode) {
        if (mode !== "lens")
            Screenshot.initialize();
        delayed.pendingMode = mode;
        delayed.restart();
    }

    function run(id) {
        switch (id) {
        case "screenshot":
            root.capture("");
            break;
        case "record":
            if (root.recording) {
                ScreenRecorder.toggleRecording();
            } else {
                ScreenRecorder.initialize();
                GlobalStates.screenRecordToolVisible = true;
            }
            break;
        case "screenshots":
            Screenshot.initialize();
            root.openFolder(Screenshot.screenshotsDir !== "" ? Screenshot.screenshotsDir : Quickshell.env("HOME") + "/Pictures/Screenshots");
            break;
        case "recordings":
            ScreenRecorder.initialize();
            root.openFolder(ScreenRecorder.videosDir !== "" ? ScreenRecorder.videosDir : Quickshell.env("HOME") + "/Videos/Recordings");
            break;
        case "picker":
            Quickshell.execDetached([Brand.appId, "colorpicker"]);
            break;
        case "ocr":
        case "qr":
        case "lens":
            root.capture(id);
            break;
        case "mirror":
            GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible;
            return;
        default:
            return;
        }
        root.done();
    }

    // Starts the screenshot tool once the menu's close animation is over
    Timer {
        id: delayed
        property string pendingMode: ""
        interval: Motion.exit.duration + 150
        onTriggered: {
            if (pendingMode !== "")
                Screenshot.captureMode = pendingMode;
            pendingMode = "";
            GlobalStates.screenshotToolVisible = true;
        }
    }
}
