import QtQuick
Rectangle {
  id: b
  property var bar; property string labelText; property string tooltipText; property Component iconComponent
  signal pressed(var mouseButton)
  implicitWidth: row.implicitWidth + 16; implicitHeight: 26
  color: "#202020"
  Row {
    id: row; anchors.centerIn: parent; spacing: 6
    Loader { id: ic; sourceComponent: b.iconComponent; width: 12; height: 12; anchors.verticalCenter: parent.verticalCenter }
    Text { text: b.labelText; color: "#e6e6e6"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
  }
}
