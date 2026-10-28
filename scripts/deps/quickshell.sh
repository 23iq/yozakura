#!/usr/bin/env bash
# Builds Quickshell from source where the distribution has no package
# (Debian/Ubuntu, openSUSE) and installs it into /usr/local. Called by
# install.sh; safe to re-run (an installed qs of the pinned version is kept).
#
#   scripts/deps/quickshell.sh FAMILY [--force]
#
# FAMILY  suse | debian | fedora | arch: which build dependencies to install
#         (through sudo and the distribution's package manager).
# --force rebuild even when the pinned version is installed, and let the
#         package manager replace packages that conflict with the build
#         dependencies (zypper --force-resolution, dnf --allowerasing).
#
# Quickshell uses private Qt APIs: after a Qt upgrade it must be rebuilt
# (re-run this script, or install.sh --force).
set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/brand.sh"

# v0.3.2: the first tag that builds against Qt 6.12 (openSUSE Tumbleweed).
QS_VERSION="$(brand_env QUICKSHELL_VERSION v0.3.2)"
QS_REPOS=("https://git.outfoxxed.me/quickshell/quickshell.git" "https://github.com/quickshell-mirror/quickshell.git")
PREFIX="/usr/local"
ROOT="$BRAND_CACHE_DIR/build/quickshell"

family="${1:-}"
force=""
[[ "${2:-}" == --force ]] && force=1

build_deps() {
  case "$family" in
  debian)
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git cmake ninja-build pkg-config g++ spirv-tools \
      qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
      qt6-shadertools-dev qt6-wayland-dev qt6-wayland-private-dev qt6-svg-dev \
      libwayland-dev wayland-protocols libcli11-dev libjemalloc-dev libpipewire-0.3-dev \
      libpam0g-dev libpolkit-agent-1-dev libglib2.0-dev libdrm-dev libgbm-dev libegl-dev libgl-dev libvulkan-dev libxcb1-dev
    ;;
  suse)
    sudo zypper --non-interactive install --no-recommends ${force:+--force-resolution} \
      git cmake ninja pkgconf gcc-c++ spirv-tools \
      qt6-base-private-devel qt6-declarative-private-devel qt6-shadertools-devel \
      qt6-wayland-private-devel qt6-svg-devel \
      wayland-devel wayland-protocols-devel cli11-devel jemalloc-devel pipewire-devel \
      pam-devel polkit-devel glib2-devel libdrm-devel libgbm-devel Mesa-libEGL-devel Mesa-libGL-devel vulkan-headers libxcb-devel
    ;;
  fedora)
    sudo dnf install -y ${force:+--allowerasing} git cmake ninja-build pkgconf-pkg-config gcc-c++ spirv-tools \
      qt6-qtbase-private-devel qt6-qtdeclarative-private-devel qt6-qtshadertools-devel \
      qt6-qtwayland-private-devel qt6-qtsvg-devel \
      wayland-devel wayland-protocols-devel cli11-devel jemalloc-devel pipewire-devel \
      pam-devel polkit-devel glib2-devel libdrm-devel mesa-libgbm-devel mesa-libEGL-devel libglvnd-devel vulkan-headers libxcb-devel
    ;;
  arch)
    sudo pacman -S --needed --noconfirm git cmake ninja pkgconf gcc spirv-tools \
      qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-svg \
      wayland wayland-protocols cli11 jemalloc libpipewire pam polkit glib2 libdrm mesa vulkan-headers libxcb
    ;;
  *)
    echo "unknown distribution family '$family' (want suse, debian, fedora or arch)" >&2
    exit 2
    ;;
  esac
}

installed_version() {
  local v
  v="$(qs --version 2>/dev/null | head -n1 || true)"
  [[ "$v" == *"${QS_VERSION#v}"* ]]
}

if [[ -z "$force" ]] && installed_version; then
  echo "quickshell $QS_VERSION is installed"
  exit 0
fi

echo "== build dependencies ($family)"
build_deps

# Older releases (Debian 13) ship wayland-protocols without the staging
# protocols Quickshell uses (ext-background-effect, 1.46): fetch a newer
# release into the build directory and point pkg-config at it.
WP_MIN="1.46"
WP_VERSION="$(brand_env WAYLAND_PROTOCOLS_VERSION 1.49)"
newer_protocols() {
  local dir="$ROOT/wayland-protocols"
  echo "== wayland-protocols $(pkg-config --modversion wayland-protocols 2>/dev/null || echo none) < $WP_MIN; using $WP_VERSION"
  if [[ ! -d "$dir/staging" ]]; then
    rm -rf "$dir"
    git clone --depth 1 --branch "$WP_VERSION" https://gitlab.freedesktop.org/wayland/wayland-protocols.git "$dir"
  fi
  mkdir -p "$ROOT/pkgconfig"
  printf 'pkgdatadir=%s\n\nName: Wayland Protocols\nDescription: Wayland protocol files\nVersion: %s\n' \
    "$dir" "$WP_VERSION" >"$ROOT/pkgconfig/wayland-protocols.pc"
  export PKG_CONFIG_PATH="$ROOT/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
}
mkdir -p "$ROOT"
pkg-config --atleast-version="$WP_MIN" wayland-protocols 2>/dev/null || newer_protocols

# build REF: clone REF (a tag, or master) and build it.
build() {
  local ref="$1" src="$ROOT/src-$1" repo
  echo "== sources ($ref)"
  if [[ "$ref" == master || ! -d "$src/.git" ]]; then
    rm -rf "$src"
    for repo in "${QS_REPOS[@]}"; do
      git clone --depth 1 --branch "$ref" "$repo" "$src" && break
      rm -rf "$src"
    done
    [[ -d "$src/.git" ]] || {
      echo "could not clone quickshell $ref" >&2
      return 1
    }
  fi
  echo "== build ($ref)"
  rm -rf "$ROOT/build"
  # The crash handler needs cpptrace, which few distributions package.
  cmake -S "$src" -B "$ROOT/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DDISTRIBUTOR="$BRAND_DISPLAY_NAME installer (source build)" -DCRASH_HANDLER=OFF &&
    cmake --build "$ROOT/build"
}

# A Qt newer than the tag knows breaks the build: upstream master follows Qt.
if ! build "$QS_VERSION"; then
  echo "== $QS_VERSION does not build against this Qt; trying upstream master"
  build master
fi

echo "== install into $PREFIX"
sudo cmake --install "$ROOT/build"
qs --version
