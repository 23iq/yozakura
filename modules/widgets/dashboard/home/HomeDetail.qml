import QtQuick
import qs.modules.services
import qs.modules.components.kit

// The details of a quick toggle or level on the composed dashboard, in
// place of the calendar and notifications: Wi-Fi networks and Bluetooth
// devices (the shared device panels of ../controls) or the audio outputs /
// inputs (HomeDevices). The label names it, "Done" closes it (`done()`).
Group {
    id: root

    // "wifi" | "bluetooth" | "output" | "input"
    property string kind: ""
    readonly property var panels: ({
            "wifi": "../controls/WifiPanel.qml",
            "bluetooth": "../controls/BluetoothPanel.qml"
        })
    readonly property bool audio: root.kind === "output" || root.kind === "input"

    signal done

    fill: true
    label: ({
            "wifi": I18n.t("dashboard.home.detail.wifi"),
            "bluetooth": I18n.t("dashboard.home.detail.bluetooth"),
            "output": I18n.t("dashboard.home.detail.output"),
            "input": I18n.t("dashboard.home.detail.input")
        })[root.kind] ?? ""
    actionText: I18n.t("bento.done")
    onActionTriggered: root.done()

    Loader {
        objectName: "detailPanel"
        width: parent.width
        height: root.bodyHeight
        active: root.kind !== "" && !root.audio
        visible: active
        clip: true
        source: root.panels[root.kind] ?? ""
    }

    HomeDevices {
        objectName: "devices"
        width: parent.width
        height: root.bodyHeight
        visible: root.audio
        output: root.kind === "output"
    }
}
