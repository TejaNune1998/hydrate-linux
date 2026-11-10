pragma Singleton
import QtQuick
QtObject {
  property real cornerRadius: 6
  function space(n) { return n }
  function duration(n) { return n }
  readonly property var font: ({ family: "DejaVu Sans", title: 18, body: 13, bodySmall: 12, caption: 10, displayLarge: 36, subtitle: 15 })
}
