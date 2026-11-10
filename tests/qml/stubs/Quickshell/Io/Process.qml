import QtQuick
QtObject {
  id: p
  property var command: []
  property bool running: false
  property var stdout: null
  signal exited(int code)
  onRunningChanged: {
    if (!running) return
    if (stdout && command[1] === "state") {
      var x = new XMLHttpRequest(); x.open("GET", "file:///tmp/stubstate.json", false); x.send()
      stdout.text = x.responseText
      stdout.streamFinished()
    }
    running = false
    exited(0)
  }
}
