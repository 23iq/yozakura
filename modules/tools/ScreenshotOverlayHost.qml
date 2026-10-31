import QtQuick
import Quickshell
import qs.modules.services
import "ScreenshotTarget.js" as ScreenshotTarget

// Per-screen host of the screenshot preview (shell.qml Variants delegate).
// The preview window only exists while there is an image to show: it is
// created on the saved signal and destroyed when the preview is dismissed.
Scope {
    id: root

    required property ShellScreen modelData

    property string path: ""

    Connections {
        target: Screenshot
        function onImageSaved(saved) {
            const s = root.modelData;
            const cursor = Quickshell.cursor;
            const sel = {
                "x": Screenshot.selectionX,
                "y": Screenshot.selectionY
            };
            const under = cursor && cursor.screen ? cursor.screen.name : "";
            if (!ScreenshotTarget.showsPreview(s, sel, Screenshot.captureMode, under))
                return;
            root.path = saved;
            if (overlay.item)
                overlay.item.imagePath = saved;
        }
    }

    Loader {
        id: overlay
        active: root.path !== ""
        sourceComponent: ScreenshotOverlay {
            targetScreen: root.modelData
            imagePath: root.path
            onImagePathChanged: {
                if (imagePath === "")
                    root.path = "";
            }
        }
    }
}
