import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hydrate"

  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/hydrate"
  property var st: ({ ml: 0, goal: 2500, glass: 250, interval: 45, start: 8, start_minute: 0, end: 22, end_minute: 0, paused: 0, off: 0, days: "all", next: "", today: 0, week: [], prev_avg: -1 })
  property var queue: []
  property bool again: false
  property var weekData: null
  readonly property real frac: Math.min(1, (st.ml || 0) / Math.max(1, st.goal || 1))
  readonly property string label: litres(st.ml) + "/" + litres(st.goal) + " L" + (st.paused === 1 ? " · paused" : "")

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function litres(ml) { return parseFloat((ml / 1000).toFixed(2)).toString() }
  // history for another week, fetched when the panel scrolls to it
  function loadWeek(offset) {
    weekReader.command = [cli, "week", String(offset)]
    weekReader.running = true
  }
  function refresh() { if (reader.running) again = true; else reader.running = true }
  function step() { runner.command = [cli].concat(queue.shift()); runner.running = true }
  function act(args) { queue.push(args); if (!runner.running) step() }

  function open() { refresh(); if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (!opened) refresh(); if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  Process {
    id: reader
    command: [root.cli, "state"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.st = JSON.parse(text) } catch (e) {} }
    }
    onExited: { if (root.again) { root.again = false; reader.running = true } }
  }

  Process {
    id: weekReader
    stdout: StdioCollector {
      onStreamFinished: { try { root.weekData = JSON.parse(text) } catch (e) {} }
    }
  }

  Process {
    id: runner
    onExited: { if (root.queue.length > 0) root.step(); else root.refresh() }
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/hydrate/changed"
    watchChanges: true
    onFileChanged: { this.reload(); root.refresh() }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Reserve enough width for the full icon + intake label. The bar layout
  // must allocate this space instead of letting the contents paint over peers.
  implicitWidth: Math.max(120, button.implicitWidth)
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  // BarIconButton is the shell's own icon + label button: it handles size, hover, tooltip and clicks
  BarIconButton {
    id: button
    anchors.fill: parent
    implicitWidth: Math.max(120, root.label.length * 8 + 30)
    bar: root.bar
    labelText: root.label
    tooltipText: "Water today: " + root.litres(root.st.ml) + " of " + root.litres(root.st.goal) + " L"
      + (root.st.paused === 1 ? "\nPaused" : root.st.off === 1 ? "\nReminders off today"
         : root.st.next ? "\nNext reminder: " + root.st.next : "")
      + "\nClick: panel   Right-click: +" + root.st.glass + " ml"

    // Minimal, crisp glass glyph: one continuous outline, open rim, and a
    // progressively rising blue fill. The lower sides join directly into the base.
    iconComponent: Component {
      Item {
        id: barGlass
        width: 24
        height: 24
        property real fraction: root.frac
        Behavior on fraction { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        readonly property real levelY: 20.0 - (Math.max(0, Math.min(1, fraction)) * 14.0)
        readonly property real taper: Math.max(0, Math.min(1, (levelY - 15.0) / 5.0))
        readonly property real leftAtLevel: 6.4 + (1.9 * taper)
        readonly property real rightAtLevel: 17.6 - (1.9 * taper)
        readonly property string waterPath: "M" + leftAtLevel + " " + levelY
          + " Q12 " + (levelY + 0.55) + " " + rightAtLevel + " " + levelY
          + " L15.7 20 L8.3 20 Z"
        readonly property string waterLine: "M" + leftAtLevel + " " + levelY
          + " Q12 " + (levelY + 0.55) + " " + rightAtLevel + " " + levelY

        Shape {
          anchors.fill: parent
          antialiasing: true

          // Dark glass interior.
          ShapePath {
            fillColor: "#071522"
            strokeColor: "transparent"
            PathSvg { path: "M6.3 3.4 L6.3 15.1 L8.7 20.1 L15.3 20.1 L17.7 15.1 L17.7 3.4 Z" }
          }
          // Intake fill clipped to the inside of the glass silhouette.
          ShapePath {
            fillColor: barGlass.fraction > 0.002 ? "#168FE8" : "transparent"
            strokeColor: "transparent"
            PathSvg { path: barGlass.fraction > 0.002 ? barGlass.waterPath : "M0 0" }
          }
          ShapePath {
            fillColor: "transparent"
            strokeColor: barGlass.fraction > 0.002 ? "#77D8FF" : "transparent"
            strokeWidth: 0.8
            capStyle: ShapePath.RoundCap
            PathSvg { path: barGlass.waterLine }
          }
          // Single connected outline: vertical sides flow into the angled lower sides and flat base.
          ShapePath {
            fillColor: "transparent"
            strokeColor: "#39B8FF"
            strokeWidth: 1.7
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: "M5.3 3.2 L5.3 15.2 L8.4 21 L15.6 21 L18.7 15.2 L18.7 3.2" }
          }
          // Fine open-glass rim, connected to both side strokes.
          ShapePath {
            fillColor: "transparent"
            strokeColor: "#68CEFF"
            strokeWidth: 1.45
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M5.3 3.2 Q12 1.7 18.7 3.2" }
          }
        }
      }
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
      else if (mouseButton === Qt.RightButton) root.act(["log"])
    }
  }
}
