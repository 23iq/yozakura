pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings.keyboard
import "../settings/Ui.js" as Ui
import "OnboardingModel.js" as Model

// Welcome: the blossom unfolds, then the greeting, what setup covers and
// the interface language (system.language, "auto" follows the locale) fade
// up one after another.
Item {
    id: root

    property OnboardingState wizard
    readonly property string language: wizard ? String(wizard.get("system.language") || "auto") : "auto"
    readonly property var languages: Model.languageChoices(I18n.availableLanguages).map(l => ({
                "value": l.code,
                "label": l.code === "auto" ? I18n.t("onboarding.system.language.auto") : l.name
            }))

    function pickLanguage(code) {
        wizard.set("system.language", code);
        wizard.remember("language", code);
    }
    property real reveal: Config.animDuration > 0 ? 0 : 1

    NumberAnimation on reveal {
        running: Config.animDuration > 0
        from: 0
        to: 1
        duration: Math.max(1400, Config.animDuration * 6)
        easing.type: Motion.morph.easing
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
                        "icon": "monitor",
                        "text": "onboarding.welcome.f_displays"
                    },
                    {
                        "icon": "palette",
                        "text": "onboarding.welcome.f_look"
                    },
                    {
                        "icon": "terminal",
                        "text": "onboarding.welcome.f_terminal"
                    },
                    {
                        "icon": "squaresFour",
                        "text": "onboarding.welcome.f_apps"
                    },
                    {
                        "icon": "sparkle",
                        "text": "onboarding.welcome.f_ai"
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

        Row {
            id: languageRow
            objectName: "languageRow"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(Styling.fontSize(0) * 0.8)
            topPadding: Math.round(Styling.fontSize(0) * 0.8)
            opacity: Math.min(1, Math.max(0, root.reveal * 2.4 - 1.3))

            Row {
                anchors.verticalCenter: languageChips.verticalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.translate
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("onboarding.system.language")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                }
            }

            KeyChips {
                id: languageChips
                objectName: "languageChips"
                options: root.languages
                value: root.language
                onSelected: code => root.pickLanguage(code)
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
