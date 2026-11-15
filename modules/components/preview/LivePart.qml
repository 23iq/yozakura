import QtQuick

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
// `snapshot`: the part is built, pictured once (grabToImage) and destroyed
// (a gallery of options: one picture each, no live objects); a change of
// `refreshKey` pictures it again (the old picture stays until then).
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
    property string fit: "contain"
    // false: the part takes no input at all
    property bool interactive: false
    // false: nothing is built (a hidden page's part costs nothing)
    property bool active: true
    property bool snapshot: false
    property var refreshKey: null
    // the native rect framed (empty: the whole part); `cropOf(item)`
    // measures it after the part settled
    property rect crop: Qt.rect(0, 0, 0, 0)
    property var cropOf: null
    // time the part gets to settle (fonts, icons, first layout) before it
    // is measured and pictured
    property int settleMs: 150

    readonly property Item item: loader.item as Item
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
        return Math.max(0.01, Math.min(root.maxZoom, s));
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
    }
    // build and settle again (a snapshot pictures it again)
    function retake() {
        settle.stop();
        if (!loader.active)
            loader.active = true;
        root.reload();
    }

    onSourceChanged: if (loader.active)
        root.reload()
    // (before the first build the gate builds it anyway)
    onRefreshKeyChanged: if (root.active && root.built && root.refreshKey !== null)
        root.retake()

    clip: root.cropped

    Item {
        id: sandbox
        width: root.partWidth
        height: root.partHeight
        x: Math.round((root.width - root.framed.width * root.shownScale) / 2 - root.framed.x * root.shownScale)
        y: Math.round((root.height - root.framed.height * root.shownScale) / 2 - root.framed.y * root.shownScale)
        scale: root.shownScale
        transformOrigin: Item.TopLeft
        enabled: root.interactive
        // a snapshot's live part is only there to be pictured
        opacity: root.snapshot ? 0.0001 : 1

        Loader {
            id: loader
            width: root.nativeWidth > 0 ? root.nativeWidth : undefined
            height: root.nativeHeight > 0 ? root.nativeHeight : undefined
            active: root.active
            // built over a few frames: a page of pictures never stalls
            asynchronous: true
            // built after the page shows (LiveGate), never in its frames
            Component.onCompleted: if (root.active)
                LiveGate.ask(root, root.reload)
            onActiveChanged: if (active && status === Loader.Null)
                LiveGate.ask(root, root.reload)
            Component.onDestruction: LiveGate.forget(root)
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
            if (root.cropOf && !root.snapshot) {
                root.crop = Qt.binding(() => root.item ? root.cropOf(root.item) : Qt.rect(0, 0, 0, 0));
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
                loader.active = false;
            }, Qt.size(w, h));
            if (!ok)
                sandbox.opacity = 0.0001;
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
