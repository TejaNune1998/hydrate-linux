#!/usr/bin/env bash
# Hydrate Installer
# Usage: ./install.sh [install|uninstall|purge|doctor]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
UNITS="$HOME/.config/systemd/user"
CDIR="$HOME/.config/hydrate"
SDIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydrate"
APPS="$HOME/.local/share/applications"
WDIR="$HOME/.config/waybar"
WMOD="$WDIR/hydrate.jsonc"
PID="hydrate"
PDIR="$HOME/.config/omarchy/plugins/$PID"
SHJ="$HOME/.config/omarchy/shell.json"

SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

detect_pm() {
  for p in pacman apt-get dnf yum zypper; do
    command -v "$p" >/dev/null 2>&1 && { echo "$p"; return; }
  done
  echo ""
}

pkg_for() {
  case "$1:$2" in
    notify-send:apt-get) echo libnotify-bin ;;
    notify-send:zypper)  echo libnotify-tools ;;
    notify-send:*)       echo libnotify ;;
    flock:*)             echo util-linux ;;
    pkill:pacman|pkill:dnf|pkill:yum) echo procps-ng ;;
    pkill:*)             echo procps ;;
    *)                   echo "$1" ;;
  esac
}

install_deps() {
  local pm cmd need=()
  pm=$(detect_pm)
  for cmd in notify-send jq flock pkill yad; do
    command -v "$cmd" >/dev/null 2>&1 || need+=("$(pkg_for "$cmd" "$pm")")
  done
  (( ${#need[@]} == 0 )) && return 0
  [[ -z "$pm" ]] && { echo "Install dependencies manually: ${need[*]}"; return 0; }
  echo "Installing dependencies: ${need[*]}"
  case "$pm" in
    pacman)  $SUDO pacman -S --needed --noconfirm "${need[@]}" ;;
    apt-get) $SUDO apt-get update -qq; $SUDO apt-get install -y "${need[@]}" ;;
    dnf|yum) $SUDO "$pm" install -y "${need[@]}" ;;
    zypper)  $SUDO zypper -n install "${need[@]}" ;;
  esac || true
}

clean_omarchy() {
  omarchy plugin disable "$PID" >/dev/null 2>&1 || true
  omarchy plugin disable local.hydrate >/dev/null 2>&1 || true
  rm -rf "$PDIR" "$HOME/.config/omarchy/plugins/local.hydrate"
  if [[ -f "$SHJ" ]] && command -v jq >/dev/null 2>&1; then
    local tmp; tmp=$(mktemp)
    if jq 'if .bar.layout then .bar.layout |= with_entries(.value |= (if type=="array" then map(select(.id != "hydrate" and .id != "local.hydrate")) else . end)) else . end' "$SHJ" > "$tmp" && jq -e . "$tmp" >/dev/null; then
      mv "$tmp" "$SHJ"
    else
      rm -f "$tmp"
    fi
  fi
}

do_install() {
  install_deps
  mkdir -p "$BIN" "$UNITS" "$CDIR" "$SDIR" "$APPS"
  touch "$SDIR/changed"

  # 1. Install CLI
  install -Dm755 "$ROOT_DIR/bin/hydrate" "$BIN/hydrate"

  # 2. Config defaults
  touch "$CDIR/config"
  for kv in GOAL_ML=2500 GLASS_ML=250 INTERVAL=45 START_HOUR=8 END_HOUR=22 PAUSED=0 ALERT_STYLE=auto; do
    grep -q "^${kv%%=*}=" "$CDIR/config" || echo "$kv" >> "$CDIR/config"
  done
  echo $(( $(date +%s) + 45 * 60 )) > "$SDIR/next_due"

  # 3. Systemd Timer
  install -Dm644 "$ROOT_DIR/systemd/hydrate.service" "$UNITS/hydrate.service"
  install -Dm644 "$ROOT_DIR/systemd/hydrate.timer" "$UNITS/hydrate.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now hydrate.timer 2>/dev/null || true

  # 4. Desktop Entry
  cat > "$APPS/hydrate.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hydrate
Comment=Water intake tracker
Exec=$BIN/hydrate panel
Icon=weather-showers
Categories=Utility;
EOF

  # 5. Omarchy Quickshell Plugin
  if command -v omarchy-shell >/dev/null 2>&1; then
    clean_omarchy
    mkdir -p "$PDIR"
    cp -r "$ROOT_DIR/omarchy/"* "$PDIR/"
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy plugin enable "$PID" right >/dev/null 2>&1 || true
    omarchy-restart-shell >/dev/null 2>&1 || omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
    echo "Omarchy: Hydrate bar widget installed and enabled."
  fi

  # 6. Waybar Module
  if command -v waybar >/dev/null 2>&1 || [[ -d "$WDIR" ]]; then
    mkdir -p "$WDIR"
    install -Dm644 "$ROOT_DIR/waybar/hydrate.jsonc" "$WMOD"
    echo "Waybar: Module installed to $WMOD."
  fi

  echo "Hydrate successfully installed!"
  echo "Left-click icon: open panel | Right-click icon: +250 ml | Hover: tooltip"
}

do_uninstall() {
  systemctl --user disable --now hydrate.timer 2>/dev/null || true
  pkill -f "hydrate" 2>/dev/null || true
  rm -f "$UNITS/hydrate.service" "$UNITS/hydrate.timer"
  rm -f "$APPS/hydrate.desktop" "$BIN/hydrate"
  systemctl --user daemon-reload 2>/dev/null || true
  clean_omarchy
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy-restart-shell >/dev/null 2>&1 || true
  rm -f "$WMOD"
  if [[ "${1:-}" == "purge" ]]; then
    rm -rf "$CDIR" "$SDIR"
    echo "Hydrate purged (all configs & history deleted)."
  else
    echo "Hydrate uninstalled (config & history preserved in $CDIR and $SDIR)."
  fi
}

do_doctor() {
  echo "=== Hydrate Diagnostics ==="
  echo "Distro PM      : $(detect_pm)"
  echo "Session        : ${XDG_SESSION_TYPE:-unknown} / ${XDG_CURRENT_DESKTOP:-unknown}"
  echo "omarchy-shell  : $(command -v omarchy-shell >/dev/null && echo 'found' || echo 'missing')"
  echo "Plugin path    : $([[ -d "$PDIR" ]] && echo 'installed' || echo 'not installed')"
  echo "systemd user   : $(systemctl --user is-active hydrate.timer 2>/dev/null || echo 'inactive')"
  for c in notify-send jq flock pkill yad waybar; do
    printf '%-14s: %s\n' "$c" "$(command -v "$c" >/dev/null && echo 'ok' || echo 'missing')"
  done
}

case "${1:-install}" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  purge)     do_uninstall purge ;;
  doctor)    do_doctor ;;
  *) echo "Usage: $0 {install|uninstall|purge|doctor}"; exit 1 ;;
esac
