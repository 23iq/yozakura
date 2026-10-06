import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.config
import "PopupMotionKinds.js" as Kinds

Menu {
    id: root

    // Propiedades principales
    property var items: []

    // Update menu width when items change
    onItemsChanged: {
        hoveredIndex = -1;
        previousHoveredIndex = -1;
        updateMenuWidth();
    }
    property int menuWidth: 140

    // Function to update menu width when items change
    function updateMenuWidth() {
        if (!items || items.length === 0) {
            menuWidth = 120;
            return;
        }

        let maxWidth = 0;
        for (let i = 0; i < items.length; i++) {
            if (items[i].isSeparator)
                continue;

            let text = items[i].text || "";
            let textWidth = textMetrics.measureText(text);
            let iconSpace = hasIcons ? 24 : 0;
            let totalItemWidth = textWidth + iconSpace + 40;

            if (totalItemWidth > maxWidth) {
                maxWidth = totalItemWidth;
            }
        }
        menuWidth = Math.min(Math.max(maxWidth, 120), 300);
    }
    property int itemHeight: 36

    // Corner radius of the menu surface
    property int menuRadius: Config.roundness

    // Placement (set by the opener from EdgeLayout.popupPlacement): the
    // resting position and the opening direction. theme.popup.entry plays
    // as a uniform scale + offset (a Controls popup has no per-axis scale).
    property real placeX: 0
    property real placeY: 0
    property string openDir: "down"
    property real motionProgress: 1
    readonly property var motionFrame: Kinds.frame(Config.theme && Config.theme.popup ? Config.theme.popup.entry : "fade-scale", openDir, motionProgress, Metrics.spacing * 2)
    readonly property string anchorEdge: Kinds.anchorEdge(openDir)

    x: placeX + motionFrame.dx
    y: placeY + motionFrame.dy
    opacity: motionFrame.opacity
    scale: Math.sqrt(motionFrame.scaleX * motionFrame.scaleY)
    transformOrigin: ({
            "top": Item.Top,
            "bottom": Item.Bottom,
            "left": Item.Left,
            "right": Item.Right
        })[anchorEdge]

    enter: Transition {
        NumberAnimation {
            property: "motionProgress"
            from: 0
            to: 1
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
            easing.overshoot: Motion.enter.overshoot
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "motionProgress"
            from: 1
            to: 0
            duration: Motion.exit.duration
            easing.type: Motion.exit.easing
        }
    }

    // Propiedades de highlight por defecto
    property color defaultHighlightColor: Styling.srItem("overprimary")
    property color defaultTextColor: Colors.overPrimary
    property color normalTextColor: Colors.overBackground

    // Propiedades internas
    property int hoveredIndex: -1
    property int previousHoveredIndex: -1

    // Detectar si algún item tiene iconos para ajustar el layout
    property bool hasIcons: {
        for (let i = 0; i < items.length; i++) {
            if (items[i].icon && items[i].icon !== "") {
                return true;
            }
        }
        return false;
    }

    // TextMetrics para medir el texto
    TextMetrics {
        id: textMetrics
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.Bold

        function measureText(text) {
            textMetrics.text = text;
            return textMetrics.width;
        }
    }

    // Configuración del menú
    width: menuWidth  // Use fixed width instead of calculated to avoid binding loop
    padding: 8
    spacing: 0

    // Estilo del menú principal
    background: Item {
        implicitWidth: root.menuWidth

        // Menu surface (popup variant: theme shape, glass, border)
        StyledRect {
            anchors.fill: parent
            variant: "popup"
            glassSurface: "popups"
            radius: root.menuRadius
            anchorEdge: root.anchorEdge
        }

        // Highlight animado que sigue al hover
        Rectangle {
            id: menuHighlight
            width: root.menuWidth - 16
            height: root.itemHeight
            color: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return root.defaultHighlightColor;
                let item = root.items[root.hoveredIndex];
                return item && item.highlightColor !== undefined ? item.highlightColor : root.defaultHighlightColor;
            }
            radius: root.menuRadius > 6 ? root.menuRadius - 6 : 0
            visible: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return false;
                let item = root.items[root.hoveredIndex];
                return item && !item.isSeparator;
            }
            opacity: visible ? 1.0 : 0

            x: 8 // Padding offset
            y: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return 8;

                let yPosition = 8;
                for (let i = 0; i < root.hoveredIndex; i++) {
                    let item = root.items[i];
                    if (item && item.isSeparator) {
                        yPosition += 10;
                    } else {
                        yPosition += root.itemHeight;
                    }
                }
                return yPosition;
            }

            Behavior on y {
                enabled: root.previousHoveredIndex !== -1 && root.hoveredIndex !== -1 && Motion.morph.duration > 0
                NumberAnimation {
                    duration: Motion.morph.duration / 2
                    easing.type: Motion.morph.easing
                }
            }

            Behavior on opacity {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration / 2
                    easing.type: Motion.enter.easing
                }
            }

            Behavior on color {
                enabled: Motion.enter.duration > 0
                ColorAnimation {
                    duration: Motion.enter.duration / 2
                    easing.type: Motion.enter.easing
                }
            }
        }
    }

    // Generar MenuItems dinámicamente
    Instantiator {
        model: root.items
        delegate: MenuItem {
            id: menuItem
            property int itemIndex: index
            property var itemData: modelData
            property bool isSeparatorItem: itemData.isSeparator || false

            text: itemData.text || ""
            width: root.menuWidth
            height: isSeparatorItem ? 10 : root.itemHeight // 2px separador + 4px margen arriba + 4px margen abajo
            enabled: !isSeparatorItem

            // Fondo - diferente para separadores
            background: Rectangle {
                anchors.fill: parent
                anchors.topMargin: isSeparatorItem ? 4 : 0
                anchors.bottomMargin: isSeparatorItem ? 4 : 0
                color: isSeparatorItem ? Colors.surface : "transparent"
                radius: isSeparatorItem ? 0 : (root.menuRadius > 6 ? root.menuRadius - 6 : 0)
            }

            // Manejo del hover - desactivado para separadores
            onHoveredChanged: {
                if (isSeparatorItem)
                    return;

                if (hovered) {
                    root.previousHoveredIndex = root.hoveredIndex;
                    root.hoveredIndex = itemIndex;
                } else {
                    let menuRoot = root;
                    let currentIndex = itemIndex;
                    Qt.callLater(() => {
                        if (menuRoot.hoveredIndex === currentIndex) {
                            menuRoot.previousHoveredIndex = menuRoot.hoveredIndex;
                            menuRoot.hoveredIndex = -1;
                        }
                    });
                }
            }

            // Contenido del item
            contentItem: Item {
                anchors.fill: parent

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: root.hasIcons ? 8 : 0
                    visible: !menuItem.isSeparatorItem

                    // Icono (opcional) - Puede ser fuente o imagen
                    Loader {
                        id: iconLoader
                        width: root.hasIcons ? 16 : 0
                        height: root.hasIcons ? 16 : 0
                        visible: root.hasIcons
                        anchors.verticalCenter: parent.verticalCenter

                        property bool isImageIcon: menuItem.itemData.isImageIcon || false
                        property string iconSource: menuItem.itemData.icon || ""

                        sourceComponent: {
                            if (iconSource === "" || !root.hasIcons)
                                return null;
                            return isImageIcon ? imageIconComponent : fontIconComponent;
                        }

                        Component {
                            id: fontIconComponent
                            Text {
                                text: iconLoader.iconSource
                                color: {
                                    if (root.hoveredIndex === menuItem.itemIndex) {
                                        return menuItem.itemData.textColor !== undefined ? menuItem.itemData.textColor : root.defaultTextColor;
                                    }
                                    return root.normalTextColor;
                                }
                                font.family: Icons.font
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                                textFormat: Text.RichText

                                Behavior on color {
                                    enabled: Motion.enter.duration > 0
                                    ColorAnimation {
                                        duration: Motion.enter.duration / 2
                                        easing.type: Motion.enter.easing
                                    }
                                }
                            }
                        }

                        Component {
                            id: imageIconComponent
                            Image {
                                mipmap: true
                                source: iconLoader.iconSource
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent
                            }
                        }
                    }

                    // Texto
                    Text {
                        text: menuItem.itemData.text || ""
                        color: {
                            if (root.hoveredIndex === menuItem.itemIndex) {
                                return menuItem.itemData.textColor !== undefined ? menuItem.itemData.textColor : root.defaultTextColor;
                            }
                            return root.normalTextColor;
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: root.menuWidth - 32 - iconLoader.width - (root.hasIcons ? parent.spacing : 0)

                        Behavior on color {
                            enabled: Motion.enter.duration > 0
                            ColorAnimation {
                                duration: Motion.enter.duration / 2
                                easing.type: Motion.enter.easing
                            }
                        }
                    }
                }
            }

            // Acción al hacer click
            onTriggered: {
                if (itemData && itemData.onTriggered) {
                    let callback = itemData.onTriggered;
                    Qt.callLater(callback);
                }
            }
        }

        onObjectAdded: (index, object) => {
            root.addItem(object);
        }

        onObjectRemoved: (index, object) => {
            root.removeItem(object);
        }
    }
}
