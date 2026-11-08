#!/usr/bin/env bash
# Hydrate installer
# usage: ./install.sh [--no-quickshell] [--no-waybar] [--quickshell] [--waybar]
# after installing, use the hydrate command: hydrate uninstall | purge | doctor
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
UNITS="$HOME/.config/systemd/user"
CDIR="$HOME/.config/hydrate"
SDIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydrate"
APPS="$HOME/.local/share/applications"
AUTOSTART="$HOME/.config/autostart"
WDIR="$HOME/.config/waybar"
WMOD="$WDIR/hydrate.jsonc"
PID="hydrate"
OLD_IDS=(hydrate local.hydrate)
PDIR="$HOME/.config/omarchy/plugins/$PID"
SHJ="$HOME/.config/omarchy/shell.json"

SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

# ---------- dependencies ----------
pm=""
for p in pacman apt-get dnf yum zypper; do
  command -v "$p" >/dev/null 2>&1 && { pm="$p"; break; }
done

pkg_for() {
  case "$1:$pm" in
    notify-send:apt-get) echo libnotify-bin ;;
    notify-send:zypper)  echo libnotify-tools ;;
    notify-send:*)       echo libnotify ;;
    flock:*)             echo util-linux ;;
    pkill:pacman|pkill:dnf|pkill:yum) echo procps-ng ;;
    pkill:*)             echo procps ;;
    *)                   echo "$1" ;;
  esac
}

pm_install() {
  case "$pm" in
    pacman)  $SUDO pacman -S --needed --noconfirm "$@" ;;
    apt-get) $SUDO apt-get update -qq; $SUDO apt-get install -y "$@" ;;
    dnf|yum) $SUDO "$pm" install -y "$@" ;;
    zypper)  $SUDO zypper -n install "$@" ;;
  esac
}

install_deps() {
  local need="" c
  for c in notify-send jq flock pkill yad; do
    command -v "$c" >/dev/null 2>&1 || need+=" $(pkg_for "$c")"
  done
  [[ -n "$need" ]] || return 0
  [[ -n "$pm" ]] || { echo "install by hand:$need"; return 0; }
  # yad lives in EPEL on rhel/centos/rocky/alma
  if [[ "$pm" == dnf || "$pm" == yum ]] && [[ "$need" == *yad* ]] &&
     grep -qiE 'rhel|centos' /etc/os-release 2>/dev/null && ! grep -qi fedora /etc/os-release 2>/dev/null; then
    pm_install epel-release || true
  fi
  # shellcheck disable=SC2086
  pm_install $need || {
    # yad is optional: retry without it so the other tools still get installed
    echo "retrying without yad (the panel will use a menu launcher)"
    # shellcheck disable=SC2086
    pm_install ${need/ yad/} || { echo "dependency install failed"; return 1; }
  }
}

# ---------- Omarchy / Quickshell ----------
has_qs() { command -v omarchy-shell >/dev/null 2>&1; }
qs_reload() { omarchy-shell shell reloadConfig >/dev/null 2>&1 || omarchy-restart-shell >/dev/null 2>&1; }
# new plugin code is not always picked up by a hot reload, so restart the shell after copying it
qs_restart() { omarchy-restart-shell >/dev/null 2>&1 || omarchy restart shell >/dev/null 2>&1 || qs_reload; }

# remove every older Hydrate plugin id (and its shell.json entries)
clean_omarchy() {
  local id tmp
  for id in "$PID" "${OLD_IDS[@]}"; do
    omarchy plugin disable "$id" >/dev/null 2>&1
    rm -rf "$HOME/.config/omarchy/plugins/$id"
  done
  [[ -f "$SHJ" ]] && command -v jq >/dev/null 2>&1 && grep -qE '"((local)\.)?hydrate"' "$SHJ" || return 0
  cp "$SHJ" "$SHJ.hydrate.bak"
  tmp=$(mktemp)
  if jq 'if .bar.layout then .bar.layout |= with_entries(.value |= (if type=="array" then map(select(.id != "hydrate" and .id != "local.hydrate" and .id != "hydrate")) else . end)) else . end' \
       "$SHJ.hydrate.bak" > "$tmp" && jq -e . "$tmp" >/dev/null; then
    mv "$tmp" "$SHJ"
  else
    rm -f "$tmp"
    echo "quickshell: remove entries with id \"hydrate\" from $SHJ by hand"
  fi
}

qs_install() {
  clean_omarchy
  mkdir -p "$PDIR"
  cp -r "$ROOT/omarchy/." "$PDIR/"
  omarchy-shell shell rescanPlugins >/dev/null 2>&1
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$PDIR" || echo "quickshell: plugin validation reported a problem (see above)"
    omarchy plugin enable "$PID" right || echo "quickshell: run manually:  omarchy plugin enable $PID right"
  fi
  qs_restart
}

# ---------- Waybar ----------
jsonok() { sed -E 's#^[[:space:]]*//.*##' "$1" | jq -e . >/dev/null 2>&1; }

waybar_install() {
  local cfg="" f tmp
  mkdir -p "$WDIR"
  sed "s|\$HOME|$HOME|g" "$ROOT/waybar/hydrate.jsonc" > "$WMOD"
  for f in "$WDIR/config.jsonc" "$WDIR/config"; do
    [[ -f "$f" ]] && { cfg="$f"; break; }
  done
  if [[ -n "$cfg" ]] && grep -q hydrate "$cfg"; then
    pkill -SIGUSR2 waybar 2>/dev/null; return 0
  fi
  tmp=$(mktemp)
  if [[ -n "$cfg" ]] && command -v jq >/dev/null 2>&1 && jsonok "$cfg" && ! grep -q '"include"' "$cfg"; then
    awk -v inc="  \"include\": [\"$WMOD\"]," '
      !a && /^[[:space:]]*\{[[:space:]]*$/ { print; print inc; a=1; next }
      !b && /"modules-right"[[:space:]]*:[[:space:]]*\[[[:space:]]*$/ { print; print "    \"custom/hydrate\","; b=1; next }
      { print }' "$cfg" > "$tmp"
  fi
  if [[ -s "$tmp" ]] && grep -q hydrate.jsonc "$tmp" && grep -q '"custom/hydrate",' "$tmp" && jsonok "$tmp"; then
    cp "$cfg" "$cfg.hydrate.bak"
    cat "$tmp" > "$cfg"
    pkill -SIGUSR2 waybar 2>/dev/null
    echo "waybar: module added to $cfg (backup $cfg.hydrate.bak)"
  else
    echo "waybar: add \"include\": [\"$WMOD\"] and \"custom/hydrate\" to modules-right in your Waybar config, then: pkill -SIGUSR2 waybar"
  fi
  rm -f "$tmp"
}

# ---------- commands ----------
do_install() {
  local qsf=auto wbf=auto a def=auto kv q=0 w=0
  for a in "$@"; do
    case "$a" in
      --quickshell)    qsf=1 ;;
      --no-quickshell) qsf=0 ;;
      --waybar)        wbf=1 ;;
      --no-waybar)     wbf=0 ;;
      *) echo "unknown option: $a"; exit 1 ;;
    esac
  done

  install_deps || exit 1
  mkdir -p "$BIN" "$UNITS" "$CDIR" "$SDIR" "$APPS"
  touch "$SDIR/changed"
  systemctl --user disable --now hydrate.timer 2>/dev/null
  pkill -f "hydrate (alert|daemon)" 2>/dev/null

  # 1. CLI
  install -Dm755 "$ROOT/bin/hydrate" "$BIN/hydrate"

  # 2. config defaults (existing values are kept)
  # gnome-like shells drop notifications after a few seconds: use a dialog there
  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME*|*Unity*|*Budgie*|*Cinnamon*|*MATE*|*COSMIC*|*Pantheon*|*Deepin*)
      command -v yad >/dev/null 2>&1 && def=dialog ;;
  esac
  touch "$CDIR/config"
  for kv in GOAL_ML=2500 GLASS_ML=250 INTERVAL=45 START_HOUR=8 START_MINUTE=0 END_HOUR=22 END_MINUTE=0 PAUSED=0 DAYS=all "ALERT_STYLE=$def"; do
    grep -q "^${kv%%=*}=" "$CDIR/config" || echo "$kv" >> "$CDIR/config"
  done
  # shellcheck disable=SC1091
  . "$CDIR/config"
  echo $(( $(date +%s) + ${INTERVAL:-45} * 60 )) > "$SDIR/next_due"

  # 3. scheduler: systemd user timer, or autostart when systemd isn't available
  if systemctl --user show-environment >/dev/null 2>&1; then
    install -Dm644 "$ROOT/systemd/hydrate.service" "$UNITS/hydrate.service"
    install -Dm644 "$ROOT/systemd/hydrate.timer" "$UNITS/hydrate.timer"
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY 2>/dev/null
    systemctl --user daemon-reload
    systemctl --user enable --now hydrate.timer
  else
    mkdir -p "$AUTOSTART"
    printf '[Desktop Entry]\nType=Application\nName=hydrate\nNoDisplay=true\nExec=%s daemon\n' "$BIN/hydrate" > "$AUTOSTART/hydrate.desktop"
    nohup "$BIN/hydrate" daemon >/dev/null 2>&1 &
    echo "no systemd user session: started 'hydrate daemon' and added an autostart entry"
  fi

  # 4. app launcher entry
  printf '[Desktop Entry]\nType=Application\nName=Hydrate\nComment=Water intake tracker\nExec=%s panel\nIcon=weather-showers\nCategories=Utility;\n' "$BIN/hydrate" > "$APPS/hydrate.desktop"

  # 5. Omarchy Quickshell plugin
  if [[ "$qsf" != 0 ]] && has_qs; then
    qs_install; q=1
  elif [[ "$qsf" == 1 ]]; then
    echo "omarchy-shell not found: cannot install the Quickshell plugin"
  fi

  # 6. Waybar: when it is running, or installed and there is no Quickshell shell
  if [[ "$wbf" == auto ]]; then
    wbf=0
    pgrep -x waybar >/dev/null 2>&1 && wbf=1
    [[ "$q" == 0 ]] && { command -v waybar >/dev/null 2>&1 || [[ -f "$WDIR/config.jsonc" || -f "$WDIR/config" ]]; } && wbf=1
  fi
  [[ "$wbf" == 1 ]] && { waybar_install; w=1; }

  echo "Hydrate installed. bars:$([[ $q == 1 ]] && echo ' quickshell')$([[ $w == 1 ]] && echo ' waybar')$([[ $q$w == 00 ]] && echo ' none (use: hydrate status, or the app launcher)')"
  echo "try: hydrate panel | hydrate alert | hydrate doctor      remove: hydrate uninstall | hydrate purge"
}

case "${1:-install}" in
  install)                 shift; do_install "$@" ;;
  --*)                     do_install "$@" ;;
  uninstall|purge|doctor)  echo "Use the hydrate command instead:  hydrate $1"; exit 1 ;;
  *) echo "usage: $0 [--no-quickshell] [--no-waybar]   (uninstall: hydrate uninstall | hydrate purge)"; exit 1 ;;
esac
