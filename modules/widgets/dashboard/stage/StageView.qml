import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.widgets.dashboard.home
import qs.modules.widgets.dashboard.widgets
import qs.config

// The stage home (layout.dashboard.home = "stage"): a hero and two
// columns of different weight, then a thin metrics strip.
//   left   the hero (StageHero: the player tinted by its art, or the
//          greeting and the large clock), the toggles and the levels
//   right  NEXT (StageNext, the largest block), the week (StageWeek; it
//          opens the month) and the notifications (2-3 rows); a toggle's,
//          level's or the week's details take the column's place
//   bottom StageMetrics (layout.dashboard.showMetrics), opens metrics
// The view offers its natural size and fills what it is given: the hero
// and NEXT take the free height. Sections enter with a short stagger.
Item {
    id: root

    // Between the columns (around the divider where groups have no box).
    readonly property int gap: Look.groupBoxed ? Look.groupGap : Space.l
    readonly property int leftW: Metrics.sheetW
    readonly property int rightW: Metrics.launcherWideW - Metrics.sheetW - root.gap * (Look.groupBoxed ? 1 : 2) - (Look.groupBoxed ? 0 : Space.hairline)
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

    signal openTab(string id)

    function openDetail(kind: string) {
        root.detail = root.detail === kind ? "" : kind;
    }

    onVisibleChanged: {
        if (!visible)
            root.detail = "";
        else
            enter.restart();
    }

    implicitWidth: Metrics.launcherWideW
    implicitHeight: Math.max(Metrics.dashH + Space.xxl, root.leftFull, right.implicitHeight) + root.metricsH

    CalendarEvents {
        id: events
        objectName: "calendarEvents"
        active: root.visible
        days: 7
        limit: 8
    }

    // Short stagger as the home appears (off with animations off).
    SequentialAnimation {
        id: enter
        PropertyAction {
            targets: [left, right, metrics]
            property: "opacity"
            value: Config.animDuration > 0 ? 0 : 1
        }
        NumberAnimation {
            target: left
            property: "opacity"
            to: 1
            duration: Config.animDuration > 0 ? Motion.enter.duration / 2 : 0
        }
        NumberAnimation {
            target: right
            property: "opacity"
            to: 1
            duration: Config.animDuration > 0 ? Motion.enter.duration / 2 : 0
        }
        NumberAnimation {
            target: metrics
            property: "opacity"
            to: 1
            duration: Config.animDuration > 0 ? Motion.enter.duration / 3 : 0
        }
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
                Layout.horizontalStretchFactor: root.leftW
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Look.groupGap

                StageHero {
                    id: hero
                    objectName: "hero"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.compact ? hero.naturalHeight * 0.6 : hero.naturalHeight
                }

                Group {
                    id: controls
                    objectName: "controls"
                    Layout.fillWidth: true
                    divider: true

                    StageToggles {
                        id: toggles
                        objectName: "toggles"
                        compact: root.compact
                        width: parent.width
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

            ColumnLayout {
                id: right
                Layout.preferredWidth: root.rightW
                Layout.horizontalStretchFactor: root.rightW
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Look.groupGap

                StageNext {
                    id: next
                    objectName: "next"
                    visible: root.detail === ""
                    events: events.available ? events.events : []
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: next.minimumHeight
                    Layout.preferredHeight: next.naturalHeight
                }

                StageWeek {
                    objectName: "week"
                    divider: true
                    visible: root.detail === ""
                    events: events.available ? events.events : []
                    Layout.fillWidth: true
                    onOpenMonth: root.openDetail("month")
                }

                StageNotifications {
                    id: notifications
                    objectName: "notifications"
                    visible: root.detail === ""
                    divider: true
                    Layout.fillWidth: true
                    // Up to three cards; on a low screen down to one (it scrolls).
                    Layout.fillHeight: true
                    Layout.preferredHeight: Math.min(notifications.wantedHeight, notifications.chrome + 3 * (notifications.rowH + notifications.rowGap))
                    Layout.maximumHeight: Layout.preferredHeight
                    Layout.minimumHeight: Math.min(notifications.wantedHeight, notifications.minimumHeight)
                }

                HomeDetail {
                    objectName: "detail"
                    visible: root.detail !== ""
                    kind: root.detail
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onDone: root.detail = ""
                }
            }
        }

        StageMetrics {
            id: metrics
            objectName: "metrics"
            visible: root.showMetrics
            Layout.fillWidth: true
            onOpen: root.openTab("metrics")
        }
    }
}
