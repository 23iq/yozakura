pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "previews/PreviewRegistry.js" as PreviewRegistry

// The detail pane beside the results (layout.launcher.preview): the
// selected result's icon, name (title role), type line and description, its
// preview body when it has one (file thumbnail / text head, calculator value,
// clipboard text: previews/PreviewRegistry.js) and an "Actions" group. The
// selection reaches it after a short pause and the body loads
// asynchronously, so moving the selection or typing never waits on it.
Item {
    id: pane

    property var selection: null
    // LauncherResults: the actions of the shown result.
    property var host: null
    // True when the selected result has a detail (the host opens the pane).
    readonly property bool available: PreviewRegistry.hasDetail(selection)

    // Debounced copy of `selection`: what the pane actually shows.
    property var shown: null
    readonly property var body: PreviewRegistry.previewFor(shown)
    readonly property var actions: PreviewRegistry.actions(shown, shown && host ? host.options(shown) : [])

    // An action row was clicked: its option id ("" = the main action).
    signal actionTriggered(string option)

    clip: true

    onSelectionChanged: {
        if (selection === null)
            shown = null;
        else
            settle.restart();
    }

    Timer {
        id: settle
        interval: Motion.delay + 40
        onTriggered: pane.shown = pane.selection
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Space.m
        visible: pane.shown !== null

        // Icon, name, type
        RowLayout {
            Layout.fillWidth: true
            spacing: Space.m

            ResultIcon {
                item: pane.shown || ({})
                size: Space.controlM + Space.l
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.xs

                KitText {
                    objectName: "detailTitle"
                    Layout.fillWidth: true
                    role: "title"
                    text: pane.shown ? pane.shown.title || "" : ""
                }
                KitText {
                    Layout.fillWidth: true
                    role: "secondary"
                    text: {
                        const s = pane.shown;
                        if (!s)
                            return "";
                        const type = I18n.t("launcher.provider." + s.provider);
                        return s.badge && s.badge !== type ? type + " · " + s.badge : type;
                    }
                }
            }
        }

        // Description / usage (a file or clip body shows the content instead;
        // the list row keeps its path)
        KitText {
            Layout.fillWidth: true
            role: "body"
            color: Type.secondary
            visible: text !== "" && (pane.body === null || pane.body.kind === "calc")
            text: pane.shown ? pane.shown.subtitle || "" : ""
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 3
        }

        // Preview body (file, calculator, clipboard)
        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.fillHeight: true
            asynchronous: true
            active: pane.body !== null
            source: active ? Qt.resolvedUrl(pane.body.file) : ""
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }
            onLoaded: item.result = pane.shown
            Connections {
                target: pane
                function onShownChanged() {
                    if (loader.item && pane.shown)
                        loader.item.result = pane.shown;
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: pane.body === null
        }

        Group {
            Layout.fillWidth: true
            label: I18n.t("launcher.actions")
            visible: pane.actions.length > 0

            ResultActions {
                objectName: "detailActions"
                width: parent.width
                options: pane.actions
                onTriggered: index => pane.actionTriggered(pane.actions[index].id || "")
            }
        }
    }
}
