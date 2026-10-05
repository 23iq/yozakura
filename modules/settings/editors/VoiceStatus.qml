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
    readonly property string tone: !status ? "muted" : (!status.installed || !status.modelPresent ? "warn" : "ok")
    readonly property string title: {
        const s = root.status;
        if (!s)
            return I18n.t("prefs.voice.status.unknown");

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
        detail: I18n.t("voice.settings.binds_hint")

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
