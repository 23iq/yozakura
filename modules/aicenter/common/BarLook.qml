pragma Singleton
import QtQuick
import qs.modules.theme
import qs.config

// Look and behaviour knobs of the AI bar (ai.appearance.*, ai.behavior.*)
// resolved in one place for every part of the bar.
QtObject {
    id: root

    readonly property var appearance: Config.ai.appearance || ({})
    readonly property var behavior: Config.ai.behavior || ({})

    readonly property bool compactDensity: appearance.density === "compact"
    readonly property bool bubbles: appearance.messageStyle !== "flat"
    readonly property real fontScale: Math.max(0.6, Math.min(2, appearance.fontScale || 1))
    readonly property bool avatars: appearance.showAvatars === true
    readonly property bool timestamps: appearance.showTimestamps === true
    readonly property int animDuration: appearance.animations === false ? 0 : Config.animDuration
    readonly property bool thinkingExpanded: behavior.thinkingExpanded === true
    readonly property bool toolsExpanded: behavior.collapseTools === false
    readonly property bool autoScroll: behavior.autoScroll !== false
    readonly property bool showThinking: Config.ai.showThinking !== false

    // Spacing scale: one step between rows of a group, two between groups.
    readonly property int gap: compactDensity ? 6 : 10
    readonly property int groupGap: compactDensity ? 12 : 20
    readonly property int pad: compactDensity ? 10 : 14

    function font(offset) {
        return Math.round(Styling.fontSize(offset) * fontScale);
    }
    function mono(offset) {
        return Math.round(Styling.monoFontSize(offset) * fontScale);
    }
    function time(ms) {
        return ms ? Qt.formatTime(new Date(ms), "hh:mm") : "";
    }
}
