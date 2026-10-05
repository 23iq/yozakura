pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.globals
import qs.config
import qs.modules.settings.controls

// Loops the real wallpaper transition shader between two of your
// wallpapers with the selected style and duration.
PreviewStage {
    id: root

    property var entry
    readonly property string style: Config.desktop.wallpaperTransition ?? "grow"
    readonly property int duration: Config.desktop.wallpaperTransitionDuration ?? 800
    // Same order as Wallpaper.qml's `modes`.
    readonly property var modes: ["fade", "grow", "wipe", "dissolve"]
    readonly property var sources: pickSources()
    property bool forward: true
    property int mode: 1
    property real progress: 0

    stageHeight: Math.round(Math.min(width * 0.36, 230))

    function stillSource(path) {
        const m = GlobalStates.wallpaperManager;
        if (!path)
            return "";
        if (m && m.getFileType && m.getFileType(path) !== "image")
            return "file://" + m.getDisplaySource(path);
        return "file://" + path;
    }

    function pickSources() {
        const m = GlobalStates.wallpaperManager;
        const list = m ? (m.wallpaperPaths || []) : [];
        const cur = m ? (m.currentWallpaper || "") : "";
        const images = list.filter(p => /\.(jpe?g|png|webp)$/i.test(p) && p !== cur);
        const first = cur || images[0] || "";
        const second = images.length > 0 ? images[Math.floor(images.length / 2)] : "";
        return [stillSource(first), stillSource(second)];
    }

    function start() {
        let s = style;
        if (s === "random")
            s = modes[1 + Math.floor(Math.random() * (modes.length - 1))];
        mode = Math.max(0, modes.indexOf(s));
        shader.seed = Math.random() * 100;
        progress = 0;
        if (style === "none") {
            forward = !forward;
            return;
        }
        anim.restart();
    }

    onStyleChanged: start()

    Timer {
        interval: (root.style === "none" ? 0 : root.duration) + 1300
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.start()
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Math.max(1, root.duration)
        easing.type: root.mode === 0 ? Easing.InOutSine : Easing.InOutCubic
        onFinished: {
            root.forward = !root.forward;
            root.progress = 0;
        }
    }

    ClippingRectangle {
        id: stage
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, Math.min(Styling.radius(2), 18) - 1)
        color: "transparent"

        Image {
            id: imageA
            anchors.fill: parent
            source: root.sources[0]
            sourceSize.width: 720
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        Image {
            id: imageB
            anchors.fill: parent
            source: root.sources[1] || root.sources[0]
            sourceSize.width: 720
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        ShaderEffectSource {
            id: fromTex
            sourceItem: root.forward ? imageA : imageB
            hideSource: true
            visible: false
        }
        ShaderEffectSource {
            id: toTex
            sourceItem: root.forward ? imageB : imageA
            hideSource: true
            visible: false
        }

        ShaderEffect {
            id: shader
            anchors.fill: parent
            property var fromSource: fromTex
            property var toSource: toTex
            property real progress: root.progress
            property real mode: root.mode
            property real aspect: height > 0 ? width / height : 1
            property point origin: Qt.point(0.62, 0.45)
            property real angle: 0.35
            property real seed: 0
            fragmentShader: Qt.resolvedUrl("../../widgets/dashboard/wallpapers/wallpaper_transition.frag.qsb")
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.sources[0] === ""
        text: Icons.image
        font.family: Icons.font
        font.pixelSize: 36
        color: Colors.overSurfaceVariant
    }
}
