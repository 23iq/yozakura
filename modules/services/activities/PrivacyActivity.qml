pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.services.activities
import "ActivityModel.js" as Model
import "PrivacyDetect.js" as PrivacyDetect

// Privacy indicators: screen sharing (xdg-desktop-portal screencast),
// camera and microphone capture, each with the app(s) using it. Detection
// runs on PipeWire link groups (see PrivacyDetect.js); /dev/video* readers
// that bypass PipeWire come from CameraWatcher.
ActivityProvider {
    id: root

    source: "privacy"

    // Link groups only while enabled: no PipeWire tracking otherwise
    readonly property var linkGroups: active ? Pipewire.linkGroups.values : []

    // Nodes on both ends of links into streams; bound so their property
    // sets (media.class, application.name...) are valid
    readonly property var graphNodes: {
        const out = [];
        for (const group of linkGroups) {
            if (!group || !group.target || !group.source || !group.target.isStream)
                continue;
            if (out.indexOf(group.target) === -1)
                out.push(group.target);
            if (out.indexOf(group.source) === -1)
                out.push(group.source);
        }
        return out;
    }

    // Binding makes node properties and link group `state` valid
    PwObjectTracker {
        objects: root.graphNodes.concat(root.linkGroups)
    }

    CameraWatcher {
        id: cameraWatcher
        running: root.active
    }

    readonly property var detected: {
        if (!active)
            return [];
        const nodes = graphNodes.map(node => {
            const p = node.properties || {};
            return {
                id: node.id,
                mediaClass: p["media.class"] || "",
                appName: p["application.name"] || "",
                binary: p["application.process.binary"] || "",
                nodeName: node.name || p["node.name"] || "",
                deviceApi: p["device.api"] || (p["api.v4l2.path"] ? "v4l2" : "") || (p["api.libcamera.location"] ? "libcamera" : ""),
                mediaRole: p["media.role"] || "",
                captureSink: p["stream.capture.sink"] === true || p["stream.capture.sink"] === "true"
            };
        });
        const links = linkGroups.filter(g => g && g.source && g.target).map(g => ({
                    source: g.source.id,
                    target: g.target.id,
                    active: g.state === PwLinkState.Active
                }));
        // Our own recorder already has its own island
        const recordingShown = RecordingActivity.activities.length > 0;
        return PrivacyDetect.detect(nodes, links, {
            cameraUsers: cameraWatcher.users,
            excludeScreen: recordingShown ? ["gpu-screen-recorder"] : []
        });
    }

    readonly property var kinds: ({
            screen: {
                icon: Icons.screencast,
                priority: Model.PRIORITY.screenShare,
                color: "primary",
                detail: "activities.screen_shared"
            },
            camera: {
                icon: Icons.webcam,
                priority: Model.PRIORITY.camera,
                color: "green",
                detail: "activities.camera"
            },
            mic: {
                icon: Icons.mic,
                priority: Model.PRIORITY.microphone,
                color: "yellow",
                detail: "activities.microphone"
            }
        })

    // First time each kind was seen, so islands keep their order
    property var since: ({})

    onDetectedChanged: {
        const next = {};
        const now = Date.now();
        for (const d of detected)
            next[d.kind] = since[d.kind] || now;
        since = next;
    }

    activities: detected.map(d => {
        const k = kinds[d.kind];
        const muted = d.kind === "mic" && MicrophoneStatus.muted;
        return {
            id: "privacy:" + d.kind,
            category: "privacy",
            priority: k.priority,
            icon: muted ? Icons.micSlash : k.icon,
            indicator: "glyph",
            label: PrivacyDetect.appsLabel(d.apps),
            detail: I18n.t(k.detail) + " · " + d.apps.join(", "),
            color: muted ? "outline" : k.color,
            startedAt: since[d.kind] || 0,
            action: d.kind
        };
    })

    // Microphone: left click toggles mute, right click opens the audio
    // mixer. Camera and screen sharing have nothing to control; their
    // islands only show the apps in a tooltip.
    function activate(activity, button, screenName) {
        if (activity.action !== "mic")
            return;
        if (button === Qt.RightButton) {
            GlobalStates.settingsCurrentTab = 2;
            if (!GlobalStates.settingsWindowVisible)
                GlobalShortcuts.toggleSettings(screenName);
            return;
        }
        if (Audio.source && Audio.source.audio)
            Audio.source.audio.muted = !Audio.source.audio.muted;
    }
}
