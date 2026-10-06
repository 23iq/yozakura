import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config

// Look: a preset ("Style") and the wallpaper, two tabs of one step. Both
// apply at once; "Preview on desktop" collapses the wizard to see them.
Item {
    id: root

    property OnboardingState wizard

    readonly property string tab: wizard && wizard.choices.lookTab === "wallpaper" ? "wallpaper" : "style"

    Item {
        id: toolbar
        width: parent.width
        height: Math.max(tabs.implicitHeight, peek.implicitHeight)

        OnboardingTabs {
            id: tabs
            objectName: "lookTabs"
            anchors.verticalCenter: parent.verticalCenter
            tabs: [
                {
                    "id": "style",
                    "icon": "magicWand",
                    "label": I18n.t("onboarding.look.style")
                },
                {
                    "id": "wallpaper",
                    "icon": "image",
                    "label": I18n.t("onboarding.look.wallpaper")
                }
            ]
            current: root.tab
            onPicked: id => root.wizard.remember("lookTab", id)
        }

        PeekButton {
            id: peek
            objectName: "lookPeek"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: pages
        anchors.top: toolbar.bottom
        anchors.topMargin: Math.round(Styling.fontSize(0) * 1.2)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        LookPresetGrid {
            objectName: "lookStyle"
            anchors.fill: parent
            wizard: root.wizard
            visible: opacity > 0
            opacity: root.tab === "style" ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 1.5
                    easing.type: Easing.OutCubic
                }
            }
        }

        LookWallpaperStrip {
            objectName: "lookWallpaper"
            anchors.fill: parent
            wizard: root.wizard
            visible: opacity > 0
            opacity: root.tab === "wallpaper" ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 1.5
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
