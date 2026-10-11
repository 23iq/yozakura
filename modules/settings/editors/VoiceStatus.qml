import QtQuick
import qs.modules.services
import qs.modules.settings

// Voice input status (backend voice.status: whisper.cpp installed, model
// downloaded, server loaded, GPU backend) + how to talk to it.
Item {
    id: root

    property var entry
    // voice.status from the backend, null until it answers
    property var status: null
    // Missing tools etc. (backend voice.status warnings), as text
    readonly property var warnings: status && status.warnings ? Array.from(status.warnings).filter(w => w !== "disabled") : []
    readonly property bool off: !!status && status.enabled === false
    readonly property string tone: !status || off ? "muted" : (!status.installed || !status.modelPresent || warnings.length > 0 ? "warn" : "ok")
    readonly property string detail: warnings.length > 0 && !off ? warnings.map(w => I18n.t("voice.settings.warn." + w)).join(" \u00b7 ") : I18n.t("voice.settings.binds_hint")
    readonly property string title: {
        const s = root.status;
        if (!s)
            return I18n.t("prefs.voice.status.unknown");

        if (root.off)
            return I18n.t("voice.settings.disabled");

        if (!s.installed)
            return I18n.t("voice.settings.not_installed");

        if (!s.modelPresent)
            return I18n.t("voice.settings.model_missing");

        const backend = (s.backend || "cpu").toUpperCase();
        return I18n.t(s.serverRunning ? "voice.settings.ready_loaded" : "voice.settings.ready", backend);
    }

    function refresh() {
        BackendService.call("voice.status", {}, (result, error) => {
            if (!error && result)
                root.status = result;
        });
    }

    implicitHeight: line.implicitHeight
    Component.onCompleted: refresh()

    StatusLine {
        id: line

        width: parent.width
        icon: "mic"
        tone: root.tone
        title: root.title
        detail: root.detail

        PillButton {
            kind: "ghost"
            icon: "arrowsClockwise"
            text: ""
            implicitWidth: 34
            onClicked: root.refresh()
            Accessible.name: I18n.t("prefs.common.refresh")
        }
    }
}
