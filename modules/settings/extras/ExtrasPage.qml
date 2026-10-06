pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.settings
import qs.modules.extras

// Settings > Apps & Extras: the optional-software catalog (CatalogHost:
// grid, notices, install bar) under the page header. Installs run in the
// backend queue; the page only selects and reports.
CatalogHost {
    id: page

    required property var category

    // SettingsShell reveal() hook (search jumps): one page, nothing to scroll to.
    function reveal(section, entry) {
    }

    mode: "settings"
    header: Component {
        PageHeader {
            category: page.category
        }
    }
}
