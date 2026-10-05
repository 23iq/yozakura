pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import "../../Ui.js" as Ui
import "../../../specials/Specials.js" as Specials

// Installed apps (the launcher's index, AppSearch) to add to a special:
// type to search, click to add. The window class comes from the desktop
// entry's StartupWMClass (else its id), the command from its Exec line;
// both stay editable on the app row.
Column {
    id: root

    signal picked(var app)

    property string query: ""
    readonly property var results: root.query.trim().length > 0 ? AppSearch.fuzzyQuery(root.query.trim()).slice(0, 6) : []

    spacing: 6

    function entryOf(r) {
        const e = DesktopEntries.byId ? DesktopEntries.byId(r.id) : null;
        return Specials.appFromEntry({
            "id": r.id,
            "name": r.name,
            "icon": e && e.icon ? e.icon : r.icon,
            "execString": r.execString || (e ? e.execString : ""),
            "startupClass": e ? (e.startupClass || "") : ""
        });
    }

    TextControl {
        id: search
        objectName: "appSearch"
        width: parent.width
        placeholder: I18n.t("specials.app_search")
        onEdited: t => root.query = t
        Connections {
            target: search.input
            function onTextChanged() {
                root.query = search.input.text;
            }
        }
    }

    Repeater {
        model: root.results
        delegate: Rectangle {
            id: row
            required property var modelData
            objectName: "appResult:" + modelData.id
            width: root.width
            height: 40
            radius: Math.min(Styling.radius(-2), 12)
            color: area.containsMouse ? Ui.alpha(Colors.primary, 0.12) : Ui.alpha(Colors.overBackground, 0.04)

            IconImage {
                id: icon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 24
                source: Quickshell.iconPath(row.modelData.icon || "", "application-x-executable")
                asynchronous: true
            }
            Text {
                anchors.left: icon.right
                anchors.leftMargin: 10
                anchors.right: addGlyph.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                elide: Text.ElideRight
            }
            Text {
                id: addGlyph
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.plus
                font.family: Icons.font
                font.pixelSize: 15
                color: Colors.primary
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.picked(root.entryOf(row.modelData));
                    search.input.text = "";
                }
            }
        }
    }
}
