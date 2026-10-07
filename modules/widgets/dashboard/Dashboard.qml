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
import qs.config
import "DashboardTabs.js" as DashboardTabs

NotchAnimationBehavior {
    id: root

    property int leftPanelWidth
    property string screenName: ""

    property var state: QtObject {
        property int currentTab: GlobalStates.dashboardCurrentTab
    }

    // Stable tab indices (DashboardTabs.js) in rail order; hidden tabs are left out.
    readonly property var tabOrder: DashboardTabs.visibleIndices(Config.layout.dashboard.tabs)
    readonly property int tabCount: DashboardTabs.tabs.length
    // Bento edit mode of the widgets tab (toggled from the rail).
    property bool bentoEditing: false
    readonly property int tabSpacing: Space.s
    // Space on each side of the rail divider.
    readonly property int railGap: Space.m

    readonly property int tabWidth: Space.controlM
    readonly property int railWidth: tabWidth + railGap * 2 + Space.hairline
    // layout.dashboard.home: the widgets tab shows the composed home view or the bento grid.
    readonly property bool homeComposed: (Config.layout.dashboard.home ?? "composed") !== "bento"
    // One stable size for every tab: the widgets tab's (composed home or bento
    // grid, always loaded while open) is the largest, so switching tabs never
    // resizes the dashboard; the other tabs fill it.
    readonly property Item widgetsItem: widgetsTabLoader.item as Item
    readonly property real widgetsWidth: homeComposed && widgetsItem ? widgetsItem.implicitWidth : 780
    readonly property real widgetsHeight: widgetsItem ? widgetsItem.implicitHeight : 430
    // Room the screen leaves for the dashboard (air on every side).
    readonly property var screenObj: {
        for (const s of Quickshell.screens)
            if (s.name === root.screenName)
                return s;
        return null;
    }
    readonly property real nonAnimWidth: DashboardTabs.fitScreen(widgetsWidth + railWidth, screenObj ? screenObj.width : 0, Space.xl)

    onHomeComposedChanged: bentoEditing = false

    implicitWidth: nonAnimWidth
    implicitHeight: DashboardTabs.fitScreen(Math.max(430, widgetsHeight), screenObj ? screenObj.height : 0, Space.xl * 2)

    // Track which tabs have been loaded (for lazy loading)
    property var loadedTabs: ({0: true}) // Tab 0 (widgets) loaded by default

    // LRU Tab Management
    property var lruAccessOrder: [0]  // Tracks access order: [0] means tab 0 is most recent
    property var lruTabsLoaded: ({0: true})  // Reflects which tabs are actually loaded

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

        if (tabIndex === 0) return true; // Always load the widgets tab (Tab 0)

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

    Row {
        id: mainLayout
        anchors.fill: parent
        spacing: root.railGap

        DashboardTabRail {
            id: tabsContainer
            width: root.tabWidth
            height: parent.height
            tabSpacing: root.tabSpacing
            order: root.tabOrder
            currentTab: root.state.currentTab
            canEdit: root.state.currentTab === 0 && !root.homeComposed
            editing: root.bentoEditing
            onNavigate: index => stack.navigateToTab(index)
            onEditToggled: root.bentoEditing = !root.bentoEditing
        }

        // A slot, so the content keeps its place where dividers are hidden (tiles).
        Item {
            width: Space.hairline
            height: parent.height

            Divider {
                vertical: true
                anchors.fill: parent
            }
        }

        // Content area
        Item {
            id: viewWrapper

            width: parent.width - root.railWidth
            height: parent.height

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

                // Generic Tab Loader Component
                component TabLoader : Loader {
                    anchors.fill: parent
                    // Load based on LRU strategy or if currently active.
                    // When the dashboard closes (isVisible false) tabs are
                    // unloaded so their image caches / GL pools are released;
                    // currentTab alone must NOT keep heavy tabs resident.
                    active: root.shouldTabBeLoaded(index)
                    
                    // Visibility handles the "switching"
                    visible: root.state.currentTab === index
                    
                    // Transitions
                    opacity: visible ? 1 : 0
                    transform: Translate {
                        y: visible ? 0 : (root.state.currentTab > index ? -20 : 20)
                        Behavior on y {
                             enabled: Config.animDuration > 0
                             NumberAnimation { duration: Config.animDuration; easing.type: Motion.morph.easing } 
                        }
                    }

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration; easing.type: Motion.enter.easing }
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

                // Tab 0: Unified Launcher
                TabLoader {
                    id: widgetsTabLoader
                    property int index: 0
                    sourceComponent: root.homeComposed ? homeComponent : unifiedLauncherComponent
                    z: visible ? 1 : 0
                }

                // Tab 1: Wallpapers
                TabLoader {
                    property int index: 1
                    sourceComponent: wallpapersComponent
                    z: visible ? 1 : 0
                }

                // Tab 2: Metrics
                TabLoader {
                    property int index: 2
                    sourceComponent: metricsComponent
                    z: visible ? 1 : 0
                }
                
                // Helper to access current item for focus
                property var currentItem: {
                    switch(root.state.currentTab) {
                        case 0: return children[0].item;
                        case 1: return children[1].item;
                        case 2: return children[2].item;
                        default: return null;
                    }
                }

                // Gesture handling para swipe vertical
                MouseArea {
                    anchors.fill: parent
                    property real startY: 0
                    property real startX: 0
                    property bool swiping: false
                    property real swipeThreshold: 50
                    
                    // Allow clicking through to tabs
                    propagateComposedEvents: true
                    preventStealing: false

                    onPressed: mouse => {
                        startY = mouse.y;
                        startX = mouse.x;
                        swiping = false;
                        mouse.accepted = false; // Let children handle clicks
                    }

                    onPositionChanged: mouse => {
                        let deltaY = mouse.y - startY;
                        let deltaX = Math.abs(mouse.x - startX);

                        // Solo considerar swipe vertical si el movimiento horizontal es mínimo
                        if (Math.abs(deltaY) > 20 && deltaX < 30) {
                            swiping = true;
                        }
                    }

                    onReleased: mouse => {
                        if (swiping) {
                            let deltaY = mouse.y - startY;

                            if (Math.abs(deltaY) > swipeThreshold && !root.bentoEditing) {
                                // Swipe up: next tab, down: previous (rail order)
                                stack.navigateToTab(DashboardTabs.step(root.tabOrder, root.state.currentTab, deltaY < 0 ? 1 : -1, false));
                            }
                        }
                        swiping = false;
                        mouse.accepted = false;
                    }
                }
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
        id: metricsComponent
        MetricsTab {}
    }

    Component {
        id: wallpapersComponent
        WallpapersTab {}
    }
}
