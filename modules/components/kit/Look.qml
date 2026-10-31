pragma Singleton
import QtQuick
import qs.config
import "../../theme/VisualLanguage.js" as VisualLanguage
import "KitStates.js" as KitStates
import qs.modules.components.kit

// The visual language (theme.language) as the kit draws it: group boxes,
// dividers and the rest / hover / active look of controls. Every decision
// lives in VisualLanguage.kit(); components read these properties and never
// branch on the language name.
QtObject {
    id: root

    readonly property string language: VisualLanguage.normalize(Config.theme.language)
    readonly property var spec: VisualLanguage.kit(Config.theme.language)
    readonly property var group: root.spec.group
    readonly property var control: root.spec.control
    readonly property var instrument: VisualLanguage.instrument(Config.theme.language)

    function alpha(role: string, a: real): color {
        if (role === "" || a <= 0)
            return "transparent";
        const c = Qt.color(Config.resolveColor(role));
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }

    // Divider / Group
    readonly property bool dividers: root.spec.dividers
    readonly property bool groupDivider: root.group.divider
    readonly property bool groupBoxed: root.group.fillOpacity > 0
    readonly property color groupFill: root.alpha(root.group.fill, root.group.fillOpacity)
    readonly property color groupOutline: root.alpha("overBackground", root.group.outline)
    readonly property color groupHighlight: Qt.rgba(1, 1, 1, root.group.highlight)
    // Dark bottom edge of a bevelled box (device), transparent elsewhere.
    readonly property color groupShade: root.alpha("shadow", root.group.shade || 0)
    readonly property int groupRadius: ({
            "card": Space.controlRadius + 4,
            "small": Space.smallRadius
        })[root.group.radius] || 0
    readonly property int groupPadding: root.group.padding === "" ? 0 : Space[root.group.padding]
    // Space between stacked groups, and the padding of a Surface around them.
    readonly property int groupGap: Space[root.group.gap]
    readonly property int surfacePadding: Space[root.group.inset]

    // Floating surfaces (Surface `floating`: OSDs): null keeps the theme's
    // popup surface (ink, classic); glass is a translucent frosted box with
    // a hairline edge and a top highlight, tiles a solid tile.
    readonly property var float: root.spec.float || null
    readonly property bool floatBoxed: root.float !== null
    readonly property color floatFill: root.floatBoxed ? root.alpha(root.float.fill, root.float.fillOpacity) : "transparent"
    readonly property color floatOutline: root.floatBoxed ? root.alpha("overBackground", root.float.outline) : "transparent"
    readonly property color floatHighlight: Qt.rgba(1, 1, 1, root.floatBoxed ? root.float.highlight : 0)

    // Lighting (theme.lighting, Lighting.qml): strength of the lit top edge
    // of shell surfaces (0 where the language draws no edges) and the peak
    // alpha of the cursor lantern.
    readonly property real edgeLight: root.spec.light.edge
    readonly property real lanternGlow: root.spec.light.lantern

    // App windows (settings): glass draws a translucent frosted background
    // over the desktop; null keeps the theme's opaque "bg" surface.
    readonly property bool windowTranslucent: !!root.spec.window
    readonly property color windowFill: root.windowTranslucent ? root.alpha(root.spec.window.fill, root.spec.window.fillOpacity) : "transparent"

    // Controls (IconButton, Chip, ListRow hover). Without a control spec
    // (classic) the theme's "common" / "focus" variants draw them.
    readonly property bool boxedControls: root.control !== null
    readonly property bool solidActive: root.boxedControls && root.control.solidActive
    readonly property bool squareControls: root.boxedControls && root.control.shape === "square"
    readonly property int labelWeight: root.boxedControls ? root.control.weight : Font.Normal
    readonly property int activeLabelWeight: root.boxedControls ? root.control.activeWeight : Font.Medium
    readonly property color controlEdge: root.boxedControls ? root.alpha("overBackground", root.control.edge) : "transparent"

    function controlFill(hovered: bool): color {
        if (!root.boxedControls)
            return "transparent";
        return hovered ? root.alpha(root.control.hoverFill, root.control.hover) : root.alpha(root.control.fill, root.control.rest);
    }

    // Big controls (Tile, LevelSlider): a raised surface even where the
    // small controls are ghosts. The language's control box where it has a
    // visible one, otherwise a soft ink wash; round languages take the
    // surface radius, square ones the control radius.
    function raisedFill(hovered: bool): color {
        if (root.boxedControls && root.control.rest > 0)
            return root.controlFill(hovered);
        return root.alpha("overBackground", hovered ? 0.12 : 0.07);
    }

    // A tonal fill (accent container): the accent held back so it reads as
    // a level, not as an action; the ink on it stays the text colour.
    readonly property real tonalStrength: 0.36
    function tonal(c: color): color {
        return Qt.alpha(c, root.tonalStrength);
    }

    function bigRadius(h: real): real {
        return Space.clampRadius(root.squareControls ? Space.controlRadius : Space.surfaceRadius, h);
    }

    // Instruments (VisualLanguage.instrument): how level controls, live
    // numbers and active tiles draw, and the inset screen behind readouts.
    //   levelControl  "slider" | "knob"     (LevelSlider)
    //   readout       "text" | "segment"    (live numbers)
    //   ledIndicator  an active Tile lights an LED instead of a solid fill
    readonly property string levelControl: root.instrument.levelControl
    readonly property string readout: root.instrument.readout
    readonly property bool ledIndicator: root.instrument.indicator === "led"
    readonly property color wellFill: root.alpha(root.instrument.well.fill, root.instrument.well.opacity)
    // Inner shadow along the top edge of a well.
    readonly property color wellEdge: root.alpha("shadow", root.instrument.well.edge)
    readonly property bool monoLabels: root.instrument.label.mono
    readonly property real labelTracking: root.instrument.label.tracking

    // Opacity of the accent tint that marks a selected / active item
    // (KitStates "active"): for lists that draw their own selection box.
    readonly property real activeTint: KitStates.opacity("active", false)

    // Icon buttons: round, or the control radius in square languages.
    function buttonRadius(h: real): real {
        return root.squareControls ? Space.clampRadius(Space.controlRadius, h) : Space.round(h);
    }

    // Chips and rows: the control radius, the small one in square languages.
    function chipRadius(h: real): real {
        return Space.clampRadius(root.squareControls ? Space.smallRadius : Space.controlRadius, h);
    }
}
