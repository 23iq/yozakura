import QtQuick
import qs.config
import qs.modules.services
import "WorkspaceNumerals.js" as Numerals
import qs.modules.theme

// Number of a workspace slot in the configured numeral system; fills the
// slot. Systems without fit hints (arabic) keep the classic text metrics.
// The others are fitted by their ink box: sized from the theme font size,
// condensed then scaled down when long (十一, XVIII), and centered on the
// ink so CJK and Latin glyphs sit mid-pill whatever the font's metrics.
Item {
    id: root

    required property int workspaceId
    property color color

    readonly property var numeralSystem: Numerals.get(Config.workspaces.numeralStyle)
    readonly property var fit: numeralSystem.fit
    readonly property bool optical: !!fit
    readonly property string text: Numerals.format(numeralSystem.id, workspaceId)
    readonly property string fontFamily: NumeralFonts.family(text)
    readonly property real basePixelSize: Config.theme.fontSize * (optical ? fit.em : 1)

    // Ink box at the base size, then the fitted size and compression.
    readonly property var fitting: {
        if (!optical)
            return {
                scale: 1,
                condense: 1
            };
        const ink = baseMetrics.tightBoundingRect;
        return Numerals.fitLabel(fit, ink.width, ink.height, Math.min(width, height));
    }

    function legacyFontSize(label) {
        const shrink = label.length > 1 && label !== "10" ? (label.length - 1) * 2 : 0;
        return Math.round(Math.max(1, Config.theme.fontSize - shrink));
    }

    TextMetrics {
        id: baseMetrics
        text: root.text
        font.family: root.fontFamily
        font.weight: label.font.weight
        font.pixelSize: Math.max(1, Math.round(root.basePixelSize))
    }

    TextMetrics {
        id: inkMetrics
        text: root.text
        font: label.font
    }

    Text {
        id: label

        readonly property rect ink: inkMetrics.tightBoundingRect

        anchors.centerIn: root.optical ? undefined : parent
        // Optical centering: put the middle of the ink box on the slot center.
        x: root.optical ? Math.round(root.width / 2 - (ink.x + ink.width / 2)) : 0
        y: root.optical ? Math.round(root.height / 2 - (baselineOffset + ink.y + ink.height / 2)) : 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: root.fontFamily
        font.weight: root.optical ? NumeralFonts.weight(root.text) : Font.Normal
        font.pixelSize: root.optical ? Math.max(1, Math.round(root.basePixelSize * root.fitting.scale)) : root.legacyFontSize(text)
        text: root.text
        color: root.color
        elide: root.optical ? Text.ElideNone : Text.ElideRight

        // Long labels are condensed around their ink center (tate-chu-yoko
        // style), the shell's distance-field text keeps them crisp.
        transform: Scale {
            origin.x: label.ink.x + label.ink.width / 2
            xScale: root.fitting.condense
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }
}
