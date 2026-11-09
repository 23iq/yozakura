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
import qs.modules.components.kit

// Installed apps (the launcher's index, AppSearch) to add to a special:
// type to search, click to add. The window class comes from the desktop
// entry's StartupWMClass (else its id), the command from its Exec line;
// both stay editable on the app row.
Column {
    id: root

    signal picked(var app)

    property string query: ""
    readonly property var results: root.query.trim().length > 0 ? AppSearch.fuzzyQuery(root.query.trim()).slice(0, 6) : []

    spacing: Space.s

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
            radius: Look.radius("control")
            color: area.containsMouse ? Ui.alpha(Colors.primary, 0.12) : Ui.alpha(Colors.overBackground, 0.04)

            IconImage {
                id: icon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 24
                source: Quickshell.iconPath(row.modelData.icon || "", "application-x-executable")
                asynchronous: true
            }
            KitText {
                role: "secondary"
                anchors.left: icon.right
                anchors.leftMargin: Space.m
                anchors.right: addGlyph.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: Colors.overBackground
                elide: Text.ElideRight
            }
            Icon {
                id: addGlyph
                role: "secondary"
                tone: "accent"
                anchors.right: parent.right
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.plus
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
