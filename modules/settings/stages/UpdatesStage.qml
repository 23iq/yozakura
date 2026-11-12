pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Updates: one clear state and one action. Up to date: a check
// mark, the installed version, when it last looked and "Check now"; a
// newer release: its version and "What's new". Under it the three
// channels as lanes (stable releases, pre-releases, every commit), the
// one followed lit with your version on it; a click on a lane follows it
// (one undo step). With checks off the state says so.
Stage {
    id: stage

    readonly property real u: Math.max(Space.px(10), stage.height * 0.045)
    readonly property string current: UpdateService.currentVersion ?? ""
    readonly property string latest: UpdateService.lastDetectedVersion ?? ""
    readonly property bool newer: stage.latest !== "" && UpdateService.updateAvailable === true
    readonly property bool checking: UpdateService.checking === true
    readonly property real lastCheck: UpdateService.lastCheckTime ?? 0
    readonly property bool service: SettingsStore.get("system.updateServiceEnabled") !== false
    readonly property string channel: String(SettingsStore.get("system.updateChannel") || "stable")
    readonly property var lanes: [
        {
            "id": "stable",
            "icon": "shieldCheck",
            "label": "prefs.updates.channel_stable",
            "tag": "prefs.updates.stage.stable"
        },
        {
            "id": "beta",
            "icon": "lightning",
            "label": "prefs.updates.channel_beta",
            "tag": "prefs.updates.stage.beta"
        },
        {
            "id": "git",
            "icon": "gitBranch",
            "label": "prefs.updates.channel_git",
            "tag": "prefs.updates.stage.git"
        }
    ]

    stageHeight: Space.px(300)

    Mark {
        anchors.fill: parent
        radius: stage.radius
        color: Qt.alpha(Colors.shadow, 0.62)
    }

    // the state and its one action
    Column {
        id: summary
        objectName: "updatesState"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(stage.height * 0.12)
        spacing: Math.round(stage.u * 0.5)

        Mark {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(stage.u * 3.6)
            height: width
            color: stage.newer ? Type.accent : Qt.alpha(Type.accent, 0.16)
            border.width: stage.newer ? 0 : Math.max(2, Math.round(stage.u * 0.12))
            border.color: Type.accent
            Icon {
                anchors.centerIn: parent
                icon: stage.newer ? Icons.downloadSimple : (stage.checking ? Icons.arrowsClockwise : Icons.check)
                size: Math.round(stage.u * 1.9)
                tone: stage.newer ? "accentInk" : "accent"
            }
        }
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "display"
            font.pixelSize: Math.round(stage.u * 1.25)
            text: stage.newer ? I18n.t("prefs.updates.available", stage.latest) : I18n.t("prefs.updates.stage.up_to_date")
        }
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "secondary"
            text: {
                if (!stage.service)
                    return I18n.t("prefs.updates.stage.off").replace("%1", stage.current);
                if (stage.checking)
                    return I18n.t("prefs.updates.checking");
                const when = stage.lastCheck > 0 ? I18n.t("prefs.updates.last_check", Qt.formatDateTime(new Date(stage.lastCheck), "d MMM, HH:mm")) : I18n.t("prefs.updates.never_checked");
                return I18n.t("prefs.updates.current", stage.current) + " · " + when;
            }
        }
        Chip {
            objectName: "updatesAction"
            anchors.horizontalCenter: parent.horizontalCenter
            primary: true
            icon: stage.newer ? Icons.fileText : Icons.arrowsClockwise
            text: I18n.t(stage.newer ? "prefs.updates.stage.whats_new" : "prefs.updates.check_now")
            enabled: !stage.checking
            onClicked: stage.newer ? Quickshell.execDetached(ProcessRole.detached(["xdg-open", UpdateService.changelogUrl ?? Brand.repoUrl])) : UpdateService.checkUpdates()
        }
    }
    StageSpot {
        anchors.fill: summary
        anchors.margins: -Space.s
        keys: ["system.updateServiceEnabled"]
    }

    // the channels as lanes; a click follows one
    Row {
        id: lanesRow
        objectName: "updatesLanes"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(stage.u * 1.2)
        spacing: Math.round(stage.u * 0.6)
        Repeater {
            model: stage.lanes
            delegate: Mark {
                id: lane
                required property var modelData
                readonly property bool on: stage.channel === lane.modelData.id
                objectName: "updatesLane:" + lane.modelData.id
                width: Math.round(stage.width * 0.26)
                height: Math.round(stage.u * 3.4)
                radius: Look.radius("box", height)
                color: lane.on ? Qt.alpha(Type.accent, 0.16) : Qt.alpha(Colors.surfaceContainer, area.containsMouse ? 0.95 : 0.8)
                border.width: lane.on ? Math.max(2, Math.round(stage.u * 0.1)) : Space.hairline
                border.color: lane.on ? Type.accent : Qt.alpha(Colors.outlineVariant, 0.7)
                Row {
                    x: Math.round(stage.u * 0.7)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(stage.u * 0.5)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons[lane.modelData.icon] ?? ""
                        size: Math.round(stage.u * 1.1)
                        tone: lane.on ? "accent" : "secondary"
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        KitText {
                            role: "body"
                            font.weight: lane.on ? Font.DemiBold : Font.Normal
                            text: I18n.t(lane.modelData.label)
                        }
                        KitText {
                            role: "caption"
                            color: Type.muted
                            text: I18n.t(lane.modelData.tag)
                        }
                    }
                }
                // your version, pinned to the lane you follow
                Mark {
                    visible: lane.on
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(stage.u * 0.6)
                    y: -height / 2
                    width: versionText.implicitWidth + stage.u * 0.8
                    height: Math.round(stage.u * 1.2)
                    radius: Look.radius("chip", height)
                    color: Type.accent
                    KitText {
                        id: versionText
                        anchors.centerIn: parent
                        role: "caption"
                        font.weight: Font.Medium
                        color: Type.accentInk
                        text: stage.current
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: lane.on ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!lane.on)
                        SettingsStore.transaction("prefs.undo.channel_changed", () => SettingsStore.set("system.updateChannel", lane.modelData.id))
                }
            }
        }
    }
    StageSpot {
        anchors.fill: lanesRow
        anchors.margins: -Space.s
        keys: ["system.updateChannel"]
    }
}
