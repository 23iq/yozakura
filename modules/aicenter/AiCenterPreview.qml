import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.aicenter.header
import qs.modules.aicenter.composer
import qs.modules.aicenter.transcript
import "../components/preview/Preview.js" as Preview

// The Assistant's panel as a picture for Settings (its Assistant stage and
// cards, by URL through a LivePart): AiCenterPanel's own surface and
// column (header, conversation, status strip, composer) built from the
// same parts, with a sample conversation instead of the Ai service, which
// it never reads (the panel itself is wired to it throughout). Samples
// (PreviewContext `preview`): "ai.rows" (ChatSession rows: {role, content,
// thinking, toolCalls, model, status, ts}), "ai.model" ({name, provider,
// kind}), "ai.size" ("compact" | "wide"), "ai.space" ("assistant" | "code": the header), "ai.effortLevels", "ai.effort", "ai.cost", "ai.context"
// ([used, window]), "ai.limit" (0..1). Everything else (message style,
// density, text size, avatars, times, thinking, the strip items, your
// fonts and colours) is the live config, read by the parts themselves.
// Size: the sidebar's width for "compact", the wide width else; as
// tall as the conversation (a picture shows all of it, no empty column).
StyledRect {
    id: root

    property var preview: null
    readonly property string size: Preview.sample(root.preview, "ai.size", "compact")
    readonly property var rows: Preview.sample(root.preview, "ai.rows", [])
    readonly property var context: Preview.sample(root.preview, "ai.context", [0, 0])
    readonly property real limit: Preview.sample(root.preview, "ai.limit", -1)

    implicitWidth: root.size === "compact" ? (Config.ai.sidebarWidth ?? 400) : Math.max(Config.ai.sidebarWidth ?? 400, Config.ai.wideWidth ?? 1040)
    implicitHeight: Math.ceil(column.implicitHeight + Space.s * 2)
    variant: "bg"
    radius: Look.radius("surface")

    // ChatSession.rows, from the sample
    QtObject {
        id: session
        readonly property ListModel rows: ListModel {}
    }
    function fill() {
        session.rows.clear();
        (root.rows || []).forEach(r => session.rows.append(r));
    }
    onRowsChanged: root.fill()
    Component.onCompleted: root.fill()

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Space.s
        spacing: Space.s

        CenterHeader {
            Layout.fillWidth: true
            preview: root.preview
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: transcript.contentHeight
            clip: true
            TranscriptView {
                id: transcript
                anchors.fill: parent
                preview: root.preview
                session: session
                agentLabel: (Preview.sample(root.preview, "ai.model", null) || {}).name || ""
            }
        }
        ComposerStatus {
            Layout.fillWidth: true
            Layout.leftMargin: Space.xs
            Layout.rightMargin: Space.xs
            preview: root.preview
            contextUsed: root.context[0] || 0
            contextWindow: root.context[1] || 0
            costText: Preview.sample(root.preview, "ai.cost", "")
            limitFraction: root.limit
            limitText: root.limit >= 0 ? Math.round(root.limit * 100) + "%" : ""
        }
        Composer {
            objectName: "previewComposer"
            Layout.fillWidth: true
            placeholder: I18n.t("ai.ask_anything")
        }
    }
}
