pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import qs.modules.notch
import qs.modules.widgets.dashboard.widgets
import qs.modules.widgets.dashboard.controls
import qs.modules.widgets.dashboard.wallpapers
import qs.modules.widgets.dashboard.metrics
import qs.modules.widgets.dashboard.home
import qs.modules.widgets.dashboard.stage
import qs.config
import "DashboardTabs.js" as DashboardTabs

NotchAnimationBehavior {
    id: root

    property int leftPanelWidth
    property string screenName: ""

    property var state: QtObject {
        property int currentTab: GlobalStates.dashboardCurrentTab
    }

    // Stable tab indices (DashboardTabs.js) in header order; hidden tabs are left out.
    readonly property var tabOrder: DashboardTabs.visibleIndices(Config.layout.dashboard.tabs)
    readonly property int tabCount: DashboardTabs.tabs.length
    // Bento edit mode of the widgets tab (toggled from the header).
    property bool bentoEditing: false
    // Between the header row and the tab content.
    readonly property int headerGap: Look.groupGap
    // layout.dashboard.home: the widgets tab shows the stage, the composed
    // home or the bento grid (unknown values: the stage).
    readonly property string home: DashboardTabs.homeOf(Config.layout.dashboard.home)
    readonly property bool homeBento: home === "bento"
    // Nothing plays on the stage home: its hero shows the time large.
    property bool stageIdle: false
    // One stable size for every tab: the widgets tab's (stage, composed home
    // or bento grid, always loaded while open) is the largest, so switching
    // tabs never resizes the dashboard; the other tabs fill it.
    readonly property Item widgetsItem: widgetsTabLoader.item as Item
    readonly property real widgetsWidth: !homeBento && widgetsItem ? widgetsItem.implicitWidth : 780
    readonly property real widgetsHeight: widgetsItem ? widgetsItem.implicitHeight : 430
    // Room the screen leaves for the dashboard (air on every side).
    readonly property var screenObj: {
        for (const s of Quickshell.screens)
            if (s.name === root.screenName)
                return s;
        return null;
    }
    readonly property real nonAnimWidth: DashboardTabs.fitScreen(widgetsWidth, screenObj ? screenObj.width : 0, Space.xl)

    onHomeBentoChanged: bentoEditing = false

    implicitWidth: nonAnimWidth
    implicitHeight: DashboardTabs.fitScreen(header.implicitHeight + headerGap + Math.max(430, widgetsHeight), screenObj ? screenObj.height : 0, Space.xl * 2)

    // Track which tabs have been loaded (for lazy loading)
    property var loadedTabs: ({
            0: true
        }) // Tab 0 (widgets) loaded by default

    // LRU Tab Management
    property var lruAccessOrder: [0]  // Tracks access order: [0] means tab 0 is most recent
    property var lruTabsLoaded: ({
            0: true
        })  // Reflects which tabs are actually loaded

    // Update LRU on tab access
    function updateLRUAccess(tabIndex) {
        // Remove if already in list
        const idx = lruAccessOrder.indexOf(tabIndex);
        if (idx !== -1) {
            lruAccessOrder.splice(idx, 1);
        }
        // Add to end (most recent)
        lruAccessOrder.push(tabIndex);
        updateLoadedTabs();
    }

    // Determine which tabs should be loaded based on LRU and config
    function updateLoadedTabs() {
        let newLoadedTabs = {};

        // Always load tab 0 (widgets bento) to avoid "jumpy" opening
        newLoadedTabs[0] = true;

        // Always load current tab
        newLoadedTabs[root.state.currentTab] = true;

        if (Config.performance.dashboardPersistTabs) {
            // Load up to maxPersistentTabs most recent tabs
            const maxTabs = Math.max(1, Config.performance.dashboardMaxPersistentTabs);
            const startIdx = Math.max(0, lruAccessOrder.length - maxTabs);
            for (let i = startIdx; i < lruAccessOrder.length; i++) {
                newLoadedTabs[lruAccessOrder[i]] = true;
            }
        }

        lruTabsLoaded = newLoadedTabs;
    }

    // Check if a tab should be loaded
    function shouldTabBeLoaded(tabIndex) {
        // When the dashboard is closed, keep only tab 0 (launcher) alive so
        // the heavy tabs (wallpapers, clipboard, notes...) release their
        // objects and image caches instead of remaining resident.
        if (!root.isVisible) {
            if (Config.performance.dashboardPersistTabs) {
                return tabIndex === 0 || lruTabsLoaded[tabIndex] === true;
            }
            return tabIndex === 0;
        }

        if (tabIndex === 0)
            return true; // Always load the widgets tab (Tab 0)

        if (Config.performance.dashboardPersistTabs) {
            return lruTabsLoaded[tabIndex] === true;
        } else {
            // Without persistence, only load current tab
            return root.state.currentTab === tabIndex;
        }
    }

    focus: true

    // Usar el comportamiento estándar de animaciones del notch
    isVisible: GlobalStates.dashboardOpen

    // Navegar a la pestaña seleccionada cuando se abre el dashboard
    Component.onCompleted: {
        root.state.currentTab = GlobalStates.dashboardCurrentTab;
    }

    // Focus search input when dashboard opens to different tabs
    onIsVisibleChanged: {
        if (isVisible) {
            // Check if current item supports focus, otherwise default logic for launcher
            if (stack.currentItem && stack.currentItem.focusSearchInput) {
                focusUnifiedLauncherTimer.restart();
            } else if (GlobalStates.dashboardCurrentTab === 0) {
                Notifications.hideAllPopups();
                focusUnifiedLauncherTimer.restart();
            }
        } else {
            // Reset launcher state when dashboard closes
            GlobalStates.clearLauncherState();
            root.bentoEditing = false;
        }
    }

    // Timer para focus en unified launcher tab
    Timer {
        id: focusUnifiedLauncherTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (stack.currentItem && stack.currentItem.focusSearchInput) {
                stack.currentItem.focusSearchInput();
            }
        }
    }

    // Escuchar cambios en dashboardCurrentTab para navegar automáticamente
    Connections {
        target: GlobalStates
        function onDashboardCurrentTabChanged() {
            if (GlobalStates.dashboardCurrentTab !== root.state.currentTab) {
                stack.navigateToTab(GlobalStates.dashboardCurrentTab);
            }
        }

        // Focus cuando cambia el texto del launcher (por shortcuts con prefix)
        function onLauncherSearchTextChanged() {
            if (isVisible && GlobalStates.dashboardCurrentTab === 0) {
                focusUnifiedLauncherTimer.restart();
            }
        }
    }

    Column {
        id: mainLayout
        anchors.fill: parent
        spacing: root.headerGap

        StageHeader {
            id: header
            objectName: "header"
            width: parent.width
            order: root.tabOrder
            currentTab: root.state.currentTab
            canEdit: root.state.currentTab === 0 && root.homeBento
            editing: root.bentoEditing
            // The idle stage hero shows the time large itself.
            showClock: !(root.state.currentTab === 0 && root.home === "stage" && root.stageIdle)
            onNavigate: index => stack.navigateToTab(index)
            onEditToggled: root.bentoEditing = !root.bentoEditing
        }

        // Content area
        Item {
            id: viewWrapper

            width: parent.width
            height: parent.height - header.height - root.headerGap

            clip: true

            // Custom Tab View with Lazy Loading + Persistence
            Item {
                id: stack
                anchors.fill: parent

                property int currentIndex: GlobalStates.dashboardCurrentTab

                // Update internal index when global changes
                Connections {
                    target: GlobalStates
                    function onDashboardCurrentTabChanged() {
                        stack.navigateToTab(GlobalStates.dashboardCurrentTab);
                    }
                }

                // Function to navigate to a specific tab
                function navigateToTab(index) {
                    if (index >= 0 && index < root.tabCount && index !== root.state.currentTab) {
                        // Reset launcher state when leaving unified launcher tab (tab 0)
                        if (root.state.currentTab === 0 && index !== 0) {
                            GlobalStates.clearLauncherState();
                            root.bentoEditing = false;
                        }

                        root.state.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;

                        // Update LRU when tab is accessed
                        root.updateLRUAccess(index);

                        if (index === 0) {
                            Notifications.hideAllPopups();
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                }

                // Tab 0: Unified Launcher
                TabLoader {
                    id: widgetsTabLoader
                    index: 0
                    sourceComponent: root.homeBento ? unifiedLauncherComponent : (root.home === "composed" ? homeComponent : stageComponent)
                    z: visible ? 1 : 0
                }

                // Tab 1: Wallpapers
                TabLoader {
                    index: 1
                    sourceComponent: wallpapersComponent
                    z: visible ? 1 : 0
                }

                // Tab 2: Metrics
                TabLoader {
                    index: 2
                    sourceComponent: metricsComponent
                    z: visible ? 1 : 0
                }

                // Helper to access current item for focus
                property var currentItem: {
                    switch (root.state.currentTab) {
                    case 0:
                        return children[0].item;
                    case 1:
                        return children[1].item;
                    case 2:
                        return children[2].item;
                    default:
                        return null;
                    }
                }

                // Swipe up: next tab, down: previous (header order).
                DashboardSwipe {
                    anchors.fill: parent
                    onSwiped: delta => {
                        if (!root.bentoEditing)
                            stack.navigateToTab(DashboardTabs.step(root.tabOrder, root.state.currentTab, delta, false));
                    }
                }
            }
        }
    }

    // Generic Tab Loader Component
    component TabLoader: Loader {
        id: slot
        // Stable tab index (DashboardTabs.js).
        property int index: 0
        anchors.fill: parent
        // Load based on LRU strategy or if currently active.
        // When the dashboard closes (isVisible false) tabs are
        // unloaded so their image caches / GL pools are released;
        // currentTab alone must NOT keep heavy tabs resident.
        active: root.shouldTabBeLoaded(slot.index)
        readonly property bool current: root.state.currentTab === slot.index
        // Where this tab waits: before (-1) or after (1) the current one in
        // header order. Switching slides the new tab in from its side while
        // the old one slides the other way and fades (clicks, Ctrl+Tab,
        // wheel and swipes alike).
        readonly property int side: root.tabOrder.indexOf(slot.index) < root.tabOrder.indexOf(root.state.currentTab) ? -1 : 1
        visible: current || opacity > 0
        enabled: current
        opacity: current ? 1 : 0
        transform: Translate {
            x: slot.current ? 0 : slot.side * Space.xxl
            Behavior on x {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }

        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: slot.current ? Motion.glide.duration : Motion.micro.duration
            }
        }

        // Forward focus
        onLoaded: {
            if (visible && item && item.focusSearchInput) {
                focusUnifiedLauncherTimer.restart();
            }
        }

        // Ensure focus when becoming visible
        onVisibleChanged: {
            if (visible && item && item.focusSearchInput) {
                focusUnifiedLauncherTimer.restart();
            }
        }
    }

    // Atajos de teclado para navegación
    Shortcut {
        id: nextTabShortcut
        sequence: "Ctrl+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            stack.navigateToTab(DashboardTabs.step(root.tabOrder, root.state.currentTab, 1));
        }
    }

    Shortcut {
        id: prevTabShortcut
        sequence: "Ctrl+Shift+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            stack.navigateToTab(DashboardTabs.step(root.tabOrder, root.state.currentTab, -1));
        }
    }

    // Animated size properties for smooth transitions
    property real animatedWidth: implicitWidth
    property real animatedHeight: implicitHeight

    width: animatedWidth
    height: animatedHeight

    // Update animated properties when implicit properties change
    onImplicitWidthChanged: animatedWidth = implicitWidth
    onImplicitHeightChanged: animatedHeight = implicitHeight

    Behavior on animatedWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
            easing.overshoot: 1.1
        }
    }

    // Component definitions for better performance (defined once, reused)
    Component {
        id: unifiedLauncherComponent
        BentoView {
            cols: Config.layout.dashboard.grid.cols
            cells: Config.layout.dashboard.grid.cells
            editing: root.bentoEditing
            onEditingRequested: on => root.bentoEditing = on
            onCommit: cells => Config.layout.dashboard.grid.cells = cells
        }
    }

    Component {
        id: homeComponent
        HomeView {}
    }

    Component {
        id: stageComponent
        StageView {
            id: stage
            onOpenTab: id => stack.navigateToTab(DashboardTabs.indexOf(id))

            Binding {
                target: root
                property: "stageIdle"
                value: !stage.playing
            }
        }
    }

    Component {
        id: metricsComponent
        MetricsTab {}
    }

    Component {
        id: wallpapersComponent
        WallpapersTab {}
    }
}
