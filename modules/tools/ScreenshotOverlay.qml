import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.config

PanelWindow {
    id: root

    // Screen property to be set by the Loader
    required property var targetScreen
    screen: targetScreen

    property string imagePath: ""

    // Position: Bottom Left with margins
    anchors {
        left: true
        bottom: true
    }

    // Width/Height handled by content + margins
    implicitWidth: mainRow.width + Space.l
    implicitHeight: mainRow.height + Space.l

    color: "transparent"
    visible: imagePath !== ""

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property Process copyOverlayProcess: Process {
        id: copyOverlayProcess
        command: ["sh", "-c", 'wl-copy --type image/png < "$1"', "overlay-copy", root.imagePath]
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("Overlay Copy Failed (Exit code: " + exitCode + ")");
        }
    }

    // Timer to auto-hide after 5 seconds
    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        running: root.visible && !mouseAreaHover.containsMouse
        onTriggered: root.imagePath = ""
    }

    // MouseArea to detect hover and prevent auto-hide
    MouseArea {
        id: mouseAreaHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton // Pass clicks through
        propagateComposedEvents: true
    }

    // Shown by ScreenshotOverlayHost, which sets imagePath on the saved signal

    Row {
        id: mainRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Space.l
        spacing: Space.s

        // Preview Image with Drag Support
        ClippingRectangle {
            id: imgContainer

            // Calculate scale to fit within 250x250 while preserving aspect ratio
            property real maxWidth: 250
            property real maxHeight: 250
            property real imgRatio: img.sourceSize.width / img.sourceSize.height
            property real boxRatio: maxWidth / maxHeight

            width: {
                if (img.sourceSize.width <= 0)
                    return 0;
                if (imgRatio > boxRatio)
                    return maxWidth;
                return Math.min(maxWidth, img.sourceSize.width * (maxHeight / img.sourceSize.height));
            }

            height: {
                if (img.sourceSize.height <= 0)
                    return 0;
                if (imgRatio > boxRatio)
                    return Math.min(maxHeight, img.sourceSize.height * (maxWidth / img.sourceSize.width));
                return maxHeight;
            }

            radius: Look.radius("box")
            color: "transparent"
            border.width: Space.hairline
            border.color: Look.groupOutline

            Image {
                id: img
                mipmap: true
                anchors.fill: parent
                source: root.imagePath !== "" ? "file://" + root.imagePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                // Invisible item to handle the Drag attached property state
                Item {
                    id: dragTarget
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: {
                        "text/uri-list": "file://" + root.imagePath
                    }
                    Drag.imageSource: img.source
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true

                    // Show Grab Hand
                    cursorShape: Qt.DragCopyCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    // Bind drag target to initiate the drag sequence
                    drag.target: dragTarget

                    // Click to Open (Left) or Delete (Middle)
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                            proc.command = ["rm", "--", root.imagePath];
                            proc.running = true;
                            root.imagePath = "";
                        } else {
                            Qt.openUrlExternally("file://" + root.imagePath);
                        }
                    }
                }

                // Icon overlay on hover (optional, but requested "Icons.handGrab" context)
                Mark {
                    anchors.centerIn: parent
                    width: Space.controlXS
                    height: width
                    color: Colors.background
                    opacity: dragArea.containsMouse ? 0.8 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.enter.duration
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: Icons.handGrab
                    }
                }
            }
        }

        // Action buttons on a floating box (the overlay sits over any content)
        Surface {
            anchors.verticalCenter: parent.verticalCenter
            floating: true
            padding: Space.xs

            Column {
                spacing: Space.xs

                // Copy
                IconButton {
                    size: "s"
                    icon: Icons.copy
                    tooltip: I18n.t("common.copy")
                    onClicked: copyOverlayProcess.running = true
                }

                IconButton {
                    size: "s"
                    icon: Icons.disk
                    tooltip: I18n.t("common.save_close")
                    onClicked: root.imagePath = "" // Hide overlay
                }

                // Edit
                IconButton {
                    size: "s"
                    icon: Icons.edit
                    tooltip: I18n.t("wallpapers.edit_gradia")
                    onClicked: {
                        // Open with Gradia (native or Flatpak for Fedora) detached
                        var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                        proc.command = ["sh", "-c", 'if command -v gradia >/dev/null; then gradia "$1"; else flatpak run be.alexandervanhee.gradia "$1"; fi > /dev/null 2>&1 &', "gradia", root.imagePath];
                        proc.running = true;
                        root.imagePath = "";
                    }
                }

                // Trash
                IconButton {
                    size: "s"
                    icon: Icons.trash
                    danger: true
                    tooltip: I18n.t("common.delete")
                    onClicked: {
                        var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                        proc.command = ["rm", "--", root.imagePath];
                        proc.running = true;
                        root.imagePath = "";
                    }
                }
            }
        }
    }
}
