import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit

// Selection frame of the wallpapers tab grid: an accent edge round the
// selected thumbnail and a strip under it with the file name (marquee when
// too long) or "current" (in the accent) for the screen's wallpaper.
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

    // No slide while scrolling (it would jump)
    Behavior on x {
        enabled: Motion.glide.duration > 0 && !highlight.scrolling
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.morph.easing
        }
    }

    Behavior on y {
        enabled: Motion.glide.duration > 0 && !highlight.scrolling
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.morph.easing
        }
    }

    ClippingRectangle {
        id: frame
        anchors.centerIn: parent
        width: parent.width - highlight.tab.wallpaperMargin * 2
        height: parent.height - highlight.tab.wallpaperMargin * 2
        color: "transparent"
        border.color: Type.accent
        border.width: Space.stroke - 1
        visible: highlight.tab.selectedIndex >= 0
        radius: Look.radius("box")
        z: 10

        // The name strip along the bottom edge
        StyledRect {
            id: label
            objectName: "highlightLabel"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: frame.border.width
            height: labelText.implicitHeight + Space.s * 2
            variant: "bg"
            backgroundOpacity: 1
            enableBorder: false
            radius: 0
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

            onVisibleChanged: {
                if (visible) {
                    labelText.x = Space.xs;
                    if (labelText.needsScroll && !isCurrentWallpaper)
                        marquee.restart();
                } else {
                    marquee.stop();
                }
            }

            Item {
                id: labelClip
                anchors.fill: parent
                anchors.leftMargin: Space.s
                anchors.rightMargin: Space.s
                clip: true

                KitText {
                    id: labelText
                    objectName: "highlightText"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: needsScroll ? undefined : parent.horizontalCenter
                    x: needsScroll ? Space.xs : undefined
                    role: "secondary"
                    elide: Text.ElideNone
                    font.weight: Font.DemiBold
                    color: label.isCurrentWallpaper ? Type.accent : Type.text
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (label.isCurrentWallpaper)
                            return I18n.t("wallpapers.current");
                        if (highlight.grid.currentIndex >= 0 && highlight.grid.currentIndex < highlight.tab.filteredWallpapers.length)
                            return highlight.tab.filteredWallpapers[highlight.grid.currentIndex].split('/').pop();
                        return "";
                    }

                    readonly property bool needsScroll: contentWidth > labelClip.width - Space.s

                    // Back to the start when the text changes or starts to overflow
                    onTextChanged: {
                        if (needsScroll)
                            x = Space.xs;
                    }

                    onNeedsScrollChanged: {
                        if (needsScroll) {
                            x = Space.xs;
                            marquee.restart();
                        }
                    }

                    SequentialAnimation {
                        id: marquee
                        running: labelText.needsScroll && label.visible && !label.isCurrentWallpaper
                        loops: Animation.Infinite

                        PauseAnimation {
                            duration: 1000
                        }
                        NumberAnimation {
                            target: labelText
                            property: "x"
                            to: labelClip.width - labelText.contentWidth - Space.xs
                            duration: 2000
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation {
                            duration: 1000
                        }
                        NumberAnimation {
                            target: labelText
                            property: "x"
                            to: Space.xs
                            duration: 2000
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}
