import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Under the editor while the open note could not be saved: the failure, a
// retry, and an explicit discard (reload the note from disk). The text stays
// in the editor and the note stays open until one of them succeeds.
RowLayout {
    id: notice

    signal retry
    signal discard

    objectName: "noteSaveNotice"
    spacing: Space.s

    Chip {
        objectName: "noteSaveFailed"
        dense: true
        danger: true
        active: true
        icon: Icons.warning
        text: I18n.t("notes.save_failed")
    }

    Item {
        Layout.fillWidth: true
    }

    Chip {
        objectName: "noteSaveRetry"
        dense: true
        quiet: true
        icon: Icons.arrowsClockwise
        text: I18n.t("notes.save_retry")
        onClicked: notice.retry()
    }

    Chip {
        objectName: "noteSaveDiscard"
        dense: true
        quiet: true
        danger: true
        icon: Icons.trash
        text: I18n.t("notes.save_discard")
        onClicked: notice.discard()
    }
}
