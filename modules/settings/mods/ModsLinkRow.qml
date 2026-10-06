import QtQuick
import qs.modules.services
import qs.modules.settings
import "../../globals/Urls.js" as Urls

// A metadata line whose value may be a web link: "Open" only for plain
// http(s) URLs (manifests are untrusted, see Urls.isWeb).
ModsMetaRow {
    id: row

    property string url: ""

    PillButton {
        visible: Urls.isWeb(row.url)
        kind: "ghost"
        text: I18n.t("mods.open_link")
        onClicked: {
            if (Urls.isWeb(row.url))
                Qt.openUrlExternally(row.url);
        }
    }
}
