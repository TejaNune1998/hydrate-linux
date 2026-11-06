import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "hydrate"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool showSettings: false

  readonly property var st: hostWidget ? hostWidget.st : ({})
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property real frac: Math.min(1, (st.ml || 0) / Math.max(1, st.goal || 1))
  readonly property var week: (st.week || []).concat([st.ml || 0])

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function act(a) { if (hostWidget) hostWidget.act(a) }
  function litres(ml) { return parseFloat((ml / 1000).toFixed(2)).toString() }
  function hour(h) { var x = h % 24; return ((x % 12) || 12) + ":00 " + (x < 12 ? "AM" : "PM") }
  function dayName(back) {
    var d = new Date(); d.setDate(d.getDate() - back)
    return back === 0 ? "Today" : Qt.formatDate(d, "ddd")
  }
  function switchPanel(d) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, d)
    return false
  }

  Shortcut { sequence: "Space"; enabled: root.opened; onActivated: root.act(["log"]) }
  Shortcut { sequence: "U"; enabled: root.opened; onActivated: root.act(["undo"]) }
  Shortcut { sequence: "P"; enabled: root.opened; onActivated: root.act([root.st.paused === 1 ? "resume" : "pause"]) }

  component Group: Column {
    id: g
    property string title
    property string ff
    property var model
    property var cur
    property var fmt: function(v) { return v }
    signal picked(var v)
    width: parent.width
    spacing: Style.space(4)

    Text {
      text: g.title
      topPadding: Style.space(4)
      color: Qt.alpha(Commons.Color.foreground, 0.6)
      font.family: g.ff
      font.pixelSize: Style.font.caption
      font.bold: true
      font.capitalization: Font.AllUppercase
    }
    Flow {
      width: parent.width
      spacing: Style.space(6)
      Repeater {
        model: g.model
        Chip {
          label: g.fmt(modelData)
          selected: g.cur === modelData
          fontFamily: g.ff
          onClicked: g.picked(modelData)
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(col.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }

      Column {
        id: col
        width: parent.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          Text {
            width: parent.width - status.implicitWidth
            text: "Hydrate"
            color: root.barForeground
            font.family: root.ff
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            id: status
            text: root.st.paused === 1 ? "Paused"
                : root.frac >= 1 ? "Goal reached"
                : root.st.next ? "Next reminder " + root.st.next : ""
            color: Qt.alpha(root.barForeground, 0.65)
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(18)

          Loader {
            id: glassLoader
            source: Qt.resolvedUrl("GlassView.qml")
            onLoaded: {
              item.fraction = Qt.binding(function() { return root.frac })
              item.shadowColor = Qt.binding(function() { return Qt.alpha(root.barForeground, 0.08) })
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            Text {
              text: root.litres(root.st.ml || 0) + " L"
              color: root.barForeground
              font.family: root.ff
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
            Text {
              text: "of " + root.litres(root.st.goal || 0) + " L  ·  " + Math.round(root.frac * 100) + "%"
              color: Qt.alpha(root.barForeground, 0.65)
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Rectangle {
          visible: glassLoader.status !== Loader.Ready
          width: parent.width
          height: Style.space(8)
          radius: height / 2
          color: Qt.alpha(Commons.Color.foreground, 0.12)
          Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * root.frac
            color: Commons.Color.accent
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)
          Chip { label: "+ " + (root.st.glass || 250) + " ml"; hint: "Space"; accentFill: true; fontFamily: root.ff; onClicked: root.act(["log"]) }
          Chip { label: "Undo"; hint: "U"; fontFamily: root.ff; onClicked: root.act(["undo"]) }
          Chip {
            label: root.st.paused === 1 ? "Resume" : "Pause"
            hint: "P"
            fontFamily: root.ff
            onClicked: root.act([root.st.paused === 1 ? "resume" : "pause"])
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          Text {
            text: "LAST 7 DAYS"
            color: Qt.alpha(Commons.Color.foreground, 0.6)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Row {
            id: bars
            width: parent.width
            height: Style.space(56)
            spacing: Style.space(8)
            Repeater {
              model: root.week.length
              Item {
                width: (bars.width - bars.spacing * (root.week.length - 1)) / root.week.length
                height: bars.height
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  radius: Style.cornerRadius
                  height: Math.max(Style.space(3), parent.height * Math.min(1, root.week[index] / Math.max(1, root.st.goal || 1)))
                  color: index === root.week.length - 1 ? Commons.Color.accent : Qt.alpha(Commons.Color.accent, 0.4)
                }
              }
            }
          }
          Row {
            width: parent.width
            spacing: bars.spacing
            Repeater {
              model: root.week.length
              Text {
                width: (bars.width - bars.spacing * (root.week.length - 1)) / root.week.length
                horizontalAlignment: Text.AlignHCenter
                text: root.dayName(root.week.length - 1 - index)
                color: Qt.alpha(root.barForeground, 0.6)
                font.family: root.ff
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: summary.implicitHeight + Style.space(20)
          radius: Style.cornerRadius
          color: "transparent"
          border.width: 1
          border.color: Qt.alpha(Commons.Color.foreground, 0.15)
          Row {
            id: summary
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(12)
            Text {
              width: parent.width - arrow.implicitWidth
              text: "Every " + (root.st.interval || 0) + " min · " + root.hour(root.st.start || 0) + " to " + root.hour(root.st.end || 0)
              color: root.barForeground
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
            Text {
              id: arrow
              text: root.showSettings ? "▴" : "▾"
              color: Qt.alpha(root.barForeground, 0.7)
              font.family: root.ff
              font.pixelSize: Style.font.body
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showSettings = !root.showSettings
          }
        }

        Column {
          visible: root.showSettings
          width: parent.width
          spacing: Style.space(8)

          Group {
            title: "Remind every"; ff: root.ff
            model: [15, 20, 30, 45, 60, 90]; cur: root.st.interval
            fmt: function(v) { return v + " min" }
            onPicked: function(v) { root.act(["set", "interval", String(v)]) }
          }
          Group {
            title: "Start at"; ff: root.ff
            model: [5, 6, 7, 8, 9, 10, 11]; cur: root.st.start
            fmt: function(v) { return root.hour(v) }
            onPicked: function(v) { root.act(["set", "start", String(v)]) }
          }
          Group {
            title: "Stop at"; ff: root.ff
            model: [17, 18, 19, 20, 21, 22, 23]; cur: root.st.end
            fmt: function(v) { return root.hour(v) }
            onPicked: function(v) { root.act(["set", "end", String(v)]) }
          }
          Group {
            title: "Glass size"; ff: root.ff
            model: [200, 250, 300, 500]; cur: root.st.glass
            fmt: function(v) { return v + " ml" }
            onPicked: function(v) { root.act(["set", "glass", String(v)]) }
          }
          Group {
            title: "Daily goal"; ff: root.ff
            model: [1500, 2000, 2500, 3000, 3500, 4000]; cur: root.st.goal
            fmt: function(v) { return root.litres(v) + " L" }
            onPicked: function(v) { root.act(["set", "goal", String(v)]) }
          }
        }
      }
    }
  }
}
