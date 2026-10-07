pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel

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
            width: Math.min(page.width - Space.xxl * 2, 1080)
            x: (page.width - width) / 2
            y: Space.xxl
            spacing: Space.xl

            // Header: the page header with the studio's two actions.
            PageHeader {
                width: parent.width
                category: page.category
                description: I18n.t("prefs.presets.studio.desc")

                PillButton {
                    objectName: "saveCurrentLook"
                    Layout.alignment: Qt.AlignTop
                    kind: "filled"
                    icon: "plus"
                    text: I18n.t("prefs.presets.save_current")
                    onClicked: page.saveCurrent()
                }
                PillButton {
                    objectName: "importPreset"
                    Layout.alignment: Qt.AlignTop
                    icon: "downloadSimple"
                    text: I18n.t("prefs.presets.import")
                    onClicked: PresetStudio.pickImport()
                }
            }

            // Tabs
            Row {
                visible: page.view !== "editor"
                spacing: Space.xs
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
                    Chip {
                        required property var modelData
                        objectName: "presetTab:" + modelData.id
                        icon: Icons[modelData.icon] ?? ""
                        text: I18n.t(modelData.label)
                        active: page.view === modelData.id
                        onClicked: page.show(modelData.id)
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
    PresetDropOverlay {
        id: dropOverlay
        objectName: "presetDropOverlay"
        anchors.fill: parent
        visible: drop.containsDrag
    }

    PresetNameDialog {
        id: dialog
    }
}
