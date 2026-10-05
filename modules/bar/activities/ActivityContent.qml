import QtQuick
import qs.config
import qs.modules.theme

// Inside of an activity island: leading indicator + label, or "+N".
Row {
    id: content

    // Activity object (see ActivityModel.js); null for the overflow island
    property var activity: null
    property int overflowCount: 0
    property real indicatorSize: 16
    property real fontSize: Styling.fontSize(-1)

    readonly property bool isOverflow: activity === null
    readonly property color accent: {
        if (!activity)
            return Colors.overBackground;
        const c = Colors[activity.color];
        return c !== undefined ? c : Colors.primary;
    }

    spacing: Math.round(indicatorSize * 0.45)

    ActivityIndicator {
        anchors.verticalCenter: parent.verticalCenter
        visible: !content.isOverflow
        kind: content.activity ? content.activity.indicator : "glyph"
        icon: content.activity ? content.activity.icon : ""
        image: content.activity ? content.activity.image : ""
        progress: content.activity ? content.activity.progress : -1
        accent: content.accent
        size: content.indicatorSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: content.isOverflow ? "+" + content.overflowCount : (content.activity ? content.activity.label : "")
        visible: text !== ""
        color: Colors.overBackground
        font.family: Config.theme.font
        font.pixelSize: content.fontSize
        font.weight: Font.DemiBold
        // Tabular figures keep ticking timers from wobbling
        font.features: ({
                "tnum": 1
            })
        elide: Text.ElideRight
        width: Math.min(implicitWidth, content.indicatorSize * 9)
    }
}
