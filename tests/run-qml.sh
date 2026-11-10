#!/usr/bin/env bash
# Panel tests (keyboard, week scrolling, focus). Needs Qt 6 qmltestrunner and QML modules:
#   Debian/Ubuntu: qt6-declarative-dev-tools qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-shapes
#                  qml6-module-qtquick-window qml6-module-qttest qml6-module-qtquick-templates
# Runs headless (xvfb-run if available, otherwise Qt's offscreen platform).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER=""
for c in qmltestrunner6 qmltestrunner /usr/lib/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qmltestrunner6; do
  command -v "$c" >/dev/null 2>&1 && { RUNNER="$c"; break; }
  [[ -x "$c" ]] && { RUNNER="$c"; break; }
done
[[ -n "$RUNNER" ]] || { echo "skip: qmltestrunner (Qt 6) not found"; exit 0; }
cd "$ROOT/tests/qml" || exit 1
if command -v xvfb-run >/dev/null 2>&1; then
  export QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1
  PRE=(xvfb-run -a -s "-screen 0 1280x1100x24")
else
  export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
  PRE=()
fi
"${PRE[@]}" "$RUNNER" -input tst_panel.qml -import "$ROOT/tests/qml/stubs" 2>&1 | grep -E "^(PASS|FAIL|XFAIL|Totals|   Actual|   Expected|Warning)" | grep -v "initTestCase\|cleanupTestCase"
exit "${PIPESTATUS[0]}"
