pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.editors
import qs.config
import "../settings/Ui.js" as Ui

// Wallpaper folder: the current wallpaper, a strip of the library to pick
// from, the folder list (same editor as Settings > Wallpapers) and the
// built-in collection as a fallback when no folder has pictures yet.
Item {
    id: root

    property OnboardingState wizard

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var paths: manager ? (manager.wallpaperPaths || []) : []
    readonly property string current: manager ? (manager.currentWallpaper || "") : ""
    readonly property string builtin: decodeURIComponent(Qt.resolvedUrl("../../assets/wallpapers_example").toString().replace("file://", ""))
    readonly property bool usingBuiltin: (root.wizard ? String(root.wizard.get("wallpaper.wallPath") || "") : "").replace(/\/+$/, "") === root.builtin

    function url(p) {
        if (!p)
            return "";
        const src = manager && manager.getDisplaySource ? manager.getDisplaySource(p) : p;
        return String(src).indexOf("://") === -1 ? "file://" + src : src;
    }

    readonly property int gap: Math.round(Styling.fontSize(0) * 1.6)

    Row {
        anchors.fill: parent
        spacing: root.gap

        // ---- left: current wallpaper + library strip ---------------------
        Column {
            id: left
            width: Math.round((parent.width - root.gap) * 0.54)
            spacing: 12

            ClippingRectangle {
                width: parent.width
                height: Math.round(width * 9 / 16)
                radius: Styling.radius(6)
                color: Colors.surfaceContainer
                Image {
                    anchors.fill: parent
                    source: root.url(root.current)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 960
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

            Grid {
                id: strip
                width: parent.width
                columns: 6
                spacing: 8
                readonly property real cell: (width - spacing * (columns - 1)) / columns
                Repeater {
                    model: root.paths.slice(0, 12)
                    delegate: ClippingRectangle {
                        id: thumb
                        required property string modelData
                        readonly property bool isCurrent: modelData === root.current
                        width: strip.cell
                        height: Math.round(strip.cell * 0.62)
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
                            onClicked: if (root.manager)
                                root.manager.setWallpaper(thumb.modelData)
                        }
                    }
                }
            }
        }

        // ---- right: folders + built-in ----------------------------------
        Column {
            width: parent.width - left.width - root.gap
            spacing: 14

            Text {
                width: parent.width
                text: I18n.t("onboarding.wallpaper.folders")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }
            Text {
                width: parent.width
                text: I18n.t("onboarding.wallpaper.folders.desc")
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }

            FolderList {
                objectName: "wallpaperFolders"
                width: parent.width
                entry: ({
                        "key": "desktop.wallpaperFolders"
                    })
            }

            ChoiceRow {
                width: parent.width
                icon: "image"
                title: I18n.t("onboarding.wallpaper.builtin")
                subtitle: I18n.t("onboarding.wallpaper.builtin.desc")
                checked: root.usingBuiltin
                onClicked: if (!root.usingBuiltin && root.wizard)
                    root.wizard.set("wallpaper.wallPath", root.builtin)
            }
        }
    }
}
