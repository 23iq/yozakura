pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "../settings/Ui.js" as Ui

// Welcome: the blossom unfolds, then the greeting and what setup covers
// fade up one after another.
Item {
    id: root

    property OnboardingState wizard
    property real reveal: Config.animDuration > 0 ? 0 : 1

    NumberAnimation on reveal {
        running: Config.animDuration > 0
        from: 0
        to: 1
        duration: Math.max(1400, Config.animDuration * 6)
        easing.type: Easing.OutCubic
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, 760)
        spacing: Math.round(Styling.fontSize(0) * 1.4)

        SakuraLogo {
            objectName: "welcomeLogo"
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.min(200, Math.round(root.height * 0.3))
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("onboarding.welcome.title", Brand.displayName)
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(16)
            font.weight: Font.Bold
            color: Colors.overBackground
            opacity: Math.min(1, Math.max(0, root.reveal * 2.2 - 0.6))
            transform: Translate {
                y: (1 - Math.min(1, Math.max(0, root.reveal * 2.2 - 0.6))) * 14
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("onboarding.welcome.subtitle")
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(2)
            color: Colors.overSurfaceVariant
            opacity: Math.min(1, Math.max(0, root.reveal * 2.2 - 0.9))
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(Styling.fontSize(0) * 0.7)
            topPadding: Math.round(Styling.fontSize(0) * 0.6)

            Repeater {
                model: [
                    {
                        "icon": "magicWand",
                        "text": "onboarding.welcome.f_look"
                    },
                    {
                        "icon": "terminal",
                        "text": "onboarding.welcome.f_apps"
                    },
                    {
                        "icon": "sparkle",
                        "text": "onboarding.welcome.f_ai"
                    },
                    {
                        "icon": "keyboard",
                        "text": "onboarding.welcome.f_keys"
                    }
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property real t: Math.min(1, Math.max(0, root.reveal * 3 - 1.4 - index * 0.18))
                    width: chipRow.implicitWidth + Math.round(Styling.fontSize(0) * 1.6)
                    height: Math.round(Styling.fontSize(0) * 2.4)
                    radius: Math.min(height / 2, Styling.radius(4))
                    color: Ui.alpha(Colors.primary, 0.12)
                    opacity: t
                    transform: Translate {
                        y: (1 - chip.t) * 10
                    }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons[chip.modelData.icon] ?? ""
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t(chip.modelData.text)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Math.round(Styling.fontSize(0) * 0.4)
            text: I18n.t("onboarding.welcome.hint")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            opacity: Math.min(1, Math.max(0, root.reveal * 2 - 1))
        }
    }
}
