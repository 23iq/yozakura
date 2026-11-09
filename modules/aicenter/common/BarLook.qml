pragma Singleton
import QtQuick
import qs.config
import qs.modules.components.kit

// Look and behaviour knobs of the AI bar (ai.appearance.*, ai.behavior.*)
// resolved in one place for every part of the bar. Sizes are the kit's
// tokens: the density picks a step of the Space scale, text sizes are the
// Type roles scaled by ai.appearance.fontScale (AiText applies them).
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

    // Density on the Space scale: `gap` between the rows of a group,
    // `groupGap` between groups, `pad` inside a card / bubble.
    readonly property int gap: compactDensity ? Space.xs : Space.s
    readonly property int groupGap: compactDensity ? Space.m : Space.l
    readonly property int pad: compactDensity ? Space.s : Space.m

    // A Type role's pixel size at the AI text scale (mono: the mono face,
    // which the theme sizes apart from the body face).
    function size(role: string): int {
        return Math.max(8, Math.round(Type.size(role) * root.fontScale));
    }
    function monoSize(role: string): int {
        const base = Math.max(1, Config.theme.fontSize);
        return Math.max(8, Math.round(Type.size(role) * Config.theme.monoFontSize / base * root.fontScale));
    }
    function time(ms) {
        return ms ? Qt.formatTime(new Date(ms), "hh:mm") : "";
    }
}
