pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.config

// Summary step: which updates to follow (system.updateChannel, the same
// key as Settings > Updates and `<app> update channel`). Only a click
// writes it, through the wizard like every other step (staged, applied
// when the wizard ends); leaving the preselected stable changes nothing.
Group {
    id: root

    property OnboardingState wizard

    readonly property string current: {
        const v = String(Config.system.updateChannel || "");
        return root.channels.some(c => c.id === v) ? v : "stable";
    }
    readonly property var channels: [
        {
            "id": "stable",
            "icon": "shieldCheck",
            "title": I18n.t("prefs.updates.channel_stable"),
            "desc": I18n.t("onboarding.finish.channel.stable")
        },
        {
            "id": "beta",
            "icon": "lightning",
            "title": I18n.t("prefs.updates.channel_beta"),
            "desc": I18n.t("onboarding.finish.channel.beta")
        },
        {
            "id": "git",
            "icon": "gitBranch",
            "title": I18n.t("prefs.updates.channel_git"),
            "desc": I18n.t("onboarding.finish.channel.git")
        }
    ]

    function choose(id) {
        if (!root.wizard)
            return;
        root.wizard.remember("updateChannel", id);
        if (id !== root.current)
            root.wizard.set("system.updateChannel", id);
    }

    label: I18n.t("onboarding.finish.channel")
    // ink: a hairline above, apart from the summary
    divider: true

    Grid {
        id: grid
        objectName: "channelGrid"
        width: parent.width
        columns: width >= Space.px(720) ? root.channels.length : 1
        columnSpacing: Space.m
        rowSpacing: Space.xs
        readonly property real cell: Math.floor((width - (columns - 1) * columnSpacing) / columns)

        Repeater {
            model: root.channels
            delegate: ChoiceRow {
                required property var modelData
                objectName: "channel:" + modelData.id
                width: grid.cell
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.desc
                checked: root.current === modelData.id
                onClicked: root.choose(modelData.id)
            }
        }
    }
}
