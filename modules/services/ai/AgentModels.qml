import QtQuick
import qs.modules.services

// Runtime model options belong to an engine and project, not the selected view.
QtObject {
    id: root
    property var catalogs: ({})

    function key(agent, cwd) {
        return JSON.stringify([agent, cwd || ""]);
    }

    function get(agent, cwd) {
        return catalogs[key(agent, cwd)] || {
            models: [],
            manualModel: false,
            loading: false
        };
    }

    function refresh(agent, cwd) {
        const id = key(agent, cwd);
        if (get(agent, cwd).loading)
            return;
        catalogs = Object.assign({}, catalogs, {
            [id]: Object.assign({}, get(agent, cwd), {
                loading: true,
                error: ""
            })
        });
        BackendService.call("agents.models", {
            agent: agent,
            cwd: cwd || ""
        }, (res, err) => {
            catalogs = Object.assign({}, catalogs, {
                [id]: Object.assign({
                    models: [],
                    manualModel: false
                }, res || {}, {
                    loading: false,
                    error: err ? String(err) : (res?.error || "")
                })
            });
        });
    }
}
