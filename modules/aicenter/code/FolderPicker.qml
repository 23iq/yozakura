pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "FolderPath.js" as FolderPath

// The Code project picker, a sheet inside the AI bar. Empty field: recent
// folders and the git repositories found under ~ (fs.repos); typing filters
// them. A path ("~/src/", "/") browses that folder (fs.list) with
// breadcrumbs and filters its subfolders by the name typed after the last
// "/". Up/Down select, Tab/Right browse into the selection, Enter (or a
// double click) chooses it, Enter with nothing selected chooses the folder
// being browsed. The desktop's dialog (zenity) stays as a fallback.
StyledRect {
    id: root
    objectName: "folderPicker"

    property bool opened: false
    property string current: ""
    signal chosen(string dir)
    signal closeRequested

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property var split: FolderPath.split(field.text, home)
    readonly property bool browsing: split.dir !== ""
    readonly property var listing: browser.listing
    readonly property var rows: FolderPath.rows({
        "text": field.text,
        "home": root.home,
        "entries": root.listing ? root.listing.entries || [] : [],
        "recents": [root.current].concat(Config.ai.agents.recentDirs || []).filter((d, i, a) => d && a.indexOf(d) === i),
        "repos": browser.repos,
        "hidden": root.showHidden
    })
    property int selected: -1
    property bool showHidden: false
    readonly property string target: FolderPath.target(rows, selected, field.text, home)

    function open(start) {
        current = start || "";
        browser.reset();
        browser.loadRepos(false);
        field.text = "";
        selected = -1;
        opened = true;
        field.forceActiveFocus();
    }
    function close() {
        if (!opened)
            return;
        opened = false;
        closeRequested();
    }
    function browse(path) {
        field.text = FolderPath.browseText(path, home);
        field.cursorPosition = field.text.length;
        field.forceActiveFocus();
    }
    function choose(path) {
        if (!path)
            return;
        const l = browser.cache[path];
        if (l && l.error && !browser.error) {
            errorText.text = l.error;
            return;
        }
        // A typed name that is not among its parent's subfolders.
        const up = browser.cache[FolderPath.parent(path)];
        if (path !== "/" && up && !up.error && !(up.entries || []).some(e => e.path === path)) {
            errorText.text = I18n.t("ai.folder.missing").arg(FolderPath.tilde(path, home));
            return;
        }
        opened = false;
        chosen(path);
        closeRequested();
    }
    function move(dir) {
        selected = FolderPath.step(rows, selected, dir);
        if (selected >= 0)
            list.positionViewAtIndex(selected, ListView.Contain);
    }
    function systemDialog() {
        const start = target || current || home;
        close();
        Ai.context.pickDirectory(start, dir => {
            if (dir)
                root.chosen(dir);
        });
    }

    onSplitChanged: {
        errorText.text = "";
        if (split.dir)
            browser.list(split.dir);
    }
    // A typed name selects its best match; browsing a folder selects nothing
    // (Enter then chooses that folder).
    onRowsChanged: selected = FolderPath.split(field.text, home).partial ? FolderPath.first(rows) : -1

    FolderBrowser {
        id: browser
    }

    variant: "bg"
    radius: Look.radius("control")
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    enabled: opened
    Behavior on opacity {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 2
            easing.type: Motion.enter.easing
        }
    }

    // Swallow clicks and wheel events so the view below gets none.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    // A readable column in the wide and fullscreen bar.
    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: BarLook.pad
        width: Math.min(parent.width - 2 * BarLook.pad, 640)
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.xs / 2
                AiText {
                    Layout.fillWidth: true
                    text: I18n.t("ai.folder.title")
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("ai.folder.current").arg(FolderPath.tilde(root.current, root.home))
                    elide: Text.ElideMiddle
                }
            }
            IconButton {
                size: "xs"
                icon: Icons.cancel
                tooltip: I18n.t("ai.close")
                onClicked: root.close()
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Look.radius("control")
            variant: field.activeFocus ? "focus" : "common"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Space.s
                anchors.rightMargin: Space.xs
                spacing: Space.xs
                Icon {
                    role: "secondary"
                    tone: "muted"
                    icon: root.browsing ? Icons.folderOpen : Icons.magnifyingGlass
                    size: BarLook.size("secondary")
                }
                TextField {
                    id: field
                    objectName: "folderField"
                    Layout.fillWidth: true
                    placeholderText: I18n.t("ai.folder.placeholder")
                    placeholderTextColor: Colors.outline
                    color: Colors.overSurface
                    font.family: root.browsing ? Config.theme.monoFont : Config.theme.font
                    font.pixelSize: root.browsing ? BarLook.monoSize("caption") : BarLook.size("secondary")
                    selectByMouse: true
                    background: null
                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onTabPressed: event => {
                        const row = root.rows[root.selected];
                        if (row && row.type !== "header")
                            root.browse(row.path);
                        event.accepted = true;
                    }
                    Keys.onRightPressed: event => {
                        const row = root.rows[root.selected];
                        if (row && row.type !== "header" && cursorPosition === text.length)
                            root.browse(row.path);
                        else
                            event.accepted = false;
                    }
                    Keys.onReturnPressed: root.choose(root.target)
                    Keys.onEnterPressed: root.choose(root.target)
                    Keys.onEscapePressed: root.close()
                }
                IconButton {
                    objectName: "folderHome"
                    icon: Icons.folder
                    size: "xs"
                    tooltip: I18n.t("ai.folder.home")
                    onClicked: root.browse(root.home)
                }
                IconButton {
                    objectName: "folderHidden"
                    visible: root.browsing
                    icon: Icons.eye
                    size: "xs"
                    active: root.showHidden
                    tooltip: I18n.t("ai.folder.hidden")
                    onClicked: root.showHidden = !root.showHidden
                }
                IconButton {
                    visible: !root.browsing
                    icon: Icons.arrowsClockwise
                    size: "xs"
                    tooltip: I18n.t("ai.folder.rescan")
                    onClicked: browser.loadRepos(true)
                }
            }
        }

        // Breadcrumbs of the browsed folder, scrolled to the deepest one.
        Flickable {
            id: crumbsView
            Layout.fillWidth: true
            visible: root.browsing
            implicitHeight: 26
            contentWidth: crumbsRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
            Row {
                id: crumbsRow
                spacing: Space.xs / 2
                Repeater {
                    model: FolderPath.crumbs(root.split.dir, root.home)
                    delegate: Row {
                        id: crumb
                        required property var modelData
                        required property int index
                        spacing: Space.xs / 2
                        Icon {
                            role: "caption"
                            tone: "muted"
                            visible: crumb.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Icons.caretRight
                            size: BarLook.size("caption")
                        }
                        StyledRect {
                            implicitWidth: crumbText.implicitWidth + 2 * Space.s
                            implicitHeight: 24
                            radius: Look.radius("small")
                            variant: crumbHover.hovered ? "common" : "transparent"
                            HoverHandler {
                                id: crumbHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: root.browse(crumb.modelData.path)
                            }
                            AiText {
                                id: crumbText
                                role: "caption"
                                anchors.centerIn: parent
                                text: crumb.modelData.label
                                font.weight: crumb.index === FolderPath.crumbs(root.split.dir, root.home).length - 1 ? Font.DemiBold : Font.Normal
                                color: Type.secondary
                            }
                        }
                    }
                }
            }
        }

        AiText {
            id: errorText
            objectName: "folderError"
            role: "caption"
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.Wrap
            color: Type.danger
        }
        AiText {
            role: "caption"
            Layout.fillWidth: true
            visible: browser.error.length > 0
            text: I18n.t("ai.folder.backend_missing")
            wrapMode: Text.Wrap
        }

        ListView {
            id: list
            objectName: "folderList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Space.hairline
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            delegate: FolderRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                row: modelData
                current: index === root.selected
                onHovered: root.selected = index
                onBrowse: root.browse(modelData.path)
                onChoose: root.choose(modelData.path)
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            AiText {
                role: "caption"
                anchors.centerIn: parent
                width: parent.width - 32
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.browsing ? (browser.loading ? I18n.t("ai.folder.loading") : (root.listing && root.listing.error ? root.listing.error : I18n.t("ai.folder.empty"))) : (browser.reposLoading ? I18n.t("ai.folder.scanning") : I18n.t("ai.folder.no_match"))
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s
            Chip {
                objectName: "folderSystemDialog"
                icon: Icons.appWindow
                text: I18n.t("ai.folder.system_dialog")
                quiet: true
                maxLabelWidth: 120
                onClicked: root.systemDialog()
            }
            Item {
                Layout.fillWidth: true
            }
            Chip {
                objectName: "folderChoose"
                Layout.maximumWidth: root.width * 0.6
                icon: Icons.folderOpen
                text: root.target ? I18n.t("ai.folder.use").arg(root.target === root.home ? "~" : FolderPath.baseName(root.target)) : I18n.t("ai.folder.use_none")
                maxLabelWidth: Math.max(60, root.width * 0.6 - 40)
                active: root.target !== ""
                enabled: root.target !== ""
                onClicked: root.choose(root.target)
            }
        }
    }
}
