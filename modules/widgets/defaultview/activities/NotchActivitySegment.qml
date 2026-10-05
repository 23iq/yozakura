pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.bar.activities
import "NotchActivities.js" as NotchActivities

// One collapsed activity segment at an edge of the notch header: the side's
// top activity (+ up to two privacy glyphs, + a count badge). The width is
// fixed per content shape (label templates, tabular figures) so ticking
// timers never move the notch; it animates with the notch on change.
// `side` "leading" sits at the left edge, "trailing" at the right edge.
Item {
    id: segment

    property var items: []
    property string side: "leading"
    // Animation length of the notch's own geometry
    property int motionDuration: 0

    signal activated(var activity, int button)

    readonly property var content: NotchActivities.segment(segment.items, segment.side, 3)
    readonly property var item: segment.content ? segment.content.item : null
    readonly property bool shown: segment.item !== null
    // Forced hover (tests and renders); the pointer drives it otherwise
    property bool hoverOverride: false
    // Off while a notch panel is open (it would cover the panel title)
    property bool tooltipEnabled: true
    readonly property bool hovered: hover.hovered || segment.hoverOverride

    readonly property real indicatorSize: Math.round(Styling.fontSize(1))
    readonly property real gap: Math.round(Styling.fontSize(-4))
    // Space between the segment and the notch content it flanks
    readonly property real innerGap: Math.round(Styling.fontSize(-2))

    // Target width: the notch's contentWidth uses this, the visual width
    // animates towards it with the notch
    readonly property real targetWidth: segment.shown ? row.implicitWidth + segment.innerGap : 0
    width: targetWidth
    Behavior on width {
        enabled: segment.motionDuration > 0
        NumberAnimation {
            duration: segment.motionDuration
            easing.type: Easing.OutCubic
        }
    }
    implicitHeight: segment.indicatorSize + 4
    clip: true

    // Keep the last content while retracting
    property var shownContent: null
    onContentChanged: if (segment.content)
        segment.shownContent = segment.content
    readonly property var showItem: segment.shownContent ? segment.shownContent.item : null

    function accent(activity) {
        if (!activity)
            return Colors.overBackground;
        const c = Colors[activity.color];
        return c !== undefined ? c : Colors.primary;
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: segment.side === "leading" ? 0 : segment.width - row.implicitWidth
        spacing: segment.gap
        opacity: segment.shown ? 1 : 0
        Behavior on opacity {
            enabled: segment.motionDuration > 0
            NumberAnimation {
                duration: segment.motionDuration
            }
        }

        ActivityIndicator {
            anchors.verticalCenter: parent.verticalCenter
            kind: segment.showItem ? segment.showItem.indicator : "glyph"
            icon: segment.showItem ? segment.showItem.icon : ""
            image: segment.showItem ? segment.showItem.image : ""
            progress: segment.showItem && segment.showItem.progress !== undefined ? segment.showItem.progress : -1
            accent: segment.accent(segment.showItem)
            size: kind === "glyph" ? Math.round(segment.indicatorSize * 0.95) : segment.indicatorSize
        }

        // Fixed-width label (template width, tabular figures)
        Item {
            id: labelBox
            readonly property string label: segment.showItem ? String(segment.showItem.label || "") : ""
            visible: NotchActivities.hasLabel(segment.showItem)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(Math.max(template.advanceWidth, labelText.implicitWidth))
            height: labelText.implicitHeight

            TextMetrics {
                id: template
                font: labelText.font
                text: NotchActivities.widthTemplate(labelBox.label)
            }
            Text {
                id: labelText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: labelBox.label
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                font.features: ({
                        "tnum": 1
                    })
            }
        }

        Repeater {
            model: segment.shownContent ? segment.shownContent.extras : []
            delegate: ActivityIndicator {
                required property var modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                kind: "glyph"
                icon: modelData.icon
                image: modelData.image
                accent: segment.accent(modelData)
                size: Math.round(segment.indicatorSize * 0.95)
            }
        }

        NotchActivityBadge {
            anchors.verticalCenter: parent.verticalCenter
            count: segment.shownContent ? segment.shownContent.badge : 0
        }
    }

    HoverHandler {
        id: hover
        enabled: segment.shown
    }

    MouseArea {
        anchors.fill: parent
        enabled: segment.shown
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => segment.activated(segment.item, event.button)
    }

    StyledToolTip {
        show: hover.hovered && segment.shown && segment.tooltipEnabled
        tooltipText: segment.items.map(a => a.detail || a.label).filter(t => !!t).join("\n")
    }
}
