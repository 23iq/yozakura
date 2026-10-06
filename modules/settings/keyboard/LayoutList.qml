pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.displays
import "../Ui.js" as Ui
import "../../services/KeyboardModel.js" as KeyboardModel

// The ordered layout list: variants, drag to reorder, remove, and the
// searchable picker that adds one. `layouts` is edited by the page.
KeyboardCard {
    id: root

    property var layouts: []
    property var catalog: null
    property bool picking: false
    property int activeIndex: 0
    property bool showIndicator: true

    signal changed(var layouts)
    signal indicatorToggled(bool value)

    icon: "translate"
    title: I18n.t("prefs.keyboard.layouts")
    subtitle: I18n.t("prefs.keyboard.layouts.desc")

    function pick(code) {
        picking = false;
        changed(KeyboardModel.addLayout(layouts, code, ""));
    }

    onPickingChanged: if (picking) {
        picker.focusSearch();
    }

    Column {
        id: list
        objectName: "layoutRows"
        width: parent.width

        Repeater {
            id: rows
            model: root.layouts

            delegate: LayoutRow {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                count: root.layouts.length
                code: entry.modelData.layout
                variant: entry.modelData.variant || ""
                description: KeyboardModel.layoutInfo(root.catalog, entry.modelData.layout)?.description ?? ""
                variantChoices: KeyboardModel.variantOptions(root.catalog, entry.modelData.layout, I18n.t("prefs.keyboard.variant_default"))
                active: entry.index === root.activeIndex && root.layouts.length > 1
                onMoveBy: delta => root.changed(KeyboardModel.moveLayout(root.layouts, entry.index, entry.index + delta))
                onVariantPicked: v => root.changed(KeyboardModel.setVariant(root.layouts, entry.index, v))
                onRemoveRequested: root.changed(KeyboardModel.removeLayout(root.layouts, entry.index))
            }
        }
    }

    // Add layout / picker
    Item {
        width: parent.width
        height: root.picking ? picker.implicitHeight + 76 : 68

        Rectangle {
            x: 20
            width: parent.width - 40
            height: 1
            color: Ui.alpha(Colors.outlineVariant, 0.45)
        }
        PillButton {
            objectName: "addLayoutButton"
            x: 20
            y: 17
            kind: root.picking ? "ghost" : "tonal"
            icon: root.picking ? "caretUp" : "plus"
            text: root.picking ? I18n.t("prefs.keyboard.close_picker") : I18n.t("prefs.keyboard.add")
            onClicked: {
                root.picking = !root.picking;
                if (root.picking)
                    KeyboardService.loadCatalog();
            }
        }
        LayoutPicker {
            id: picker
            objectName: "picker"
            visible: root.picking
            y: 68
            width: parent.width
            catalog: root.catalog
            skip: root.layouts.map(l => l.layout)
            onPicked: code => root.pick(code)
        }
    }

    DisplayRow {
        width: parent.width
        label: I18n.t("prefs.keyboard.show_indicator")
        hint: I18n.t("prefs.keyboard.show_indicator.desc")
        ToggleControl {
            objectName: "indicatorToggle"
            anchors.right: parent.right
            checked: root.showIndicator
            onToggled: v => root.indicatorToggled(v)
        }
    }
}
