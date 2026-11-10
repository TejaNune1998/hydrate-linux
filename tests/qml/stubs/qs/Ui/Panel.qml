import QtQuick
Item {
  property string moduleName
  property bool manageIpc
  property var bar: null
  property bool opened: true
  property bool popoutSwitchClosing: false
  property color barForeground: "#e6e6e6"
  property var controller: QtObject { function show() {} function hide() {} }
  function toggle() { opened = !opened }
  function closeForPopoutSwitch() {}
}
