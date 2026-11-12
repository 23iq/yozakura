pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The converter's content: a drop zone while empty, then one row per file
// grouped by kind (a header per kind with several files), the quality
// control when a lossy target is chosen, and Convert. Files come by drag and
// drop (anywhere, also with files listed), Ctrl+V or the file chooser.
// Enter converts, Esc closes (closeRequested), Tab walks the target chips.
FocusScope {
    id: root

    property alias converter: conv
    readonly property alias picker: picker

    signal closeRequested

    focus: true

    function pickRow(path, anchor) {
        const row = Model.rowByPath(conv.rows, path);
        if (!row)
            return;
        picker.mode = "row";
        picker.subject = path;
        picker.open(row.name, row.targets, row.target);
    }

    function pickKind(kind) {
        const group = conv.groups.find(g => g.kind === kind);
        picker.mode = "kind";
        picker.subject = kind;
        picker.open(I18n.t("converter.all_kind", I18n.t(Model.kindInfo(kind).label)), Model.commonTargets(conv.rows, kind), group ? group.target : "");
    }

    ConverterState {
        id: conv
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
        }
    }

    Surface {
        id: surface
        anchors.fill: parent
        variant: "bg"

        ColumnLayout {
            anchors.fill: parent
            spacing: Look.groupGap

            // header: title, add files, clear all
            RowLayout {
                Layout.fillWidth: true
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
                    icon: Icons.plus
                    tooltip: I18n.t("converter.add")
                    onClicked: chooser.open()
                }

                IconButton {
                    objectName: "pasteButton"
                    size: "s"
                    icon: Icons.clipboard
                    tooltip: I18n.t("converter.paste")
                    onClicked: conv.paste()
                }

                IconButton {
                    objectName: "clearButton"
                    visible: !conv.empty
                    size: "s"
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
                            onPickKind: kind => root.pickKind(kind)
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

                Chip {
                    objectName: "convertButton"
                    primary: conv.startCount > 0
                    enabled: conv.startCount > 0
                    focusable: true
                    icon: conv.busy ? Icons.spinnerGap : Icons.swap
                    text: conv.busy && conv.startCount === 0 ? I18n.t("converter.converting") : (conv.startCount > 1 ? I18n.t("converter.convert_n", conv.startCount) : I18n.t("converter.convert"))
                    onClicked: conv.convert()
                }
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
        opacity: drop.containsDrag ? 0.1 : 0
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
            root.forceActiveFocus();
        }
        onDismissed: root.forceActiveFocus()
    }
}
