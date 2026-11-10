#!/usr/bin/env bash
# Tests for the hydrate command. Usage: bash tests/run.sh
# Needs bash, jq and flock. Tests that fake the clock need `faketime` and are skipped without it.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/hydrate"
[[ -x "$CLI" ]] || chmod +x "$CLI"
pass=0; fail=0; skipped=0

ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
skip() { skipped=$((skipped + 1)); printf '  skip  %s\n' "$1"; }
eq()   { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
exit_is() { local name="$1" want="$2"; shift 2; "$@" >/dev/null 2>&1; eq "$name" "$want" "$?"; }

# fresh sandbox: own HOME, stubbed system commands, the real jq/flock
new_home() {
  export HOME; HOME="$(mktemp -d)"
  S="$HOME/.local/state/hydrate"; C="$HOME/.config/hydrate"; B="$HOME/stub"
  mkdir -p "$S" "$C" "$B"
  printf 'GOAL_ML=2500\nGLASS_ML=250\nINTERVAL=45\nSTART_HOUR=8\nSTART_MINUTE=0\nEND_HOUR=22\nEND_MINUTE=0\nPAUSED=0\nDAYS=all\nALERT_STYLE=notify\n' > "$C/config"
  for c in pkill systemctl loginctl; do printf '#!/bin/sh\nexit 0\n' > "$B/$c"; done
  # notify-send: logs alerts; with --wait it prints "default" when STUB_CLICK=1 (a click), nothing otherwise (a dismiss)
  cat > "$B/notify-send" <<'STUB'
#!/bin/sh
case "$*" in
  *--wait*) echo ALERT >> "$HOME/alerts"; [ "${STUB_CLICK:-0}" = 1 ] && echo default ;;
  *)        echo TOAST >> "$HOME/toasts" ;;
esac
exit 0
STUB
  printf '#!/bin/sh\n[ -n "${FAKE_LOCKER:-}" ] && exit 0\nexit 1\n' > "$B/pgrep"
  chmod +x "$B"/*
  export PATH="$B:$PATH"
}
alerts() { [[ -f "$HOME/alerts" ]] && wc -l < "$HOME/alerts" | tr -d ' ' || echo 0; }
ml()     { cat "$S/$(date +%F).ml" 2>/dev/null || echo 0; }
have_faketime() { command -v faketime >/dev/null 2>&1; }
at()     { local when="$1"; shift; faketime -f "$when" "$CLI" "$@"; }   # run the CLI at a fake time

echo "log, undo, entries"
new_home
"$CLI" log >/dev/null; "$CLI" log 500 >/dev/null
eq "log adds a glass, then a custom amount" 750 "$(ml)"
eq "every drink is recorded" 2 "$(wc -l < "$S/$(date +%F).log" | tr -d ' ')"
"$CLI" set glass 400 >/dev/null; "$CLI" undo
eq "undo removes what was really logged (500), not the current glass size" 250 "$(ml)"
"$CLI" log >/dev/null; "$CLI" undo
eq "undo of a 400 ml glass" 250 "$(ml)"
rm -f "$S"/*.log; echo 300 > "$S/$(date +%F).ml"; "$CLI" undo
eq "old days without entries fall back to one glass (400)" 0 "$(ml)"
"$CLI" undo; eq "undo never goes below zero" 0 "$(ml)"
exit_is "log 0 is rejected" 1 "$CLI" log 0
exit_is "log abc is rejected" 1 "$CLI" log abc
"$CLI" log 330 >/dev/null; "$CLI" entries | grep -q "+330 ml" && ok "entries lists the drink" || bad "entries lists the drink"
"$CLI" reset; eq "reset clears the day and its entries" "0 no" "$(ml) $([[ -e $S/$(date +%F).log ]] && echo yes || echo no)"

echo "concurrent logging"
new_home
for _ in $(seq 1 30); do "$CLI" log 10 >/dev/null & done; wait
eq "30 parallel logs are all counted" 300 "$(ml)"
eq "30 parallel logs are all recorded" 30 "$(wc -l < "$S/$(date +%F).log" | tr -d ' ')"

echo "settings validation"
new_home
exit_is "interval 90 is accepted" 0 "$CLI" set interval 90
exit_is "interval 20 is rejected" 1 "$CLI" set interval 20
exit_is "snooze 15 is accepted" 0 "$CLI" set snooze 15
exit_is "snooze 7 is rejected" 1 "$CLI" set snooze 7
exit_is "goal 3000 is accepted" 0 "$CLI" set goal 3000
exit_is "goal 1500 is rejected" 1 "$CLI" set goal 1500
exit_is "days weekdays" 0 "$CLI" set days weekdays
exit_is "days sometimes is rejected" 1 "$CLI" set days sometimes
exit_is "day mon custom window" 0 "$CLI" set day mon 09:00-17:30
exit_is "day sat off" 0 "$CLI" set day sat off
exit_is "day with start after end is rejected" 1 "$CLI" set day tue 18:00-09:00
exit_is "day with a bad name is rejected" 1 "$CLI" set day funday off
exit_is "quiet windows" 0 "$CLI" set quiet 12:00-13:00,15:00-15:30
exit_is "bad quiet window is rejected" 1 "$CLI" set quiet noon
exit_is "skip locked off" 0 "$CLI" set skip locked off
exit_is "skip idle 10" 0 "$CLI" set skip idle 10
exit_is "skip idle 0 is rejected" 1 "$CLI" set skip idle 0
exit_is "skip unknown is rejected" 1 "$CLI" set skip coffee on
eq "interval is stored" "90" "$(. "$C/config"; echo "$INTERVAL")"
"$CLI" set day mon default >/dev/null; grep -q '^DAY_MON=' "$C/config" && bad "day default removes the override" || ok "day default removes the override"
"$CLI" version | grep -q '^hydrate [0-9]' && ok "version prints" || bad "version prints"

echo "reminder schedule and skips"
if have_faketime; then
  new_home
  tick_at() { rm -f "$HOME/alerts"; echo 1 > "$S/next_due"; at "$1" tick; alerts; }
  "$CLI" set start_minute 30 >/dev/null; "$CLI" set end 17 >/dev/null; "$CLI" set end_minute 15 >/dev/null
  eq "before the window (08:29)" 0 "$(tick_at '2026-11-04 08:29:00')"
  eq "window start (08:30)"      1 "$(tick_at '2026-11-04 08:30:00')"
  eq "inside the window (12:00)" 1 "$(tick_at '2026-11-04 12:00:00')"
  eq "window end (17:15)"        0 "$(tick_at '2026-11-04 17:15:00')"
  "$CLI" set quiet 12:00-13:00 >/dev/null
  eq "quiet window blocks (12:30)" 0 "$(tick_at '2026-11-04 12:30:00')"
  eq "after the quiet window (13:00)" 1 "$(tick_at '2026-11-04 13:00:00')"
  "$CLI" set quiet off >/dev/null
  "$CLI" set days weekdays >/dev/null
  eq "weekdays only: Saturday is silent" 0 "$(tick_at '2026-11-07 10:00:00')"
  eq "weekdays only: Wednesday fires"    1 "$(tick_at '2026-11-04 10:00:00')"
  "$CLI" set day sat 10:00-11:00 >/dev/null
  eq "per-day window: Saturday inside 10:00-11:00" 1 "$(tick_at '2026-11-07 10:30:00')"
  eq "per-day window: Saturday outside"           0 "$(tick_at '2026-11-07 12:00:00')"
  "$CLI" set day wed off >/dev/null
  eq "per-day off: Wednesday is silent" 0 "$(tick_at '2026-11-04 10:00:00')"
  "$CLI" set day wed default >/dev/null
  "$CLI" pause >/dev/null
  eq "paused is silent" 0 "$(tick_at '2026-11-04 10:00:00')"
  "$CLI" resume >/dev/null
  echo 2500 > "$S/2026-11-04.ml"
  eq "goal reached is silent" 0 "$(tick_at '2026-11-04 10:00:00')"
  rm -f "$S/2026-11-04.ml"

  # skip reasons hold a due reminder back and keep it due
  echo 1 > "$S/next_due"
  FAKE_LOCKER=1; export FAKE_LOCKER
  rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "screen locked: no alert" "0 1" "$(alerts) $(cat "$S/next_due")"
  unset FAKE_LOCKER
  rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "unlocked: the held-back reminder fires" 1 "$(alerts)"
  printf '#!/bin/sh\n[ "$1" = mode ] && echo default && echo do-not-disturb\n' > "$B/makoctl"; chmod +x "$B/makoctl"
  echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "do not disturb (mako): no alert" 0 "$(alerts)"
  "$CLI" set skip dnd off >/dev/null
  echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "do not disturb skip switched off: alert" 1 "$(alerts)"
  rm -f "$B/makoctl"
  if command -v jq >/dev/null 2>&1; then
    mkdir -p "$HOME/run/hypr/abc"; export XDG_RUNTIME_DIR="$HOME/run"
    printf '#!/bin/sh\necho "{\\"fullscreen\\": 2}"\n' > "$B/hyprctl"; chmod +x "$B/hyprctl"
    echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
    eq "fullscreen window (Hyprland): no alert" 0 "$(alerts)"
    printf '#!/bin/sh\necho "{\\"fullscreen\\": 0}"\n' > "$B/hyprctl"
    echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
    eq "windowed app (Hyprland): alert" 1 "$(alerts)"
    rm -f "$B/hyprctl"
  else skip "fullscreen detection (needs jq)"; fi
  "$CLI" set skip idle 5 >/dev/null
  printf '#!/bin/sh\necho 600000\n' > "$B/xprintidle"; chmod +x "$B/xprintidle"; export DISPLAY=:9
  echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "idle for 10 min with a 5 min limit: no alert" 0 "$(alerts)"
  printf '#!/bin/sh\necho 1000\n' > "$B/xprintidle"
  echo 1 > "$S/next_due"; rm -f "$HOME/alerts"; at '2026-11-04 10:00:00' tick
  eq "active user: alert" 1 "$(alerts)"
  rm -f "$B/xprintidle"; unset DISPLAY
else skip "schedule and skip tests (faketime not installed)"; fi

echo "alert: click and snooze"
new_home
echo 1 > "$S/next_due"; STUB_CLICK=1 "$CLI" alert
eq "click logs a glass" 250 "$(ml)"
"$CLI" set snooze 20 >/dev/null; echo 1 > "$S/next_due"
STUB_CLICK=0 "$CLI" alert; due=$(( $(cat "$S/next_due") - $(date +%s) ))
(( due >= 1195 && due <= 1200 )) && ok "dismiss snoozes by the configured 20 minutes" || bad "snooze (due in ${due}s)"
eq "dismiss logs nothing" 250 "$(ml)"

echo "weeks, entries history, export"
if have_faketime; then
  new_home
  w() { echo "$2" > "$S/$1.ml"; }
  w 2026-10-19 1000; w 2026-10-26 2000; w 2026-10-27 3000; w 2026-10-29 2500; w 2026-10-30 2000; w 2026-10-31 4000
  w 2026-11-02 2250; w 2026-11-03 1750; w 2026-11-04 500
  printf '1793000000\t250\n1793003600\t250\n' > "$S/2026-11-03.log"
  json() { at '2026-11-04 10:00:00' "$@" | jq -c "$JQ"; }
  JQ='[.week, .prev_avg, .min_offset, .today]'
  eq "state: this week, last week avg, oldest week, today" '[[2250,1750,500,-1,-1,-1,-1],2700,-2,2]' "$(json state)"
  JQ='[.offset, .start, .week, .avg, .prev_avg, .today]'
  eq "week -1" '[-1,"2026-10-26",[2000,3000,0,2500,2000,4000,0],2700,1000,-1]' "$(json week -1)"
  eq "week -2" '[-2,"2026-10-19",[1000,0,0,0,0,0,0],1000,-1,-1]' "$(json week -2)"
  eq "week 0 marks today" '[0,"2026-11-02",[2250,1750,500,-1,-1,-1,-1],1500,2700,2]' "$(json week 0)"
  [[ "$(at '2026-11-04 10:00:00' stats -1)" == *"Week avg  2.7 L"* ]] && ok "stats -1 prints the average" || bad "stats -1"
  eq "entries for a date" "2026-11-03  1.75 L" "$(at '2026-11-04 10:00:00' entries 2026-11-03 | sed -n 1p)"
  eq "entries shows each drink" 2 "$(at '2026-11-04 10:00:00' entries 2026-11-03 | grep -c ' +250 ml')"
  at '2026-11-04 10:00:00' entries 2026-11-02 | grep -q 'no individual entries' && ok "entries for an old day without detail" || bad "entries for an old day"
  exit_is "entries rejects a bad date" 1 "$CLI" entries notadate
  "$CLI" export "$HOME/out.csv" >/dev/null
  eq "export: header, day totals, one row per drink" "date,time,ml|2026-10-19,,1000|2" "$(sed -n 1p "$HOME/out.csv")|$(sed -n 2p "$HOME/out.csv")|$(grep -c '^2026-11-03,' "$HOME/out.csv")"
  "$CLI" backup "$HOME/b.tar.gz" >/dev/null; rm -rf "$S"; "$CLI" restore "$HOME/b.tar.gz" >/dev/null
  eq "backup and restore bring the history back" 1000 "$(cat "$S/2026-10-19.ml")"
else skip "history tests (faketime not installed)"; fi

echo "uninstall and purge ask first"
new_home
mkdir -p "$HOME/.local/bin" && cp "$CLI" "$HOME/.local/bin/hydrate"
exit_is "uninstall without a terminal and without --yes refuses" 1 "$HOME/.local/bin/hydrate" uninstall
[[ -x "$HOME/.local/bin/hydrate" ]] && ok "nothing was removed" || bad "nothing was removed"
exit_is "purge without a terminal and without --yes refuses" 1 "$HOME/.local/bin/hydrate" purge
[[ -d "$C" ]] && ok "settings are still there" || bad "settings are still there"
echo n | exit_is "answering no cancels" 1 "$HOME/.local/bin/hydrate" uninstall
"$HOME/.local/bin/hydrate" uninstall --yes >/dev/null 2>&1
[[ ! -e "$HOME/.local/bin/hydrate" && -d "$C" && -d "$S" ]] && ok "uninstall --yes removes the command, keeps data" || bad "uninstall --yes"
cp "$CLI" "$HOME/.local/bin/hydrate"
"$HOME/.local/bin/hydrate" purge --yes >/dev/null 2>&1
[[ ! -e "$C" && ! -e "$S" ]] && ok "purge --yes deletes settings and history" || bad "purge --yes"

echo "update"
new_home
exit_is "update without a recorded folder fails" 1 "$CLI" update
mkdir -p "$HOME/src"; printf '#!/bin/sh\necho "reinstalled with: $*" > "$HOME/reinstalled"\n' > "$HOME/src/install.sh"; chmod +x "$HOME/src/install.sh"
echo "$HOME/src" > "$C/source"; echo "--no-waybar" > "$C/install-flags"
"$CLI" update >/dev/null 2>&1
eq "update reinstalls from the recorded folder with the saved flags" "reinstalled with: --no-waybar" "$(cat "$HOME/reinstalled" 2>/dev/null)"

echo "installer"
new_home
for c in yad omarchy-shell omarchy omarchy-restart-shell; do printf '#!/bin/sh\nexit 0\n' > "$B/$c"; chmod +x "$B/$c"; done
bash "$ROOT/install.sh" --no-waybar >/dev/null 2>&1
exit_is "install ran" 0 test -x "$HOME/.local/bin/hydrate"
eq "plugin files are copied" "BarWidget.qml Chip.qml GlassView.qml Panel.qml manifest.json" "$(ls "$HOME/.config/omarchy/plugins/hydrate" | tr '\n' ' ' | sed 's/ $//')"
eq "new settings get defaults" "10 1 1 1 0" "$(. "$C/config"; echo "$SNOOZE_MIN $SKIP_LOCKED $SKIP_DND $SKIP_FULLSCREEN $SKIP_IDLE_MIN")"
eq "the source folder and options are recorded" "$ROOT --no-waybar" "$(cat "$C/source") $(cat "$C/install-flags")"
"$HOME/.local/bin/hydrate" set interval 90 >/dev/null
bash "$ROOT/install.sh" --no-waybar >/dev/null 2>&1
eq "reinstalling keeps your settings" 90 "$(. "$C/config"; echo "$INTERVAL")"
"$HOME/.local/bin/hydrate" update >/dev/null 2>&1; eq "hydrate update reinstalls from the recorded folder" 0 "$?"
exit_is "hydrate doctor runs" 0 "$HOME/.local/bin/hydrate" doctor
"$HOME/.local/bin/hydrate" uninstall --yes >/dev/null 2>&1
[[ ! -e "$HOME/.local/bin/hydrate" && ! -e "$HOME/.config/omarchy/plugins/hydrate" ]] && ok "uninstall --yes removes the command and the plugin" || bad "uninstall --yes"

echo
echo "$pass passed, $fail failed, $skipped skipped"
(( fail == 0 ))
