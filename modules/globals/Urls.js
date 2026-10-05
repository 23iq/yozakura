.pragma library

// Links from untrusted text (chat markdown, preset/mod manifests) are opened
// only when they are plain http(s) URLs: file:, custom scheme handlers and
// the like could launch local programs.
function isWeb(url) {
    return typeof url === "string" && /^https?:\/\/[^\s\/?#][^\s]*$/i.test(url);
}
