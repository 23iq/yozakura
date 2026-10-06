pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.extras

// AI & voice from the extras catalog, in three sections: AI agents (CLI
// agents with their own login), Local AI & GPU (Ollama with a "pull a
// model" chip row once it is installed, CUDA, local voice input) and cloud
// providers (the AI bar's Connect sheet, loaded over the step). The master
// `ai.enabled` switch sits on top. Installs run in the backend queue.
Item {
    id: root

    property OnboardingState wizard

    readonly property bool aiOn: wizard ? wizard.get("ai.enabled") !== false : true
    readonly property bool ollamaInstalled: ExtrasService.cardState("ollama") === "installed"

    Component.onCompleted: ExtrasService.load()

    CatalogHost {
        id: host
        objectName: "aiCatalog"
        anchors.fill: parent
        mode: "onboarding"
        autoPreselect: false
        showChips: false
        // compact: the four agents fit one row
        minCardWidth: 220
        categories: ["agents", "localai", "gpu"]
        sideMargin: 0
        topMargin: 0
        sections: [
            {
                "title": I18n.t("onboarding.ai.agents"),
                "icon": "robot",
                "hint": I18n.t("onboarding.ai.agents.desc"),
                "categories": ["agents"]
            },
            {
                "title": I18n.t("onboarding.ai.local"),
                "icon": "cpu",
                "hint": I18n.t("onboarding.ai.local.desc"),
                "categories": ["localai", "gpu"],
                "footer": root.ollamaInstalled ? pullRow : null
            }
        ]
        header: ChoiceRow {
            objectName: "aiMaster"
            mode: "toggle"
            icon: "sparkle"
            title: I18n.t("onboarding.ai.enable")
            subtitle: I18n.t("onboarding.ai.enable.desc")
            checked: root.aiOn
            onToggled: v => root.wizard.set("ai.enabled", v)
        }
        footer: Column {
            spacing: 8
            SectionLabel {
                width: parent.width
                icon: "plugsConnected"
                text: I18n.t("onboarding.ai.cloud")
            }
            ChoiceRow {
                objectName: "aiProviders"
                width: parent.width
                mode: "link"
                enabled: root.aiOn
                dimmed: !root.aiOn
                icon: "globe"
                title: I18n.t("onboarding.ai.providers")
                subtitle: I18n.t("onboarding.ai.providers.desc")
                onClicked: connect.active = true
            }
        }
    }

    Component {
        id: pullRow
        OllamaPullRow {}
    }

    // The AI bar's Connect sheet, loaded on demand over the step.
    Loader {
        id: connect
        objectName: "aiConnectLoader"
        anchors.fill: parent
        z: 10
        active: false
        onActiveChanged: {
            if (active)
                setSource(Qt.resolvedUrl("../aicenter/providers/ConnectSheet.qml"), {
                    opened: true
                });
        }
        Connections {
            target: connect.item
            ignoreUnknownSignals: true
            function onCloseRequested() {
                connect.active = false;
            }
        }
    }
}
