import QtQuick
import QtQuick.Window
import qs.modules.components.kit

// LivePart: a real shell component shown as a picture. The component is
// created by URL (compiled on first use, no static import of its feature)
// at its own, native size in a sandbox, and the sandbox is scaled uniformly
// into this item (centred). The part is inert: it takes no pointer, hover
// or key input (its HoverHandlers, MouseAreas and popups never fire), so a
// page draws its own interaction on top (`mapFromPart`).
//
//     LivePart {
//         source: Qt.resolvedUrl("../../bar/workspaces/Workspaces.qml")
//         properties: ({ "bar": fakeBar, "orientation": "horizontal" })
//     }
//
// `properties` are the initial properties (required ones included; give a
// PreviewContext as the part's `preview` where it takes one). Native size:
// `nativeWidth` / `nativeHeight`, or the item's implicit size (0). What is
// framed: the whole part, or `crop` (a native rect; `cropOf(item)`, when
// set, measures it once the part has settled). Scale: `zoom` when > 0,
// else the largest that fits (`fit`: "contain" | "width" | "height"),
// never above `maxZoom`.
// Readable: never below `minZoom`, nor below the zoom that draws the part's
// smallest text at `readableGlyph` px (measured once it settled; 0: off).
// Then the frame no longer fits, and `cut` says what shows: "center" (the
// middle), "start" (its start: the top / left), "ends" (its start and its
// end side by side, a small break between: a whole bar's two corners).
// `snapshot`: the part is built, pictured once (grabToImage) and destroyed
// (a gallery of options: one picture each, no live objects); a change of
// `refreshKey` pictures it again (the old picture stays until then; a burst
// of changes, a slider dragged, pictures it once, `refreshDelay` after the
// last). A grab that fails (the window hid meanwhile) is tried again.
// Off screen nothing lives: hidden (`shown`: an ancestor hides it, a cached
// page, the kept-alive Settings window, another tab) for `holdMs`, the live
// part is destroyed (a picture stays) and built again when it shows.
// A part whose root has a `ready` property (it builds more of itself by
// URL) is measured and pictured once `ready` is true.
Item {
    id: root

    property url source
    property var properties: ({})
    property real nativeWidth: 0
    property real nativeHeight: 0
    property real zoom: 0
    property real maxZoom: 1
    property real minZoom: 0
    property real readableGlyph: 0
    property string cut: "center"
    // the smallest text of the part, native px (measured when it settled)
    property real smallestGlyph: 0
    readonly property real readableZoom: Math.max(root.minZoom, root.readableGlyph > 0 && root.smallestGlyph > 0 ? root.readableGlyph / root.smallestGlyph : 0)
    property string fit: "contain"
    // false: the part takes no input at all
    property bool interactive: false
    // The part never takes the keyboard: a view that grabs it when it is
    // built or changes (the dashboard's focus: true, BentoView's
    // forceActiveFocus) gives it back to what had it (the page's control).
    property Item focusBefore: null
    Component.onCompleted: root.focusBefore = root.Window.window ? root.Window.window.activeFocusItem : null
    function inPart(it) {
        for (let p = it; p; p = p.parent)
            if (p === sandbox)
                return true;
        return false;
    }
    Connections {
        target: root.interactive ? root.Window.window : null
        function onActiveFocusItemChanged() {
            const it = root.Window.window ? root.Window.window.activeFocusItem : null;
            if (!it)
                return;
            if (!root.inPart(it)) {
                root.focusBefore = it;
                return;
            }
            if (root.focusBefore && root.focusBefore.visible)
                root.focusBefore.forceActiveFocus();
            else
                it.focus = false;
        }
    }
    // false: nothing is built
    property bool active: true
    // on screen (false: an ancestor hides it); a part hidden `holdMs` is
    // torn down, so a hidden page or window costs nothing (a quick switch
    // of tabs keeps it)
    property bool shown: root.visible
    property int holdMs: 1500
    property bool snapshot: false
    property var refreshKey: null
    // a refresh waits this long for the next change (one picture per burst)
    property int refreshDelay: 250
    // the native rect framed (empty: the whole part); `cropOf(item)`
    // measures it after the part settled
    property rect crop: Qt.rect(0, 0, 0, 0)
    property var cropOf: null
    // time the part gets to settle (fonts, icons, first layout) before it
    // is measured and pictured
    property int settleMs: 150

    readonly property Item item: loader.item as Item
    // shown, or hidden for less than `holdMs`
    readonly property bool awake: hold.awake
    // a snapshot whose picture is taken: its live part is gone
    property bool pictured: false
    // the live part should exist now
    readonly property bool wanted: root.active && root.awake && !root.pictured
    LiveHold {
        id: hold
        shown: root.shown
        holdMs: root.holdMs
    }
    onWantedChanged: {
        if (root.wanted)
            LiveGate.ask(root, root.wake);
        else
            root.sleep();
    }
    Component.onDestruction: {
        root.leaving = true;
        root.crop = Qt.rect(0, 0, 0, 0);
        LiveGate.forget(root);
    }
    // built in its turn (LiveGate), unless it already is
    function wake() {
        if (root.wanted && loader.status === Loader.Null)
            root.reload();
    }
    // the live part goes (a picture stays)
    function sleep() {
        LiveGate.forget(root);
        settle.stop();
        regrab.stop();
        stuck.stop();
        root.settled = false;
        if (loader.source.toString() !== "")
            loader.source = "";
    }
    readonly property bool ready: root.snapshot ? shot.status === Image.Ready : (loader.status === Loader.Ready && root.settled)
    property bool settled: false
    // the native size of the part when it was pictured (it is gone since)
    property size shotSize: Qt.size(0, 0)
    // the picture's grab result (its image lives as long as it does)
    property var grab: null
    readonly property real partWidth: root.nativeWidth > 0 ? root.nativeWidth : (root.item ? root.item.implicitWidth : root.shotSize.width)
    readonly property real partHeight: root.nativeHeight > 0 ? root.nativeHeight : (root.item ? root.item.implicitHeight : root.shotSize.height)
    readonly property bool cropped: root.crop.width > 0 && root.crop.height > 0
    readonly property rect framed: root.cropped ? root.crop : Qt.rect(0, 0, root.partWidth, root.partHeight)
    readonly property real shownScale: {
        if (root.zoom > 0)
            return root.zoom;
        if (root.framed.width <= 0 || root.framed.height <= 0)
            return 1;
        const sx = root.width / root.framed.width;
        const sy = root.height / root.framed.height;
        const s = root.fit === "width" ? sx : (root.fit === "height" ? sy : Math.min(sx, sy));
        return Math.max(0.01, Math.max(Math.min(root.readableZoom, root.maxZoom), Math.min(root.maxZoom, s)));
    }
    // the frame at that scale is larger than this item: it is cut
    readonly property bool overflows: root.framed.width * root.shownScale > root.width + 0.5 || root.framed.height * root.shownScale > root.height + 0.5
    // the cut runs across the long side
    readonly property bool cutAcross: root.framed.width >= root.framed.height
    // (only a long thing: a bar, a dock; a squarish one shows its middle)
    readonly property bool split: root.cut === "ends" && root.overflows && Math.max(root.framed.width, root.framed.height) >= 2 * Math.min(root.framed.width, root.framed.height)
    readonly property real gap: Space.s
    // the length each end gets (item px), when split
    readonly property real half: Math.max(0, ((root.cutAcross ? root.width : root.height) - root.gap) / 2)
    // where the framed rect starts in this item
    readonly property real originX: (root.cut === "start" || root.split) && root.cutAcross && root.framed.width * root.shownScale > root.width ? 0 : (root.width - root.framed.width * root.shownScale) / 2
    readonly property real originY: (root.cut === "start" || root.split) && !root.cutAcross && root.framed.height * root.shownScale > root.height ? 0 : (root.height - root.framed.height * root.shownScale) / 2

    // the smallest text drawn by the part (native px)
    function measureGlyph() {
        let least = 0;
        const walk = it => {
            if (!it || it.visible === false || it.opacity === 0)
                return;
            if (it.font !== undefined && typeof it.text === "string" && it.text !== "" && it.height > 0) {
                const px = it.font.pixelSize > 0 ? it.font.pixelSize : it.font.pointSize * 1.33;
                const r = it.mapToItem(sandbox, 0, 0, it.width, it.height);
                const size = px * (r.height / it.height);
                if (size > 0 && (least === 0 || size < least))
                    least = size;
            }
            const kids = it.children || [];
            for (let i = 0; i < kids.length; i++)
                walk(kids[i]);
        };
        walk(root.item);
        return least;
    }
    // the framed rect's place in this item
    readonly property rect partRect: Qt.rect(sandbox.x + root.framed.x * root.shownScale, sandbox.y + root.framed.y * root.shownScale, root.framed.width * root.shownScale, root.framed.height * root.shownScale)

    // a rect of an item of the part (in that item's coordinates), in this item
    function mapFromPart(it, r) {
        if (!it || !root.item)
            return Qt.rect(0, 0, 0, 0);
        const p = it.mapToItem(sandbox, r ? r.x : 0, r ? r.y : 0);
        const w = r ? r.width : it.width, h = r ? r.height : it.height;
        return Qt.rect(sandbox.x + p.x * root.shownScale, sandbox.y + p.y * root.shownScale, w * root.shownScale, h * root.shownScale);
    }

    // one more each build: a picture of an older build is dropped
    property int generation: 0
    property bool built: false
    function reload() {
        root.settled = false;
        root.built = true;
        root.generation++;
        loader.setSource(root.source, root.properties || {});
        stuck.restart();
    }
    // an asynchronous build that never lands (seen offscreen under load:
    // the Loader stays Loading) is started again, a few times
    Timer {
        id: stuck
        property int tries: 0
        interval: 4000
        onTriggered: {
            if (loader.status !== Loader.Loading || !root.wanted) {
                stuck.tries = 0;
                return;
            }
            if (stuck.tries++ < 3)
                root.reload();
        }
    }
    // build and settle again (a snapshot pictures it again); hidden, it is
    // built when it shows
    function retake() {
        settle.stop();
        refresh.stop();
        root.pictured = false;
        if (root.wanted)
            root.reload();
    }
    // the same, once a burst of changes is over
    function refreshSoon() {
        if (root.built)
            refresh.restart();
    }
    Timer {
        id: refresh
        interval: root.refreshDelay
        onTriggered: root.retake()
    }

    onSourceChanged: if (root.built && root.wanted)
        root.reload()
    // torn down: the frame stops following the part (its owner's cropOf
    // must not run in a context that is going away)
    property bool leaving: false
    // (before the first build the gate builds it anyway)
    onRefreshKeyChanged: if (root.refreshKey !== null)
        root.refreshSoon()

    clip: root.cropped || root.overflows

    // the start (all of it unless split)
    Item {
        id: startView
        width: root.split && root.cutAcross ? root.half : root.width
        height: root.split && !root.cutAcross ? root.half : root.height
        clip: root.split

        Item {
            id: sandbox
            width: root.partWidth
            height: root.partHeight
            x: Math.round(root.originX - root.framed.x * root.shownScale)
            y: Math.round(root.originY - root.framed.y * root.shownScale)
            scale: root.shownScale
            transformOrigin: Item.TopLeft
            enabled: root.interactive
            // a snapshot's live part is only there to be pictured
            opacity: root.snapshot ? 0.0001 : 1

            // (built after the page shows, LiveGate, never in its frames;
            // emptied while the part sleeps)
            Loader {
                id: loader
                width: root.nativeWidth > 0 ? root.nativeWidth : undefined
                height: root.nativeHeight > 0 ? root.nativeHeight : undefined
                // built over a few frames: a page of pictures never stalls
                asynchronous: true
                onLoaded: settle.restart()
            }
        }

        Timer {
            id: settle
            interval: root.settleMs
            // polls left while a part with a `ready` property is not ready
            property int waits: 0
            onTriggered: {
                if (!root.item)
                    return;
                // a part that builds more by URL (LiveHosted's HostedFrame)
                // says when it is whole: measured / pictured only then (at
                // most ~40 more settle periods)
                if (root.item.ready === false && settle.waits < 40) {
                    settle.waits++;
                    settle.restart();
                    return;
                }
                settle.waits = 0;
                // live: the frame follows the part (what cropOf reads is bound)
                if (root.readableGlyph > 0)
                    root.smallestGlyph = root.measureGlyph();
                if (root.cropOf && !root.snapshot) {
                    root.crop = Qt.binding(() => root.item && !root.leaving ? root.cropOf(root.item) : Qt.rect(0, 0, 0, 0));
                } else if (root.cropOf) {
                    const r = root.cropOf(root.item);
                    if (r && r.width > 0 && r.height > 0)
                        root.crop = r;
                }
                root.settled = true;
                if (!root.snapshot)
                    return;
                // twice the shown size: sharp on a HiDPI screen
                const w = Math.max(1, Math.round(root.partWidth * root.shownScale * 2));
                const h = Math.max(1, Math.round(root.partHeight * root.shownScale * 2));
                root.shotSize = Qt.size(root.partWidth, root.partHeight);
                sandbox.opacity = 1;
                const gen = root.generation;
                const ok = sandbox.grabToImage(result => {
                    if (gen !== root.generation)
                        return;
                    // (the url lives as long as its result)
                    root.grab = result;
                    shot.source = result.url;
                    sandbox.opacity = 0.0001;
                    regrab.tries = 0;
                    root.pictured = true;
                }, Qt.size(w, h));
                if (!ok) {
                    // (no window to render in now: tried again shortly)
                    sandbox.opacity = 0.0001;
                    regrab.restart();
                }
            }
        }
        // a failed grab, tried again while the part is wanted (a few times)
        Timer {
            id: regrab
            property int tries: 0
            interval: 400
            onTriggered: {
                if (!root.wanted || !root.item || regrab.tries >= 20)
                    return;
                regrab.tries++;
                settle.restart();
            }
        }

        Image {
            id: shot
            visible: root.snapshot
            x: sandbox.x
            y: sandbox.y
            width: root.partWidth * root.shownScale
            height: root.partHeight * root.shownScale
            smooth: true
            mipmap: true
            cache: false
        }
    }

    // the end, beside the start (split): the same part, its far end
    ShaderEffectSource {
        id: endView
        readonly property Item from: root.snapshot ? shot : sandbox
        // the source's own scale: the sandbox is native, the picture shown size
        readonly property real unit: root.snapshot ? root.shownScale : 1
        readonly property real len: root.half / root.shownScale
        visible: root.split
        // (a picture: it may be decoded after the split shows)
        live: true
        sourceItem: root.split ? endView.from : null
        hideSource: false
        x: root.cutAcross ? root.width - root.half : root.originX
        y: root.cutAcross ? root.originY : root.height - root.half
        width: root.cutAcross ? root.half : root.framed.width * root.shownScale
        height: root.cutAcross ? root.framed.height * root.shownScale : root.half
        sourceRect: root.cutAcross ? Qt.rect((root.framed.x + root.framed.width - endView.len) * endView.unit, root.framed.y * endView.unit, endView.len * endView.unit, root.framed.height * endView.unit) : Qt.rect(root.framed.x * endView.unit, (root.framed.y + root.framed.height - endView.len) * endView.unit, root.framed.width * endView.unit, endView.len * endView.unit)
        textureSize: Qt.size(Math.max(1, Math.ceil(endView.width * 2)), Math.max(1, Math.ceil(endView.height * 2)))
        smooth: true
    }
}
