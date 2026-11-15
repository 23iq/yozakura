pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The converter's content: a drop zone while empty, then one row per file
// grouped by kind (a header per kind with several files), the quality
// control when a lossy target is chosen, and Convert. Files come by drag and
// drop (anywhere, also with files listed), Ctrl+V or the file chooser
// (Ctrl+O, the drop zone, the + button). Keyboard: Tab walks every control
// (toolbar, drop zone, kind and target chips, row buttons, Convert), Enter
// converts, Delete removes the row in focus (FileRow), Esc closes
// (closeRequested). The list follows the focus and fades out at the bottom
// while more rows are below.
FocusScope {
    id: root

    property alias converter: conv
    readonly property alias picker: picker
    readonly property alias chooser: chooser

    signal closeRequested

    focus: true

    // anchor: the chip that asks (the focus returns to it)
    function pickRow(path, anchor) {
        const row = Model.rowByPath(conv.rows, path);
        if (!row || !Model.editable(row))
            return;
        picker.mode = "row";
        picker.subject = path;
        picker.open(row.name, row.targets, row.target, anchor);
    }

    function pickKind(kind, anchor) {
        const group = conv.groups.find(g => g.kind === kind);
        picker.mode = "kind";
        picker.subject = kind;
        picker.open(I18n.t("converter.all_kind", I18n.t(Model.kindInfo(kind).label)), Model.commonTargets(conv.rows, kind), group ? group.target : "", anchor);
    }

    // Scroll the list so the control in focus is in view.
    readonly property Item focusItem: root.Window.activeFocusItem
    onFocusItemChanged: root.reveal(root.focusItem)

    function reveal(item) {
        if (!item || !list.visible)
            return;
        let inside = false;
        for (let p = item.parent; p; p = p.parent) {
            if (p === list.contentItem) {
                inside = true;
                break;
            }
        }
        if (!inside)
            return;
        const top = item.mapToItem(list.contentItem, 0, 0).y - Space.s;
        const bottom = top + item.height + Space.s * 2;
        if (top < list.contentY)
            list.contentY = Math.max(list.originY, top);
        else if (bottom > list.contentY + list.height)
            list.contentY = Math.min(bottom - list.height, list.originY + list.contentHeight - list.height);
    }

    ConverterState {
        id: conv
        objectName: "converterState"
    }

    FileChooser {
        id: chooser
        onChosen: paths => conv.add(paths)
        onUnavailable: conv.notice = I18n.t("converter.no_chooser")
    }

    Component.onDestruction: conv.dispose()

    Keys.onPressed: event => {
        if (picker.shown)
            return;
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && conv.startCount > 0) {
            conv.convert();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            conv.paste();
            event.accepted = true;
        } else if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
            chooser.open();
            event.accepted = true;
        }
    }

    Surface {
        id: surface
        anchors.fill: parent
        variant: "bg"

        ColumnLayout {
            anchors.fill: parent
            spacing: Look.groupGap

            // header: title, add files, paste, clear all; at the rows'
            // inset (the art column, the row buttons' right edge)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                spacing: Space.s

                Icon {
                    icon: Icons.swap
                    role: "title"
                    tone: "accent"
                }

                KitText {
                    Layout.fillWidth: true
                    role: "title"
                    text: I18n.t("converter.title")
                }

                IconButton {
                    objectName: "addButton"
                    size: "s"
                    focusable: true
                    icon: Icons.plus
                    tooltip: I18n.t("converter.add")
                    onClicked: chooser.open()
                }

                IconButton {
                    objectName: "pasteButton"
                    size: "s"
                    focusable: true
                    icon: Icons.clipboard
                    tooltip: I18n.t("converter.paste")
                    onClicked: conv.paste()
                }

                IconButton {
                    objectName: "clearButton"
                    visible: !conv.empty
                    size: "s"
                    focusable: true
                    icon: Icons.broom
                    tooltip: I18n.t("converter.clear")
                    onClicked: conv.clearAll()
                }
            }

            DropZone {
                objectName: "dropZone"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: conv.empty
                dragging: drop.containsDrag
                message: conv.notice
                onClicked: chooser.open()
            }

            ListView {
                id: list
                objectName: "fileList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !conv.empty
                clip: true
                spacing: Space.xs
                boundsBehavior: Flickable.StopAtBounds
                // more rows below: the last visible ones fade out
                readonly property bool more: list.contentHeight > list.height && !list.atYEnd
                layer.enabled: list.more
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: fade
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
                model: KeyedListModel {
                    keys: Model.entryKeys(conv.rows)
                }

                delegate: Loader {
                    id: entry
                    required property string key
                    width: ListView.view.width
                    sourceComponent: entry.key.indexOf("h:") === 0 ? headerComp : rowComp

                    Component {
                        id: headerComp
                        KindHeader {
                            converter: conv
                            kind: entry.key.substring(2)
                            onPickKind: (kind, anchor) => root.pickKind(kind, anchor)
                        }
                    }

                    Component {
                        id: rowComp
                        FileRow {
                            objectName: "row:" + entry.key.substring(2)
                            converter: conv
                            path: entry.key.substring(2)
                            onPickTarget: (path, anchor) => root.pickRow(path, anchor)
                        }
                    }
                }
            }

            KitText {
                objectName: "notice"
                Layout.fillWidth: true
                visible: !conv.empty && conv.notice !== ""
                role: "caption"
                color: Type.danger
                wrapMode: Text.WordWrap
                text: conv.notice
            }

            // footer: quality (lossy targets only) and the one primary action
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                visible: !conv.empty
                spacing: Space.s

                // quality of lossy targets (jpg, webp, mp3, video...) only
                Icon {
                    visible: conv.showQuality
                    icon: Icons.faders
                    role: "secondary"
                    tone: "muted"
                }

                KitText {
                    visible: conv.showQuality
                    role: "secondary"
                    color: Type.secondary
                    text: I18n.t("converter.quality")
                }

                Segmented {
                    id: quality
                    objectName: "quality"
                    visible: conv.showQuality
                    model: [
                        {
                            "name": "small",
                            "text": I18n.t("converter.quality.small")
                        },
                        {
                            "name": "balanced",
                            "text": I18n.t("converter.quality.balanced")
                        },
                        {
                            "name": "best",
                            "text": I18n.t("converter.quality.best")
                        }
                    ]
                    currentIndex: ["small", "balanced", "best"].indexOf(conv.quality)
                    onActivated: index => conv.quality = ["small", "balanced", "best"][index]
                }

                Item {
                    Layout.fillWidth: true
                }

                // Convert; while converting with nothing new to start, it
                // turns (spinner and all) into Stop all: always a real action
                Chip {
                    objectName: "convertButton"
                    readonly property bool stops: conv.busy && conv.startCount === 0
                    primary: conv.startCount > 0
                    danger: stops
                    enabled: conv.startCount > 0 || stops
                    focusable: true
                    action: true
                    icon: stops ? Icons.spinnerGap : Icons.swap
                    spinning: stops
                    text: stops ? I18n.t("converter.stop_all") : (conv.startCount > 1 ? I18n.t("converter.convert_n", conv.startCount) : I18n.t("converter.convert"))
                    onClicked: stops ? conv.stopAll() : conv.convert()
                }
            }
        }
    }

    // the list fade's mask (out of the layout): opaque, then clear over
    // the last row height
    Mark {
        id: fade
        width: list.width
        height: list.height
        visible: false
        layer.enabled: list.more
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Type.text
            }
            GradientStop {
                position: Math.max(0, 1 - Space.rowHeight / Math.max(1, fade.height))
                color: Type.text
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Type.text, 0)
            }
        }
    }

    // Files dropped anywhere on the window, also while some are listed
    DropArea {
        id: drop
        objectName: "dropArea"
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: event => {
            if (event.hasUrls) {
                conv.addUrls(event.urls);
                event.acceptProposedAction();
            }
        }
    }

    // the wash over the list while files are dragged over it
    Mark {
        anchors.fill: parent
        visible: !conv.empty
        radius: Space.surfaceRadius
        color: Type.accent
        opacity: drop.containsDrag ? Look.activeTint : 0
    }

    FormatPicker {
        id: picker
        objectName: "picker"
        anchors.fill: parent
        property string mode: "row"
        property string subject: ""
        onChosen: id => {
            if (picker.mode === "kind")
                conv.setKindTarget(picker.subject, id);
            else
                conv.setTarget(picker.subject, id);
            picker.restoreFocus(root);
        }
        onDismissed: picker.restoreFocus(root)
    }
}
