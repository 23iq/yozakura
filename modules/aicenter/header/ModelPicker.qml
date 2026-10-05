pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Searchable model/agent list grouped by provider (Ctrl+K). Keyboard:
// type to filter, Up/Down to move, Enter to pick, Esc to close.
Popup {
    id: root

    property string filterKind: "chat"   // chat (api+local) | agent | all
    signal picked(string id)

    width: Math.min(parent ? parent.width - 24 : 420, 420)
    height: Math.min(460, list.contentHeight + search.height + 34)
    padding: 8
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property int selectedIndex: 0
    readonly property var entries: {
        const q = search.text.toLowerCase();
        const all = Ai.models.filter(m => root.filterKind === "all" || (root.filterKind === "agent" ? m.kind === "agent" : m.kind !== "agent"));
        return all.filter(m => !q || m.name.toLowerCase().includes(q) || m.model.toLowerCase().includes(q) || m.provider.includes(q));
    }

    onOpened: {
        search.text = "";
        selectedIndex = Math.max(0, entries.findIndex(m => m.id === (Ai.currentModel ? Ai.currentModel.id : "")));
        search.forceActiveFocus();
        if (Ai.catalog && Ai.catalog.apiModels.length === 0)
            Ai.catalog.refresh();
    }

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(0)
        enableShadow: true
    }

    contentItem: ColumnLayout {
        spacing: 6

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: I18n.t("ai.search_models")
            placeholderTextColor: Colors.outline
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            leftPadding: 32
            background: StyledRect {
                variant: "common"
                radius: Styling.radius(-4)
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.magnifyingGlass
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: Colors.outline
                }
            }
            onTextChanged: root.selectedIndex = 0
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    root.selectedIndex = Math.min(root.entries.length - 1, root.selectedIndex + 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                    list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.entries[root.selectedIndex])
                        root.picked(root.entries[root.selectedIndex].id);
                    root.close();
                    event.accepted = true;
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            clip: true
            model: root.entries
            spacing: 2
            section.property: "provider"
            section.delegate: Text {
                required property string section
                text: section === "agent" ? I18n.t("ai.cli_agents") : section.toUpperCase()
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                font.weight: Font.DemiBold
                color: Colors.outline
                topPadding: 8
                bottomPadding: 2
                leftPadding: 8
            }
            delegate: StyledRect {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                height: 40
                radius: Styling.radius(-6)
                variant: entry.index === root.selectedIndex ? "focus" : (hov.hovered ? "common" : "transparent")
                HoverHandler {
                    id: hov
                }
                TapHandler {
                    onTapped: {
                        root.picked(entry.modelData.id);
                        root.close();
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    Image {
                        source: entry.modelData.icon
                        sourceSize: Qt.size(18, 18)
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        opacity: entry.modelData.available ? 1 : 0.4
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            elide: Text.ElideRight
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurface
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: entry.modelData.kind === "local" ? I18n.t("ai.local_model") + (entry.modelData.description ? " · " + entry.modelData.description : "") : entry.modelData.description
                            elide: Text.ElideRight
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-4)
                            color: Colors.outline
                        }
                    }
                    Text {
                        visible: Ai.currentModel && Ai.currentModel.id === entry.modelData.id
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: Colors.primary
                    }
                }
            }
        }

        Text {
            visible: root.entries.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 10
            text: Ai.catalog && Ai.catalog.fetching ? I18n.t("ai.loading_models") : I18n.t("ai.no_models")
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: root.width - 30
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
    }
}
