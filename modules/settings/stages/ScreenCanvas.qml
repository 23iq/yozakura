pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings
import "../live/LiveKeys.js" as LiveKeys

// The Screen destination's canvas (two panes): the whole screen as it is
// laid out (every bar, the island, the dock, the frame, on your wallpaper).
// One canvas serves every Screen tab (SettingsPageHost keeps it while the
// tabs change): a tab only changes `part`, which is ringed; the whole
// monitor always stays in frame (never cropped by a zoom). Every other
// part is a click away (a bar opens the Bar tab and picks it, the island
// and the dock their tabs; on the Bar tab a module scrolls to its card).
// Under it a loupe, the tab's own stage at a readable scale (the bar strip,
// the island in its states, the dock); the desktop and the lock screen
// tabs draw their stage over the canvas instead (the same screen, its
// widgets shown, or locked). Each tab's stage is built once and kept, so
// going back to a tab never rebuilds it; parts cross-fade.
Item {
    id: canvas
    objectName: "screenCanvas"

    // "bar" | "island" | "dock" | "desktop" | "lock": the part this tab edits
    property string part: "bar"
    // the tab's own stage (the loupe, or the cover), by URL
    property string loupeUrl: ""
    // the pointer is over the canvas (the page shows its hint meanwhile)
    readonly property bool hovered: hover.hovered

    readonly property var parts: ["bar", "island", "dock", "desktop", "lock"]
    // part -> stage URL, filled as tabs are visited (kept)
    property var urls: ({})
    onPartChanged: canvas.remember()
    onLoupeUrlChanged: canvas.remember()
    // a tab shows: its part and its stage at once
    function show(part, url) {
        // a new part: what is under the canvas takes its height at once
        // (its stage cross-fades in; only a change within a tab eases)
        switchHold.restart();
        canvas.loupeUrl = "";
        canvas.part = part;
        canvas.loupeUrl = url;
    }
    Component.onCompleted: {
        canvas.remember();
        Qt.callLater(() => canvas.ready = true);
    }
    function remember() {
        if (canvas.loupeUrl === "" || canvas.urls[canvas.part] === canvas.loupeUrl)
            return;
        const u = Object.assign({}, canvas.urls);
        u[canvas.part] = canvas.loupeUrl;
        canvas.urls = u;
    }

    // past the first placement (later height changes ease)
    property bool ready: false
    readonly property bool covered: canvas.part === "desktop" || canvas.part === "lock"
    readonly property Item current: loupes.count > 0 ? loupes.itemAt(canvas.parts.indexOf(canvas.part)) : null
    readonly property var loupe: canvas.current ? canvas.current.item : null
    // a part that is off has nothing to magnify (the canvas shows it gone)
    readonly property bool partOn: canvas.part === "dock" ? SettingsStore.get("dock.enabled") !== false : canvas.part === "island" ? SettingsStore.get("notch.enabled") !== false : true
    // (a part that is off: its stage may draw a ghost of it with its
    // switch, the dock)
    readonly property bool ghostLoupe: !canvas.partOn && !!canvas.loupe && canvas.loupe.ghost === true
    readonly property bool loupeShown: !canvas.covered && (canvas.partOn || canvas.ghostLoupe) && !!canvas.loupe
    readonly property real screenH: Math.round(canvas.width * 9 / 16)
    readonly property real loupeH: canvas.loupeShown ? Math.min(Space.px(320), Math.max(Space.px(96), canvas.loupe.preferredHeight || Space.px(120))) : 0
    // a part that is off: a note with its switch instead of the loupe
    readonly property bool offNote: !canvas.partOn && !canvas.ghostLoupe && (canvas.part === "island" || canvas.part === "dock")
    // what the column under the canvas holds (eased between tabs; a resize
    // lands at once)
    readonly property real underH: canvas.loupeShown ? Space.m + canvas.loupeH : (canvas.offNote ? Space.m + offRow.height : 0)
    property real shownUnderH: 0
    property real _lastW: -1
    onUnderHChanged: {
        const resized = canvas.width !== canvas._lastW;
        canvas._lastW = canvas.width;
        underAnim.stop();
        if (resized || switchHold.running || Motion.glide.duration <= 0 || !canvas.ready) {
            canvas.shownUnderH = canvas.underH;
        } else {
            underAnim.to = canvas.underH;
            underAnim.start();
        }
    }
    Timer {
        id: switchHold
        interval: Math.max(1, Motion.glide.duration)
    }
    NumberAnimation {
        id: underAnim
        target: canvas
        property: "shownUnderH"
        duration: Motion.glide.duration
        easing.type: Motion.glide.easing
    }
    // asked of the page: the canvas and what is under it
    readonly property real preferredHeight: canvas.screenH + canvas.shownUnderH
    readonly property bool pageWide: false
    property bool calm: false

    implicitHeight: canvas.preferredHeight

    HoverHandler {
        id: hover
    }

    Stage {
        id: frame
        width: parent.width
        height: canvas.screenH
        stageHeight: canvas.screenH

        ScreenMini {
            id: mini
            objectName: "screenCanvasMini"
            anchors.fill: parent
            showWindows: true
            windowsOpacity: 0.55
            barOpacity: frame.barOpacity
            cornerRadius: 0
            emphasis: canvas.part === "island" || canvas.part === "dock" ? canvas.part : ""
            // the island and the dock open their tabs
            partsClickable: !canvas.covered
            onPartPicked: part => SettingsStore.navigate(part === "island" ? "notch" : "dock")
            // on the Bar tab the bar's modules are buttons: each scrolls
            // to its card and flashes it (never adds or picks a bar)
            modulesClickable: canvas.part === "bar"
            onModulePicked: id => SettingsStore.navigate("bar", LiveKeys.sectionOf(id), "")
            // every bar can be picked; on the Bar tab the picked one is ringed
            selectable: !canvas.covered
            selectedPanel: canvas.part === "bar" ? SettingsStore.selectedPanel : -1
            onPanelPicked: index => {
                SettingsStore.selectedPanel = index;
                if (canvas.part !== "bar")
                    SettingsStore.navigate("bar");
            }
        }
    }

    // the part is off: say so, with the switch that brings it back
    Row {
        id: offRow
        objectName: "screenCanvasOff"
        y: frame.height + Space.m
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Space.m
        opacity: canvas.offNote ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            text: I18n.t(canvas.part === "dock" ? "prefs.dock.off_stage" : "prefs.notch.off_stage")
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            kind: "tonal"
            text: I18n.t("prefs.disabled.turn_on")
            onClicked: SettingsStore.set(canvas.part === "dock" ? "dock.enabled" : "notch.enabled", true)
        }
    }

    // every visited tab's stage, kept: the loupe under the canvas, or the
    // cover over it (desktop, lock screen); the current one fades in
    Repeater {
        id: loupes
        model: canvas.parts
        delegate: Loader {
            id: loupeLoader
            required property string modelData
            readonly property bool cover: loupeLoader.modelData === "desktop" || loupeLoader.modelData === "lock"
            readonly property bool current: canvas.part === loupeLoader.modelData
            readonly property bool shown: loupeLoader.current && (loupeLoader.cover || canvas.loupeShown)
            objectName: "screenCanvasLoupe:" + loupeLoader.modelData
            y: loupeLoader.cover ? 0 : frame.height + Space.m
            width: canvas.width
            height: loupeLoader.cover ? canvas.screenH : (loupeLoader.current ? canvas.loupeH : (loupeLoader.item ? Math.min(Space.px(320), Math.max(Space.px(96), loupeLoader.item.preferredHeight || Space.px(120))) : 0))
            z: loupeLoader.cover ? 1 : 0
            active: !!canvas.urls[loupeLoader.modelData]
            source: canvas.urls[loupeLoader.modelData] || ""
            opacity: loupeLoader.shown ? 1 : 0
            visible: opacity > 0
            enabled: loupeLoader.shown
            // in turn, never two stages superimposed: the one left fades
            // out quickly, the new one fades in once it has gone
            Behavior on opacity {
                enabled: Motion.glide.duration > 0
                SequentialAnimation {
                    PauseAnimation {
                        duration: loupeLoader.shown ? Motion.micro.duration : 0
                    }
                    NumberAnimation {
                        duration: loupeLoader.shown ? Motion.glide.duration : Motion.micro.duration
                        easing.type: loupeLoader.shown ? Motion.glide.easing : Motion.exit.easing
                    }
                }
            }
            onLoaded: {
                if (item && "calm" in item)
                    item.calm = !loupeLoader.cover;
            }
        }
    }
}
