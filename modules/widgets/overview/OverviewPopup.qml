import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.config
import "."

PanelWindow {
    id: overviewPopup

    readonly property var overviewView: overviewLoader.item

    // Next/previous workspace: the strip moves its selection, other styles switch
    function stepWorkspace(dir) {
        if (overviewView && overviewView.stepWorkspace(dir))
            return;
        const target = (YozdService.focusedWorkspace?.id || 1) + dir;
        if (target > Config.workspaces.shown)
            YozdService.dispatch("workspace 1");
        else if (target < 1)
            YozdService.dispatch("workspace " + Config.workspaces.shown);
        else
            YozdService.dispatch(dir > 0 ? "workspace r+1" : "workspace r-1");
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("overview")
    WlrLayershell.keyboardFocus: latch.keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool overviewOpen: screenVisibilities ? screenVisibilities.overview : false
    // The surface is mapped: shell.qml keeps the window loaded while true.
    readonly property bool mapped: latch.shown

    // Latched (SurfaceLatch): on close the search field lets go of the
    // input method, then keyboard focus drops, and the surface unmaps at
    // least a frame later (never in the same tick, also with 0 ms motion).
    visible: latch.shown
    exclusionMode: ExclusionMode.Ignore

    SurfaceLatch {
        id: latch
        active: overviewPopup.overviewOpen
        holdMs: Config.animDuration > 0 ? Motion.enter.duration : 0
        focusHost: overviewPopup.contentItem
    }

    // Mask to capture input on the entire window when open
    mask: Region {
        item: overviewOpen ? fullMask : emptyMask
    }

    // Full screen mask when open
    Item {
        id: fullMask
        anchors.fill: parent
    }

    // Empty mask when hidden
    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    FocusGrab {
        id: focusGrab
        windows: [overviewPopup]
        active: overviewOpen

        onCleared: {
            // Use Qt.callLater to avoid potential race conditions
            Qt.callLater(() => {
                if (overviewOpen) {
                    Visibilities.setActiveModule("");
                }
            });
        }
    }

    // Semi-transparent backdrop
    Scrim {
        id: backdrop
        shown: overviewPopup.overviewOpen
        onClicked: Visibilities.setActiveModule("")
    }

    // Main content column (search + overview)
    Item {
        id: mainContainer
        anchors.centerIn: parent
        width: Math.max(searchContainer.width, overviewContainer.width + (scrollbarContainer.visible ? scrollbarContainer.width + Space.s : 0))
        height: searchContainer.height + Space.s + overviewContainer.height

        opacity: overviewOpen ? 1 : 0
        scale: overviewOpen ? 1 : 0.9

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
                easing.overshoot: 1.2
            }
        }

        // Search input container
        StyledRect {
            id: searchContainer
            variant: "bg"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(400, overviewContainer.width)
            height: searchRow.implicitHeight + Space.l * 2
            radius: Look.radius("surface", height)

            // The rect\'s own shadow (also drawn by a corner style\'s mask)
            enableShadow: true

            RowLayout {
                id: searchRow
                anchors.fill: parent
                anchors.margins: Space.l
                spacing: Space.s

                Icon {
                    Layout.preferredWidth: Space.controlM
                    Layout.preferredHeight: Space.controlM
                    Layout.alignment: Qt.AlignVCenter
                    icon: Icons.overview
                    role: "title"
                    tone: "secondary"
                }

                // Search input
                SearchField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    boxed: true
                    placeholderText: I18n.t("overview.search")
                    handleTabNavigation: true
                    clearOnEscape: false

                    // Match counter suffix
                    KitText {
                        id: matchCounter
                        visible: overviewLoader.item && overviewLoader.item.searchQuery.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: Space.l
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!overviewLoader.item)
                                return "0";
                            const matches = overviewLoader.item.matchingWindows.length;
                            if (matches > 0) {
                                return `${overviewLoader.item.selectedMatchIndex + 1}/${matches}`;
                            }
                            return "0";
                        }
                        role: "caption"
                        tabular: true
                        color: (overviewPopup.overviewView && overviewPopup.overviewView.matchingWindows.length > 0) ? Type.accent : Type.danger
                        opacity: 0.8
                    }

                    onSearchTextChanged: text => {
                        if (overviewLoader.item) {
                            overviewLoader.item.searchQuery = text;
                        }
                    }

                    onAccepted: {
                        if (overviewLoader.item) {
                            overviewLoader.item.navigateToSelectedWindow();
                        }
                    }

                    onTabPressed: {
                        if (searchInput.text.length === 0) {
                            overviewPopup.stepWorkspace(1);
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onShiftTabPressed: {
                        if (searchInput.text.length === 0) {
                            overviewPopup.stepWorkspace(-1);
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onDownPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onUpPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onEscapePressed: {
                        if (searchInput.text.length > 0) {
                            searchInput.clear();
                            if (overviewLoader.item) {
                                overviewLoader.item.searchQuery = "";
                            }
                        } else {
                            Visibilities.setActiveModule("");
                        }
                    }

                    onLeftPressed: {
                        if (searchInput.text.length === 0) {
                            overviewPopup.stepWorkspace(-1);
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onRightPressed: {
                        if (searchInput.text.length === 0) {
                            overviewPopup.stepWorkspace(1);
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }
                }
            }
        }

        // Overview container
        Item {
            id: overviewContainer
            anchors.top: searchContainer.bottom
            anchors.topMargin: Space.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: overviewPopup.overviewView ? overviewPopup.overviewView.implicitWidth + Space.xl * 2 : 400
            height: overviewPopup.overviewView ? overviewPopup.overviewView.implicitHeight + Space.xl * 2 : 300

            // Background panel
            StyledRect {
                id: overviewBackground
                variant: "bg"
                anchors.fill: parent
                radius: Look.radius("surface")

                // The rect\'s own shadow (also drawn by a corner style\'s mask)
                enableShadow: true
            }

            // Loader for Overview to prevent issues during destruction
            Loader {
                id: overviewLoader
                anchors.centerIn: parent
                active: latch.shown

                sourceComponent: OverviewView {
                    currentScreen: overviewPopup.screen
                }
            }
        }

        // External scrollbar for scrolling mode (to the right of overview)
        StyledRect {
            id: scrollbarContainer
            visible: overviewLoader.item && overviewLoader.item.needsScrollbar
            variant: "bg"
            anchors.left: overviewContainer.right
            anchors.leftMargin: Space.s
            anchors.verticalCenter: overviewContainer.verticalCenter
            width: Space.xxl
            height: Math.max(overviewContainer.height * 0.6, 200)
            radius: Look.radius("surface", width)

            // The rect\'s own shadow (also drawn by a corner style\'s mask)
            enableShadow: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (overviewLoader.item && overviewLoader.item.flickable) {
                        const flickable = overviewLoader.item.flickable;
                        const delta = wheel.angleDelta.y > 0 ? -150 : 150;
                        flickable.contentY = Math.max(0, Math.min(flickable.contentY + delta, flickable.contentHeight - flickable.height));
                    }
                }
            }

            ScrollBar {
                id: externalScrollBar
                anchors.centerIn: parent
                height: parent.height - Space.l
                width: Space.m
                orientation: Qt.Vertical
                policy: ScrollBar.AlwaysOn

                position: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.yPosition : 0
                size: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.heightRatio : 1

                // Notify flickable when manually scrolling to disable animation
                onActiveChanged: {
                    if (overviewLoader.item) {
                        overviewLoader.item.isManualScrolling = active;
                    }
                }

                onPositionChanged: {
                    if (active && overviewLoader.item && overviewLoader.item.flickable) {
                        overviewLoader.item.flickable.contentY = position * overviewLoader.item.flickable.contentHeight;
                    }
                }

                contentItem: Mark {
                    implicitWidth: Space.m
                    color: externalScrollBar.hovered && !externalScrollBar.pressed ? Qt.lighter(Type.accent, 1.2) : Type.accent

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Motion.exit.duration
                        }
                    }
                }

                background: Mark {
                    implicitWidth: Space.m
                    color: Type.track
                }
            }
        }
    }

    // Ensure focus when overview opens
    onOverviewOpenChanged: {
        if (overviewOpen) {
            Qt.callLater(() => {
                searchInput.clear();
                if (overviewLoader.item) {
                    overviewLoader.item.resetSearch();
                }
                searchInput.focusInput();
            });
        }
    }
}
