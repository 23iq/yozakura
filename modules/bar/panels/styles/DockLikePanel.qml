import QtQuick
import qs.modules.theme

// "dock-like": the bar sized to its content and centered on its edge (the
// panel's align defaults to center), groups in one run with dividers,
// modules at bar size on the bar surface, a density gap from the edge.
DockPanel {
    surface: "barbg"
    ownShadow: false
    outerMargin: Metrics.spacing
}
