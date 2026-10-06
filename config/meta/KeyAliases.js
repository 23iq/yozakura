.pragma library

// Renamed or moved config keys. Each alias copies the user's stored value
// from `from` to `to` ("<domain>.<path>", the domain is the config file)
// once, on the first load of the shell, then removes `from`:
//   {from: "bar.activities", to: "notch.activities"}
//   {from: "theme.terminalOpacity", to: "glass.surfaces.terminal.amount",
//    transform: function (v) { return v; }}
// An existing `to` value is never overwritten. The `to` key must exist in
// config/defaults; the `from` key must not any more (the validator drops
// keys without a default). Run by ConfigValidator.migrateAliases through
// config/AliasGate.qml; tests in tests/key-aliases.test.cjs.

var aliases = [];

// Config domains (file names) an alias reads or writes.
function domains(list) {
    var out = [];
    (list || aliases).forEach(function (a) {
        [a.from, a.to].forEach(function (key) {
            var d = String(key).split(".")[0];
            if (out.indexOf(d) === -1)
                out.push(d);
        });
    });
    return out;
}
