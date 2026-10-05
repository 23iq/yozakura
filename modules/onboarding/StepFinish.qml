pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "../settings/Ui.js" as Ui
import "OnboardingModel.js" as Model

// Done: a summary of what was set up, "open settings" and how to come back.
Item {
    id: root

    property OnboardingState wizard

    readonly property var summary: {
        const w = root.wizard;
        if (!w)
            return [];
        const lang = String(w.get("system.language") || "auto");
        const agents = Model.AGENTS.filter(a => a.config !== "" && w.detected.agents[a.id] !== undefined && w.get("ai.agents." + a.config + ".enabled") !== false).map(a => a.label);
        const tourDone = Model.TOUR.filter(t => w.tour[t.id] === "done").length;
        return [
            {
                "icon": "magicWand",
                "label": I18n.t("onboarding.finish.preset"),
                "value": w.chosenPreset !== "" ? w.chosenPreset : I18n.t("onboarding.preset.keep")
            },
            {
                "icon": "terminal",
                "label": I18n.t("onboarding.system.terminal"),
                "value": String(w.get("general.terminal") || "")
            },
            {
                "icon": "translate",
                "label": I18n.t("onboarding.system.language"),
                "value": lang === "auto" ? I18n.t("onboarding.system.language.auto") : ((I18n.availableLanguages || {})[lang] || lang)
            },
            {
                "icon": "sparkle",
                "label": I18n.t("onboarding.ai.agents"),
                "value": w.get("ai.enabled") === false ? I18n.t("onboarding.off") : (agents.length > 0 ? agents.join(", ") : I18n.t("onboarding.finish.none"))
            },
            {
                "icon": "mic",
                "label": I18n.t("onboarding.voice.title"),
                "value": w.voiceInstalled ? (w.get("voice.enabled") !== false ? I18n.t("onboarding.on") : I18n.t("onboarding.off")) : I18n.t("onboarding.not_installed")
            },
            {
                "icon": "keyboard",
                "label": I18n.t("onboarding.finish.tour"),
                "value": I18n.t("onboarding.finish.tour_value", tourDone, Model.TOUR.length)
            }
        ];
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, 720)
        spacing: Math.round(Styling.fontSize(0) * 1.2)

        SakuraLogo {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.min(120, Math.round(root.height * 0.18))
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("onboarding.finish.title")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(12)
            font.weight: Font.Bold
            color: Colors.overBackground
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("onboarding.finish.subtitle")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            color: Colors.overSurfaceVariant
        }

        Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: root.summary
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    width: (grid.width - grid.columnSpacing) / 2
                    height: Math.round(Styling.fontSize(0) * 3.6)
                    radius: Styling.radius(2)
                    color: Ui.alpha(Colors.overBackground, 0.04)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons[cell.modelData.icon] ?? ""
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(2)
                            color: Colors.primary
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            Text {
                                width: parent.width
                                text: cell.modelData.label
                                elide: Text.ElideRight
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }
                            Text {
                                width: parent.width
                                text: cell.modelData.value
                                elide: Text.ElideRight
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                            }
                        }
                    }
                }
            }
        }

        NavButton {
            objectName: "finishOpenSettings"
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "tonal"
            icon: "gear"
            text: I18n.t("onboarding.finish.open_settings")
            onClicked: {
                root.wizard.finish();
                if (!GlobalStates.settingsWindowVisible)
                    GlobalShortcuts.toggleSettings();
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("onboarding.finish.again", Brand.appId + " onboarding")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }
}
