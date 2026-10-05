import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.globals
import "Ui.js" as Ui

// About: name, version, a couple of useful shortcuts and the legal row.
Item {
    id: page

    required property var category

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 520)
        spacing: 18

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112
            height: 112
            radius: Math.min(Styling.radius(12), 36)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Colors.primary
                }
                GradientStop {
                    position: 1
                    color: Colors.tertiary
                }
            }
            Image {
                anchors.centerIn: parent
                width: 72
                height: 72
                source: Qt.resolvedUrl("../../assets/yozakura/yozakura-icon.svg")
                sourceSize.width: 144
                sourceSize.height: 144
                fillMode: Image.PreserveAspectFit
                mipmap: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Colors.overPrimary
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Brand.displayName
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(16)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("prefs.about.version", Config.version)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("prefs.about.blurb")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Ui.alpha(Colors.overBackground, 0.85)
            lineHeight: 1.2
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            PillButton {
                objectName: "aboutRunSetup"
                icon: "seal"
                text: I18n.t("onboarding.run_again")
                onClicked: {
                    GlobalStates.settingsWindowVisible = false;
                    OnboardingService.open();
                }
            }
            PillButton {
                icon: "folder"
                text: I18n.t("prefs.about.open_config")
                onClicked: Quickshell.execDetached(["xdg-open", Config.configDir])
            }
            PillButton {
                icon: "code"
                text: I18n.t("prefs.about.source")
                onClicked: Quickshell.execDetached(["xdg-open", Brand.repoUrl])
            }
        }

        LegalNotice {
            width: parent.width
        }
    }
}
