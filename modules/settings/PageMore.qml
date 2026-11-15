pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "SchemaUtil.js" as SchemaUtil
import "CompositorGate.js" as CompositorGate
import "../components/kit/KitStates.js" as KitStates

// The tab's "More settings" card, after its cards: every advanced entry of
// the tab (SchemaUtil.moreGroups: the rare knobs and plumbing), folded. Its
// heading is the button that unfolds it (Enter / Space, a pointer click;
// an `Accessible` button that says whether it is expanded) and says how
// many settings it holds now (compositor gate, visibleWhen). Unfolded, one
// group per section (SettingsSection `more`: the section's title as a
// group label over its advanced rows). The rows are built the first time
// it opens and kept. A search jump to one of its rows opens it at once
// (rowFor / sectionFor) so the page can scroll there.
Card {
    id: moreCard

    required property var category
    // every key a card row of the page edits (no second "Turn on")
    property var pageKeys: []
    property bool expanded: false
    // the rows exist (built on the first open, then kept)
    property bool built: false
    onExpandedChanged: if (moreCard.expanded)
        moreCard.built = true
    // a jump: no fold animation, the rows in place at once
    property bool instant: false

    readonly property var groups: SchemaUtil.moreGroups(moreCard.category)
    // advanced entries that show on this compositor with this config
    readonly property int count: {
        let n = 0;
        for (const g of moreCard.groups) {
            if (!CompositorGate.allows(g.section.compositor, YozdService.compositorName))
                continue;
            for (const e of g.entries) {
                if (SettingsStore.visible(e))
                    n++;
            }
        }
        return n;
    }

    objectName: "moreSettings"
    visible: moreCard.count > 0
    shadow: true
    spacing: 0
    // (the padding of the page's cards: its heading on their titles' line)
    padding: Look.boxPadding + Space.s

    function open(now) {
        moreCard.instant = now === true;
        moreCard.expanded = true;
        moreCard.instant = false;
    }
    // the row of an entry (opening the card), null: not here
    function rowFor(entryId) {
        if (!moreCard.groups.some(g => g.entries.some(e => SchemaUtil.entryId(e) === entryId)))
            return null;
        moreCard.open(true);
        return moreCard._find(s => s.rowFor(entryId));
    }
    // the group of a section (opening the card), null: not here
    function sectionFor(sectionId) {
        if (!moreCard.groups.some(g => g.section.id === sectionId))
            return null;
        moreCard.open(true);
        return moreCard._find(s => s.sectionId === sectionId ? s : null);
    }
    function _find(pick) {
        const list = (content.item as Item)?.children ?? [];
        for (let i = 0; i < list.length; i++) {
            const s = list[i] as SettingsSection;
            if (!s)
                continue;
            const hit = pick(s);
            if (hit)
                return hit;
        }
        return null;
    }

    // The heading: the button that folds the card open or shut.
    Item {
        id: head
        objectName: "moreSettingsButton"
        width: moreCard.contentWidth
        height: Math.max(Space.rowHeight, titleText.implicitHeight + Space.s * 2)
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: titleText.text
        // the open / shut state is spoken in the description: Accessible.expanded
        // needs a newer Qt than the oldest one we support (6.11)
        Accessible.description: countText.text + ", " + I18n.t(moreCard.expanded ? "prefs.more.expanded" : "prefs.more.collapsed")
        Accessible.onPressAction: moreCard.expanded = !moreCard.expanded
        Keys.onReturnPressed: moreCard.expanded = !moreCard.expanded
        Keys.onEnterPressed: moreCard.expanded = !moreCard.expanded
        Keys.onSpacePressed: moreCard.expanded = !moreCard.expanded

        // the language's hover box, as on a row
        StyledRect {
            anchors.fill: parent
            opacity: headArea.containsMouse || head.activeFocus ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
            variant: "focus"
            backgroundOpacity: KitStates.opacity("hover", true)
            enableBorder: false
            enableShadow: false
            radius: Look.chipRadius(Space.rowHeight)
        }
        FocusRing {
            shown: head.activeFocus
            radius: Look.chipRadius(Space.rowHeight)
        }

        Icon {
            id: caret
            x: Look.rowInset
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.caretRight
            role: "title"
            tone: "secondary"
            rotation: moreCard.expanded ? 90 : 0
            Behavior on rotation {
                enabled: Motion.micro.duration > 0
                NumberAnimation {
                    duration: Motion.micro.duration
                    easing.type: Motion.micro.easing
                }
            }
        }
        KitText {
            id: titleText
            objectName: "moreSettingsTitle"
            anchors.left: caret.right
            anchors.leftMargin: Space.s
            anchors.right: countText.left
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            wrapMode: Text.WordWrap
            text: I18n.t("prefs.more.title")
        }
        KitText {
            id: countText
            objectName: "moreSettingsCount"
            anchors.right: parent.right
            anchors.rightMargin: Look.rowInset
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            color: Type.muted
            text: I18n.tn("prefs.more.count", moreCard.count)
        }
        MouseArea {
            id: headArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                head.forceActiveFocus();
                moreCard.expanded = !moreCard.expanded;
            }
        }
    }

    // The rows, folding open under the heading (Motion.glide; at once for
    // a jump).
    Item {
        id: fold
        property real unfolded: moreCard.expanded ? 1 : 0
        Behavior on unfolded {
            enabled: !moreCard.instant && Motion.glide.duration > 0
            NumberAnimation {
                duration: moreCard.expanded ? Motion.glide.duration : Motion.exit.duration
                easing.type: moreCard.expanded ? Motion.glide.easing : Motion.exit.easing
            }
        }
        width: moreCard.contentWidth
        height: Math.round((content.height + Space.s) * fold.unfolded)
        visible: fold.unfolded > 0
        opacity: fold.unfolded
        clip: fold.unfolded < 1

        Loader {
            id: content
            y: Space.s
            width: parent.width
            active: moreCard.built
            sourceComponent: Column {
                width: content.width
                spacing: Space.m

                Repeater {
                    model: moreCard.groups
                    delegate: SettingsSection {
                        required property var modelData
                        width: parent.width
                        more: true
                        section: modelData.section
                        pageKeys: moreCard.pageKeys
                    }
                }
            }
        }
    }
}
