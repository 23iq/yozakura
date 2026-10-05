import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config

// Selection frame of the wallpapers tab grid, with the selected file name
// (marquee when too long) or "current" in a label under the thumbnail.
Item {
    id: highlight

    // The WallpapersTab (selection, filtered list, margins) and its grid.
    required property var tab
    required property GridView grid
    // Same as the grid's isScrolling: no hover/animation while dragged or flicked.
    readonly property bool scrolling: grid.dragging || grid.flicking

    width: highlight.grid.cellWidth
    height: highlight.grid.cellHeight
    z: 100

    // Deshabilitar animaciones durante scroll para evitar saltos
    Behavior on x {
        enabled: Config.animDuration > 0 && !highlight.scrolling
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }
    }

    Behavior on y {
        enabled: Config.animDuration > 0 && !highlight.scrolling
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }
    }

    ClippingRectangle {
        id: highlightRectangle
        anchors.centerIn: parent
        width: parent.width - highlight.tab.wallpaperMargin * 2
        height: parent.height - highlight.tab.wallpaperMargin * 2
        color: "transparent"
        border.color: Styling.srItem("overprimary")
        border.width: 2
        visible: highlight.tab.selectedIndex >= 0
        radius: Styling.radius(4)
        z: 10

        // Borde interior original
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -20
            anchors.bottomMargin: 0
            anchors.leftMargin: -20
            anchors.rightMargin: -20
            color: "transparent"
            border.color: Colors.background
            border.width: 28
            radius: Styling.radius(24)
            z: 5

            // Etiqueta unificada que se anima con el highlight
            Rectangle {
                id: label
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottomMargin: 0
                height: 28
                color: "transparent"
                z: 6
                clip: true

                property var currentItem: highlight.grid.currentItem
                property bool isCurrentWallpaper: {
                    if (!highlight.tab.screenWallpaperKnown || highlight.grid.currentIndex < 0)
                        return false;
                    return highlight.tab.screenWallpaper === highlight.tab.filteredWallpapers[highlight.grid.currentIndex];
                }
                property bool showHoveredItem: currentItem && currentItem.isHovered && !visible

                visible: highlight.tab.selectedIndex >= 0 || showHoveredItem

                Rectangle {
                    id: labelClip
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: highlight.grid.cellWidth - 20
                    height: parent.height
                    color: "transparent"
                    clip: true

                    Text {
                        id: labelText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: needsScroll ? undefined : parent.horizontalCenter
                        x: needsScroll ? 4 : undefined
                        text: {
                            if (label.isCurrentWallpaper) {
                                return I18n.t("wallpapers.current");
                            } else if (highlight.grid.currentIndex >= 0 && highlight.grid.currentIndex < highlight.tab.filteredWallpapers.length) {
                                return highlight.tab.filteredWallpapers[highlight.grid.currentIndex].split('/').pop();
                            }
                            return "";
                        }
                        color: label.isCurrentWallpaper ? Styling.srItem("overprimary") : Colors.overBackground
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter

                        readonly property bool needsScroll: contentWidth > labelClip.width - 8

                        // Resetear posición cuando cambia el texto o cuando deja de necesitar scroll
                        onTextChanged: {
                            if (needsScroll) {
                                x = 4;
                            }
                        }

                        onNeedsScrollChanged: {
                            if (needsScroll) {
                                x = 4;
                                scrollAnimation.restart();
                            }
                        }

                        SequentialAnimation {
                            id: scrollAnimation
                            running: labelText.needsScroll && label.visible && !label.isCurrentWallpaper
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: 1000
                            }
                            NumberAnimation {
                                target: labelText
                                property: "x"
                                to: labelClip.width - labelText.contentWidth - 4
                                duration: 2000
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation {
                                duration: 1000
                            }
                            NumberAnimation {
                                target: labelText
                                property: "x"
                                to: 4
                                duration: 2000
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        labelText.x = 4;
                        if (labelText.needsScroll && !isCurrentWallpaper) {
                            scrollAnimation.restart();
                        }
                    } else {
                        scrollAnimation.stop();
                    }
                }
            }
        }
    }
}
