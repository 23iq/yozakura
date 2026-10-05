pragma Singleton
import QtQuick
import qs.modules.theme
import qs.modules.services
import "ActivityModel.js" as Model

// Yozakura's own screen recorder: pulsing red dot + elapsed time; click stops.
ActivityProvider {
    id: root

    source: "recording"

    onActiveChanged: if (active)
        ScreenRecorder.initialize()
    Component.onCompleted: if (active)
        ScreenRecorder.initialize()

    activities: active && ScreenRecorder.isRecording ? [
        {
            id: "recording",
            category: "privacy",
            priority: Model.PRIORITY.recording,
            icon: Icons.recordScreen,
            indicator: "dot",
            label: ScreenRecorder.duration || Model.formatDuration(0),
            detail: I18n.t("activities.stop_recording"),
            color: "red",
            startedAt: ScreenRecorder._startedAt.getTime(),
            action: "stop"
        }
    ] : []

    function activate(activity, button, screenName) {
        if (ScreenRecorder.isRecording)
            ScreenRecorder.toggleRecording();
    }
}
