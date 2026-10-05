import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "clipboard_utils.js" as ClipboardUtils
import "ClipboardView.js" as ClipboardView

// State and actions of the clipboard tab (history, search, selection,
// delete/alias modes, options menu, preview loading). ClipboardTab.qml lays
// out the view on top of it; the Clipboard*.qml components bind to it.
Item {
    id: root
    focus: true

    // Set by the view: the history ListView, and a request to focus search.
    property ListView listView: null
    signal focusSearchRequested

    // Prefix support
    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var allItems: []
    property bool hasNavigatedFromSearch: false

    ListModel {
        id: itemsModel
    }
    // {itemId, itemData} rows of the list, synced from allItems
    property alias historyModel: itemsModel
    property bool clearButtonFocused: false
    property bool clearButtonConfirmState: false
    property bool anyItemDragging: false

    // Delete mode state
    property bool deleteMode: false
    property string itemToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0

    // Alias mode state
    property bool aliasMode: false
    property string itemToAlias: ""
    property string newAlias: ""
    property int aliasSelectedIndex: -1
    property int aliasButtonIndex: 0

    // Item to select again after pin/alias/reorder refreshes the list
    property string pendingItemIdToSelect: ""

    // Options menu state (expandable row)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    property int previewImageSize: 200

    // Item whose full content / link preview is loaded; content is only
    // trusted while it matches the selection.
    property string currentItemId: ""
    property string currentFullContent: ""
    property bool loadingLinkPreview: false
    property int linkPreviewCacheRevision: 0  // Bumped on cache updates (rebinds favicons)

    readonly property var currentSelectedItem: {
        if (selectedIndex < 0 || selectedIndex >= allItems.length)
            return null;
        return allItems[selectedIndex];
    }

    readonly property bool contentMatchesSelection: {
        if (!currentSelectedItem)
            return false;
        return currentItemId === currentSelectedItem.id;
    }

    // Full content of the selection once loaded, its preview until then.
    readonly property string safeCurrentContent: {
        if (!currentSelectedItem)
            return "";
        if (contentMatchesSelection && currentFullContent)
            return currentFullContent;
        return currentSelectedItem.preview || "";
    }

    // Cached link preview of the selection (text items whose content is a URL).
    property var linkPreviewData: {
        var _rev = linkPreviewCacheRevision;
        if (!currentSelectedItem)
            return null;
        if (currentSelectedItem.isImage || currentSelectedItem.isFile)
            return null;

        var urlToLookup = "";
        if (contentMatchesSelection && currentFullContent) {
            urlToLookup = currentFullContent.trim();
        } else {
            // The preview only counts when it is not truncated ("...")
            var preview = currentSelectedItem.preview || "";
            if (preview && !preview.endsWith("...")) {
                urlToLookup = preview.trim();
            }
        }

        if (!urlToLookup || !ClipboardUtils.isUrl(urlToLookup))
            return null;

        return ClipboardService.linkPreviewCache[urlToLookup] || null;
    }

    implicitWidth: 400
    implicitHeight: 392

    // Refresh the list when the tab becomes visible
    onVisibleChanged: {
        if (visible) {
            ClipboardService.list();
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && root.listView.count > 0) {
            root.listView.positionViewAtIndex(0, ListView.Beginning);
        }

        // Selecting another row closes the options menu
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }
    }

    onSearchTextChanged: {
        updateFilteredItems();
    }

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= itemsModel.count)
            return;
        const list = root.listView;
        // Rows above are collapsed
        const itemY = index * ClipboardView.ROW_HEIGHT;
        const expandedHeight = ClipboardView.rowHeight(itemsModel.get(index).itemData, true);
        const maxContentY = Math.max(0, list.contentHeight - list.height);
        const y = ClipboardView.scrollToShow(itemY, expandedHeight, list.contentY, list.height, maxContentY);
        if (y !== -1)
            list.contentY = y;
    }

    // Helpers kept for callers (requestOpenItem passes getFilePathFromUri).
    function getFilePathFromUri(content) {
        return ClipboardView.filePathFromUri(content);
    }

    function isImageFile(filePath) {
        return ClipboardView.isImagePath(filePath);
    }

    // Row icon: "link" marks URLs (favicon), else image/file/clip glyphs.
    function getIconForItem(item) {
        if (!item)
            return Icons.clip;
        if (!item.isImage && !item.isFile && ClipboardUtils.isUrl(item.preview || ""))
            return "link";
        if (item.isImage)
            return Icons.image;
        if (item.isFile)
            return Icons.file;
        return Icons.clip;
    }

    // Favicon of a URL item: the cached preview favicon, else Google's PNG
    // service (avoids Qt ICO decode warnings).
    function getFaviconUrl(item) {
        if (!item || item.isImage || item.isFile)
            return "";
        var content = item.preview || "";
        if (!ClipboardUtils.isUrl(content))
            return "";
        var cachedData = ClipboardService.linkPreviewCache[content.trim()];
        if (cachedData && cachedData.favicon) {
            return cachedData.favicon;
        }
        return ClipboardUtils.getFaviconFallbackUrl(content);
    }

    // Fallback favicon: the site's /favicon.ico
    function getFaviconFallbackUrl(item) {
        if (!item || item.isImage || item.isFile)
            return "";
        return ClipboardUtils.getFaviconUrl(item.preview || "");
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        hasNavigatedFromSearch = false;
        clearButtonFocused = false;
        clearButtonConfirmState = false;
        root.focusSearchRequested();
        updateFilteredItems();
    }

    function resetClearButton() {
        clearButtonConfirmState = false;
    }

    function collapseOptions() {
        expandedItemIndex = -1;
        selectedOptionIndex = 0;
        keyboardNavigation = false;
    }

    // The selected item when no delete/alias mode is active (keyboard actions).
    function actionableItem() {
        if (deleteMode || aliasMode || selectedIndex < 0 || selectedIndex >= allItems.length)
            return null;
        return allItems[selectedIndex] || null;
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            cancelDeleteMode();
        }
        if (aliasMode) {
            cancelAliasMode();
        }
    }

    function enterDeleteMode(itemId) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        itemToDelete = itemId;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        itemToDelete = "";
        deleteButtonIndex = 0;
        root.focusSearchRequested();
        updateFilteredItems();
        selectedIndex = originalSelectedIndex;
        root.listView.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteItem() {
        ClipboardService.deleteItem(itemToDelete);

        deleteMode = false;
        itemToDelete = "";
        deleteButtonIndex = 0;
        originalSelectedIndex = -1;
        selectedIndex = -1;
        hasNavigatedFromSearch = false;

        refreshClipboardHistory();
        root.focusSearchRequested();
    }

    function enterAliasMode(itemId) {
        aliasSelectedIndex = selectedIndex;
        aliasMode = true;
        itemToAlias = itemId;

        const i = ClipboardView.indexOfId(allItems, itemId);
        if (i !== -1)
            newAlias = allItems[i].alias || allItems[i].preview;

        aliasButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelAliasMode() {
        aliasMode = false;
        itemToAlias = "";
        newAlias = "";
        aliasButtonIndex = 0;
        root.focusSearchRequested();
        updateFilteredItems();
        selectedIndex = aliasSelectedIndex;
        root.listView.currentIndex = aliasSelectedIndex;
        aliasSelectedIndex = -1;
    }

    function confirmAliasItem() {
        const i = ClipboardView.indexOfId(allItems, itemToAlias);
        const originalPreview = i !== -1 ? allItems[i].preview : "";

        // Select this item again after the refresh
        pendingItemIdToSelect = itemToAlias;

        // An alias equal to the content (or empty) clears it
        const alias = newAlias.trim();
        if (alias !== "" && alias !== originalPreview) {
            ClipboardService.setAlias(itemToAlias, alias);
        } else {
            ClipboardService.setAlias(itemToAlias, "");
        }

        aliasMode = false;
        itemToAlias = "";
        newAlias = "";
        aliasButtonIndex = 0;
        aliasSelectedIndex = -1;
        root.focusSearchRequested();
    }

    function clearClipboardHistory() {
        ClipboardService.clear();
        clearButtonConfirmState = false;
        clearButtonFocused = false;
        root.focusSearchRequested();
    }

    function focusSearchInput() {
        root.focusSearchRequested();
    }

    function selectRow(i) {
        selectedIndex = i;
        root.listView.currentIndex = i;
    }

    function updateFilteredItems() {
        // Keep the selected item selected across (double) updates
        var currentIdToKeep = "";
        if (selectedIndex >= 0 && selectedIndex < allItems.length) {
            currentIdToKeep = allItems[selectedIndex].id;
        }

        var newItems = ClipboardView.filterItems(ClipboardService.items, searchText);
        allItems = newItems;
        // Minimal model changes so delegates are not recreated
        ClipboardView.syncModel(itemsModel, newItems);

        // A pending item (after pin/alias/reorder) wins
        if (pendingItemIdToSelect !== "") {
            const pending = ClipboardView.indexOfId(newItems, pendingItemIdToSelect);
            pendingItemIdToSelect = "";
            if (pending !== -1) {
                selectRow(pending);
                return;
            }
        }

        if (currentIdToKeep !== "") {
            const kept = ClipboardView.indexOfId(newItems, currentIdToKeep);
            if (kept !== -1) {
                selectRow(kept);
                return;
            }
        }

        if (searchText.length > 0 && allItems.length > 0) {
            // Select the first hit unless the selection is still valid
            if (selectedIndex < 0 || selectedIndex >= allItems.length) {
                selectRow(0);
            }
        } else if (searchText.length === 0) {
            // Cleared search: reset unless the user navigated the list
            if (!hasNavigatedFromSearch || allItems.length === 0) {
                selectRow(-1);
            } else if (selectedIndex >= allItems.length) {
                selectRow(Math.max(0, allItems.length - 1));
            } else if (selectedIndex < 0 && allItems.length > 0) {
                selectRow(0);
            }
        }
    }

    function onDownPressed() {
        const count = root.listView.count;
        if (!root.hasNavigatedFromSearch) {
            root.hasNavigatedFromSearch = true;
            if (count > 0 && root.selectedIndex === -1) {
                selectRow(0);
            }
        } else if (count > 0 && root.selectedIndex >= 0 && root.selectedIndex < count - 1) {
            selectRow(root.selectedIndex + 1);
        }
    }

    function onUpPressed() {
        if (root.selectedIndex > 0) {
            selectRow(root.selectedIndex - 1);
        } else if (root.selectedIndex === 0) {
            root.selectedIndex = -1;
            root.hasNavigatedFromSearch = false;
            root.listView.currentIndex = -1;
        }
    }

    function refreshClipboardHistory() {
        ClipboardService.list();
    }

    function copyToClipboard(itemId) {
        // The daemon copies from the encrypted store (text, file URI or
        // image blob) with the right MIME type.
        const i = ClipboardView.indexOfId(root.allItems, itemId);
        if (i !== -1)
            ClipboardService.copyItem(itemId, root.allItems[i].mime);
    }

    signal requestOpenItem(string itemId, var items, string currentContent, var filePathGetter, var urlChecker)

    function openItem(itemId) {
        requestOpenItem(itemId, root.allItems, root.safeCurrentContent, getFilePathFromUri, ClipboardUtils.isUrl);
    }

    Connections {
        target: ClipboardService
        function onListCompleted() {
            root.updateFilteredItems();
        }
    }

    // Load what the preview needs when the selection changes
    Connections {
        target: root
        function onSelectedIndexChanged() {
            // Forget the previous item's content so linkPreviewData cannot
            // show stale data
            root.currentItemId = "";
            root.currentFullContent = "";
            root.loadingLinkPreview = false;

            if (root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                let item = root.allItems[root.selectedIndex];
                if (item.isImage && !ClipboardService.getImageData(item.id)) {
                    ClipboardService.decodeToDataUrl(item.id, item.mime);
                } else if (item.isImage) {
                    // Materialize the blob for drag-and-drop / open
                    ClipboardService.requestImagePath(item.id);
                } else {
                    ClipboardService.getFullContent(item.id);
                }
            }
        }
    }

    Connections {
        target: ClipboardService
        function onFullContentRetrieved(itemId, content) {
            // Only for the currently selected item
            if (root.currentSelectedItem && root.currentSelectedItem.id === itemId) {
                root.currentItemId = itemId;
                root.currentFullContent = content;

                if (ClipboardUtils.isUrl(content)) {
                    root.loadingLinkPreview = true;
                    ClipboardService.fetchLinkPreview(content.trim(), itemId);
                }
            }
        }

        function onLinkPreviewFetched(url, metadata, requestItemId) {
            // Rebind linkPreviewData and favicons
            root.linkPreviewCacheRevision++;

            if (root.currentSelectedItem && root.currentSelectedItem.id === requestItemId) {
                root.loadingLinkPreview = false;
            }
        }
    }
}
