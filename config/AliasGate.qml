import QtQuick
import "ConfigValidator.js" as ConfigValidator
import "meta/KeyAliases.js" as KeyAliases

// Key-alias migration on the first load (config/meta/KeyAliases.js). An
// alias can move a value between config files, which load independently;
// so the first validation of every file an alias touches waits here until
// all of them were read (or reported missing), the aliases run over their
// raw contents, then each validates (and writes back) its migrated object.
// Files no alias touches validate at once; with no aliases nothing waits.
// A file that never reports in releases the others after `timeout` ms.
QtObject {
    id: gate

    property var aliases: KeyAliases.aliases
    readonly property var domains: KeyAliases.domains(aliases)
    property int timeout: 3000
    property bool done: domains.length === 0
    // name -> ConfigFile (read) or null (missing file)
    property var arrived: ({})

    property Timer releaseTimer: Timer {
        interval: gate.timeout
        onTriggered: gate.flush()
    }

    // Takes over `file`'s first validation; false when it is not gated.
    function hold(file) {
        if (done || domains.indexOf(file.name) === -1)
            return false;
        arrived[file.name] = file;
        releaseTimer.start();
        check();
        return true;
    }

    // A gated file is missing: it has nothing to migrate.
    function skip(name) {
        if (done || domains.indexOf(name) === -1)
            return;
        if (!(name in arrived))
            arrived[name] = null;
        releaseTimer.start();
        check();
    }

    function check() {
        for (let i = 0; i < domains.length; i++) {
            if (!(domains[i] in arrived))
                return;
        }
        flush();
    }

    function flush() {
        if (done)
            return;
        done = true;
        releaseTimer.stop();
        const raws = {};
        for (const name in arrived) {
            raws[name] = null;
            const f = arrived[name];
            if (!f)
                continue;
            try {
                raws[name] = JSON.parse(f.text());
            } catch (e) {
                // malformed: ConfigFile.validate backs it up
            }
        }
        const changed = ConfigValidator.migrateAliases(raws, aliases);
        if (changed.length > 0)
            console.log("Config key aliases migrated in: " + changed.join(", "));
        for (const name in arrived) {
            const f = arrived[name];
            if (f)
                f.validate(() => {
                    f.ready = true;
                }, raws[name] || undefined);
        }
    }
}
