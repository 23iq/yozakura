pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../theme/AppThemes.js" as AppThemes
import "../Ui.js" as Ui

// External app theming: one row per AppThemes.js entry with its toggle
// (apps.theming.<id>), whether the app is installed and when its theme was
// last written, plus "Regenerate now" (Colors.regenerateApps()).
Item {
    id: root
    objectName: "appThemingEditor"

    property var entry
    // AppThemes.parseStatus() of the last probe
    property var status: ({})
    property bool probing: false
    property real lastRegenerated: 0

    function refresh() {
        if (probe.running)
            return;
        root.probing = true;
        probe.running = true;
    }

    function regenerate() {
        if (typeof Colors.regenerateApps === "function")
            Colors.regenerateApps();
        root.lastRegenerated = Date.now();
        settleTimer.restart();
    }

    function ago(ms) {
        if (!ms)
            return "";
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
        if (s < 60)
            return I18n.t("prefs.term.theming.just_now");
        if (s < 3600)
            return I18n.t("prefs.term.theming.minutes_ago", Math.round(s / 60));
        if (s < 86400)
            return I18n.t("prefs.term.theming.hours_ago", Math.round(s / 3600));
        return Qt.formatDateTime(new Date(ms), "d MMM, HH:mm");
    }

    function detail(id) {
        const st = root.status[id];
        if (!st)
            return root.probing ? I18n.t("prefs.term.theming.checking") : "";
        if (!st.installed)
            return I18n.t("prefs.term.theming.not_installed");
        if (!st.written)
            return I18n.t("prefs.term.theming.installed_never");
        return I18n.t("prefs.term.theming.installed_written", root.ago(st.written));
    }

    Process {
        id: probe
        command: ["sh", "-c", AppThemes.statusScript(), "app-themes-status", Brand.cacheDir, Brand.appId]
        stdout: StdioCollector {
            id: probeOut
        }
        onExited: {
            root.status = AppThemes.parseStatus(probeOut.text);
            root.probing = false;
        }
    }

    // Generators write asynchronously; look again once they are done.
    Timer {
        id: settleTimer
        interval: 2500
        onTriggered: root.refresh()
    }

    Connections {
        target: Colors
        ignoreUnknownSignals: true
        function onAppThemesRegenerated() {
            settleTimer.restart();
        }
    }

    Component.onCompleted: refresh()

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            spacing: 10
            PillButton {
                objectName: "regenerateApps"
                kind: "filled"
                icon: "arrowsClockwise"
                text: I18n.t("prefs.term.theming.regenerate")
                onClicked: root.regenerate()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.lastRegenerated > 0
                text: I18n.t("prefs.term.theming.regenerated")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.primary
            }
        }

        Repeater {
            model: AppThemes.APPS

            delegate: Item {
                id: appRow
                required property var modelData
                readonly property bool on: SettingsStore.get("apps.theming." + appRow.modelData.id) !== false
                readonly property var st: root.status[appRow.modelData.id]
                readonly property bool installed: !st || st.installed
                width: column.width
                height: 54

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(Styling.radius(2), 16)
                    color: Ui.alpha(Colors.overBackground, appRow.on ? 0.05 : 0.025)
                    border.width: 1
                    border.color: Ui.alpha(Colors.outlineVariant, 0.5)
                }
                Rectangle {
                    id: appIcon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 11
                    color: appRow.on && appRow.installed ? Ui.alpha(Colors.primary, 0.16) : Ui.alpha(Colors.overBackground, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: Icons[appRow.modelData.icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: appRow.on && appRow.installed ? Colors.primary : Colors.overSurfaceVariant
                    }
                }
                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 12
                    anchors.right: hookPill.visible ? hookPill.left : toggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    opacity: appRow.installed ? 1 : 0.6
                    Text {
                        width: parent.width
                        text: appRow.modelData.label
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.detail(appRow.modelData.id)
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: appRow.st && appRow.st.installed && appRow.st.written ? Colors.primary : Colors.overSurfaceVariant
                    }
                }
                AppHookPill {
                    id: hookPill
                    objectName: "appHook:" + appRow.modelData.id
                    anchors.right: toggle.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var hook: AppHooksService.status[appRow.modelData.id]
                    appLabel: appRow.modelData.label
                    hookState: hook ? hook.state : ""
                    reason: hook && hook.reason ? hook.reason : ""
                    needsRestart: !!(hook && hook.needsRestart)
                    themed: appRow.on
                    onConnectRequested: AppHooksService.connectApp(appRow.modelData.id)
                }
                ToggleControl {
                    id: toggle
                    objectName: "appTheme:" + appRow.modelData.id
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: appRow.on
                    onToggled: v => SettingsStore.set("apps.theming." + appRow.modelData.id, v)
                }
            }
        }
    }
}
