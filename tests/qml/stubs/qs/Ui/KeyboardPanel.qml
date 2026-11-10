import QtQuick
Rectangle {
  property var anchorItem; property var owner; property var bar; property bool open
  property var focusTarget; property real contentWidth: 300; property real contentHeight: 300
  function fittedContentWidth(w) { return w }
  function fittedContentHeight(h) { return h }
  default property alias body: holder.data
  width: contentWidth + 32; height: contentHeight + 32
  Item { id: holder; x: 16; y: 16; width: contentWidth; height: contentHeight }
  Component.onCompleted: if (focusTarget) focusTarget.forceActiveFocus()
}
