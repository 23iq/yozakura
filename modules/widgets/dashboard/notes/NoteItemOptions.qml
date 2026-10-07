pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Options of an expanded note row as compact kit ListRows (like the
// launcher's ResultActions): Edit / Rename / Delete for a note, Rich text /
// Markdown for the "create" row. The highlighted option follows
// tab.selectedOptionIndex (keyboard) and the mouse.
Column {
    id: options

    // The NotesTab (state + actions) and the row's note entry
    required property var tab
    required property var note

    readonly property var noteOptions: [
        {
            text: I18n.t("common.edit"),
            icon: Icons.edit,
            run: () => options.tab.openNoteInEditor(options.note.id)
        },
        {
            text: I18n.t("common.rename"),
            icon: Icons.cursorText,
            run: () => {
                options.tab.enterRenameMode(options.note.id);
                options.tab.expandedItemIndex = -1;
            }
        },
        {
            text: I18n.t("common.delete"),
            icon: Icons.trash,
            destructive: true,
            run: () => {
                options.tab.enterDeleteMode(options.note.id);
                options.tab.expandedItemIndex = -1;
            }
        }
    ]

    readonly property var createOptions: [
        {
            text: I18n.t("notes.rich_text"),
            icon: Icons.file,
            run: () => {
                options.tab.expandedItemIndex = -1;
                options.tab.createNewNote(options.note.noteNameToCreate || "", false);
            }
        },
        {
            text: I18n.t("notes.markdown"),
            icon: Icons.markdown,
            run: () => {
                options.tab.expandedItemIndex = -1;
                options.tab.createNewNote(options.note.noteNameToCreate || "", true);
            }
        }
    ]

    Repeater {
        model: options.note.isCreateButton ? options.createOptions : options.noteOptions

        ListRow {
            id: option
            required property var modelData
            required property int index

            width: options.width
            height: Space.controlS
            title: modelData.text
            highlighted: options.tab.selectedOptionIndex === index
            onClicked: modelData.run()
            onHoveredChanged: {
                if (hovered && !highlighted) {
                    options.tab.selectedOptionIndex = index;
                    options.tab.keyboardNavigation = false;
                }
            }

            leading: Component {
                Text {
                    width: Type.iconSize("body")
                    horizontalAlignment: Text.AlignHCenter
                    text: option.modelData.icon
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: option.modelData.destructive ? Colors.error : Type.secondary
                }
            }
        }
    }
}
