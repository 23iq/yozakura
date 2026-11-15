pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.settings.store
import qs.modules.settings.home
import "schema/Categories.js" as Categories
import "Ui.js" as Ui
import "Registry.js" as Registry

// Settings window content, the "showcase" frame: a home screen
// (SettingsHome: search + a bento of live tiles + pills) and, once a
// destination is opened, its page - the tile grows into it (a shared
// element, home/MorphFrame: a snapshot of the tile grows from its place to
// the window and cross-fades into the page, which grows with it) - with
// only a back pill, the title and the tabs as chrome (DestinationHeader)
// over the page (SettingsPageHost: built on first visit, kept alive). Esc,
// the back pill, the mouse back button and Alt+Left return home: the page
// shrinks back into the tile of the destination it shows now (after tabs,
// Ctrl+Tab, a search jump or a deep link alike) and the tile takes over.
// Every change applies at once; Ctrl+Z / Ctrl+Shift+Z undo / redo it
// (UndoPill).
Item {
    id: shell

    property string currentCategory: ""
    property bool atHome: true
    // 0 = home, 1 = page fully open (animated).
    property real reveal: atHome ? 0 : 1
    // Where the page grows from / shrinks back to (a home tile or a search
    // result), in shell coordinates; null: from the middle.
    property var origin: null
    property var pendingReveal: null
    // A tile grows into its page (until the page is in and laid out) /
    // a page shrinks into its tile: the shared-element transition runs.
    property bool opening: false
    property bool closing: false
    readonly property bool morphing: shell.opening || shell.closing
    // The page's share while it opens: 0 until it is laid out, then it
    // fades up (it never shows half built).
    property real readyFade: 1
    // The item the next opening grows out of (a tile, a result row).
    property Item morphItem: null
    property bool selecting: false
    // The active preset's changes sheet is open (home footer, toast).
    property alias changesOpen: overlays.changesOpen
    readonly property alias home: homeView
    // Off until the first frame: a deep link opens straight on its page.
    property bool animated: false

    // Open: a whole-window morph (the morph token, not a glide: a short
    // glide reads as a flash at this size), decelerating so it lands
    // softly. Back: the exit token (shorter, accelerating away).
    Behavior on reveal {
        enabled: shell.animated && Motion.morph.duration > 0
        NumberAnimation {
            duration: shell.atHome ? Motion.exit.duration : Motion.morph.duration
            easing.type: shell.atHome ? Motion.exit.easing : Motion.morph.easing
        }
    }
    onRevealChanged: shell.settle()
    onReadyFadeChanged: shell.settle()

    NumberAnimation {
        id: readyAnim
        target: shell
        property: "readyFade"
        to: 1
        duration: Motion.glide.duration
        easing.type: Motion.glide.easing
    }
    Connections {
        target: page
        function onPageReadyChanged() {
            if (!page.pageReady) {
                readyAnim.stop();
                shell.readyFade = 0;
            } else if (shell.opening && shell.animated && Motion.glide.duration > 0) {
                readyAnim.restart();
            } else {
                shell.readyFade = 1;
            }
            shell.maybeReveal();
        }
    }

    // The item a transition grows out of / shrinks into: its rect (as home
    // lays it out at rest: home's own scale left out) and its snapshot.
    function morphFrom(item) {
        if (item) {
            const p = item.mapToItem(homeView, 0, 0);
            shell.origin = {
                "x": homeView.x + p.x,
                "y": homeView.y + p.y,
                "w": item.width,
                "h": item.height
            };
        } else {
            shell.origin = null;
        }
        morph.capture(item);
    }

    // The tile of the destination a category belongs to.
    function tileOf(categoryId) {
        const g = Categories.groupOf(categoryId);
        return g ? homeView.tileFor(g.id) : null;
    }

    // A transition ends: the real tile is back, a jump to a row runs.
    function settle() {
        if (shell.closing && shell.reveal === 0) {
            shell.closing = false;
            morph.capture(null);
        }
        if (shell.opening && shell.reveal === 1 && shell.readyFade === 1) {
            shell.opening = false;
            morph.capture(null);
            // a search jump: the palette closes behind the page
            homeView.clearSearch();
            shell.maybeReveal();
        }
    }

    // Scroll to / flash the row a search or a link asked for, once the page
    // is laid out and stands still (never mid-morph).
    function maybeReveal() {
        if (shell.pendingReveal && page.item && page.pageReady && !shell.opening && !shell.atHome)
            revealTimer.restart();
    }

    // Accepts a category id, a moved id or a destination id
    // (Categories.resolve); opens its page (a tab of the same destination
    // slides in from its side).
    function select(id) {
        const c = Categories.resolve(id);
        if (!c)
            return;
        const changed = c.id !== currentCategory || !page.item;
        const tabs = Categories.tabsOf(c.id);
        const from = tabs.findIndex(t => t.id === currentCategory);
        const to = tabs.findIndex(t => t.id === c.id);
        page.direction = !shell.atHome && from >= 0 && to >= 0 && from !== to ? (to > from ? 1 : -1) : 0;
        // from home (or on the way back to it): the destination's tile grows
        // into the page
        const grow = shell.atHome && shell.animated;
        if (grow) {
            readyAnim.stop();
            shell.morphFrom(shell.morphItem || shell.tileOf(c.id));
            shell.closing = false;
            shell.opening = true;
        }
        shell.morphItem = null;
        currentCategory = c.id;
        shell.selecting = true;
        GlobalStates.settingsCategory = c.id;
        shell.selecting = false;
        if (changed)
            page.load(c);
        if (grow)
            shell.readyFade = page.pageReady ? 1 : 0;
        shell.atHome = false;
    }

    // A home tile (or pill) opens its destination's first tab, growing
    // out of the tile.
    function openDestination(id, from) {
        const g = Categories.groupById(id);
        if (!g)
            return;
        shell.morphItem = from || null;
        select(g.categories[0]);
    }

    function goHome() {
        if (shell.atHome)
            return;
        // into the tile of the destination shown now, wherever the page
        // came from
        if (shell.animated) {
            shell.opening = false;
            readyAnim.stop();
            shell.readyFade = 1;
            shell.morphFrom(shell.tileOf(shell.currentCategory));
            shell.closing = true;
        }
        shell.atHome = true;
        GlobalStates.settingsCategory = "";
        homeView.forceActiveFocus();
    }

    function openSearch() {
        goHome();
        Qt.callLater(homeView.focusSearch);
    }

    function navigate(categoryId, sectionId, entryId) {
        pendingReveal = {
            "section": sectionId || "",
            "entry": entryId || ""
        };
        const c = Categories.resolve(categoryId);
        if (c && c.id === currentCategory && page.item && !shell.atHome)
            shell.maybeReveal();
        else
            select(categoryId);
    }

    // The active preset's actions (home footer, changes sheet, toast).
    function presetAction(id) {
        overlays.presetAction(id);
    }

    // Ctrl+Tab: the next tab in destination order; at home the first (or,
    // backwards, the last), not the one after the page last shown.
    function step(delta) {
        const list = Categories.ordered();
        let i = shell.atHome ? (delta > 0 ? 0 : list.length - 1) : list.findIndex(c => c.id === currentCategory) + delta;
        i = (i + list.length) % list.length;
        select(list[i].id);
    }

    // Another part of the shell asks for a page (e.g. the microphone
    // activity opens Sound) while the window is open.
    Connections {
        target: GlobalStates
        function onSettingsCategoryChanged() {
            // (not the echo of a select() under way)
            if (!shell.selecting && GlobalStates.settingsCategory && (GlobalStates.settingsCategory !== shell.currentCategory || shell.atHome))
                shell.select(GlobalStates.settingsCategory);
        }
        // a plain open after a close starts at home
        function onSettingsWindowVisibleChanged() {
            if (!GlobalStates.settingsWindowVisible) {
                // the next open (maybe a deep link) starts without motion
                shell.animated = false;
                shell.opening = false;
                shell.closing = false;
                morph.capture(null);
                shell.readyFade = 1;
                shell.atHome = true;
                GlobalStates.settingsCategory = "";
            } else {
                Qt.callLater(() => shell.animated = true);
            }
        }
    }

    Component.onCompleted: {
        // A preset trial or edit outlives the window: bring back its pill/banner.
        PresetStudio.refreshSessions();
        if (Categories.resolve(GlobalStates.settingsCategory))
            select(GlobalStates.settingsCategory);
        else
            homeView.forceActiveFocus();
        Qt.callLater(() => shell.animated = true);
    }

    Connections {
        target: SettingsStore
        function onNavigateRequested(categoryId, sectionId, entryId) {
            shell.navigate(categoryId, sectionId, entryId);
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: shell.openSearch()
    }
    Shortcut {
        sequences: ["Alt+Left"]
        onActivated: shell.goHome()
    }
    Shortcut {
        sequences: ["Ctrl+Z"]
        onActivated: SettingsStore.undo()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
        onActivated: SettingsStore.redo()
    }
    Shortcut {
        sequences: ["Ctrl+PgDown", "Ctrl+Tab"]
        onActivated: shell.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+PgUp", "Ctrl+Shift+Tab"]
        onActivated: shell.step(-1)
    }
    // Esc returns home when nothing inside took it (a search field clears
    // itself first, a popup closes first).
    Keys.onEscapePressed: shell.goHome()

    // Window background: the wallpaper, blurred, darkened and vignetted
    // (kit Ambient), so the window carries the desktop's colour; plain on
    // battery saver.
    Ambient {
        objectName: "windowAmbient"
        anchors.fill: parent
        // the wallpaper after the first frame (decode + blur cost it; it fades in)
        source: homeView.warm ? SettingsStore.wallpaper : ""
        plain: Config.performance.batterySaver === true
        // full on home and on the tabs about the desktop; quiet on the
        // others (the backdrop, not content)
        strength: Look.ambientStrength * (shell.atHome || !!Registry.DESKTOP_STAGES[shell.currentCategory] ? 1 : 0.3)
    }

    // The mouse back button returns home.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onClicked: shell.goHome()
    }

    SettingsHome {
        id: homeView
        objectName: "settingsHome"
        y: overlays.bannerHeight
        width: parent.width
        height: parent.height - y
        // shown on the way back from its first frame (the tile's snapshot
        // is taken from it)
        visible: shell.reveal < 1 || shell.closing
        enabled: shell.atHome
        focus: shell.atHome
        // gone under the growing page early: never two screens at once
        opacity: Math.max(0, 1 - shell.reveal / 0.35)
        scale: 1 - Math.min(1, shell.reveal / 0.35) * 0.03
        onDestinationOpened: (id, tile) => shell.openDestination(id, tile)
        onResultActivated: (r, row) => {
            shell.morphItem = row || null;
            shell.navigate(r.categoryId, r.sectionId, r.entryId);
        }
        onPresetAction: id => shell.presetAction(id)
        wantIndex: shell.changesOpen
    }

    // The shared element: the page grows out of the tile (and back), the
    // tile's snapshot cross-fading with it.
    MorphFrame {
        id: morph
        objectName: "settingsMorph"
        anchors.fill: parent
        active: shell.morphing
        t: shell.reveal
        origin: shell.origin
        pageFade: pageView.opacity

        FocusScope {
            id: pageView
            objectName: "settingsPageView"
            y: overlays.bannerHeight
            width: parent.width
            height: parent.height - y
            visible: shell.reveal > 0
            enabled: !shell.atHome
            focus: !shell.atHome
            // One fade for the header and the cards together while the
            // transition runs: in as the frame grows (once the page is
            // laid out: it never reflows in view), out as it shrinks. The
            // page host's own enter (tabs) does the rest.
            opacity: shell.morphing ? shell.readyFade * Math.max(0, Math.min(1, (shell.reveal - 0.15) / 0.5)) : 1

            DestinationHeader {
                id: header
                objectName: "destinationHeader"
                x: Space.xl
                y: Space.l
                width: parent.width - Space.xl * 2
                category: page.category
                onTabSelected: id => shell.select(id)
                onBack: shell.goHome()
            }

            SettingsPageHost {
                id: page
                objectName: "settingsPage"
                y: header.y + header.height + Space.m
                width: parent.width
                height: parent.height - y
                // the morph fades the page in: no enter of its own then
                quiet: shell.opening
                onLoaded: shell.maybeReveal()
            }

            // once the page scrolls, a hairline under the header: cards slide
            // under a clear edge instead of being cut mid-heading
            Mark {
                objectName: "headerEdge"
                x: Space.xl
                y: page.y - Space.xs
                width: parent.width - Space.xl * 2
                height: Space.hairline
                radius: 0
                color: Type.hairline
                opacity: (Ui.prop(page.item, "contentY") || 0) > Space.s ? 1 : 0
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
            }
        }
    }

    UndoPill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.xl
        z: 6
    }

    // The preset overlays (edit banner, trial pill, toast, changes sheet,
    // name dialog), by URL once home has shown its first frame (or a page is
    // open): none is on the first frame, nor is their compile.
    PresetOverlays {
        id: overlays
        anchors.fill: parent
        z: 7
        ready: homeView.warm || !shell.atHome
        index: homeView.index
        onNavigate: (c, sec, e) => shell.navigate(c, sec, e)
    }

    // Reveal after the page laid out.
    Timer {
        id: revealTimer
        interval: 60
        onTriggered: {
            const r = shell.pendingReveal;
            shell.pendingReveal = null;
            if (r)
                Ui.invoke(page.item, "reveal", [r.section, r.entry]);
        }
    }
}
