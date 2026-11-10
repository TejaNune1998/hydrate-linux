import QtQuick
import qs.Commons
import qs.Commons as Commons

Rectangle {
  id: chip
  property string label
  property bool selected: false
  property bool accentFill: false
  property string hint: ""
  property bool compact: false
  property string fontFamily: Style.font.family
  readonly property bool filled: selected || accentFill
  signal clicked()

  implicitWidth: row.implicitWidth + Style.space(compact ? 10 : 20)
  implicitHeight: row.implicitHeight + Style.space(compact ? 6 : 12)
  radius: Style.cornerRadius
  color: filled ? Commons.Color.accent : Qt.alpha(Commons.Color.foreground, mouse.containsMouse ? 0.18 : 0.08)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(8)
    Text {
      text: chip.label
      color: chip.filled ? Commons.Color.background : Commons.Color.foreground
      font.family: chip.fontFamily
      font.pixelSize: Style.font.body
      font.bold: chip.filled
    }
    Text {
      visible: chip.hint !== ""
      text: chip.hint
      color: Qt.alpha(chip.filled ? Commons.Color.background : Commons.Color.foreground, 0.6)
      font.family: chip.fontFamily
      font.pixelSize: Style.font.caption
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
