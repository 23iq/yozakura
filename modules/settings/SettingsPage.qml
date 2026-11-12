pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.services
import qs.modules.theme
import "CompositorGate.js" as CompositorGate
import "SchemaUtil.js" as SchemaUtil
import "BentoLayout.js" as BentoLayout
import "Registry.js" as Registry

// A schema-driven destination tab: a hero holding its stage (the live
// miniature of what the tab controls, `stage` in the schema) over a bento
// of cards, one per section (SettingsSection), packed in two or three
// columns (BentoLayout.js: a card with picture cards or an editor takes two).
// The hero recedes (scales down, fades) as the cards scroll up under it.
// Nothing here is category specific.
Flickable {
    id: page

    required property var category
    // Entries of this page the compositor gate hides on the running compositor
    readonly property var gated: CompositorGate.hiddenBy(page.category.sections, YozdService.compositorName)
    readonly property string stageUrl: page.category.stage ? Qt.resolvedUrl(Registry.stage(page.category.stage)) : ""

    // Sections fill in a few per frame (as many as fit a frame budget): a
    // long page shows its top at once and never freezes the window.
    readonly property int sectionCount: (page.category.sections || []).length
    property int builtSections: 1
    readonly property bool complete: builtSections >= sectionCount
    // The sections built so far fill the viewport: the page can be shown.
    // SettingsPageHost keeps the page hidden until `enterReady`.
    property bool filled: false
    readonly property bool enterReady: complete || filled

    function buildAll() {
        builtSections = sectionCount;
    }

    FrameAnimation {
        running: !page.complete
        onTriggered: {
            if (!page.filled && page.height > 0 && body.y + bento.height >= page.height)
                page.filled = true;
            const start = Date.now();
            do {
                page.builtSections++;
            } while (!page.complete && Date.now() - start < 6)
        }
    }

    contentWidth: width
    contentHeight: body.y + body.height + Space.xxl * 3
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
        onTriggered: SettingsStore.highlightedEntry = ""
    }

    // The hero: the stage, centred, receding as the page scrolls.
    Loader {
        id: stageLoader
        objectName: "pageStage"
        readonly property real recede: Math.max(0, Math.min(1, page.contentY / Math.max(1, height)))
        width: Math.min(page.width - Space.xxl * 2, Space.px(760))
        x: (page.width - width) / 2
        y: Space.s + page.contentY * 0.35
        active: page.stageUrl !== ""
        visible: active
        source: page.stageUrl
        scale: 1 - stageLoader.recede * 0.18
        opacity: 1 - stageLoader.recede * 0.7
        transformOrigin: Item.Top
        z: 0
    }

    // The bento of cards.
    Item {
        id: body
        z: 1
        width: Math.min(page.width - Space.xxl * 2, Space.px(1180))
        x: (page.width - width) / 2
        y: stageLoader.active ? stageLoader.height + Space.xl : Space.s
        height: bento.height + (note.visible ? note.height + Space.l : 0)

        Item {
            id: bento
            objectName: "pageBento"
            readonly property real gap: Space.l
            readonly property int cols: BentoLayout.columns(width, Space.px(300))
            readonly property real colW: (width - gap * (cols - 1)) / cols
            // card heights and spans -> places (re-run when one changes)
            property var places: []
            width: parent.width
            height: 0

            function relayout() {
                const items = [];
                for (let i = 0; i < sections.count; i++) {
                    const s = sections.itemAt(i);
                    items.push({
                        "span": BentoLayout.spanOf(page.category.sections[i], SchemaUtil.inWindow),
                        "height": s && s.visible ? s.implicitHeight : 0
                    });
                }
                const r = BentoLayout.place(items, bento.cols, bento.gap);
                bento.places = r.places;
                bento.height = r.height;
            }
            onColsChanged: Qt.callLater(bento.relayout)
            onWidthChanged: Qt.callLater(bento.relayout)

            Repeater {
                id: sections
                model: page.category.sections

                delegate: SettingsSection {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property var place: bento.places[index] || ({
                            "col": 0,
                            "span": 1,
                            "y": 0
                        })
                    section: modelData
                    pending: index >= page.builtSections
                    x: card.place.col * (bento.colW + bento.gap)
                    y: card.place.y
                    width: card.place.span * bento.colW + (card.place.span - 1) * bento.gap
                    onImplicitHeightChanged: Qt.callLater(bento.relayout)
                    onVisibleChanged: Qt.callLater(bento.relayout)
                    Component.onCompleted: Qt.callLater(bento.relayout)
                }
            }
        }

        KitText {
            id: note
            objectName: "compositorOnlyNote"
            y: bento.height + Space.l
            width: parent.width
            visible: page.gated.count > 0
            role: "caption"
            color: Type.muted
            wrapMode: Text.WordWrap
            text: I18n.tn("prefs.compositor_only.note", page.gated.count).replace("%2", CompositorGate.describe(page.gated.compositors))
        }
    }
}
