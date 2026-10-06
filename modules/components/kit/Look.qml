pragma Singleton
import QtQuick
import qs.config
import "../../theme/VisualLanguage.js" as VisualLanguage
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
    readonly property int groupRadius: ({
            "card": Space.controlRadius + 4,
            "small": Space.smallRadius
        })[root.group.radius] || 0
    readonly property int groupPadding: root.group.padding === "" ? 0 : Space[root.group.padding]
    // Space between stacked groups, and the padding of a Surface around them.
    readonly property int groupGap: Space[root.group.gap]
    readonly property int surfacePadding: Space[root.group.inset]

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

    // Icon buttons: round, or the control radius in square languages.
    function buttonRadius(h: real): real {
        return root.squareControls ? Space.clampRadius(Space.controlRadius, h) : Space.round(h);
    }

    // Chips and rows: the control radius, the small one in square languages.
    function chipRadius(h: real): real {
        return Space.clampRadius(root.squareControls ? Space.smallRadius : Space.controlRadius, h);
    }
}
