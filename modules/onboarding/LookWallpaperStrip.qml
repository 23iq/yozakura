pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit
import qs.modules.settings.editors

// Look step, "Wallpaper" tab: the current wallpaper, a strip of the library
// to pick from (colors follow the pick; Tab focuses it, arrows move, Enter
// picks), the folder list (same editor as Settings > Wallpapers) and the
// built-in collection as a fallback.
Item {
    id: root

    property OnboardingState wizard

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var paths: manager ? (manager.wallpaperPaths || []) : []
    readonly property string current: manager ? (manager.currentWallpaper || "") : ""
    readonly property string builtin: decodeURIComponent(Qt.resolvedUrl("../../assets/wallpapers_example").toString().replace("file://", ""))
    readonly property bool usingBuiltin: (root.wizard ? String(root.wizard.get("wallpaper.wallPath") || "") : "").replace(/\/+$/, "") === root.builtin
    readonly property int gap: Space.xl
    readonly property int stripHeight: Space.controlXL - Space.l

    function url(p) {
        if (!p)
            return "";
        const src = manager && manager.getDisplaySource ? manager.getDisplaySource(p) : p;
        return String(src).indexOf("://") === -1 ? "file://" + src : src;
    }

    function pick(path) {
        if (!root.manager || !path)
            return;
        root.manager.setWallpaper(path);
        root.wizard.remember("wallpaper", path);
    }

    function useBuiltin() {
        if (root.usingBuiltin)
            return;
        root.wizard.set("wallpaper.wallPath", root.builtin);
        root.wizard.remember("wallpaperFolder", root.builtin);
    }

    // ---- left: current wallpaper + library strip ---------------------------
    Column {
        id: left
        width: Math.round((parent.width - root.gap) * 0.58)
        height: parent.height
        spacing: Space.m

        Art {
            id: hero
            width: parent.width
            height: Math.max(Space.controlXL, Math.min(Math.round(width * 9 / 16), parent.height - root.stripHeight - caption.height - parent.spacing * 2 - Space.stroke * 2))
            radius: Look.bigRadius(height)
            source: root.url(root.current)
        }

        KitText {
            id: caption
            width: parent.width
            role: "secondary"
            text: root.paths.length > 0 ? I18n.t("onboarding.wallpaper.count", root.paths.length) : I18n.t("onboarding.wallpaper.empty")
        }

        ListView {
            id: strip
            objectName: "wallpaperStrip"
            x: -Space.stroke
            width: parent.width + Space.stroke * 2
            height: root.stripHeight + Space.stroke * 2
            leftMargin: Space.stroke
            rightMargin: Space.stroke
            topMargin: Space.stroke
            orientation: ListView.Horizontal
            spacing: Space.s
            clip: true
            model: root.paths
            currentIndex: Math.max(0, root.paths.indexOf(root.current))
            activeFocusOnTab: true
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Keys.onReturnPressed: root.pick(root.paths[strip.currentIndex])
            Keys.onEnterPressed: root.pick(root.paths[strip.currentIndex])
            Keys.onSpacePressed: root.pick(root.paths[strip.currentIndex])

            delegate: Art {
                id: thumb
                required property string modelData
                required property int index
                readonly property bool isCurrent: modelData === root.current
                width: Math.round(root.stripHeight * 16 / 10)
                height: root.stripHeight
                radius: Space.clampRadius(Space.controlRadius, height)
                source: root.url(thumb.modelData)

                // The selected mark: an accent edge over the image.
                Rectangle {
                    anchors.fill: parent
                    visible: thumb.isCurrent
                    radius: thumb.radius
                    color: "transparent"
                    border.width: Space.stroke - 1
                    border.color: Type.accent
                }

                FocusRing {
                    shown: strip.activeFocus && strip.currentIndex === thumb.index
                    radius: thumb.radius + Space.stroke
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        strip.currentIndex = thumb.index;
                        root.pick(thumb.modelData);
                    }
                }
            }
        }
    }

    // ---- right: folders + built-in ------------------------------------------
    Flickable {
        id: side
        anchors.left: left.right
        anchors.leftMargin: root.gap
        anchors.right: parent.right
        height: parent.height
        contentWidth: width
        contentHeight: folders.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: side.contentHeight > side.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Group {
            id: folders
            width: side.width - Space.s
            label: I18n.t("onboarding.wallpaper.folders")

            KitText {
                width: parent.width
                role: "secondary"
                wrapMode: Text.WordWrap
                text: I18n.t("onboarding.wallpaper.folders.desc")
            }

            FolderList {
                objectName: "wallpaperFolders"
                width: parent.width
                entry: ({
                        "key": "desktop.wallpaperFolders"
                    })
            }

            ChoiceRow {
                objectName: "builtinWallpapers"
                width: parent.width
                icon: "image"
                title: I18n.t("onboarding.wallpaper.builtin")
                subtitle: I18n.t("onboarding.wallpaper.builtin.desc")
                checked: root.usingBuiltin
                onClicked: root.useBuiltin()
            }
        }
    }
}
