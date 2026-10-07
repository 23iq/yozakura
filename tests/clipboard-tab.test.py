"""ClipboardTab offscreen: history list, search, navigation, delete/alias, preview.

Loads the real tab (and every component it is split into) with the services
stubbed, then drives it through its public API (searchText, onDownPressed,
enterDeleteMode, ...) and inspects the rendered delegates, options menu and
preview/metadata texts.
"""
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from tabs_env import TabsEnv  # noqa: E402
from PySide6.QtCore import QCoreApplication  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402
from PySide6.QtNetwork import QNetworkProxy  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402

env = TabsEnv("clipboard-tab", tabs=["clipboard"], clip_items=[])
h = env.h
# Favicons point at the network: send every request to a dead local proxy.
QNetworkProxy.setApplicationProxy(QNetworkProxy(QNetworkProxy.HttpProxy, "127.0.0.1", 9))
# Keys instead of English strings, and a Visibilities that records the module.
h.module("qs.modules.services", {
    "Visibilities": "pragma Singleton\nimport QtQuick\nQtObject { property var active: null; "
                    "function setActiveModule(m) { active = m; } }",
    "I18n": "pragma Singleton\nimport QtQuick\nQtObject { function t(k, a) { return a === undefined ? k : k + ':' + a; } }",
})
env._qmldir(env.root / "qs/modules/widgets/dashboard/clipboard", "qs.modules.widgets.dashboard.clipboard")
win = env.load("""import QtQuick
import QtQuick.Window
import qs.modules.widgets.dashboard.clipboard
Window {
    width: 900; height: 400; visible: true
    ClipboardTab { objectName: "tab"; anchors.fill: parent; leftPanelWidth: 400; prefixIcon: "P" }
}""")
tab = h.find(win, "tab")
svc_expr = "ClipboardService"
ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + (" " + str(detail) if detail != "" else ""))


def pump(ms=60):
    end = time.time() + ms / 1000
    while time.time() < end:
        QCoreApplication.processEvents()
        time.sleep(0.005)


inner = tab.children()[0]  # created in ClipboardTab.qml: its context sees the services


def ev(expr):
    e = QQmlExpression(h.engine.contextForObject(inner), tab, expr)
    r = e.evaluate()
    assert not e.hasError(), e.error().toString()
    return r[0] if isinstance(r, tuple) else r


def calls():
    return json.loads(ev(f"JSON.stringify({svc_expr}.calls)"))


def reset_calls():
    ev(f"{svc_expr}.calls = []")


def walk(item=None):
    """Every QObject below the tab: QObject children and visual child items
    (ListView delegates have no QObject parent)."""
    seen, stack = [], [item or tab]
    while stack:
        o = stack.pop()
        if any(o is x for x in seen):
            continue
        seen.append(o)
        stack.extend(o.children())
        if isinstance(o, QQuickItem):
            stack.extend(o.childItems())
    return seen


def texts():
    out = []
    for o in walk():
        mo = o.metaObject()
        if mo.indexOfProperty("text") >= 0 and mo.indexOfProperty("visible") >= 0:
            t = o.property("text")
            if isinstance(t, str) and t and o.property("visible"):
                out.append(t)
    return out


def delegates():
    return [o for o in walk()
            if all(o.metaObject().indexOfProperty(p) >= 0 for p in ("isInDeleteMode", "displayText", "isDraggingForReorder"))]


pump()
ev(f"{svc_expr}.autoComplete = false")
check("history requested on load", ["list", None, None] in calls())
now_ms = int(time.time() * 1000)
items = [
    {"id": "1", "preview": "hello\nworld", "mime": "text/plain", "size": 11, "createdAt": now_ms - 5 * 60000,
     "hash": "0123456789abcdef0123", "pinned": True},
    {"id": "2", "preview": "https://example.invalid/page", "mime": "text/plain", "size": 1536,
     "createdAt": now_ms - 3 * 3600000, "alias": "my link"},
    {"id": "3", "preview": "[[ image ]]", "mime": "image/png", "isImage": True, "size": 3 * 1024 * 1024},
]
ev(f"{svc_expr}.items = {json.dumps(items)}; {svc_expr}.listCompleted()")
pump()
check("all items listed", ev("allItems.length") == 3)
check("nothing selected initially", ev("selectedIndex") == -1)
ds = delegates()
check("one delegate per item", len(ds) == 3, len(ds))
check("newlines flattened in the row text", "hello world" in [d.property("displayText") for d in ds])
check("alias shown instead of the content", "my link" in [d.property("displayText") for d in ds])
check("image row is labelled Image", "Image" in [d.property("displayText") for d in ds])
t = texts()
check("relative times", "clipboard.min_ago:5" in t and "clipboard.hours_ago:3" in t, [x for x in t if "ago" in x])
check("empty-state placeholder hidden", "clipboard.no_history" not in t)

# Search matches content and alias, selects the first hit.
ev("searchText = 'LINK'")
pump()
check("search matches the alias", ev("allItems.length") == 1 and ev("allItems[0].id") == "2")
check("first hit selected while searching", ev("selectedIndex") == 0)
ev("searchText = 'zzz'")
pump()
check("no hits", ev("allItems.length") == 0)
ev("clearSearch()")
pump()
check("clear search restores the list", ev("allItems.length") == 3 and ev("selectedIndex") == -1)

# Keyboard navigation through the public handlers.
reset_calls()
ev("onDownPressed()")
pump()
check("down selects the first row", ev("selectedIndex") == 0)
check("selecting text loads its full content", ["getFullContent", "1", None] in calls(), calls())
ev("onDownPressed(); onDownPressed()")
pump()
check("down moves to the last row", ev("selectedIndex") == 2)
check("selecting an undecoded image decodes it", ["decodeToDataUrl", "3", "image/png"] in calls())
check("metadata shows MIME and size", "image/png" in texts() and "3.0 MB" in texts(), [x for x in texts() if "MB" in x])
ev("onDownPressed()")
check("down stops at the end", ev("selectedIndex") == 2)
ev("onUpPressed(); onUpPressed()")
check("up moves back", ev("selectedIndex") == 0)
ev("onUpPressed()")
check("up from the first row returns to search", ev("selectedIndex") == -1 and not ev("hasNavigatedFromSearch"))

# Preview of a URL item: full content -> link preview request -> embed.
ev("onDownPressed(); onDownPressed()")
pump()
reset_calls()
ev(f"{svc_expr}.fullContentRetrieved('2', 'https://example.invalid/page')")
pump()
check("full content of a URL fetches a link preview",
      ["fetchLinkPreview", "https://example.invalid/page", "2"] in calls(), calls())
check("loading indicator while fetching", ev("loadingLinkPreview") and "clipboard.loading_preview" in texts())
ev(f"""{svc_expr}.linkPreviewCache = {{ "https://example.invalid/page": {{ title: "Example title",
    description: "Example description", site_name: "Example" }} }};
    {svc_expr}.linkPreviewFetched("https://example.invalid/page", {{}}, "2")""")
pump()
t = texts()
check("embed shows title/description/site", all(x in t for x in ("Example title", "Example description", "Example")), "")
check("loading indicator gone", not ev("loadingLinkPreview") and "clipboard.loading_preview" not in t)
check("size in KB", "1.5 KB" in t)
check("full date and short checksum", any(re.fullmatch(r"calendar\.month\.\w+ \d+, \d{4} \d+:\d\d:\d\d [AP]M", x) for x in t)
      and "N/A" in t, [x for x in t if "calendar" in x])

# Options menu (expanded row).
ev("expandedItemIndex = selectedIndex")
pump(1500)
t = texts()
check("options menu lists actions", all(x in t for x in ("common.copy", "common.open", "clipboard.pin", "clipboard.alias",
                                                        "common.delete")), [x for x in t if x.startswith(("common", "clipboard."))])
expanded = [d for d in delegates() if d.property("isExpanded")]
check("expanded row grows by the options list", len(expanded) == 1 and expanded[0].property("height") == 48 + 4 + 180 + 8,
      [d.property("height") for d in expanded])
ev("selectedIndex = 0")
check("changing selection collapses the menu", ev("expandedItemIndex") == -1)

# Search field keys (SearchInput signals).
search = next(o for o in walk() if o.metaObject().indexOfSignal("shiftAccepted()") >= 0)
reset_calls()
ev("selectedIndex = 1")
search.shiftAccepted.emit()
check("shift+enter opens the options menu", ev("expandedItemIndex") == 1 and ev("keyboardNavigation"))
search.downPressed.emit()
search.downPressed.emit()
check("down walks the options", ev("selectedOptionIndex") == 2)
for _ in range(5):
    search.downPressed.emit()
check("down stops at the last option (5 for a URL)", ev("selectedOptionIndex") == 4)
search.upPressed.emit()
search.upPressed.emit()
search.accepted.emit()
check("enter runs the selected option (pin)", ["togglePin", "2", None] in calls() and ev("expandedItemIndex") == -1, calls())
search.ctrlUpPressed.emit()
check("ctrl+up moves the item up", ["moveItemUp", "2", None] in calls())
search.shiftAccepted.emit()
search.escapePressed.emit()
check("escape closes the menu first", ev("expandedItemIndex") == -1 and ev("Visibilities.active") is None)
search.accepted.emit()
check("enter copies and closes", ["copyItem", "2", "text/plain"] in calls() and ev("Visibilities.active") == "")
ev("Visibilities.active = null")

# Delete mode.
reset_calls()
ev("enterDeleteMode('1')")
pump()
d1 = [d for d in delegates() if d.property("isInDeleteMode")]
check("delete mode marks the row", len(d1) == 1 and d1[0].property("displayText") == 'Delete "hello world"?',
      [d.property("displayText") for d in d1])
ev("confirmDeleteItem()")
pump()
check("confirm deletes and refreshes", ["deleteItem", "1", None] in calls() and ["list", None, None] in calls())
check("delete mode left", not ev("deleteMode") and ev("selectedIndex") == -1)

# Alias mode.
reset_calls()
ev("selectedIndex = 1; enterAliasMode('2')")
pump()
check("alias mode prefills the current alias", ev("newAlias") == "my link")
ev("newAlias = 'renamed'; confirmAliasItem()")
check("alias saved", ["setAlias", "2", "renamed"] in calls())
ev("selectedIndex = 0; enterAliasMode('1'); newAlias = 'hello\\nworld'; confirmAliasItem()")
check("alias equal to the content clears it", ["setAlias", "1", ""] in calls(), calls())

# Copy + open.
reset_calls()
ev("copyToClipboard('3')")
check("copy passes the mime", ["copyItem", "3", "image/png"] in calls())
opened = []
tab.requestOpenItem.connect(lambda *a: opened.append(a[0]))
ev("openItem('2')")
check("openItem emits requestOpenItem", opened == ["2"])
ev(f"{svc_expr}.items = []; {svc_expr}.listCompleted()")
pump()
check("empty history shows the placeholder", "clipboard.no_history" in texts())

h.exit(0 if ok else 1)
