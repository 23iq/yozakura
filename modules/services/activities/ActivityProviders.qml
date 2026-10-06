pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services.activities

// The provider registry. Adding an activity source = one new provider file
// (`pragma Singleton` + `ActivityProvider { ... }`, or `TransferProvider`
// for a backend transfers source) + one entry here, and a default under
// bar.activities.sources if it should be toggleable.
Singleton {
    readonly property var all: [
        // Activities
        RecordingActivity, PrivacyActivity, TimerActivity, TasksActivity,
        // Transfers (shown together as "downloads")
        NotificationProgressActivity, JobViewActivity, BrowserDownloadsActivity, SteamActivity, TerminalDownloadsActivity, FileOpsActivity, PackagesActivity, TorrentsActivity, Aria2Activity, SyncthingActivity, LaunchersActivity]
}
