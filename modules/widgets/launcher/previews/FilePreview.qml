import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.config
import "PreviewRegistry.js" as PreviewRegistry

// File result preview: a thumbnail for images, the first 40 lines for text
// (read by `head`, off the UI thread), otherwise the file's metadata.
ColumnLayout {
    id: preview

    property var result: null
    readonly property string path: result && result.data ? result.data.path : ""
    readonly property string kind: path ? PreviewRegistry.fileKind(path) : "other"
    property string text: ""

    spacing: Metrics.spacing

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

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: preview.kind !== "other"

        Image {
            anchors.fill: parent
            visible: preview.kind === "image"
            source: visible ? "file://" + preview.path : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
        }

        Flickable {
            anchors.fill: parent
            visible: preview.kind === "text"
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Text {
                id: body
                width: parent.width
                text: preview.text
                color: Colors.overBackground
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
                wrapMode: Text.WrapAnywhere
            }
        }
    }

    // Metadata (always shown for other files, as a footer otherwise)
    Text {
        Layout.fillWidth: true
        Layout.fillHeight: preview.kind === "other"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: preview.kind === "other" ? Text.AlignHCenter : Text.AlignLeft
        text: preview.result ? (preview.result.title || "") + "\n" + (preview.result.subtitle || "") : ""
        color: Colors.outline
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        elide: Text.ElideMiddle
        maximumLineCount: 3
        wrapMode: Text.WrapAnywhere
    }
}
