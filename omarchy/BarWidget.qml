import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hydrate"

  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/hydrate"
  property var st: ({ ml: 0, goal: 2500, glass: 250, interval: 45, start: 8, end: 22, paused: 0, next: "", week: [] })
  property var queue: []
  property bool again: false
  readonly property real frac: Math.min(1, (st.ml || 0) / Math.max(1, st.goal || 1))
  readonly property bool iconOk: iconLoader.status === Loader.Ready
  readonly property string label: litres(st.ml) + "/" + litres(st.goal) + " L" + (st.paused === 1 ? " ⏸" : "")
  readonly property string tip: "Water today: " + litres(st.ml) + " of " + litres(st.goal) + " L"
    + (st.paused === 1 ? "\nPaused" : (st.next ? "\nNext reminder: " + st.next : ""))
    + "\nClick: panel   Right-click: +" + st.glass + " ml"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function litres(ml) { return parseFloat((ml / 1000).toFixed(2)).toString() }
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
    panelLoader.item.anchorItem = btn
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

  implicitWidth: btn.implicitWidth
  implicitHeight: btn.implicitHeight
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: btn
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tip
    text: "🥤 " + root.label
    onPressed: function(code) {
      if (code === Qt.LeftButton) root.toggle()
      else if (code === Qt.RightButton) root.act(["log"])
    }
  }
}
