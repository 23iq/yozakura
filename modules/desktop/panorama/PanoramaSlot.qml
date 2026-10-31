import QtQuick
import qs.modules.services
import qs.config
import "PanoramaMath.js" as PanoramaMath

// The panorama slot of a screen: its active workspace's position in the
// workspace list (`index`) out of `count`. niri keeps a per-output list in
// display order; Hyprland/MangoWC use workspace ids.
QtObject {
    id: root

    property var screen: null
    readonly property var monitor: YozdService.monitorFor(screen)
    readonly property var _workspaces: YozdService.workspaces
    readonly property var info: PanoramaMath.slot(YozdService.compositorName === "niri", monitor, _workspaces ? _workspaces.values : [], Config.workspaces.shown)
    readonly property int index: info.index
    readonly property int count: info.count
}
