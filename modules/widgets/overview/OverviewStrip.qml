pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.workspaces
import qs.modules.bar.panels
import qs.config
import "StripMath.js" as StripMath
import "OverviewSearch.js" as OverviewSearch

// Overview style "strip": a horizontal filmstrip of workspaces with the
// selected one centered. Reuses OverviewWindow for the previews, which expects
// the layout contract of the grid (this root is a one-row grid of `count`
// columns; windowSpace sits two levels under it).
Item {
    id: overviewRoot

    property var currentScreen: null
    readonly property var monitor: currentScreen ? YozdService.monitorFor(currentScreen) : YozdService.focusedMonitor
    readonly property var monitors: CompositorData.monitors
    readonly property int monitorId: monitor?.id ?? -1
    readonly property var monitorData: monitors.find(m => m.id === monitorId) ?? null
    readonly property var windowList: CompositorData.windowList
    readonly property string barPosition: Panels.primaryEdge
    readonly property var barPanel: monitor ? Visibilities.getBarPanelForScreen(monitor.name) : null
    readonly property bool isBarPinned: barPanel ? barPanel.pinned : (Config.bar.pinnedOnStartup ?? true)
    readonly property int barReserved: isBarPinned ? BarMetrics.notchRestHeight : 0

    // Contract with OverviewWindow (grid vocabulary).
    readonly property var motion: Motion
    readonly property real previewScale: Config.overview.scale
    readonly property real workspaceSpacing: Config.overview.workspaceSpacing
    readonly property real workspacePadding: 8
    readonly property int rows: 1
    readonly property int columns: count
    readonly property int workspacesShown: count
    readonly property int workspaceGroup: 0
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int count: StripMath.count(Config.workspaces.shown, activeId, windowList)
    readonly property int visibleCells: StripMath.visibleCount(Config.overview.columns, count)
    property int selected: activeId

    readonly property real workspaceImplicitWidth: dimension(true)
    readonly property real workspaceImplicitHeight: dimension(false)
    readonly property real cellW: workspaceImplicitWidth + workspacePadding
    readonly property real cellH: workspaceImplicitHeight + workspacePadding

    // Search (same surface as the grid; OverviewView forwards to it).
    property string searchQuery: ""
    property var matchingWindows: []
    property int selectedMatchIndex: 0

    property real appear: 0
    property bool settled: false

    implicitWidth: visibleCells * cellW + (visibleCells - 1) * workspaceSpacing
    implicitHeight: cellH
    clip: true
    focus: true

    function dimension(horizontal) {
        if (!monitorData)
            return horizontal ? 200 : 150;
        const rotated = (monitorData.transform % 2 === 1);
        const s = monitorData.scale || 1.0;
        let size = horizontal ? (rotated ? monitor?.height : monitor?.width) : (rotated ? monitor?.width : monitor?.height);
        size = ((size || (horizontal ? 1920 : 1080)) / s) * previewScale;
        const reservedAxis = horizontal ? (barPosition === "left" || barPosition === "right") : (barPosition === "top" || barPosition === "bottom");
        if (reservedAxis)
            size -= barReserved * previewScale;
        return Math.max(0, Math.round(size));
    }

    function stepWorkspace(dir) {
        if (searchQuery.length > 0)
            return false;
        selected = StripMath.step(selected, dir, count);
        return true;
    }

    function commit() {
        YozdService.dispatch(`workspace ${selected}`);
        Visibilities.setActiveModule("");
    }

    function resetSearch() {
        searchQuery = "";
    }

    function updateMatches() {
        matchingWindows = OverviewSearch.rank(searchQuery, windowList);
        selectedMatchIndex = matchingWindows.length > 0 ? 0 : -1;
        followMatch();
    }

    function followMatch() {
        const id = matchingWindows[selectedMatchIndex]?.workspace?.id;
        if (id > 0)
            selected = Math.min(id, count);
    }

    function selectNextMatch() {
        if (matchingWindows.length === 0)
            return;
        selectedMatchIndex = (selectedMatchIndex + 1) % matchingWindows.length;
        followMatch();
    }

    function selectPrevMatch() {
        if (matchingWindows.length === 0)
            return;
        selectedMatchIndex = (selectedMatchIndex - 1 + matchingWindows.length) % matchingWindows.length;
        followMatch();
    }

    function navigateToSelectedWindow() {
        const win = matchingWindows[selectedMatchIndex];
        if (searchQuery.length === 0 || !win) {
            if (searchQuery.length === 0)
                commit();
            return;
        }
        Visibilities.setActiveModule("", true);
        Qt.callLater(() => YozdService.dispatch(`focuswindow address:${win.address}`));
    }

    function isWindowMatched(address) {
        return searchQuery.length > 0 && matchingWindows.some(w => w?.address === address);
    }

    function isWindowSelected(address) {
        return matchingWindows.length > 0 && selectedMatchIndex >= 0 && matchingWindows[selectedMatchIndex]?.address === address;
    }

    onSearchQueryChanged: updateMatches()
    onWindowListChanged: if (searchQuery.length > 0)
        updateMatches()
    onActiveIdChanged: selected = activeId

    Keys.onPressed: event => {
        const dir = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0;
        if (dir !== 0) {
            event.accepted = stepWorkspace(dir);
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            selected = event.key === Qt.Key_Home ? 1 : count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            navigateToSelectedWindow();
            event.accepted = true;
        }
    }

    WheelHandler {
        id: wheel
        property real carry: 0
        onWheel: event => {
            carry += (event.angleDelta.y !== 0 ? -event.angleDelta.y : -event.angleDelta.x);
            while (Math.abs(carry) >= 120) {
                overviewRoot.stepWorkspace(carry > 0 ? 1 : -1);
                carry -= carry > 0 ? 120 : -120;
            }
        }
    }

    NumberAnimation on appear {
        id: appearAnim
        running: false
        from: 0
        to: 1
        duration: overviewRoot.motion.enter.duration
        easing.type: overviewRoot.motion.enter.easing
        easing.overshoot: overviewRoot.motion.enter.overshoot
    }

    Component.onCompleted: {
        if (overviewRoot.motion.enter.duration > 0)
            appearAnim.start();
        else
            appear = 1;
        settled = true;
    }

    // The belt moves horizontally; windowSpace must stay two levels under the
    // root (OverviewWindow reaches the root through its parents).
    Item {
        id: belt
        objectName: "belt"
        width: overviewRoot.count * overviewRoot.cellW + (overviewRoot.count - 1) * overviewRoot.workspaceSpacing
        height: overviewRoot.cellH
        x: StripMath.beltX(overviewRoot.implicitWidth, overviewRoot.cellW, overviewRoot.workspaceSpacing, overviewRoot.selected)
        opacity: overviewRoot.appear
        scale: 0.94 + 0.06 * overviewRoot.appear
        transformOrigin: Item.Center

        Behavior on x {
            enabled: overviewRoot.settled && overviewRoot.motion.morph.duration > 0
            NumberAnimation {
                duration: overviewRoot.motion.morph.duration
                easing.type: overviewRoot.motion.morph.easing
                easing.overshoot: overviewRoot.motion.morph.overshoot
            }
        }

        Repeater {
            model: overviewRoot.count
            delegate: OverviewStripCell {
                required property int index
                workspaceId: index + 1
                x: StripMath.cellX(overviewRoot.cellW, overviewRoot.workspaceSpacing, workspaceId)
                width: overviewRoot.cellW
                height: overviewRoot.cellH
                selected: workspaceId === overviewRoot.selected
                emphasis: StripMath.emphasis(workspaceId, overviewRoot.selected)
                dropHover: overviewRoot.draggingTargetWorkspace === workspaceId && overviewRoot.draggingFromWorkspace !== workspaceId
                onPicked: {
                    if (overviewRoot.draggingTargetWorkspace === -1) {
                        overviewRoot.selected = workspaceId;
                        YozdService.dispatch(`workspace ${workspaceId}`);
                    }
                }
                onOpened: {
                    if (overviewRoot.draggingTargetWorkspace === -1) {
                        overviewRoot.selected = workspaceId;
                        overviewRoot.commit();
                    }
                }
                onDragEntered: overviewRoot.draggingTargetWorkspace = workspaceId
                onDragExited: {
                    if (overviewRoot.draggingTargetWorkspace === workspaceId)
                        overviewRoot.draggingTargetWorkspace = -1;
                }
            }
        }

        OverviewStripWindows {
            id: windowSpace
            strip: overviewRoot
        }
    }
}
