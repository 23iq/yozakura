pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "WallpaperGrid.js" as WallpaperGrid

// Componente principal para el selector de fondos de pantalla.
FocusScope {
    id: wallpapersTabRoot

    // Propiedades personalizadas para la funcionalidad del componente.
    property string searchText: ""
    property int selectedIndex: GlobalStates.wallpaperSelectedIndex

    // Función para actualizar el índice seleccionado de forma centralizada
    function setSelectedIndex(newIndex: int) {
        GlobalStates.wallpaperSelectedIndex = newIndex;
        selectedIndex = newIndex;
    }

    readonly property string currentScreenName: YozdService.focusedMonitor ? YozdService.focusedMonitor.name : ""

    property bool isPerScreen: {
        if (!GlobalStates.wallpaperManager || currentScreenName === "")
            return false;
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        return perScreen[currentScreenName] !== undefined;
    }

    // Wallpaper shown on the focused screen (its per-screen one, else the
    // global one): marked "current" in the grid.
    readonly property bool screenWallpaperKnown: GlobalStates.wallpaperManager !== null
    readonly property string screenWallpaper: {
        if (!GlobalStates.wallpaperManager)
            return "";
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        if (currentScreenName !== "" && perScreen[currentScreenName] !== undefined)
            return perScreen[currentScreenName] || "";
        return GlobalStates.wallpaperManager.currentWallpaper || "";
    }

    function togglePerScreenMode() {
        if (!GlobalStates.wallpaperManager || currentScreenName === "")
            return;

        if (isPerScreen) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(currentScreenName);
        } else {
            // Apply current wallpaper to this screen to toggle it on
            let currentWall = GlobalStates.wallpaperManager.currentWallpaper;
            if (currentWall) {
                GlobalStates.wallpaperManager.setWallpaper(currentWall, currentScreenName);
            }
        }
    }

    property var activeFilters: []  // Lista de tipos de archivo seleccionados para filtrar

    // Configuración interna del grid
    // Reflows with the tab's width (cells about three quarters of a bento cell).
    readonly property int gridColumns: WallpaperGrid.columnsFor(wallpaperGridContainer.width, Metrics.bentoCell * 0.75)
    readonly property int wallpaperMargin: 4

    // Array de elementos focusables para navegación cíclica
    property var focusableElements: [
        {
            id: "perScreenCheckbox",
            focusFunc: function () {
                perScreenToggle.focusToggle();
            }
        },
        {
            id: "oledCheckbox",
            focusFunc: function () {
                oledToggle.focusToggle();
            }
        },
        {
            id: "tintCheckbox",
            focusFunc: function () {
                tintToggle.focusToggle();
            }
        },
        {
            id: "schemeSelector",
            focusFunc: function () {
                schemeSelector.openAndFocus();
            }
        },
        {
            id: "filters",
            focusFunc: function () {
                wallpapersFilterBar.focusFilters();
            }
        }
    ]

    property int currentFocusIndex: -1

    // Función para enfocar el campo de búsqueda
    function focusSearch() {
        currentFocusIndex = -1;
        wallpaperSearchInput.focusInput();

        // Restaurar índice válido si está en -1 y hay wallpapers
        if (selectedIndex === -1 && filteredWallpapers.length > 0) {
            const currentIndex = findCurrentWallpaperIndex();
            setSelectedIndex(currentIndex !== -1 ? currentIndex : 0);
        }
    }

    // Alias para compatibilidad con Dashboard
    function focusSearchInput() {
        focusSearch();
    }

    // Función para enfocar los filtros
    function focusFilters() {
        currentFocusIndex = 2;
        focusableElements[2].focusFunc();
    }

    // Función para navegar hacia adelante (Tab)
    function focusNextElement() {
        if (currentFocusIndex === -1) {
            currentFocusIndex = 0;
            focusableElements[currentFocusIndex].focusFunc();
        } else if (currentFocusIndex === focusableElements.length - 1) {
            // Si estamos en el último elemento, volver al search
            focusSearch();
        } else {
            currentFocusIndex++;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    // Función para navegar hacia atrás (Shift+Tab)
    function focusPreviousElement() {
        if (currentFocusIndex === -1 || currentFocusIndex === 0) {
            // Si estamos en el search o en el primer elemento focusable, volver al search
            focusSearch();
        } else {
            currentFocusIndex--;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    // Función para posicionar el wallpaper actual centrado verticalmente
    function centerCurrentWallpaper() {
        const currentIndex = findCurrentWallpaperIndex();
        if (currentIndex !== -1) {
            setSelectedIndex(currentIndex);

            // Calcular la fila del wallpaper actual
            const currentRow = Math.floor(currentIndex / wallpapersTabRoot.gridColumns);
            // Calcular el índice del primer item de esa fila
            const rowStartIndex = currentRow * wallpapersTabRoot.gridColumns;

            // Posicionar para que la fila esté centrada verticalmente
            wallpaperGrid.positionViewAtIndex(rowStartIndex, GridView.Center);
        }
    }

    // Función para encontrar el índice del wallpaper actual en la lista filtrada
    function findCurrentWallpaperIndex() {
        if (!screenWallpaperKnown || !screenWallpaper) {
            return -1;
        }

        return filteredWallpapers.indexOf(screenWallpaper);
    }

    // Llama a focusSearch una vez que el componente se ha completado.
    Component.onCompleted: {
        centerTimer.start();
    }

    // Actualizar subcarpetas cuando la pestaña se haga visible
    onVisibleChanged: {
        if (visible) {
            if (GlobalStates.wallpaperManager) {
                console.log("WallpapersTab became visible, updating subfolders");
                GlobalStates.wallpaperManager.scanSubfolders();
            }
            // Reposicionar al wallpaper actual cuando se hace visible
            centerTimer.restart();
        }
    }

    // Timer para asegurar que el centrado ocurre después de que el GridView esté listo
    Timer {
        id: centerTimer
        interval: 50
        repeat: false
        onTriggered: {
            centerCurrentWallpaper();
            focusSearch();
        }
    }

    // Propiedad calculada que filtra los fondos de pantalla según el texto de búsqueda y tipos activos.
    property var filteredWallpapers: {
        if (!GlobalStates.wallpaperManager)
            return [];

        let wallpapers = GlobalStates.wallpaperManager.wallpaperPaths;

        // Filtrar por texto de búsqueda
        if (searchText.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileName = path.split('/').pop().toLowerCase();
                return fileName.includes(searchText.toLowerCase());
            });
        }

        // Filtrar por tipos activos si hay filtros seleccionados
        if (activeFilters.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileType = GlobalStates.wallpaperManager.getFileType(path);
                const subfolder = GlobalStates.wallpaperManager.getSubfolderFromPath(path);

                // Verificar si coincide con algún filtro activo
                for (var i = 0; i < activeFilters.length; i++) {
                    var filter = activeFilters[i];
                    if (filter === fileType) {
                        return true;
                    }
                    if (filter.startsWith("subfolder_") && subfolder === filter.replace("subfolder_", "")) {
                        return true;
                    }
                }
                return false;
            });
        }

        return wallpapers;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Barra superior con OLED mode, búsqueda y scheme selector
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 8
            z: 1000 // Asegurar que el menú desplegable se dibuje por encima del resto del contenido

            // Barra de búsqueda centrada
            SearchInput {
                id: wallpaperSearchInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: searchText
                placeholderText: I18n.t("wallpapers.search")
                iconText: ""
                clearOnEscape: false
                handleTabNavigation: true
                disableCursorNavigation: true
                radius: Styling.radius(4)

                // Manejo de eventos de búsqueda y teclado.
                onSearchTextChanged: text => {
                    searchText = text;
                    if (text.length > 0 && filteredWallpapers.length > 0) {
                        setSelectedIndex(0);
                    } else {
                        setSelectedIndex(-1);
                    }
                }

                onEscapePressed: {
                    Visibilities.setActiveModule("");
                }

                onTabPressed: {
                    focusNextElement();
                }

                onShiftTabPressed: {
                    focusPreviousElement();
                }

                onDownPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            let newIndex = selectedIndex + wallpapersTabRoot.gridColumns;
                            if (newIndex >= filteredWallpapers.length) {
                                newIndex = filteredWallpapers.length - 1;
                            }
                            setSelectedIndex(newIndex);
                        } else if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        }
                    }
                }
                onUpPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        } else if (selectedIndex >= wallpapersTabRoot.gridColumns) {
                            setSelectedIndex(selectedIndex - wallpapersTabRoot.gridColumns);
                        }
                    }
                }
                onLeftPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        } else if (selectedIndex > 0) {
                            setSelectedIndex(selectedIndex - 1);
                        }
                    }
                }
                onRightPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            setSelectedIndex(selectedIndex + 1);
                        } else if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        }
                    }
                }
                onAccepted: {
                    if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length) {
                        let selectedWallpaper = filteredWallpapers[selectedIndex];
                        if (selectedWallpaper && GlobalStates.wallpaperManager) {
                            // Grow from the selected thumbnail's centre.
                            let selectedItem = wallpaperGrid.itemAtIndex ? wallpaperGrid.itemAtIndex(selectedIndex) : null;
                            if (selectedItem)
                                GlobalStates.setWallpaperTransitionOrigin(selectedItem, selectedItem.width / 2, selectedItem.height / 2, currentScreenName);
                            if (isPerScreen && currentScreenName !== "") {
                                GlobalStates.wallpaperManager.setWallpaper(selectedWallpaper, currentScreenName);
                            } else {
                                GlobalStates.wallpaperManager.setWallpaper(selectedWallpaper);
                            }
                        }
                    }
                }
            }

            // Per-Screen Monitor toggle
            WallpaperToggle {
                id: perScreenToggle
                Layout.preferredWidth: 120 // un poco mas ancho para que quepa el nombre monitor si es largo
                label: wallpapersTabRoot.currentScreenName // Get the monitor name!
                centerLabel: true
                checked: wallpapersTabRoot.isPerScreen
                onToggled: wallpapersTabRoot.togglePerScreenMode()
                onNextRequested: wallpapersTabRoot.focusNextElement()
                onPreviousRequested: wallpapersTabRoot.focusPreviousElement()
                onEscapeRequested: wallpapersTabRoot.focusSearch()
            }

            // OLED Mode
            WallpaperToggle {
                id: oledToggle
                label: I18n.t("wallpapers.oled")
                checked: Config.theme.oledMode
                toggleEnabled: !Config.theme.lightMode
                dimWhenDisabled: true
                onToggled: Config.theme.oledMode = !Config.theme.oledMode
                onNextRequested: wallpapersTabRoot.focusNextElement()
                onPreviousRequested: wallpapersTabRoot.focusPreviousElement()
                onEscapeRequested: wallpapersTabRoot.focusSearch()
            }

            // Tint Toggle a la derecha del search
            WallpaperToggle {
                id: tintToggle
                label: I18n.t("wallpapers.tint")
                animateLabelColor: false
                checked: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
                onToggled: {
                    if (GlobalStates.wallpaperManager) {
                        GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                    }
                }
                onNextRequested: wallpapersTabRoot.focusNextElement()
                onPreviousRequested: wallpapersTabRoot.focusPreviousElement()
                onEscapeRequested: wallpapersTabRoot.focusSearch()
            }

            // Spacer
            // Item { Layout.fillWidth: true }

            // Scheme Selector a la derecha
            Item {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 48

                SchemeSelector {
                    id: schemeSelector
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    // No height set, allows expansion based on implicitHeight

                    onSchemeSelectorClosed: {
                        wallpapersTabRoot.focusSearch();
                    }

                    onEscapePressedOnScheme: {
                        wallpapersTabRoot.focusSearch();
                    }

                    onTabPressed: {
                        wallpapersTabRoot.focusNextElement();
                    }

                    onShiftTabPressed: {
                        wallpapersTabRoot.focusPreviousElement();
                    }
                }
            }
        }

        // FilterBar centrada
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: wallpapersFilterBar.height

            FilterBar {
                id: wallpapersFilterBar
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                activeFilters: wallpapersTabRoot.activeFilters

                onActiveFiltersChanged: {
                    wallpapersTabRoot.activeFilters = activeFilters;
                }

                onEscapePressedOnFilters: {
                    wallpapersTabRoot.focusSearch();
                }

                onTabPressed: {
                    wallpapersTabRoot.focusNextElement();
                }

                onShiftTabPressed: {
                    wallpapersTabRoot.focusPreviousElement();
                }
            }
        }

        // Grid de wallpapers
        ClippingRectangle {
            id: wallpaperGridContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            radius: Styling.radius(4)
            clip: true

            // Calcular tamaño de celda basado en columnas y proporción 1:1
            // El grid tiene margins negativos, así que el ancho real es width + margin*2
            readonly property real gridWidth: width + (wallpapersTabRoot.wallpaperMargin * 2)
            readonly property real cellSize: gridWidth / wallpapersTabRoot.gridColumns

            GridView {
                id: wallpaperGrid
                anchors.fill: parent
                anchors.margins: -wallpapersTabRoot.wallpaperMargin
                cellWidth: wallpaperGridContainer.cellSize
                cellHeight: wallpaperGridContainer.cellSize
                flow: GridView.FlowLeftToRight
                boundsBehavior: Flickable.StopAtBounds
                model: filteredWallpapers
                currentIndex: selectedIndex

                // Propiedad para detectar si está en movimiento (drag o flick)
                property bool isScrolling: dragging || flicking

                // Deshabilitar highlight durante scroll para evitar glitches
                highlightFollowsCurrentItem: !isScrolling

                // Optimizaciones de rendimiento
                cacheBuffer: cellHeight
                displayMarginBeginning: cellHeight
                displayMarginEnd: cellHeight
                reuseItems: true

                // Configuración de scroll optimizada
                flickDeceleration: 5000
                maximumFlickVelocity: 8000

                // Sincronizar selectedIndex cuando el GridView cambia su currentIndex
                onCurrentIndexChanged: {
                    if (currentIndex !== selectedIndex && currentIndex >= 0) {
                        setSelectedIndex(currentIndex);
                    }
                }

                // Elemento de realce para el wallpaper seleccionado.
                highlight: WallpaperGridHighlight {
                    tab: wallpapersTabRoot
                    grid: wallpaperGrid
                }

                // Delegado para cada elemento de la cuadrícula con lazy loading optimizado.
                delegate: WallpaperGridCell {
                    tab: wallpapersTabRoot
                    grid: wallpaperGrid
                }
            }
        }
    }
}
