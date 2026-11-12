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
import "Registry.js" as Registry
import "PageCache.js" as PageCache
import "Ui.js" as Ui

// The pages of the settings window. Every page is created from its file by
// URL on its first visit (schema categories: SettingsPage.qml; hand-written
// ones: Registry.PAGES), so opening the window compiles only the page it
// shows. The last `keep` visited pages stay alive, hidden and disabled
// (PageCache.js decides which one goes), so a revisit is instant and keeps
// its scroll position; the oldest is destroyed. A new page stays hidden
// until what is on screen is built (`enterReady`, SettingsPage fills its
// sections a few per frame) and then enters; `direction` (+1 / -1, a tab to
// the right / left) slides it in from that side, 0 from below.
Item {
    id: host

    property var category: null
    property int keep: 4
    property int direction: 0
    // The shown page.
    property Item item: null
    // [{id, item}] most recent first.
    property var _pages: []
    property real slide: 0
    // The shown page has what is on screen built.
    readonly property bool pageReady: !!host.item && Ui.prop(host.item, "enterReady") !== false

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
            "visible": false
        };
        const p = cat.page ? Registry.page(cat.page) : null;
        if (p && p.props)
            Object.assign(props, p.props);
        const page = component.createObject(pages, props);
        // createObject's property map converts the schema object (arrays
        // become lists); the page reads the schema itself.
        if (page)
            page.category = cat;
        return page;
    }

    // Shows `cat` (null: nothing): its kept page or a new one.
    function load(cat) {
        enterAnim.stop();
        if (host.item) {
            host.item.visible = false;
            host.item.enabled = false;
        }
        host.category = cat;
        if (!cat) {
            host.item = null;
            return;
        }
        let page = PageCache.find(host._pages, cat.id);
        const fresh = page === null;
        if (fresh)
            page = host.create(cat);
        if (!page) {
            host.item = null;
            return;
        }
        const next = PageCache.visit(host._pages, cat.id, page, host.keep);
        host._pages = next.pages;
        next.dropped.forEach(d => d.destroy());
        host.slide = 1;
        page.enabled = true;
        page.visible = true;
        host.item = page;
        // A kept page is complete: it enters at once.
        if (host.pageReady)
            enterAnim.restart();
        host.loaded();
    }

    onPageReadyChanged: {
        if (host.pageReady)
            enterAnim.restart();
    }

    opacity: 1 - host.slide
    transform: Translate {
        x: host.direction * host.slide * Space.xl
        y: host.direction === 0 ? host.slide * Space.l : 0
    }

    Item {
        id: pages
        anchors.fill: parent
    }

    NumberAnimation {
        id: enterAnim
        target: host
        property: "slide"
        from: 1
        to: 0
        duration: Math.max(1, Motion.glide.duration)
        easing.type: Motion.glide.easing
    }
}
