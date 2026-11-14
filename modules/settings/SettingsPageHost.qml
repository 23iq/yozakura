import QtQuick
import qs.modules.theme
import qs.modules.components.kit
// Not used here: lets Quickshell's scanner reach the page directories the
// pages are loaded from by URL.
import qs.modules.settings.presets
import qs.modules.settings.displays
import qs.modules.settings.keyboard
import qs.modules.settings.extras
import qs.modules.settings.connect
import qs.modules.settings.mods
import qs.modules.settings.layout
import qs.modules.settings.system
import qs.modules.settings.changes
import qs.modules.settings.stages
import qs.modules.settings.home
import "Registry.js" as Registry
import "PageCache.js" as PageCache
import "Ui.js" as Ui

// The pages of the settings window. Every page is created from its file by
// URL on its first visit (schema categories: SettingsPage.qml; hand-written
// ones: Registry.PAGES), so opening the window compiles only the page it
// shows. The last `keep` visited pages stay alive, hidden and disabled
// (PageCache.js decides which one goes), so a revisit is instant and keeps
// its scroll position; the oldest is destroyed.
// A tab switch is one transition of two pages: the page left keeps showing
// (disabled) until the new one has what is on screen built (`enterReady`,
// SettingsPage fills its sections a few per frame; a kept page at once),
// then the old one slides out and fades while the new one slides in from
// the other side (`direction` +1 / -1: a tab to the right / left), never a
// blank frame. From another destination (0) the page shows as soon as it
// is built (the window's morph brings it in).
// The Screen tabs in two panes share one canvas (stages/ScreenCanvas.qml),
// kept here above the pages: it stays on screen while the tabs slide under
// it and only changes the part it shows.
Item {
    id: host

    // pages slide inside the content area, never over the window's edge
    clip: true

    property var category: null
    property int keep: 4
    property int direction: 0
    // The shown page.
    property Item item: null
    // The page sliding out (a tab switch).
    property Item leaving: null
    // [{id, item}] most recent first.
    property var _pages: []
    // Someone else fades the page in (the shell's tile morph): no enter of
    // its own, the page stands in place at once.
    property bool quiet: false
    // The shown page has what is on screen built.
    readonly property bool itemReady: !!host.item && Ui.prop(host.item, "enterReady") !== false
    // Something is on screen: the shown page, or the page left while the
    // new one builds (the window never shows an empty frame)
    readonly property bool pageReady: host.itemReady || !!host.leaving
    // the Screen part of the shown page ("": no shared canvas)
    readonly property string canvasPart: host.item ? (Ui.prop(host.item, "canvasPart") || "") : ""
    property bool canvasWanted: false
    // what the canvas last showed (kept while no Screen tab shows)
    property string canvasShows: "bar"
    property string canvasStage: ""
    onCanvasPartChanged: {
        if (host.canvasPart === "")
            return;
        host.canvasWanted = true;
        host.canvasStage = Ui.prop(host.item, "stageUrl") || "";
        host.canvasShows = host.canvasPart;
        Ui.invoke(canvasLoader.item, "show", [host.canvasShows, host.canvasStage]);
    }

    signal loaded

    function urlOf(cat) {
        if (cat.page) {
            const p = Registry.page(cat.page);
            return p ? Qt.resolvedUrl(p.file) : Qt.resolvedUrl("PlaceholderPage.qml");
        }
        return Qt.resolvedUrl(cat.sections ? "SettingsPage.qml" : "PlaceholderPage.qml");
    }

    function create(cat) {
        const component = Qt.createComponent(host.urlOf(cat));
        if (component.status !== Component.Ready) {
            console.warn("SettingsPageHost:", component.errorString());
            return null;
        }
        const props = {
            "category": cat,
            "width": Qt.binding(() => host.width),
            "height": Qt.binding(() => host.height),
            "visible": false,
            "opacity": 0
        };
        const p = cat.page ? Registry.page(cat.page) : null;
        if (p && p.props)
            Object.assign(props, p.props);
        const page = component.createObject(pages, props);
        // createObject's property map converts the schema object (arrays
        // become lists); the page reads the schema itself.
        if (page) {
            page.category = cat;
            if ("sharedCanvas" in page)
                page.sharedCanvas = Qt.binding(() => canvasLoader.item);
        }
        return page;
    }

    // Ends a transition at once: the page left hides, the shown one sits.
    function settle() {
        swap.stop();
        fade.stop();
        if (host.leaving) {
            host.leaving.visible = false;
            host.leaving.enabled = false;
            host.leaving.opacity = 1;
            host.leaving.x = 0;
            host.leaving = null;
        }
        if (host.item) {
            host.item.opacity = 1;
            host.item.x = 0;
        }
    }

    // Shows `cat` (null: nothing): its kept page or a new one.
    function load(cat) {
        host.settle();
        const old = host.item;
        host.category = cat;
        let page = cat ? PageCache.find(host._pages, cat.id) : null;
        if (cat && page === null)
            page = host.create(cat);
        if (!page) {
            if (old) {
                old.visible = false;
                old.enabled = false;
            }
            host.item = null;
            return;
        }
        const next = PageCache.visit(host._pages, cat.id, page, host.keep);
        host._pages = next.pages;
        // a tab of the same destination: the old page stays until the new
        // one enters with it; else it goes at once
        if (old && old !== page && host.direction !== 0 && next.dropped.indexOf(old) < 0)
            host.leaving = old;
        else if (old && old !== page) {
            old.visible = false;
            old.enabled = false;
        }
        next.dropped.forEach(d => d.destroy());
        page.x = 0;
        page.opacity = 0;
        page.enabled = true;
        page.visible = true;
        host.item = page;
        // a kept page is complete: it enters at once
        if (host.itemReady)
            host.enter();
        host.loaded();
    }

    function enter() {
        if (!host.item)
            return;
        if (Motion.glide.duration <= 0 || host.quiet) {
            host.settle();
            return;
        }
        // from another destination (or nothing): a plain fade, from the
        // next frame on (the page and the header lay out first)
        if (host.direction === 0 || !host.leaving) {
            host.settle();
            host.item.opacity = 0;
            fade.restart();
            return;
        }
        inX.from = host.direction * Space.xl * 2;
        outX.to = -host.direction * Space.xl;
        swap.restart();
    }

    onItemReadyChanged: {
        if (host.itemReady && host.item && host.item.opacity === 0 && !swap.running && !fade.running)
            host.enter();
    }

    Item {
        id: pages
        anchors.fill: parent
    }

    NumberAnimation {
        id: fade
        target: host.item
        property: "opacity"
        from: 0
        to: 1
        duration: Math.max(1, Motion.glide.duration)
        easing.type: Motion.glide.easing
    }

    // In turn, never superimposed: the old page leaves quickly toward the
    // side away from the new tab (micro), then the new one slides in from
    // that tab's side (glide). The host clips, so pages travel inside the
    // content area only.
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation {
                id: outX
                target: host.leaving
                property: "x"
                from: 0
                duration: Math.max(1, Motion.micro.duration)
                easing.type: Motion.exit.easing
            }
            NumberAnimation {
                target: host.leaving
                property: "opacity"
                from: 1
                to: 0
                duration: Math.max(1, Motion.micro.duration)
                easing.type: Motion.exit.easing
            }
        }
        ScriptAction {
            script: {
                if (host.leaving) {
                    host.leaving.visible = false;
                    host.leaving.enabled = false;
                }
            }
        }
        ParallelAnimation {
            NumberAnimation {
                id: inX
                target: host.item
                property: "x"
                to: 0
                duration: Math.max(1, Motion.glide.duration)
                easing.type: Motion.glide.easing
            }
            NumberAnimation {
                target: host.item
                property: "opacity"
                from: 0
                to: 1
                duration: Math.max(1, Motion.glide.duration)
                easing.type: Motion.glide.easing
            }
        }
        onFinished: host.settle()
    }

    // The Screen canvas, one for the Screen tabs: built the first time a
    // Screen tab shows in two panes, then kept; it sits where the shown
    // page keeps its stage (a sticky column: the same place in every tab).
    Loader {
        id: canvasLoader
        objectName: "sharedCanvas"
        readonly property point slot: host.canvasPart !== "" ? (Ui.prop(host.item, "previewAt") || Qt.point(0, 0)) : Qt.point(0, 0)
        z: 2
        x: canvasLoader.slot.x
        y: canvasLoader.slot.y
        width: host.canvasPart !== "" ? (Ui.prop(host.item, "previewW") || 0) : 0
        height: canvasLoader.item ? canvasLoader.item.implicitHeight : 0
        active: host.canvasWanted
        visible: host.canvasPart !== "" && !!host.item && host.item.visible
        source: Qt.resolvedUrl("stages/ScreenCanvas.qml")
        onLoaded: {
            item.width = Qt.binding(() => canvasLoader.width);
            item.show(host.canvasShows, host.canvasStage);
        }
    }
}
