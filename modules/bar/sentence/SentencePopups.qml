pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.bar
import qs.modules.bar.clock
import qs.modules.bar.islandchips

// The popups a sentence fragment opens: the same ones as the matching bar
// modules (clock, battery, controls, media, notifications), each loaded on
// first use and anchored to `anchorItem` (the clicked fragment's span).
Item {
    id: root

    required property var bar
    required property Item anchorItem
    property string screenName: ""
    property date now: new Date()
    property bool use12h: false

    readonly property bool anyOpen: [clock, battery, controls, media, notifications].some(l => l.item && l.item.isOpen)

    function loaderOf(kind: string): Loader {
        switch (kind) {
        case "clock":
            return clock;
        case "battery":
            return battery;
        case "controls":
            return controls;
        case "media":
            return media;
        case "notifications":
            return notifications;
        }
        return null;
    }

    function toggle(kind: string): void {
        const l = root.loaderOf(kind);
        if (!l)
            return;
        l.active = true;
        root.requested(kind);
    }

    // Asks the popup of `kind` to toggle (each popup listens for its own)
    signal requested(string kind)

    Loader {
        id: clock
        active: false
        sourceComponent: ClockPopup {
            id: clockPopup
            Connections {
                target: root
                function onRequested(kind: string): void {
                    if (kind === "clock")
                        clockPopup.toggle();
                }
            }
            anchorItem: root.anchorItem
            bar: root.bar
            now: root.now
            use12h: root.use12h
        }
    }
    Loader {
        id: battery
        active: false
        sourceComponent: BatteryPopup {
            id: batteryPopup
            Connections {
                target: root
                function onRequested(kind: string): void {
                    if (kind === "battery")
                        batteryPopup.toggle();
                }
            }
            anchorItem: root.anchorItem
            bar: root.bar
        }
    }
    Loader {
        id: controls
        active: false
        sourceComponent: ControlsPopup {
            id: controlsPopup
            Connections {
                target: root
                function onRequested(kind: string): void {
                    if (kind === "controls")
                        controlsPopup.toggle();
                }
            }
            anchorItem: root.anchorItem
            bar: root.bar
        }
    }
    Loader {
        id: media
        active: false
        sourceComponent: MediaPopup {
            id: mediaPopup
            Connections {
                target: root
                function onRequested(kind: string): void {
                    if (kind === "media")
                        mediaPopup.toggle();
                }
            }
            anchorItem: root.anchorItem
            bar: root.bar
            screenName: root.screenName
        }
    }
    Loader {
        id: notifications
        active: false
        sourceComponent: NotificationsPopup {
            id: notificationsPopup
            Connections {
                target: root
                function onRequested(kind: string): void {
                    if (kind === "notifications")
                        notificationsPopup.toggle();
                }
            }
            anchorItem: root.anchorItem
            bar: root.bar
        }
    }
}
