pragma Singleton
import QtQuick
import qs.config
import "DensityMetrics.js" as DensityMetrics

// Density-scaled layout sizes. "cozy" (default) equals the historic literals.
QtObject {
    readonly property string density: Config.theme && Config.theme.density ? Config.theme.density : "cozy"
    readonly property var all: DensityMetrics.metrics(density)

    readonly property int rowHeight: all.rowHeight
    readonly property int iconSize: all.iconSize
    readonly property int badgeHeight: all.badgeHeight
    readonly property int spacing: all.spacing
    readonly property int padding: all.padding
    readonly property int launcherCompactW: all.launcherCompactW
    readonly property int launcherCompactH: all.launcherCompactH
    readonly property int launcherWideW: all.launcherWideW
    readonly property int launcherWideH: all.launcherWideH
    readonly property int launcherLeftPanelW: all.launcherLeftPanelW
    readonly property int dashTabWidth: all.dashTabWidth
    readonly property int dashWideW: all.dashWideW
    readonly property int dashNarrowW: all.dashNarrowW
    readonly property int dashH: all.dashH
    readonly property int menuW: all.menuW
    readonly property int menuItemH: all.menuItemH
    readonly property int osdW: all.osdW
    readonly property int osdMargin: all.osdMargin
    readonly property int toastW: all.toastW
    readonly property int bentoCell: all.bentoCell
    readonly property int sheetW: all.sheetW
}
