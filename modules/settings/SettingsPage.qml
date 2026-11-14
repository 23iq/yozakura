pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.services
import qs.modules.theme
import "CompositorGate.js" as CompositorGate
import "SchemaUtil.js" as SchemaUtil
import "BentoLayout.js" as BentoLayout
import "Registry.js" as Registry

// A schema-driven tab, one scrolling page on the destination's grid: in a
// wide window two equal columns, the same in every tab of a destination
// (switching tabs never changes the content width). A tab with a stage
// (`stage`: the live picture of what the tab places or styles; only tabs
// about something on the desktop have one, see Registry.DESKTOP_STAGES)
// keeps the right column for it, sticky (it stays in view while the cards
// scroll in the left column; nothing sits under it); a tab without one
// fills both columns with its cards. The Screen tabs share one canvas the
// page host keeps across them (`sharedCanvas`, stages/ScreenCanvas.qml).
// The tab's hint (`hero.hint`) shows quietly while the pointer is over the
// stage (and once, the first time the page shows); the Wallpaper library is
// a strip along the stage's foot (`hero.foot`). A narrow window stacks the
// stage over one or two columns of cards. Cards are a masonry
// (BentoLayout.js, cards as tall as their rows); `row` names the cards
// that come first, in that order. Nothing here is category specific.
Flickable {
    id: page

    required property var category
    // Entries of this page the compositor gate hides on the running compositor
    readonly property var gated: CompositorGate.hiddenBy(page.category.sections, YozdService.compositorName)
    readonly property string stageUrl: page.category.stage ? Qt.resolvedUrl(Registry.stage(page.category.stage)) : ""
    readonly property var hero: page.category.hero || ({})
    // `hero.foot`: entries in a strip along the stage's foot (the wallpaper
    // library), as wide as the stage; not in their card
    readonly property var heroIds: page.hero.foot || []
    readonly property real footH: page.heroIds.length > 0 && page.stageUrl !== "" ? Space.px(76) : 0
    // a wide page (no right column for it) puts the foot beside the stage
    readonly property bool footSide: !page.split && page.footH > 0 && heroArea.width - page.height / 3 * 16 / 9 - Space.l >= Space.px(480)
    // `row`: the sections that lead the page, in this order
    readonly property var leadIds: (page.category.row || []).map(r => typeof r === "string" ? r : r.id)
    // the sections in page order: the lead ones first, then cards of plain
    // rows, then cards of big controls (BentoLayout.order)
    readonly property var order: BentoLayout.order(page.category.sections || [], page.leadIds, SchemaUtil.inWindow, page.importanceOrder)
    // rank of a section in the page order (built in this order too)
    readonly property var rank: {
        const out = [];
        page.order.forEach((i, k) => out[i] = k);
        return out;
    }
    readonly property bool listForm: page.category.form === "list"
    // a stage that is not the desktop: no wallpaper (Stage `calm`)
    readonly property bool plainStage: !Registry.DESKTOP_STAGES[page.category.id]
    // every key a window row of this page edits (a card offers no "Turn on"
    // for a switch that is a row of the page)
    readonly property var pageKeys: (page.category.sections || []).reduce((all, sec) => all.concat((sec.entries || []).filter(e => e.key && SchemaUtil.inWindow(e, sec)).map(e => e.key)), [])
    readonly property real margin: Space.xl
    readonly property real gap: Look.screenGap
    // room kept under the last card: the undo pill floats there
    readonly property real pillRoom: Space.controlM + Space.xl * 2
    // The destination grid: two equal columns in a wide window (every tab
    // of a destination the same, a list band excepted)
    readonly property real cardsW: page.width - page.margin * 2
    readonly property bool wide: !page.listForm && page.cardsW >= Space.px(900)
    readonly property real colW: Math.floor((page.cardsW - page.gap) / 2)
    // two panes: the cards in the left column, the stage alone in the
    // right one, sticky
    readonly property bool split: page.wide && page.stageUrl !== ""
    // a Screen tab in two panes: the stage is the host's Screen canvas
    // (the whole screen, this tab's part in focus), kept across the tabs
    readonly property string canvasPart: page.split ? (Registry.SCREEN_PARTS[page.category.id] || "") : ""
    property Item sharedCanvas: null
    readonly property bool usesShared: page.canvasPart !== "" && page.sharedCanvas !== null
    // the page's own stage: built the first time it is needed and kept
    // (a resize across the two-pane width never rebuilds it)
    readonly property bool ownStage: page.stageUrl !== "" && !page.usesShared
    property bool ownStageBuilt: false
    // (decided on the next tick: the host hands a Screen tab its shared
    // canvas just after creating the page)
    function wantOwnStage() {
        if (page.ownStage)
            page.ownStageBuilt = true;
    }
    onOwnStageChanged: Qt.callLater(page.wantOwnStage)
    Component.onCompleted: Qt.callLater(page.wantOwnStage)
    // what the stage area shows (its height, its off note)
    readonly property var stageItem: page.usesShared ? page.sharedCanvas : (page.ownStage ? stageLoader.stage : null)
    readonly property bool importanceOrder: page.wide
    // where the shared canvas goes, in the page's (viewport) coordinates
    readonly property point previewAt: Qt.point(heroArea.x, heroArea.y - page.contentY)
    readonly property real previewW: heroArea.width
    // the pointer is over the stage (its hint shows meanwhile)
    readonly property bool previewHovered: heroHover.hovered || (page.usesShared && page.sharedCanvas.hovered === true)

    // Sections fill in a few per frame (as many as fit a frame budget): a
    // long page shows its top at once and never freezes the window.
    readonly property int sectionCount: (page.category.sections || []).length
    property int builtSections: 1
    readonly property bool complete: builtSections >= sectionCount
    // The sections built so far fill the viewport: the page can be shown.
    // SettingsPageHost keeps the page hidden until `enterReady`.
    property bool filled: false
    readonly property bool enterReady: complete || filled
    // once shown, cards glide to new places (a toggle that shows rows):
    // before, they land in place
    property bool settled: false
    onEnterReadyChanged: if (enterReady) {
        Qt.callLater(() => page.settled = true);
        hintOnce.start();
    }
    // the hint shows once by itself, the first time the page shows
    property bool hintIntro: false
    Timer {
        id: hintOnce
        interval: 3200
        onRunningChanged: if (running)
            page.hintIntro = true
        onTriggered: page.hintIntro = false
    }

    // every card placed inside the viewport is built (a card still to build
    // has no height: it would appear, or grow, after the page showed; cards
    // fill holes above others, so build order alone does not decide it)
    function viewportBuilt() {
        const places = bento.places;
        for (let i = 0; i < places.length; i++) {
            if (places[i] && body.y + places[i].y < page.height && page.rank[i] >= page.builtSections)
                return false;
        }
        return true;
    }

    function buildAll() {
        builtSections = sectionCount;
    }

    FrameAnimation {
        running: !page.complete
        onTriggered: {
            // filled: every column reaches below the viewport, so the cards
            // still to come land out of sight (masonry puts a card at the
            // top of the shortest column)
            bento.relayout();
            if (!page.filled && page.height > 0 && body.y + bento.floor >= page.height && page.viewportBuilt())
                page.filled = true;
            const start = Date.now();
            do {
                page.builtSections++;
            } while (!page.complete && Date.now() - start < 6)
            if (page.complete)
                bento.relayout();
        }
    }

    contentWidth: width
    contentHeight: Math.max(body.y + body.height, page.split ? Space.s + page.heroBlockH : 0) + page.margin + page.pillRoom
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    NumberAnimation {
        id: scroller
        target: page
        property: "contentY"
        duration: Math.max(1, Motion.morph.duration)
        easing.type: Motion.morph.easing
    }

    // Scroll to an entry (or a section), flash it and give it focus.
    function reveal(sectionId, entryId) {
        buildAll();
        // place the cards now (twice: a card's new width can rewrap it)
        bento.relayout();
        bento.relayout();
        let target = null;
        for (let i = 0; i < sections.count; i++) {
            const s = sections.itemAt(i) as SettingsSection;
            if (!s)
                continue;
            if (entryId) {
                const r = s.rowFor(entryId);
                if (r) {
                    target = r;
                    break;
                }
            } else if (s.sectionId === sectionId) {
                target = s;
                break;
            }
        }
        if (!target)
            return;
        const y = target.mapToItem(page.contentItem, 0, 0).y;
        scroller.to = Math.max(0, Math.min(y - (page.height - target.height) / 3, contentHeight - height));
        scroller.restart();
        if (entryId) {
            SettingsStore.highlightedEntry = entryId;
            unflash.restart();
            target.forceActiveFocus();
        } else {
            // a card reached from the stage: a brief accent wash
            SettingsStore.highlightedSection = sectionId;
            unflash.restart();
        }
    }

    // Scroll an item of the page (e.g. one row of a custom editor) into view.
    function revealItem(item) {
        if (!item)
            return;
        const y = item.mapToItem(page.contentItem, 0, 0).y;
        const top = item.height > height / 2 ? y - Space.xxl * 3 : y - (height - item.height) / 2;
        scroller.to = Math.max(0, Math.min(top, contentHeight - height));
        scroller.restart();
    }

    Timer {
        id: unflash
        interval: 1600
        onTriggered: {
            SettingsStore.highlightedEntry = "";
            SettingsStore.highlightedSection = "";
        }
    }

    // The stage block (the stage, its foot, its hint) and, in two panes,
    // how far it scrolls before it sticks (a block taller than the window
    // scrolls until its foot shows, then stays)
    readonly property real heroBlockH: heroArea.height + (page.hero.hint ? heroHint.height + Space.m : 0)
    readonly property real stickAfter: Math.max(0, Space.s + page.heroBlockH + page.margin - page.height)

    // The stage: in two panes the right column, sticky; else on top,
    // receding as the page scrolls.
    Item {
        id: heroArea
        objectName: "pageHero"
        readonly property real recede: page.split ? 0 : Math.max(0, Math.min(1, page.contentY / Math.max(1, height)))
        x: page.split ? page.margin + page.colW + page.gap : page.margin
        y: page.split ? Space.s + Math.max(0, page.contentY - page.stickAfter) : Space.s + page.contentY * 0.35
        z: 2
        width: page.split ? page.cardsW - page.colW - page.gap : page.cardsW
        height: page.usesShared ? Math.round(page.sharedCanvas.preferredHeight) : (stageLoader.shown ? stageLoader.height + (page.footH > 0 && !page.footSide ? Space.s + page.footH : 0) : 0)
        visible: page.stageUrl !== ""
        scale: 1 - heroArea.recede * 0.12
        opacity: 1 - heroArea.recede * 0.7
        transformOrigin: Item.Top

        HoverHandler {
            id: heroHover
        }

        Loader {
            id: stageLoader
            objectName: "pageStage"
            // the loaded stage, untyped (stages declare what they ask for)
            readonly property var stage: stageLoader.item
            readonly property bool shown: page.ownStage && stageLoader.status === Loader.Ready
            readonly property real asked: stageLoader.stage && stageLoader.stage.preferredHeight > 0 ? stageLoader.stage.preferredHeight : 0
            // two panes: the column's width, as tall as it asks (a 16:9
            // screen by default); on top: a third of the page at most, a
            // list page's band short
            height: page.split ? Math.round(stageLoader.asked > 0 ? Math.min(stageLoader.asked, page.height - page.margin * 2) : heroArea.width * 9 / 16) : Math.round(Math.min(page.height / 3, stageLoader.asked > 0 ? stageLoader.asked : page.listForm ? Math.max(Space.px(110), Math.min(page.height * 0.2, Space.px(150))) : Math.max(Space.px(150), Math.min(page.height * 0.32, heroArea.width * 9 / 16, Space.px(300)))))
            // a desktop stage is a 16:9 screen; a plain one (a band, the
            // battery, a terminal) is a wide strip of the thing itself;
            // a strip stage (`pageWide: true`) takes the page's width
            readonly property bool strip: !!stageLoader.stage && stageLoader.stage.pageWide === true
            width: Math.round(page.split || page.listForm || stageLoader.strip ? heroArea.width : (page.plainStage ? Math.min(heroArea.width, Space.px(900)) : Math.min(heroArea.width, height * 16 / 9)))
            x: page.footSide ? 0 : (heroArea.width - width) / 2
            visible: page.ownStage
            active: page.ownStageBuilt
            source: page.stageUrl
            // a page that is not about the desktop, or a strip of the thing
            // itself (the bar, the island): a plain stage, no picture
            onLoaded: {
                if (item && "calm" in item)
                    item.calm = Qt.binding(() => page.plainStage || stageLoader.strip);
            }

            // a soft shadow under the stage
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: Look.radius("surface", parent.height)
                offset: Qt.vector2d(0, Space.m)
                blur: Space.xxl
                color: Qt.alpha(Colors.shadow, 0.4)
            }
        }

        // `hero.foot`: a strip along the stage's foot, as wide as the stage
        Column {
            id: heroFoot
            objectName: "heroFoot"
            visible: page.footH > 0 && stageLoader.shown
            x: page.footSide ? stageLoader.width + Space.l : stageLoader.x
            y: page.footSide ? 0 : stageLoader.height + Space.s
            width: page.footSide ? heroArea.width - x : stageLoader.width
            Repeater {
                model: page.footH > 0 ? (page.category.sections || []).reduce((all, sec) => all.concat((sec.entries || []).filter(e => page.heroIds.indexOf(e.key || e.id) >= 0)), []) : []
                delegate: SettingRow {
                    required property var modelData
                    width: heroFoot.width
                    height: page.footSide ? stageLoader.height : page.footH
                    entry: modelData
                    bare: true
                    fillHeight: (page.footSide ? stageLoader.height : page.footH) - Space.s * 2
                }
            }
        }
    }

    // the hint: a quiet caption under the stage, there while the pointer
    // is over the stage (and once by itself); its line is kept, so
    // nothing moves when it shows
    KitText {
        id: heroHint
        objectName: "heroHint"
        // (none while the stage says its part is off: the hint would talk
        // about something not there)
        readonly property bool wanted: heroArea.visible && !!page.hero.hint && !(page.stageItem && page.stageItem.offNote === true)
        readonly property bool shown: heroHint.wanted && (page.previewHovered || page.hintIntro)
        visible: !!page.hero.hint && heroArea.visible
        z: 2
        x: page.split ? heroArea.x : page.footSide ? page.margin + stageLoader.x : page.margin
        y: heroArea.y + heroArea.height * heroArea.scale + Space.m
        width: page.split ? heroArea.width : page.footSide ? stageLoader.width : page.cardsW
        horizontalAlignment: Text.AlignHCenter
        role: "caption"
        color: Type.muted
        // two lines at most in a narrow window, whole
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        opacity: heroHint.shown ? heroArea.opacity : 0
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        text: page.hero.hint ? I18n.t(page.hero.hint) : ""
    }

    // The cards.
    Item {
        id: body
        z: 1
        // two panes: the left column; else the whole grid
        width: page.split ? page.colW : page.cardsW
        x: page.margin
        y: heroArea.visible && !page.split ? page.heroBlockH + page.gap + Space.s : Space.s
        height: bento.height + (note.visible ? note.height + page.gap : 0)

        Item {
            id: bento
            objectName: "pageBento"
            readonly property real gap: page.gap
            // columns with hysteresis: a resize near a breakpoint never makes
            // the cards flip back and forth
            property int fullCols: 1
            function pickCols() {
                if (page.split || page.wide) {
                    // the destination grid: the left column of two panes,
                    // or both columns
                    bento.fullCols = page.split ? 1 : 2;
                    return;
                }
                const w = body.width;
                const n = BentoLayout.columns(w, Space.px(340));
                // fewer columns only once the width is clearly under the
                // switch point
                bento.fullCols = n < bento.fullCols && BentoLayout.columns(w + Space.px(24), Space.px(340)) >= bento.fullCols ? bento.fullCols : n;
            }
            Connections {
                target: body
                function onWidthChanged() {
                    bento.pickCols();
                }
            }
            Component.onCompleted: bento.pickCols()
            readonly property bool wide: page.wide
            onWideChanged: bento.pickCols()
            readonly property bool split: page.split
            onSplitChanged: bento.pickCols()
            readonly property var spans: (page.category.sections || []).map(s => BentoLayout.spanOf(s, SchemaUtil.inWindow))
            // the cards that show (a section without a window row is no card)
            readonly property int cols: page.split ? 1 : BentoLayout.fit(fullCols, bento.spans.filter((sp, i) => ((page.category.sections || [])[i].entries || []).some(e => SchemaUtil.inWindow(e, page.category.sections[i]))))
            // the grid's column: a lone card keeps a column's width, at the
            // grid's start (the grid never moves between tabs)
            readonly property real colW: page.split ? body.width : (body.width - gap * (fullCols - 1)) / fullCols
            // card places {x, y, w} (in page order), re-run when a card's
            // height or visibility changes
            property var places: []
            // the columns of the cards once the page is whole (see relayout)
            property var assigned: null
            property bool frozen: false
            Connections {
                target: page.visible ? SettingsStore : null
                function onValueSet(key, value) {
                    bento.frozen = true;
                }
            }
            property int assignedCols: 0
            // cards that took the free columns beside them keep that span
            // while the column count holds: a widened card is shorter, and
            // placing it narrow again would widen it again (no relayout loop)
            property var grown: ({})
            property int grownCols: 0
            property real floor: 0
            width: colW * cols + gap * (cols - 1)
            x: page.wide ? 0 : (parent.width - width) / 2
            height: 0

            // `eased`: a discrete relayout (a card shown or hidden, a new
            // column count): the cards glide to their places. Otherwise (a
            // card folding rows open or shut, content wrapping, a resize)
            // they follow in the same frame, in lockstep with the fold.
            function relayout(eased) {
                const items = [];
                for (const i of page.order) {
                    const s = sections.itemAt(i);
                    items.push({
                        "span": page.split ? 1 : Math.max(bento.spans[i] || 1, bento.grownCols === bento.cols ? (bento.grown[i] || 1) : 1),
                        "height": s && s.visible ? s.implicitHeight : 0
                    });
                }
                // after the first change made on the page, cards keep their
                // columns (a toggle never reshuffles them); until then, and
                // for a new column count, they are placed afresh (content
                // that loads late still balances the columns)
                const keep = bento.frozen && bento.assigned !== null && bento.assignedCols === bento.cols;
                const r = BentoLayout.place(items, bento.cols, bento.gap, keep ? page.order.map(i => bento.assigned[i]) : null, null);
                if (!keep) {
                    const a = [];
                    page.order.forEach((i, k) => a[i] = r.places[k]);
                    bento.assigned = a;
                    // (recorded once every card is built: a neighbour still
                    // to come is no free column)
                    const g = bento.grownCols === bento.cols ? Object.assign({}, bento.grown) : {};
                    if (page.complete)
                        page.order.forEach((i, k) => {
                            if (r.places[k].span > (bento.spans[i] || 1))
                                g[i] = Math.max(g[i] || 1, r.places[k].span);
                        });
                    bento.grown = g;
                    bento.grownCols = bento.cols;
                    bento.assignedCols = bento.cols;
                }
                const out = [];
                page.order.forEach((i, k) => {
                    const pl = r.places[k];
                    out[i] = {
                        "x": pl.col * (bento.colW + bento.gap),
                        "y": pl.y,
                        "w": pl.span * bento.colW + (pl.span - 1) * bento.gap,
                        // the last card of a column reaches the tallest one's end
                        "extra": r.extra[k] || 0
                    };
                });
                bento.places = out;
                // (only after a change made on the page: a page that builds or
                // loads content late never moves by itself once shown)
                const glide = eased === true && page.settled && bento.frozen && Motion.glide.duration > 0;
                for (let i = 0; i < sections.count; i++) {
                    const s = sections.itemAt(i);
                    if (s && out[i])
                        s.moveTo(out[i], glide);
                }
                bento.height = r.height;
                bento.floor = r.floor;
            }
            function relayoutEased() {
                bento.relayout(true);
            }
            onColsChanged: Qt.callLater(bento.relayoutEased)
            onColWChanged: Qt.callLater(bento.relayout)

            Repeater {
                id: sections
                model: page.category.sections

                delegate: SettingsSection {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property var place: bento.places[index] || ({
                            "x": 0,
                            "y": 0,
                            "w": bento.width
                        })
                    section: modelData
                    exclude: page.heroIds
                    pageKeys: page.pageKeys
                    pending: page.rank[index] >= page.builtSections
                    height: implicitHeight + (card.place.extra || 0)

                    // To a place: gliding (a discrete relayout) or at once.
                    // A placement at once leaves alone a glide already
                    // heading there (a fold under a gliding card).
                    function moveTo(pl, glide) {
                        const props = [["x", pl.x, ax], ["y", pl.y, ay], ["width", pl.w, aw]];
                        props.forEach(p => {
                            const a = p[2];
                            if (glide && Math.abs(card[p[0]] - p[1]) > 0.5) {
                                a.stop();
                                a.to = p[1];
                                a.start();
                            } else if (!(a.running && a.to === p[1])) {
                                a.stop();
                                card[p[0]] = p[1];
                            }
                        });
                    }
                    NumberAnimation {
                        id: ax
                        target: card
                        property: "x"
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    NumberAnimation {
                        id: ay
                        target: card
                        property: "y"
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    NumberAnimation {
                        id: aw
                        target: card
                        property: "width"
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    // a card that shows on a shown page fades in (built late,
                    // or brought back by a setting)
                    NumberAnimation {
                        id: fadeIn
                        target: card
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    // at once, in the same frame: a card that grows never
                    // paints over the card under it
                    onImplicitHeightChanged: bento.relayout()
                    // just built (not brought back by a setting): built
                    // cards land out of sight, they need no fade
                    property bool fresh: false
                    onPendingChanged: if (!card.pending) {
                        card.fresh = true;
                        Qt.callLater(() => card.fresh = false);
                    }
                    onVisibleChanged: {
                        if (card.visible && page.settled && page.complete && !card.fresh && Motion.glide.duration > 0)
                            fadeIn.restart();
                        Qt.callLater(bento.relayoutEased);
                    }
                    Component.onCompleted: {
                        card.moveTo(card.place, false);
                        Qt.callLater(bento.relayout);
                    }
                }
            }
        }

        KitText {
            id: note
            objectName: "compositorOnlyNote"
            y: bento.height + page.gap
            width: parent.width
            visible: page.gated.count > 0
            role: "caption"
            color: Type.muted
            wrapMode: Text.WordWrap
            text: page.gated.count > 0 ? I18n.tn("prefs.compositor_only.note", page.gated.count).replace("%2", CompositorGate.describe(page.gated.compositors)) : ""
        }
    }
}
