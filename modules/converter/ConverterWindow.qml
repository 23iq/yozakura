import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit

// The file converter: a compact floating toplevel (a real window, so files
// can be dragged in from a file manager), opened from the tools menu or
// `<app> run converter` (GlobalStates.converterWindowVisible) and loaded
// by URL from shell.qml only while open.
FloatingWindow {
    id: root

    // six hero controls wide and tall: scales with the UI spacing (Space)
    implicitWidth: Space.controlXL * 6
    implicitHeight: Space.controlXL * 6
    minimumSize: Qt.size(Space.controlXL * 4, Space.controlXL * 4)
    title: I18n.t("converter.title")
    color: "transparent"
    visible: GlobalStates.converterWindowVisible

    onVisibleChanged: {
        if (!visible && GlobalStates.converterWindowVisible)
            GlobalStates.converterWindowVisible = false;
    }

    ConverterView {
        anchors.fill: parent
        focus: true
        onCloseRequested: GlobalStates.converterWindowVisible = false
    }
}
