import QtQuick
import qs.modules.services

// Data of the folder picker: `fs.list` of the browsed folder (cached per
// folder for the picker's lifetime) and `fs.repos` (git repositories under
// ~, cached by the backend). Both are asynchronous IPC calls; the picker
// renders whatever has arrived. `error` is set when the backend has no
// `fs` service (an older daemon): typing a path still works.
QtObject {
    id: root
    property string dir: ""
    property var cache: ({})
    readonly property var listing: dir ? (cache[dir] || null) : null
    readonly property bool loading: dir !== "" && listing === null
    property var repos: []
    property bool reposLoading: false
    property bool reposLoaded: false
    property string error: ""

    function list(path) {
        dir = path || "";
        if (!dir || cache[dir])
            return;
        const asked = dir;
        BackendService.call("fs.list", {
            "dir": asked
        }, (res, err) => {
            if (err) {
                root.error = String(err.message || err);
                root._store(asked, {
                    "dir": asked,
                    "entries": [],
                    "error": root.error
                });
                return;
            }
            root._store(asked, res || {
                "dir": asked,
                "entries": []
            });
        });
    }
    function _store(path, value) {
        const next = Object.assign({}, cache);
        next[path] = value;
        cache = next;
    }

    function loadRepos(refresh) {
        if (reposLoading || (reposLoaded && !refresh))
            return;
        reposLoading = true;
        BackendService.call("fs.repos", {
            "refresh": !!refresh
        }, (res, err) => {
            root.reposLoading = false;
            root.reposLoaded = true;
            if (err)
                root.error = String(err.message || err);
            else
                root.repos = (res && res.repos) || [];
        });
    }

    // Forget listings (the picker reopened: folders may have changed).
    function reset() {
        cache = ({});
        error = "";
    }
}
