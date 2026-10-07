pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.components.kit
import "NotchActivities.js" as NotchActivities

// One non-download activity in a notch panel as a ListRow: recording (with
// a stop button), timers, privacy (kind + apps; the microphone gets a mute
// toggle). Clicking the row activates it (right click too).
ListRow {
    id: row

    property var activity: null
    property string screenName: ""

    readonly property var a: row.activity || ({})
    readonly property var text: NotchActivities.activityText(row.a, {
        recording: I18n.t("shell.activities_recording")
    })

    title: row.text.primary
    subtitle: row.text.secondary
    onClicked: ActivityService.activate(row.activity, Qt.LeftButton, row.screenName)

    leading: Component {
        Art {
            width: Space.controlS
            height: Space.controlS
            source: row.a.image || ""
            icon: row.a.icon || ""
        }
    }
    trailing: Component {
        Row {
            spacing: Space.xs

            IconButton {
                objectName: "activityStop"
                size: "s"
                visible: row.a.source === "recording"
                icon: Icons.stop
                Accessible.name: I18n.t("activities.stop")
                onClicked: ActivityService.activate(row.activity, Qt.LeftButton, row.screenName)
            }
            IconButton {
                objectName: "activityMute"
                size: "s"
                visible: row.a.source === "privacy" && row.a.action === "mic"
                active: MicrophoneStatus.muted
                icon: MicrophoneStatus.muted ? Icons.micSlash : Icons.mic
                Accessible.name: MicrophoneStatus.muted ? I18n.t("activities.unmute") : I18n.t("activities.mute")
                onClicked: ActivityService.activate(row.activity, Qt.LeftButton, row.screenName)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: event => ActivityService.activate(row.activity, event.button, row.screenName)
    }
}
