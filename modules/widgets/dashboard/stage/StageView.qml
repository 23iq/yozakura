import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.widgets.dashboard.widgets
import qs.config
import "StageNav.js" as StageNav

// The stage home (layout.dashboard.home = "stage"): a hero and two
// columns of different weight, then a thin metrics strip.
//   left   the hero (StageHero: the player tinted by its art, or the
//          greeting and the large clock), one row of seven toggle tiles and
//          three slim level sliders; its width is the tile row's
//   right  StageRight: NEXT, the week and the notifications; a toggle's,
//          level's or the week's detail slides in over it
//   bottom StageMetrics (layout.dashboard.showMetrics), opens metrics
// The view offers its natural size and fills what it is given: the hero
// and NEXT take the free height; lower than natural, `compact` slims the
// controls. On open the sections rise in with a short stagger (hero,
// controls, right column, metrics; none on close). Keyboard: Tab walks the
// controls in reading order, the arrows move spatially (StageNav), Esc
// closes a detail before the dashboard; the first focus is play.
Item {
    id: root

    // Between the columns (around the divider where groups have no box).
    readonly property int gap: Look.groupBoxed ? Look.groupGap : Space.l
    readonly property real leftW: toggles.rowWidth + Look.groupPadding * 2
    readonly property bool showMetrics: Config.layout.dashboard.showMetrics ?? true
    readonly property bool playing: hero.playing
    // What the right column shows instead of NEXT / week / notifications.
    property string detail: ""
    // The left column at full size (independent of `compact`, so the
    // natural height never depends on the mode it picks).
    readonly property real leftFull: hero.naturalHeight + Look.groupGap + controls.chrome + Space.m + toggles.fullHeight + levels.fullHeight
    readonly property real metricsH: root.showMetrics ? metrics.implicitHeight + Space.m : 0
    // Shorter than the full left column (a low screen): compact controls.
    readonly property bool compact: root.height > 0 && root.height - root.metricsH < root.leftFull - 1
    // Open reveal: 0 -> 1 over the whole stagger (one animation drives all).
    property real reveal: 1
    readonly property int revealStep: Motion.delay
    readonly property int revealSpan: Motion.glide.duration + root.revealStep * 3

    signal openTab(string id)

    function openDetail(kind: string) {
        root.detail = root.detail === kind ? "" : kind;
    }

    // One section's share of the reveal (eased): index 0 hero .. 3 metrics.
    function shown(i: int): real {
        if (root.reveal >= 1 || root.revealSpan <= 0)
            return 1;
        const p = Math.max(0, Math.min(1, (root.reveal * root.revealSpan - i * root.revealStep) / Math.max(1, Motion.glide.duration)));
        return 1 - Math.pow(1 - p, 3);
    }

    // The host focuses this on open: play, or the first toggle when idle.
    // No ring until the keys move focus (FocusState).
    property bool quietFocus: false
    function focusSearchInput() {
        const target = hero.focusTarget ?? toggles.firstTile;
        root.quietFocus = true;
        if (target)
            target.forceActiveFocus();
        root.quietFocus = false;
        FocusState.keyboard = false;
    }

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            if (!root.quietFocus && root.visible)
                FocusState.keyboard = true;
        }
    }

    function focusables(): var {
        const out = [];
        const walk = it => {
            for (let i = 0; i < it.children.length; i++) {
                const c = it.children[i];
                if (!c.visible || !c.enabled || c.opacity <= 0)
                    continue;
                if (c.activeFocusOnTab)
                    out.push(c);
                walk(c);
            }
        };
        walk(root);
        return out;
    }

    function moveFocus(dir: string): bool {
        const items = root.focusables();
        const from = items.findIndex(it => it.activeFocus);
        if (from < 0)
            return false;
        const rects = items.map(it => {
            const p = it.mapToItem(root, 0, 0);
            return {
                "x": p.x,
                "y": p.y,
                "w": it.width,
                "h": it.height
            };
        });
        const to = StageNav.pick(rects, from, dir);
        if (to < 0)
            return false;
        items[to].forceActiveFocus(Qt.TabFocusReason);
        return true;
    }

    Keys.onPressed: event => {
        const dir = StageNav.direction(event.key);
        if (dir !== "" && !(event.modifiers & Qt.ControlModifier))
            event.accepted = root.moveFocus(dir);
        else if (event.key === Qt.Key_Escape && root.detail !== "") {
            root.detail = "";
            event.accepted = true;
        }
    }

    // The tabs load with the dashboard: created = opened (a tab switch back
    // only cross-slides, Dashboard's tab slots).
    Component.onCompleted: root.playReveal()

    function playReveal() {
        if (root.revealSpan > 0)
            revealAnim.restart();
    }
    onVisibleChanged: {
        if (!visible) {
            root.detail = "";
            revealAnim.stop();
            root.reveal = 1;
        }
    }

    implicitWidth: Metrics.launcherWideW - Space.xl
    implicitHeight: Math.max(Metrics.dashH, root.leftFull, right.naturalHeight) + root.metricsH

    CalendarEvents {
        id: events
        objectName: "calendarEvents"
        active: root.visible
        days: 7
        limit: 8
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: root.revealSpan
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Space.m

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            ColumnLayout {
                id: left
                Layout.preferredWidth: root.leftW
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: Look.groupGap

                StageHero {
                    id: hero
                    objectName: "hero"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.compact ? hero.naturalHeight * 0.75 : hero.naturalHeight
                    opacity: root.shown(0)
                    transform: Translate {
                        y: (1 - root.shown(0)) * Space.m
                    }
                }

                Group {
                    id: controls
                    objectName: "controls"
                    Layout.fillWidth: true
                    divider: true
                    opacity: root.shown(1)
                    transform: Translate {
                        y: (1 - root.shown(1)) * Space.m
                    }

                    StageToggles {
                        id: toggles
                        objectName: "toggles"
                        compact: root.compact
                        width: parent.width
                        detail: root.detail
                        onDetails: kind => root.openDetail(kind)
                    }

                    StageLevels {
                        id: levels
                        objectName: "levels"
                        compact: root.compact
                        width: parent.width
                        detail: root.detail
                        onDetails: kind => root.openDetail(kind)
                    }
                }
            }

            // A slot, so the columns keep their place without the divider
            // (hidden where groups are boxes: glass cards, tiles).
            Item {
                implicitWidth: Space.hairline
                Layout.fillHeight: true
                visible: !Look.groupBoxed

                Divider {
                    objectName: "columnDivider"
                    vertical: true
                    anchors.fill: parent
                    visible: Look.dividers
                }
            }

            StageRight {
                id: right
                objectName: "right"
                Layout.fillWidth: true
                Layout.fillHeight: true
                events: events.available ? events.events : []
                detail: root.detail
                opacity: root.shown(2)
                transform: Translate {
                    y: (1 - root.shown(2)) * Space.m
                }
                onOpenMonth: root.openDetail("month")
                onDone: root.detail = ""
            }
        }

        StageMetrics {
            id: metrics
            objectName: "metrics"
            visible: root.showMetrics
            Layout.fillWidth: true
            opacity: root.shown(3)
            transform: Translate {
                y: (1 - root.shown(3)) * Space.s
            }
            onOpen: root.openTab("metrics")
        }
    }
}
