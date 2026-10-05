.pragma library
.import "../../globals/BrandActions.js" as BrandActions

// Pure privacy detection over a PipeWire graph snapshot. Unit tested in
// tests/activities.test.cjs.
//
// nodes: [{ id, mediaClass, appName, binary, nodeName, deviceApi, mediaRole, captureSink }]
// links: [{ source, target, active }]   (node ids; one per link group)
// opts:  { cameraUsers: [binary], ignore: [name], excludeScreen: [name] }
//
// A capture happens when an *active* link feeds an input stream
// (Stream/Input/Audio|Video) from a real source node:
//   Audio/Source*  -> microphone (sink monitors, e.g. cava, are ignored)
//   Video/Source from v4l2/libcamera -> camera
//   any other Video/Source (xdg-desktop-portal screencast) -> screen sharing

var KINDS = ["screen", "camera", "mic"];

// Shell internals, mixers and graph tools: they open streams constantly
var DEFAULT_IGNORE = ["cava", "quickshell", "qs", BrandActions.appId, BrandActions.legacyAppId, "pavucontrol", "pwvucontrol", "easyeffects", "helvum", "qpwgraph", "coppwr", "wireplumber", "pipewire", "pipewire-pulse", "xdg-desktop-portal", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-wlr", "xdg-desktop-portal-gnome", "xdg-desktop-portal-kde"];

// application.name values that say nothing about the app
var GENERIC_NAME = /webrtc|voiceengine|^alsa plug-in|^pulseaudio|^pipewire|^portal|^libcamera|^speech-dispatcher/i;

function lower(s) {
    return s === undefined || s === null ? "" : String(s).toLowerCase();
}

function prettify(binary) {
    var b = String(binary || "").replace(/\.(bin|exe|AppImage)$/i, "").replace(/[-_]+/g, " ").trim();
    if (!b)
        return "";
    return b.charAt(0).toUpperCase() + b.slice(1);
}

// Human name of the app that owns a stream node
function appLabel(node) {
    var name = node.appName || "";
    if (!name || GENERIC_NAME.test(name))
        name = prettify(node.binary) || name || node.nodeName || "";
    return name;
}

function isIgnored(node, ignore) {
    var keys = [lower(node.binary), lower(node.appName), lower(node.nodeName)];
    for (var i = 0; i < ignore.length; i++) {
        var ig = lower(ignore[i]);
        if (ig && keys.indexOf(ig) !== -1)
            return true;
    }
    return false;
}

function isCameraSource(node) {
    var api = lower(node.deviceApi);
    var name = lower(node.nodeName);
    return api === "v4l2" || api === "libcamera" || lower(node.mediaRole) === "camera" || name.indexOf("v4l2_") === 0 || name.indexOf("libcamera") === 0;
}

function classify(source, target) {
    var tClass = String(target.mediaClass || "");
    var sClass = String(source.mediaClass || "");
    if (tClass.indexOf("Stream/Input/Audio") === 0) {
        if (target.captureSink)
            return "";
        return sClass.indexOf("Audio/Source") === 0 ? "mic" : "";
    }
    if (tClass.indexOf("Stream/Input/Video") === 0 && sClass.indexOf("Video/Source") === 0)
        return isCameraSource(source) ? "camera" : "screen";
    return "";
}

function pushUnique(list, value) {
    if (value && list.indexOf(value) === -1)
        list.push(value);
}

// Returns [{ kind, apps: [label], streams: [nodeId] }] ordered screen,
// camera, mic; kinds without users are omitted.
function detect(nodes, links, opts) {
    var o = opts || {};
    var ignore = DEFAULT_IGNORE.concat(o.ignore || []);
    var excludeScreen = o.excludeScreen || [];
    var byId = {};
    for (var i = 0; i < (nodes || []).length; i++)
        byId[nodes[i].id] = nodes[i];

    var found = {
        screen: { apps: [], streams: [] },
        camera: { apps: [], streams: [] },
        mic: { apps: [], streams: [] }
    };

    for (var j = 0; j < (links || []).length; j++) {
        var link = links[j];
        if (!link || !link.active)
            continue;
        var source = byId[link.source];
        var target = byId[link.target];
        if (!source || !target || isIgnored(target, ignore))
            continue;
        var kind = classify(source, target);
        if (!kind)
            continue;
        if (kind === "screen" && isIgnored(target, excludeScreen))
            continue;
        pushUnique(found[kind].apps, appLabel(target));
        pushUnique(found[kind].streams, target.id);
    }

    // Apps reading /dev/video* directly (browsers, Zoom) bypass PipeWire
    var users = o.cameraUsers || [];
    for (var k = 0; k < users.length; k++) {
        var user = { binary: users[k], appName: "", nodeName: "" };
        if (!isIgnored(user, ignore))
            pushUnique(found.camera.apps, prettify(users[k]));
    }

    var out = [];
    for (var n = 0; n < KINDS.length; n++) {
        var entry = found[KINDS[n]];
        if (entry.apps.length > 0)
            out.push({
                kind: KINDS[n],
                apps: entry.apps,
                streams: entry.streams
            });
    }
    return out;
}

// "Firefox", "Firefox +2"
function appsLabel(apps) {
    if (!apps || apps.length === 0)
        return "";
    return apps.length === 1 ? apps[0] : apps[0] + " +" + (apps.length - 1);
}

// Parse `find /proc/<pid>/fd -lname '/dev/video*'` style output where each
// line is "<pid> <comm>"; returns unique process names.
function parseCameraUsers(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line)
            continue;
        var space = line.indexOf(" ");
        var comm = space === -1 ? line : line.slice(space + 1).trim();
        pushUnique(out, comm);
    }
    return out;
}
