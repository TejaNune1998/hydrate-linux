import QtQuick
import QtQuick.Shapes

Item {
  id: root
  property real fraction: 0
  property color shadowColor: Qt.rgba(1, 1, 1, 0.07)
  implicitWidth: 124
  implicitHeight: 168
  width: implicitWidth
  height: implicitHeight

  readonly property real q: Math.max(0, Math.min(0.96, fraction))
  readonly property real sy: 168 - q * 138
  readonly property color blue: "#378ADD"
  readonly property color deep: "#185FA5"
  readonly property color pale: "#85B7EB"
  readonly property color mist: "#E6F1FB"
  readonly property color line: Qt.rgba(0.216, 0.541, 0.867, 0.85)

  function wall(y) { return 26 + 12 * (y - 22) / 140 }
  function basin(y) {
    var l = wall(y)
    return "M" + l + " " + y + "H" + (140 - l) + "L102 162Q101 167 95 167H45Q39 167 38 162Z"
  }
  function ellipse(cy, rx, ry) {
    return "M" + (70 - rx) + " " + cy + "A" + rx + " " + ry + " 0 1 0 " + (70 + rx) + " " + cy
         + "A" + rx + " " + ry + " 0 1 0 " + (70 - rx) + " " + cy + "Z"
  }
  readonly property real surfRx: 43 - 12 * (sy - 22) / 140

  Item {
    id: art
    width: 140
    height: 190
    scale: root.width / 140
    transformOrigin: Item.TopLeft

    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4
      layer.textureSize: Qt.size(art.width * 2, art.height * 2)

      ShapePath {
        fillColor: root.shadowColor
        strokeColor: "transparent"
        PathSvg { path: root.ellipse(178, 40, 5) }
      }
      ShapePath {
        fillColor: Qt.rgba(0.71, 0.83, 0.96, 0.12)
        strokeColor: "transparent"
        PathSvg { path: "M22 20A48 5.5 0 0 0 118 20L106 164Q105 172 97 172H43Q35 172 34 164Z" }
      }
      ShapePath {
        fillColor: root.q > 0.02 ? Qt.rgba(0.216, 0.541, 0.867, 0.82) : "transparent"
        strokeColor: "transparent"
        PathSvg { path: root.basin(root.sy) }
      }
      ShapePath {
        fillColor: root.q > 0.02 ? Qt.rgba(0.094, 0.373, 0.647, 0.35) : "transparent"
        strokeColor: "transparent"
        PathSvg { path: root.basin(Math.max(root.sy, 134)) }
      }
      ShapePath {
        fillColor: root.q > 0.02 ? root.pale : "transparent"
        strokeColor: "transparent"
        PathSvg { path: root.ellipse(root.sy, root.surfRx, 5) }
      }
      ShapePath {
        fillColor: root.q > 0.02 ? Qt.rgba(0.9, 0.945, 0.98, 0.55) : "transparent"
        strokeColor: "transparent"
        PathSvg { path: root.ellipse(root.sy, root.surfRx * 0.55, 2.6) }
      }
    }

    Repeater {
      model: [
        { x: 52, y: 140, r: 2.6 }, { x: 84, y: 124, r: 2.0 }, { x: 66, y: 112, r: 1.6 },
        { x: 90, y: 150, r: 2.2 }, { x: 58, y: 156, r: 1.6 }
      ]
      Rectangle {
        x: modelData.x - modelData.r
        y: modelData.y - modelData.r
        width: modelData.r * 2
        height: modelData.r * 2
        radius: modelData.r
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0.9, 0.945, 0.98, 0.8)
        visible: root.q > 0.02 && modelData.y > root.sy + 6
      }
    }

    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4
      layer.textureSize: Qt.size(art.width * 2, art.height * 2)

      ShapePath {
        fillColor: Qt.rgba(0.9, 0.945, 0.98, 0.22)
        strokeColor: Qt.rgba(0.9, 0.945, 0.98, 0.45)
        strokeWidth: 1
        PathSvg { path: "M36 152H104L102 162Q101 167 95 167H45Q39 167 38 162Z" }
      }
      ShapePath {
        fillColor: Qt.rgba(1, 1, 1, 0.38)
        strokeColor: "transparent"
        PathSvg { path: "M32 34L37.5 34L44 146L40 146Z" }
      }
      ShapePath {
        fillColor: Qt.rgba(1, 1, 1, 0.22)
        strokeColor: "transparent"
        PathSvg { path: "M104 42L107 42L101 120L98.5 120Z" }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.line
        strokeWidth: 2.2
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M22 20L34 164Q35 172 43 172H97Q105 172 106 164L118 20" }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.line
        strokeWidth: 2
        capStyle: ShapePath.RoundCap
        PathSvg { path: "M22 20A48 5.5 0 0 1 118 20" }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.line
        strokeWidth: 2
        capStyle: ShapePath.RoundCap
        PathSvg { path: "M22 20A48 5.5 0 0 0 118 20" }
      }
    }
  }
}
