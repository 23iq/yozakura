.pragma library

// Which PAM stack the lock screen authenticates against.
//
// Default (lockscreen.pamService empty): the bundled config/pam/password.conf
// (pam_unix only), exactly as before. A plain service name opts into the
// system stack /etc/pam.d/<name> (sssd/LDAP, systemd-homed, fprintd, U2F),
// but only when that file is a usable password stack; anything else keeps
// the bundled file, so a typo can never leave the lock screen without a
// working stack and a passwordless stack can never unlock it.
//
// Refused (bundled config used, with a warning):
// - names ending in "-autologin" (gdm-autologin, sddm-autologin,
//   lightdm-autologin: display-manager stacks that let anyone in);
// - a service file with an `auth` line using pam_permit.so (every password
//   would unlock);
// - a service file that does not exist or cannot be read.
// Only direct `auth ... pam_permit.so` lines are seen: a stack that reaches
// pam_permit through `include` / `substack` / `@include` is not detected,
// which is why the setting's description says the service decides who can
// unlock.

var SYSTEM_DIR = "/etc/pam.d";
var BUNDLED_CONFIG = "password.conf";

// A plain PAM service name: letters, digits, "-", "_", "." (no path
// separators, no leading dot or dash), at most 64 characters.
var NAME_RE = /^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}$/;

// Display-manager autologin stacks: never a password check.
var AUTOLOGIN_RE = /-autologin$/i;

// An `auth` line (also "-auth") whose module is pam_permit.so, as a POSIX
// ERE for grep -E -i (PAM reads the type case-insensitively).
var PERMIT_ERE = "^[[:space:]]*-?auth[[:space:]].*pam_permit\\.so";

// The configured name, trimmed; "" when unset or not a plain service name.
function serviceName(value) {
    if (typeof value !== "string")
        return "";
    var name = value.trim();
    return NAME_RE.test(name) ? name : "";
}

// Why a plain service name is refused before its file is looked at
// ("autologin"); "" when its file may be checked.
function refusal(value) {
    var name = serviceName(value);
    return name && AUTOLOGIN_RE.test(name) ? "autologin" : "";
}

// Path of the service file whose check decides the stack; "" for none
// (unset, not a plain name, or refused by name).
function servicePath(value) {
    var name = serviceName(value);
    return name && !refusal(name) ? SYSTEM_DIR + "/" + name : "";
}

// argv of the check of a service file (data as argv, no shell). grep exits
// 0 when an auth line uses pam_permit.so, 1 when the file was read and has
// none, 2 when it is missing or unreadable (-s: no message).
function checkCommand(path) {
    return ["grep", "-Eiqs", "-e", PERMIT_ERE, "--", path];
}

// The verdict for an exit code of checkCommand: "usable", "permit" (refused:
// passwordless auth) or "unreadable" (missing, unreadable, check failed).
function checkResult(exitCode) {
    if (exitCode === 1)
        return "usable";
    if (exitCode === 0)
        return "permit";
    return "unreadable";
}

// A line for the log saying why the configured service is not used; ""
// when it is used or unset.
function warning(value, checkedPath, verdict) {
    if (typeof value !== "string" || value.trim() === "")
        return "";
    var name = serviceName(value);
    if (!name)
        return "lockscreen.pamService is not a plain PAM service name; using the bundled config";
    if (refusal(name) === "autologin")
        return "PAM service \"" + name + "\" is an autologin stack (no password check); refused, using the bundled config";
    var path = servicePath(name);
    if (checkedPath !== path)
        return "PAM service " + path + " not checked yet; using the bundled config";
    if (verdict === "permit")
        return "PAM service " + path + " has an auth line using pam_permit.so (any password would unlock); refused, using the bundled config";
    if (verdict !== "usable")
        return "PAM service " + path + " does not exist or cannot be read; using the bundled config";
    return "";
}

// {configDirectory, config, system} for PamContext. `checkedPath` is the
// service file the last check looked at and `verdict` its checkResult; the
// system stack is used only when that check is about the current setting
// and found a usable stack.
function target(value, checkedPath, verdict, bundledDir) {
    var path = servicePath(value);
    if (path !== "" && verdict === "usable" && checkedPath === path)
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
