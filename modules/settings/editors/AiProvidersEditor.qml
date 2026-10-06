import QtQuick
import QtQuick.Layouts
import qs.modules.aicenter.providers

// Settings > AI providers: the AI bar's Connect sheet, embedded (provider
// grid with connection state -> key/URL form, Test, Save, Disconnect).
ColumnLayout {
    id: root

    property var entry

    spacing: 0

    ConnectSheet {
        objectName: "settingsConnectSheet"
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        embedded: true
    }
}
