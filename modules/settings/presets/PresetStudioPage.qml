pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Settings "Presets" category: the preset studio. Gallery (live
// thumbnails on the current wallpaper; apply, try, duplicate, rename,
// delete with undo, export/import, save the current look), Mixer (a new
// preset from per-aspect sources) and the preset editor (what a preset
// changes, jump into settings with edits saved into the preset).
Item {
    id: page

    required property var category
    property string view: "gallery"
    property string editing: ""
    readonly property var current: body.item

    // SettingsShell reveal() hook (search jumps): nothing to scroll to.
    function reveal(section, entry) {
    }

    function show(v) {
        if (v.indexOf("editor:") === 0) {
            editing = v.slice(7);
            view = "editor";
        } else {
            view = v || "gallery";
        }
        flick.contentY = 0;
    }

    function handle(name, id) {
        switch (id) {
        case "apply":
            PresetStudio.apply(name);
            break;
        case "try":
            PresetStudio.tryPreset(name);
            break;
        case "duplicate":
            dialog.ask(I18n.t("prefs.presets.dialog.duplicate", name), PresetModel.uniqueName(PresetStudio.presets, I18n.t("prefs.presets.copy_of", name)), I18n.t("prefs.presets.duplicate"), "", n => PresetStudio.duplicate(name, n, (ok, created) => {
                    if (ok)
                        page.show("editor:" + created);
                }));
            break;
        case "rename":
            dialog.ask(I18n.t("prefs.presets.dialog.rename", name), name, I18n.t("prefs.presets.rename"), name, n => PresetStudio.rename(name, n, ok => {
                    if (ok && page.editing === name)
                        page.editing = n;
                }));
            break;
        case "update":
            PresetStudio.updateFromCurrent(name);
            break;
        case "export":
            PresetStudio.pickExport(name);
            break;
        case "delete":
            if (page.view === "editor" && page.editing === name)
                page.show("gallery");
            PresetStudio.remove(name);
            break;
        }
    }

    function saveCurrent() {
        dialog.ask(I18n.t("prefs.presets.dialog.save_current"), PresetModel.uniqueName(PresetStudio.presets, I18n.t("prefs.presets.my_look")), I18n.t("prefs.presets.save"), "", n => PresetStudio.saveCurrent(n));
    }

    Component.onCompleted: {
        PresetStudio.refresh();
        if (PresetStudio.requestedView) {
            show(PresetStudio.requestedView);
            PresetStudio.requestedView = "";
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 140
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: column
            width: Math.min(page.width - 64, 1080)
            x: (page.width - width) / 2
            y: 36
            spacing: 24

            // Header
            Item {
                width: parent.width
                height: Math.max(56, headText.implicitHeight)

                Rectangle {
                    id: tile
                    width: 56
                    height: 56
                    radius: Math.min(Styling.radius(4), 20)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Ui.alpha(Colors.primary, 0.28)
                        }
                        GradientStop {
                            position: 1
                            color: Ui.alpha(Colors.tertiary, 0.14)
                        }
                    }
                    border.width: 1
                    border.color: Ui.alpha(Colors.primary, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: Icons[page.category.icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: 26
                        color: Colors.primary
                    }
                }
                Column {
                    id: headText
                    anchors.left: tile.right
                    anchors.leftMargin: 18
                    anchors.right: headActions.left
                    anchors.rightMargin: 12
                    spacing: 4
                    Text {
                        width: parent.width
                        text: I18n.t(page.category.title)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(12)
                        font.weight: Font.Bold
                        color: Colors.overBackground
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: I18n.t("prefs.presets.studio.desc")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
                Row {
                    id: headActions
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 8
                    PillButton {
                        objectName: "saveCurrentLook"
                        kind: "filled"
                        icon: "plus"
                        text: I18n.t("prefs.presets.save_current")
                        onClicked: page.saveCurrent()
                    }
                    PillButton {
                        objectName: "importPreset"
                        icon: "downloadSimple"
                        text: I18n.t("prefs.presets.import")
                        onClicked: PresetStudio.pickImport()
                    }
                }
            }

            // Tabs
            Row {
                visible: page.view !== "editor"
                spacing: 4
                Repeater {
                    model: [
                        {
                            "id": "gallery",
                            "icon": "squaresFour",
                            "label": "prefs.presets.tab.gallery"
                        },
                        {
                            "id": "mixer",
                            "icon": "faders",
                            "label": "prefs.presets.tab.mixer"
                        }
                    ]
                    Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool on: page.view === modelData.id
                        objectName: "presetTab:" + modelData.id
                        width: tabRow.implicitWidth + 32
                        height: 38
                        radius: height / 2
                        color: on ? Colors.primary : (tabArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.08) : Ui.alpha(Colors.overBackground, 0.04))
                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons[tab.modelData.icon] ?? ""
                                font.family: Icons.font
                                font.pixelSize: 15
                                color: tab.on ? Colors.overPrimary : Colors.overSurfaceVariant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t(tab.modelData.label)
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                color: tab.on ? Colors.overPrimary : Colors.overBackground
                            }
                        }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.show(tab.modelData.id)
                        }
                    }
                }
            }

            Loader {
                id: body
                width: parent.width
                sourceComponent: page.view === "mixer" ? mixer : (page.view === "editor" ? editor : gallery)
            }
        }
    }

    Component {
        id: gallery
        PresetGallery {
            onOpenPreset: name => page.show("editor:" + name)
            onCardAction: (name, id) => page.handle(name, id)
            onSaveRequested: page.saveCurrent()
        }
    }
    Component {
        id: mixer
        PresetMixer {
            onAskName: (suggestion, sources) => dialog.ask(I18n.t("prefs.presets.dialog.mix"), suggestion, I18n.t("prefs.presets.mixer.create"), "", n => PresetStudio.mix(n, sources, ok => {
                        if (ok)
                            page.show("editor:" + n);
                    }))
        }
    }
    Component {
        id: editor
        PresetEditor {
            name: page.editing
            onBack: page.show("gallery")
            onAction: id => page.handle(page.editing, id)
        }
    }

    // Drop a bundle file anywhere on the page to import it.
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: d => {
            (d.urls || []).forEach(u => {
                if (String(u).toLowerCase().endsWith(".json"))
                    PresetStudio.importFile(String(u));
            });
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        visible: drop.containsDrag
        radius: Math.min(Styling.radius(6), 26)
        color: Ui.alpha(Colors.primary, 0.1)
        border.width: 2
        border.color: Colors.primary
        Text {
            anchors.centerIn: parent
            text: I18n.t("prefs.presets.drop")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(4)
            font.weight: Font.Bold
            color: Colors.primary
        }
    }

    PresetNameDialog {
        id: dialog
    }
}
