#!/usr/bin/env bash
# Installs matugen (the palette generator) where the distribution has no
# package: the upstream release binary on x86_64, otherwise `cargo install`.
# Goes to /usr/local/bin (through sudo) so the compositor's session PATH
# finds it. Called by install.sh; safe to re-run.
#
#   scripts/deps/matugen.sh [--force]
set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/brand.sh"

# Keep in step with the Arch/Fedora packages: the templates use its syntax.
MATUGEN_VERSION="$(brand_env MATUGEN_VERSION 4.2.0)"
DEST="/usr/local/bin/matugen"

if [[ "${1:-}" != --force ]] && [[ "$(matugen --version 2>/dev/null || true)" == *"$MATUGEN_VERSION"* ]]; then
  echo "matugen $MATUGEN_VERSION is installed"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ "$(uname -m)" == x86_64 ]]; then
  url="https://github.com/InioX/matugen/releases/download/v$MATUGEN_VERSION/matugen-$MATUGEN_VERSION-x86_64.tar.gz"
  echo "== downloading $url"
  curl -fsSL "$url" -o "$tmp/matugen.tar.gz"
  tar -xzf "$tmp/matugen.tar.gz" -C "$tmp"
  bin="$(find "$tmp" -type f -name matugen -perm -u+x | head -n1)"
else
  command -v cargo >/dev/null 2>&1 || {
    echo "no matugen release binary for $(uname -m) and cargo is not installed (install rust/cargo, then re-run)" >&2
    exit 1
  }
  echo "== cargo install matugen $MATUGEN_VERSION"
  cargo install --locked --root "$tmp" --version "$MATUGEN_VERSION" matugen
  bin="$tmp/bin/matugen"
fi
[[ -n "$bin" && -x "$bin" ]] || {
  echo "the matugen archive has no binary" >&2
  exit 1
}
sudo install -D -m 755 "$bin" "$DEST"
"$DEST" --version
