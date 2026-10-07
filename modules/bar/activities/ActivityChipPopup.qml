import QtQuick
import qs.config
import qs.modules.components
import qs.modules.components.kit
import qs.modules.widgets.defaultview.panels
import "../../widgets/defaultview/panels/NotchPanels.js" as NotchPanels

// Detail popup of a bar activity chip: the notch's own panel for it
// (TransfersPanel, TimerPanel, PrivacyPanel... from NotchPanels.js) inside
// a BarPopup anchored to the chip, so it opens away from the bar on every
// edge. Opened by hover it takes no focus grab (the bar keeps seeing the
// pointer); pinned by a click it grabs like any bar popup.
BarPopup {
    id: popup

    // NotchPanels.js id shown ("" keeps the last one while closing)
    property string panelId: ""
    property string screenName: ""
    property bool pinned: false
    readonly property bool hovered: contentHover.hovered
    readonly property var entry: NotchPanels.byId(popup.panelId)
    readonly property NotchPanel panel: loader.item as NotchPanel

    objectName: "activityChipPopup"
    groupId: "activityChips"
    claimFocus: popup.pinned
    popupPadding: 0
    contentWidth: popup.entry ? NotchPanels.widthFor(popup.entry.id, Config.notch.expandedMediaWidth) : 320
    contentHeight: popup.panel ? Math.max(1, popup.panel.implicitHeight + popup.titleInset) : 1
    // Panels keep a small gap above their title (they sit under the notch
    // header there); a popup gives the title the surface padding instead
    readonly property real titleInset: popup.panel ? Math.max(0, popup.panel.padding - popup.panel.topPadding) : 0

    Item {
        anchors.fill: parent

        HoverHandler {
            id: contentHover
        }

        Loader {
            id: loader
            y: popup.titleInset
            width: parent.width
            height: popup.panel ? popup.panel.implicitHeight : 0
            active: popup.entry !== null
            source: popup.entry ? Qt.resolvedUrl("../../widgets/defaultview/panels/" + popup.entry.url) : ""
            onLoaded: {
                const p = loader.item as NotchPanel;
                if (!p)
                    return;
                p.screenName = Qt.binding(() => popup.screenName);
                p.revealed = Qt.binding(() => popup.isOpen);
                p.maxRows = popup.entry ? popup.entry.maxRows || 0 : 0;
                p.closeRequested.connect(popup.close);
            }
        }
    }
}
