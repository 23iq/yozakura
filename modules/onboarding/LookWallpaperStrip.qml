pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.editors
import qs.config
import "../settings/Ui.js" as Ui

// Look step, "Wallpaper" tab: the current wallpaper, a strip of the library
// to pick from (colors follow the pick), the folder list (same editor as
// Settings > Wallpapers) and the built-in collection as a fallback.
Item {
    id: root

    property OnboardingState wizard

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var paths: manager ? (manager.wallpaperPaths || []) : []
    readonly property string current: manager ? (manager.currentWallpaper || "") : ""
    readonly property string builtin: decodeURIComponent(Qt.resolvedUrl("../../assets/wallpapers_example").toString().replace("file://", ""))
    readonly property bool usingBuiltin: (root.wizard ? String(root.wizard.get("wallpaper.wallPath") || "") : "").replace(/\/+$/, "") === root.builtin
    readonly property int gap: Math.round(Styling.fontSize(0) * 1.6)
    readonly property int stripHeight: Math.round(Styling.fontSize(0) * 4.4)

    function url(p) {
        if (!p)
            return "";
        const src = manager && manager.getDisplaySource ? manager.getDisplaySource(p) : p;
        return String(src).indexOf("://") === -1 ? "file://" + src : src;
    }

    function pick(path) {
        if (!root.manager)
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
        spacing: 12

        ClippingRectangle {
            id: hero
            width: parent.width
            height: Math.max(80, Math.min(Math.round(width * 9 / 16), parent.height - root.stripHeight - parent.spacing))
            radius: Styling.radius(6)
            color: Colors.surfaceContainer
            Image {
                anchors.fill: parent
                source: root.url(root.current)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 1280
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: caption.implicitHeight + 16
                color: Ui.alpha(Colors.background, 0.72)
                Text {
                    id: caption
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    text: root.paths.length > 0 ? I18n.t("onboarding.wallpaper.count", root.paths.length) : I18n.t("onboarding.wallpaper.empty")
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                }
            }
        }

        ListView {
            id: strip
            objectName: "wallpaperStrip"
            width: parent.width
            height: root.stripHeight
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: root.paths
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: ClippingRectangle {
                id: thumb
                required property string modelData
                readonly property bool isCurrent: modelData === root.current
                width: Math.round(strip.height * 16 / 10)
                height: strip.height
                radius: Styling.radius(0)
                color: Colors.surfaceContainer
                border.width: isCurrent ? 2 : 0
                border.color: Colors.primary
                Image {
                    anchors.fill: parent
                    source: root.url(thumb.modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 200
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(thumb.modelData)
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

        Column {
            id: folders
            width: side.width - 8
            spacing: 12

            SectionLabel {
                width: parent.width
                icon: "folderOpen"
                text: I18n.t("onboarding.wallpaper.folders")
                hint: I18n.t("onboarding.wallpaper.folders.desc")
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
