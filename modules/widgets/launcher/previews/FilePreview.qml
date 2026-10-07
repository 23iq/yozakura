import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.components.kit
import "PreviewRegistry.js" as PreviewRegistry

// File result preview inside the detail pane: a rounded thumbnail for
// images, the first 40 lines for text (read by `head`, off the UI thread);
// nothing for other files (the pane's header already names them).
Item {
    id: preview

    property var result: null
    readonly property string path: result && result.data ? result.data.path : ""
    readonly property string kind: path ? PreviewRegistry.fileKind(path) : "other"
    property string text: ""

    onPathChanged: {
        text = "";
        head.running = false;
        if (kind === "text")
            head.running = true;
    }

    Process {
        id: head
        command: ["head", "-n", "40", "--", preview.path]
        stdout: StdioCollector {
            onStreamFinished: preview.text = PreviewRegistry.firstLines(text, 40)
        }
    }

    Art {
        anchors.fill: parent
        visible: preview.kind === "image"
        source: visible ? "file://" + preview.path : ""
        fillMode: Image.PreserveAspectFit
    }

    Flickable {
        anchors.fill: parent
        visible: preview.kind === "text"
        clip: true
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        KitText {
            id: body
            width: parent.width
            role: "caption"
            color: Type.secondary
            font.family: Config.theme.monoFont
            text: preview.text
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
            verticalAlignment: Text.AlignTop
        }
    }
}
