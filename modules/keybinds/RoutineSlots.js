.pragma library

// One unassigned "Not set" row per saved routine that no bind runs yet
// (action utilities.routine {routine: id}), next to the catalog slots of
// BindModel.slotRows. KeybindsStore.claim turns a clicked one into a
// custom bind named after the routine. Tested in tests/routines.test.cjs.

var ACTION = "utilities.routine";

function _boundIds(rows) {
    var used = {};
    (rows || []).forEach(function (r) {
        (r.actions || []).forEach(function (a) {
            if (a && a.id === ACTION && a.args && a.args.routine)
                used[String(a.args.routine)] = true;
        });
    });
    return used;
}

function rows(existing, routines) {
    var used = _boundIds(existing);
    return (routines || []).filter(function (r) {
        return r && r.id && !used[r.id];
    }).map(function (r) {
        return {
            "uid": "slot:routine:" + r.id,
            "kind": "slot",
            "path": "",
            "index": -1,
            "keys": [{
                    "modifiers": [],
                    "key": ""
                }],
            "actions": [{
                    "id": ACTION,
                    "args": {
                        "routine": r.id
                    },
                    "layouts": []
                }],
            "enabled": true,
            "name": String(r.name || r.id),
            "group": "utilities",
            "routine": r.id
        };
    });
}

// Name of the routine an action runs ("" when it is not a routine action).
function routineOf(action, routines) {
    if (!action || action.id !== ACTION || !action.args)
        return "";
    var id = String(action.args.routine || "");
    var list = routines || [];
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return String(list[i].name || id);
    return id;
}
