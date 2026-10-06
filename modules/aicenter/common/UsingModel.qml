pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.aicenter.common
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// "Using Codex · GPT-5.5 · medium" under an empty state: the engine, the
// concrete model and effort a first message will use (Ai.effort.summary).
// Click opens the model picker.
StyledRect {
    id: root
    objectName: "usingModel"
    readonly property string summary: Ai.effort ? Ai.effort.summary : ""

    visible: summary.length > 0
    implicitWidth: row.implicitWidth + 20
    implicitHeight: row.implicitHeight + 10
    radius: Styling.radius(-4)
    variant: hover.hovered ? "common" : "transparent"
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: Ai.modelSelectionRequested()
    }
    RowLayout {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 20)
        spacing: 6
        Text {
            text: Icons.sparkle
            font.family: Icons.font
            font.pixelSize: BarLook.font(-3)
            color: Colors.primary
        }
        Text {
            objectName: "usingModelText"
            Layout.fillWidth: true
            text: I18n.t("ai.using_model").arg(root.summary)
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-3)
            color: Colors.overSurfaceVariant
        }
    }
}
