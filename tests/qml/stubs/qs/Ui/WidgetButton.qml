import QtQuick
Rectangle {
  id: b
  property var bar; property string text; property string tooltipText
  signal pressed(var buttonCode)
  implicitWidth: 40 + label.implicitWidth; implicitHeight: 26
  color: "#202020"
  Text { id: label; anchors.centerIn: parent; text: b.text; color: "#e6e6e6"; font.pixelSize: 13 }
}
