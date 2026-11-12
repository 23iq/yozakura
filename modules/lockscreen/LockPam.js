.pragma library

// Which PAM stack the lock screen authenticates against.
//
// Default (lockscreen.pamService empty): the bundled config/pam/password.conf
// (pam_unix only), exactly as before. A plain service name opts into the
// system stack /etc/pam.d/<name> (sssd/LDAP, systemd-homed, fprintd, U2F),
// but only when that file exists; anything else keeps the bundled file, so
// a typo can never leave the lock screen without a working stack.

var SYSTEM_DIR = "/etc/pam.d";
var BUNDLED_CONFIG = "password.conf";

// A plain PAM service name: letters, digits, "-", "_", "." (no path
// separators, no leading dot or dash), at most 64 characters.
var NAME_RE = /^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}$/;

// The configured name, trimmed; "" when unset or not a plain service name.
function serviceName(value) {
    if (typeof value !== "string")
        return "";
    var name = value.trim();
    return NAME_RE.test(name) ? name : "";
}

// Path of the service file whose existence decides the stack; "" for none.
function servicePath(value) {
    var name = serviceName(value);
    return name ? SYSTEM_DIR + "/" + name : "";
}

// {configDirectory, config} for PamContext. `checkedPath` is the service
// file the last existence check looked at and `exists` its result; the
// system stack is used only when that check is about the current setting.
function target(value, checkedPath, exists, bundledDir) {
    var path = servicePath(value);
    if (path !== "" && exists === true && checkedPath === path)
        return {
            "configDirectory": SYSTEM_DIR,
            "config": serviceName(value),
            "system": true
        };
    return {
        "configDirectory": bundledDir,
        "config": BUNDLED_CONFIG,
        "system": false
    };
}
