import QtQuick
import Quickshell.Wayland
import qs.modules.services
import qs.modules.globals
import qs.config
import "StripMath.js" as StripMath

// Window previews of every workspace in the strip, laid out on the belt's
// one-row grid. Reuses OverviewWindow unchanged; it finds the strip root
// through its parents (dragArea > window > this item > belt > strip).
Item {
    id: windowSpace

    required property Item strip
    readonly property var motion: Motion

    anchors.fill: parent

    readonly property var windowData: {
        const monId = strip.monitorId;
        const toplevels = ToplevelManager.toplevels.values;
        return strip.windowList.filter(win => win?.workspace?.id > 0 && win.monitor === monId).map(win => ({
                    windowData: win,
                    toplevel: (() => {
                            const cls = win.class || "";
                            if (!cls)
                                return null;
                            const candidates = toplevels.filter(t => t.appId === cls);
                            if (candidates.length <= 1)
                                return candidates[0] || null;
                            return candidates.find(t => t.title === (win.title || "")) || candidates[0];
                        })()
                }));
    }

    Repeater {
        model: windowSpace.windowData

        delegate: OverviewWindow {
            id: window
            required property var modelData
            readonly property int wsId: windowData?.workspace?.id ?? 1

            windowData: modelData.windowData
            toplevel: modelData.toplevel
            scale: windowSpace.strip.previewScale
            availableWorkspaceWidth: windowSpace.strip.workspaceImplicitWidth
            availableWorkspaceHeight: windowSpace.strip.workspaceImplicitHeight
            monitorData: windowSpace.strip.monitorData
            barPosition: windowSpace.strip.barPosition
            barReserved: windowSpace.strip.barReserved

            isSearchMatch: windowSpace.strip.isWindowMatched(windowData?.address)
            isSearchSelected: windowSpace.strip.isWindowSelected(windowData?.address)

            xOffset: Math.round(StripMath.cellX(windowSpace.strip.cellW, windowSpace.strip.workspaceSpacing, wsId) + windowSpace.strip.workspacePadding / 2)
            yOffset: Math.round(windowSpace.strip.workspacePadding / 2)

            opacity: StripMath.emphasis(wsId, windowSpace.strip.selected)
            Behavior on opacity {
                enabled: windowSpace.motion.morph.duration > 0
                NumberAnimation {
                    duration: windowSpace.motion.morph.duration
                    easing.type: windowSpace.motion.morph.easing
                }
            }

            onDragStarted: windowSpace.strip.draggingFromWorkspace = wsId
            onDragFinished: targetWorkspace => {
                windowSpace.strip.draggingFromWorkspace = -1;
                if (targetWorkspace !== -1 && targetWorkspace !== wsId)
                    YozdService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
            }
            onWindowClicked: {
                Visibilities.setActiveModule("", true);
                Qt.callLater(() => YozdService.dispatch(`focuswindow address:${windowData.address}`));
            }
            onWindowClosed: YozdService.dispatch(`closewindow address:${windowData.address}`)
        }
    }
}
