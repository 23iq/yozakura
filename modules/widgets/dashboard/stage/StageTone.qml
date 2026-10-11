import QtQuick
import "StageModel.js" as StageModel

// The tone of an image (the album art): the art drawn into a tiny canvas
// and averaged by StageModel.averageTone (saturated, mid-bright pixels
// weigh most). `tone` is {r, g, b} (0..1) or null (no art, still loading,
// transparent); `color` the same as a QML color (transparent when null).
Item {
    id: root

    property url source: ""
    property var tone: null
    readonly property color color: root.tone ? Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 1) : "transparent"
    readonly property int samples: 12
    readonly property string key: root.source.toString()

    width: root.samples
    height: root.samples
    opacity: 0

    function load() {
        if (root.key === "") {
            root.tone = null;
            return;
        }
        if (canvas.isImageLoaded(root.key))
            canvas.requestPaint();
        else
            canvas.loadImage(root.key);
    }

    onKeyChanged: root.load()
    Component.onCompleted: root.load()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            if (!ctx)
                return;
            ctx.clearRect(0, 0, width, height);
            if (root.key === "" || !isImageLoaded(root.key)) {
                root.tone = null;
                return;
            }
            ctx.drawImage(root.key, 0, 0, width, height);
            const img = ctx.getImageData(0, 0, width, height);
            root.tone = StageModel.averageTone(img ? img.data : null);
        }
    }
}
