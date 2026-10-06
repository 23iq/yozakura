import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "ExtrasModel.js" as ExtrasModel
import "ExtrasUi.js" as Ui

// Sticky bottom bar of the catalog: what is installing right now (mini
// progress, "+2 queued") and the "Install 3 apps · 1.3 GB" button for the
// grid selection. Slides in while there is a selection or a running job.
StyledRect {
    id: root

    property var selected: ({})
    signal clearRequested

    readonly property var ids: ExtrasModel.selectedIds(ExtrasService.catalog, ExtrasService.status, ExtrasService.progress, root.selected)
    readonly property string size: ExtrasModel.selectionSize(ExtrasService.catalog ? ExtrasService.catalog.entries : [], root.selectedMap)
    readonly property var selectedMap: {
        const m = {};
        root.ids.forEach(id => m[id] = true);
        return m;
    }
    readonly property var jobs: ExtrasService.activeJobs
    readonly property var current: root.jobs.length > 0 ? root.jobs[0] : null
    readonly property bool shown: root.ids.length > 0 || root.jobs.length > 0

    function jobName(p) {
        if (!p)
            return "";
        const names = (p.entries || []).map(id => ExtrasService.displayName(id));
        if (names.length > 0)
            return names.join(", ");
        return I18n.t("extras.ui.job." + p.kind);
    }

    function install() {
        if (root.ids.length > 0 && !ExtrasService.offline)
            ExtrasService.install(root.ids, false);
    }

    variant: "popup"
    // opaque: cards scroll underneath
    backgroundOpacity: 1
    radius: Styling.radius(8)
    enableShadow: true
    implicitHeight: 64
    visible: opacity > 0
    opacity: root.shown ? 1 : 0
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
        }
    }
    transform: Translate {
        y: root.shown ? 0 : 24
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // solid base under the (possibly translucent) popup fill: card text
    // scrolling underneath never shows through
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 1)
        z: -1
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
        z: 10
    }

    // Running job summary
    Item {
        id: summary
        x: 22
        width: parent.width - 22 - 18 - (actions.visible ? actions.width + 14 : 0)
        anchors.verticalCenter: parent.verticalCenter
        height: 34

        Column {
            visible: !!root.current
            width: parent.width
            spacing: 6

            Row {
                width: parent.width
                spacing: 8
                Text {
                    id: jobLabel
                    objectName: "jobLabel"
                    width: Math.min(implicitWidth, parent.width - (more.visible ? more.implicitWidth + 8 : 0))
                    elide: Text.ElideRight
                    text: {
                        const p = root.current;
                        if (!p)
                            return "";
                        const pct = p.state === "running" && p.percent >= 0 ? " · " + p.percent + "%" : "";
                        return I18n.t(p.state === "running" ? "extras.ui.jobs.running" : "extras.ui.jobs.waiting", root.jobName(p)) + pct;
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Text {
                    id: more
                    visible: root.jobs.length > 1
                    text: I18n.tn("extras.ui.jobs.more", root.jobs.length - 1)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                }
            }
            ProgressTrack {
                width: Math.min(parent.width, 320)
                percent: root.current && root.current.state === "running" ? root.current.percent : -1
            }
        }

        Row {
            visible: !root.current
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.packageBox
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(2)
                color: Colors.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tn("extras.ui.selected_n", root.ids.length)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        visible: root.ids.length > 0

        ExtrasButton {
            objectName: "clearButton"
            kind: "ghost"
            text: I18n.t("extras.ui.clear")
            onClicked: root.clearRequested()
        }
        ExtrasButton {
            objectName: "installButton"
            kind: "filled"
            icon: "downloadSimple"
            enabled: !ExtrasService.offline
            implicitHeight: 38
            text: I18n.tn("extras.ui.install_n", root.ids.length) + (root.size !== "" ? "  ·  " + root.size : "")
            onClicked: root.install()
        }
    }
}
