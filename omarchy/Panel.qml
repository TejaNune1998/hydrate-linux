import QtQuick
import QtQuick.Controls
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
  readonly property var week: st.week || []
  readonly property int weekCount: st.days === "weekdays" ? 5 : 7
  readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function act(a) { if (hostWidget) hostWidget.act(a) }
  function litres(ml) { return parseFloat((ml / 1000).toFixed(2)).toString() }
  function dayTooltip(index) {
    var value = root.week[index]
    if (value === undefined || value < 0)
      return root.dayNames[index] + " · No intake logged"
    return root.dayNames[index] + " · " + root.litres(Number(value)) + " L"
  }
  function clock(totalMinutes) {
    var total = ((Number(totalMinutes) % 1440) + 1440) % 1440
    var h24 = Math.floor(total / 60)
    var minute = total % 60
    var h12 = h24 % 12 || 12
    return (h12 < 10 ? "0" : "") + h12 + ":" + (minute < 10 ? "0" : "") + minute + " " + (h24 < 12 ? "AM" : "PM")
  }
  function switchPanel(d) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, d)
    return false
  }

  // Handle shortcuts on the panel's actual focus target. Shortcut objects
  // attached to the outer Panel can miss key events because KeyboardPanel
  // owns focus in a separate popup surface.

  // Compact settings form: enter values directly instead of selecting preset chips.
  property string formMessage: ""

  function saveSettings() {
    var interval = Number(intervalField.currentText)
    var startTotal = startField.totalMinutes()
    var endTotal = endField.totalMinutes()
    var startHour = Math.floor(startTotal / 60)
    var startMinute = startTotal % 60
    var endHour = Math.floor(endTotal / 60)
    var endMinute = endTotal % 60
    var glass = Number(glassField.currentText)
    var goalLitres = Number(goalField.currentText)
    var days = daysField.currentIndex === 1 ? "weekdays" : "all"

    if (![30, 45, 60].includes(interval)) {
      formMessage = "Choose a reminder interval of 30, 45, or 60 minutes."
      return
    }
    if (![0, 15, 30, 45].includes(startMinute) || ![0, 15, 30, 45].includes(endMinute)) {
      formMessage = "Choose minutes in 15-minute steps."
      return
    }
    if (startTotal >= endTotal) {
      formMessage = "Start time must be earlier than stop time."
      return
    }
    if (![200, 250, 300, 350, 400].includes(glass)) {
      formMessage = "Choose a glass size between 200 and 400 ml."
      return
    }
    if (![2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6].includes(goalLitres)) {
      formMessage = "Choose a daily goal between 2 and 6 litres."
      return
    }
    if (days !== "all" && days !== "weekdays") {
      formMessage = 'Reminder days must be "all" or "weekdays".'
      return
    }

    if (interval !== root.st.interval) root.act(["set", "interval", String(interval)])
    if (startHour !== root.st.start) root.act(["set", "start", String(startHour)])
    if (startMinute !== (root.st.start_minute || 0)) root.act(["set", "start_minute", String(startMinute)])
    if (endHour !== root.st.end) root.act(["set", "end", String(endHour)])
    if (endMinute !== (root.st.end_minute || 0)) root.act(["set", "end_minute", String(endMinute)])
    if (days !== root.st.days) root.act(["set", "days", days])
    if (glass !== root.st.glass) root.act(["set", "glass", String(glass)])
    var goalMl = Math.round(goalLitres * 1000)
    if (goalMl !== root.st.goal) root.act(["set", "goal", String(goalMl)])

    formMessage = "Settings saved."
    root.showSettings = false
  }

  function loadSettingsIntoForm() {
    var intervalOptions = [30, 45, 60]
    var savedIntervalIndex = intervalOptions.indexOf(Number(root.st.interval || 45))
    intervalField.currentIndex = savedIntervalIndex >= 0 ? savedIntervalIndex : 1
    startField.setTotalMinutes((Number(root.st.start === undefined ? 8 : root.st.start) * 60) + Number(root.st.start_minute || 0))
    endField.setTotalMinutes((Number(root.st.end === undefined ? 22 : root.st.end) * 60) + Number(root.st.end_minute || 0))
    daysField.currentIndex = root.st.days === "weekdays" ? 1 : 0
    var glassOptions = [200, 250, 300, 350, 400]
    var savedGlassIndex = glassOptions.indexOf(Number(root.st.glass || 250))
    glassField.currentIndex = savedGlassIndex >= 0 ? savedGlassIndex : 1
    var goalOptions = [2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6]
    var savedGoalIndex = goalOptions.indexOf(Number(root.st.goal || 2500) / 1000)
    goalField.currentIndex = savedGoalIndex >= 0 ? savedGoalIndex : 1
    formMessage = ""
  }

  onShowSettingsChanged: {
    if (showSettings) Qt.callLater(root.loadSettingsIntoForm)
  }

  component FormField: Column {
    id: field
    property string label
    property string placeholder: ""
    property alias text: input.text
    property alias validator: input.validator
    property int hintMode: Qt.ImhNone
    spacing: Style.space(3)

    Text {
      text: field.label
      color: Qt.alpha(Commons.Color.foreground, 0.65)
      font.family: root.ff
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }
    Rectangle {
      width: field.width
      height: Style.space(34)
      radius: Style.cornerRadius
      color: Qt.alpha(Commons.Color.foreground, 0.07)
      border.width: input.activeFocus ? 1 : 0
      border.color: Commons.Color.accent

      TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Style.space(9)
        anchors.rightMargin: Style.space(9)
        verticalAlignment: TextInput.AlignVCenter
        color: root.barForeground
        font.family: root.ff
        font.pixelSize: Style.font.bodySmall
        selectByMouse: true
        inputMethodHints: field.hintMode
        clip: true
        text: ""
        // The placeholder is kept separate so the saved value remains easy to edit.
        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          text: field.placeholder
          color: Qt.alpha(root.barForeground, 0.35)
          font: input.font
          visible: input.text.length === 0 && !input.activeFocus
        }
      }
    }
  }

  // Small native-looking dropdown used by the quarter-hour time picker.
  component TimeChoice: ComboBox {
    id: choice
    property var choices: []
    model: choices
    height: Style.space(34)
    font.family: root.ff
    font.pixelSize: Style.font.bodySmall
    palette.text: root.barForeground
    palette.buttonText: root.barForeground

    contentItem: Text {
      leftPadding: Style.space(7)
      rightPadding: Style.space(18)
      text: choice.displayText
      color: root.barForeground
      font.family: root.ff
      font.pixelSize: Style.font.bodySmall
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
    indicator: Text {
      text: choice.popup.visible ? "▴" : "▾"
      color: Qt.alpha(root.barForeground, 0.75)
      font.family: root.ff
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
    }
    background: Rectangle {
      radius: Style.cornerRadius
      color: Qt.alpha(Commons.Color.foreground, 0.07)
      border.width: choice.activeFocus ? 1 : 0
      border.color: Commons.Color.accent
    }
    delegate: ItemDelegate {
      required property int index
      required property var modelData
      width: choice.width
      height: Style.space(32)
      highlighted: choice.highlightedIndex === index
      text: modelData
      font.family: root.ff
      font.pixelSize: Style.font.bodySmall
      contentItem: Text {
        text: modelData
        color: root.barForeground
        font: parent.font
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
      }
      background: Rectangle {
        radius: Style.cornerRadius
        color: parent.highlighted ? Qt.alpha(Commons.Color.accent, 0.22) : "transparent"
      }
    }
    popup: Popup {
      y: choice.height + Style.space(3)
      width: choice.width
      padding: Style.space(4)
      implicitHeight: contentItem.implicitHeight + padding * 2
      contentItem: ListView {
        clip: true
        implicitHeight: contentHeight
        model: choice.popup.visible ? choice.delegateModel : null
        currentIndex: choice.highlightedIndex
      }
      background: Rectangle {
        radius: Style.cornerRadius
        color: Commons.Color.background
        border.width: 1
        border.color: Qt.alpha(root.barForeground, 0.25)
      }
    }
  }

  // 12-hour time control: click arrows for hours, choose quarter-hour and AM/PM.
  component TimePicker: Column {
    id: timeField
    property string label
    property int hourValue: 8
    property int minuteValue: 0
    property string periodValue: "AM"
    readonly property bool popupOpen: minuteChoice.popup.visible || periodChoice.popup.visible
    spacing: Style.space(3)

    function totalMinutes() {
      return ((hourValue % 12) + (periodValue === "PM" ? 12 : 0)) * 60 + minuteValue
    }
    function setTotalMinutes(total) {
      var t = ((Number(total) % 1440) + 1440) % 1440
      var h24 = Math.floor(t / 60)
      hourValue = h24 % 12 || 12
      minuteValue = t % 60
      periodValue = h24 < 12 ? "AM" : "PM"
      minuteChoice.currentIndex = minuteValue / 15
      periodChoice.currentIndex = periodValue === "PM" ? 1 : 0
    }
    onMinuteValueChanged: minuteChoice.currentIndex = [0, 15, 30, 45].indexOf(minuteValue)
    onPeriodValueChanged: periodChoice.currentIndex = periodValue === "PM" ? 1 : 0

    Text {
      text: timeField.label
      color: Qt.alpha(Commons.Color.foreground, 0.65)
      font.family: root.ff
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }
    Row {
      width: timeField.width
      spacing: Style.space(3)
      Rectangle {
        width: Style.space(52)
        height: Style.space(34)
        radius: Style.cornerRadius
        color: Qt.alpha(Commons.Color.foreground, 0.07)
        border.width: 0
        Row {
          anchors.fill: parent
          Text {
            width: parent.width - Style.space(18)
            height: parent.height
            text: timeField.hourValue < 10 ? "0" + timeField.hourValue : String(timeField.hourValue)
            color: root.barForeground
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          Column {
            width: Style.space(18)
            height: parent.height
            Rectangle {
              width: parent.width
              height: parent.height / 2
              color: upArea.containsMouse ? Qt.alpha(Commons.Color.accent, 0.18) : "transparent"
              Text { anchors.centerIn: parent; text: "▲"; color: root.barForeground; font.pixelSize: 8 }
              MouseArea {
                id: upArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: timeField.hourValue = timeField.hourValue >= 12 ? 1 : timeField.hourValue + 1
              }
            }
            Rectangle {
              width: parent.width
              height: parent.height / 2
              color: downArea.containsMouse ? Qt.alpha(Commons.Color.accent, 0.18) : "transparent"
              Text { anchors.centerIn: parent; text: "▼"; color: root.barForeground; font.pixelSize: 8 }
              MouseArea {
                id: downArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: timeField.hourValue = timeField.hourValue <= 1 ? 12 : timeField.hourValue - 1
              }
            }
          }
        }
      }
      Text {
        width: Style.space(6)
        height: Style.space(34)
        text: ":"
        color: root.barForeground
        font.family: root.ff
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      TimeChoice {
        id: minuteChoice
        width: Style.space(48)
        choices: ["00", "15", "30", "45"]
        currentIndex: 0
        onActivated: timeField.minuteValue = Number(currentText)
      }
      TimeChoice {
        id: periodChoice
        width: Style.space(48)
        choices: ["AM", "PM"]
        currentIndex: 0
        onActivated: timeField.periodValue = currentText
      }
    }
  }

  component FormSelect: Column {
    id: selectField
    property string label
    property alias currentIndex: selector.currentIndex
    readonly property bool popupOpen: selector.popup.visible
    spacing: Style.space(3)

    Text {
      text: selectField.label
      color: Qt.alpha(Commons.Color.foreground, 0.65)
      font.family: root.ff
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }

    ComboBox {
      id: selector
      width: selectField.width
      height: Style.space(34)
      model: ["Everyday", "Weekdays"]
      currentIndex: 0
      font.family: root.ff
      font.pixelSize: Style.font.bodySmall
      palette.text: root.barForeground
      palette.buttonText: root.barForeground

      contentItem: Text {
        leftPadding: Style.space(9)
        rightPadding: Style.space(28)
        text: selector.displayText
        color: root.barForeground
        font.family: root.ff
        font.pixelSize: Style.font.bodySmall
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      indicator: Text {
        text: selector.popup.visible ? "▴" : "▾"
        color: Qt.alpha(root.barForeground, 0.75)
        font.family: root.ff
        font.pixelSize: Style.font.body
        anchors.right: parent.right
        anchors.rightMargin: Style.space(9)
        anchors.verticalCenter: parent.verticalCenter
      }

      background: Rectangle {
        radius: Style.cornerRadius
        color: Qt.alpha(Commons.Color.foreground, 0.07)
        border.width: selector.activeFocus ? 1 : 0
        border.color: Commons.Color.accent
      }

      delegate: ItemDelegate {
        required property int index
        required property var modelData
        width: selector.width
        height: Style.space(34)
        highlighted: selector.highlightedIndex === index
        text: modelData
        font.family: root.ff
        font.pixelSize: Style.font.bodySmall
        contentItem: Text {
          text: modelData
          color: root.barForeground
          font: parent.font
          verticalAlignment: Text.AlignVCenter
          leftPadding: Style.space(8)
        }
        background: Rectangle {
          radius: Style.cornerRadius
          color: parent.highlighted ? Qt.alpha(Commons.Color.accent, 0.22) : "transparent"
        }
      }

      popup: Popup {
        y: selector.height + Style.space(3)
        width: selector.width
        padding: Style.space(4)
        implicitHeight: contentItem.implicitHeight + padding * 2
        contentItem: ListView {
          clip: true
          implicitHeight: contentHeight
          model: selector.popup.visible ? selector.delegateModel : null
          currentIndex: selector.highlightedIndex
        }
        background: Rectangle {
          radius: Style.cornerRadius
          color: Commons.Color.background
          border.width: 1
          border.color: Qt.alpha(root.barForeground, 0.25)
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

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (!root.opened || event.modifiers !== Qt.NoModifier)
          return

        // Let an open dropdown handle Space and its navigation keys.
        var dropdownOpen = intervalField.popup.visible
            || glassField.popup.visible
            || goalField.popup.visible
            || daysField.popupOpen
            || startField.popupOpen
            || endField.popupOpen
        if (dropdownOpen)
          return

        if (event.key === Qt.Key_Space) {
          root.act(["log"])
          event.accepted = true
        } else if (event.key === Qt.Key_U || event.key === Qt.Key_u) {
          root.act(["undo"])
          event.accepted = true
        } else if (event.key === Qt.Key_P || event.key === Qt.Key_p) {
          root.act([root.st.paused === 1 ? "resume" : "pause"])
          event.accepted = true
        }
      }

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
                : root.st.off === 1 ? "Weekend: reminders off"
                : root.st.next ? "Next reminder " + root.st.next : ""
            color: Qt.alpha(root.barForeground, 0.65)
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
          }
        }

        // glass + numbers (falls back to a plain bar if the glass can't load)
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

        // this week (mon..sun, or mon..fri when reminders are weekdays only)
        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
            Text {
              width: parent.width - avg.implicitWidth
              text: "THIS WEEK"
              color: Qt.alpha(Commons.Color.foreground, 0.6)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Text {
              id: avg
              text: "Last week avg " + (root.st.prev_avg >= 0 ? root.litres(root.st.prev_avg) + " L" : "-")
              color: Qt.alpha(root.barForeground, 0.65)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
          }
          Row {
            id: bars
            width: parent.width
            height: Style.space(56)
            spacing: Style.space(8)
            Repeater {
              model: root.weekCount
              Item {
                width: (bars.width - bars.spacing * (root.weekCount - 1)) / root.weekCount
                height: bars.height
                Rectangle {
                  readonly property real v: root.week[index] === undefined ? -1 : root.week[index]
                  anchors.bottom: parent.bottom
                  width: parent.width
                  radius: Style.cornerRadius
                  height: v < 0 ? Style.space(3) : Math.max(Style.space(3), parent.height * Math.min(1, v / Math.max(1, root.st.goal || 1)))
                  color: v < 0 ? Qt.alpha(Commons.Color.foreground, 0.12)
                       : index === root.st.today ? Commons.Color.accent : Qt.alpha(Commons.Color.accent, 0.4)
                }
                MouseArea {
                  id: barHover
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  ToolTip.visible: containsMouse
                  ToolTip.text: root.dayTooltip(index)
                  ToolTip.delay: 250
                  ToolTip.timeout: 3000
                }
              }
            }
          }
          Row {
            width: parent.width
            spacing: bars.spacing
            Repeater {
              model: root.weekCount
              Item {
                width: (bars.width - bars.spacing * (root.weekCount - 1)) / root.weekCount
                height: dayLabel.implicitHeight
                Text {
                  id: dayLabel
                  anchors.fill: parent
                  horizontalAlignment: Text.AlignHCenter
                  text: root.dayNames[index]
                  color: Qt.alpha(root.barForeground, index === root.st.today ? 0.95 : 0.6)
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: index === root.st.today
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  ToolTip.visible: containsMouse
                  ToolTip.text: root.dayTooltip(index)
                  ToolTip.delay: 250
                  ToolTip.timeout: 3000
                }
              }
            }
          }
        }

        // settings (collapsed by default)
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
              text: "Every " + (root.st.interval || 0) + " min · "
                    + root.clock((Number(root.st.start || 0) * 60) + Number(root.st.start_minute || 0))
                    + " to " + root.clock((Number(root.st.end || 0) * 60) + Number(root.st.end_minute || 0))
                    + (root.st.days === "weekdays" ? " · weekdays" : "")
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

          Grid {
            id: settingsGrid
            width: parent.width
            columns: 2
            columnSpacing: Style.space(12)
            rowSpacing: Style.space(8)

            Column {
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              spacing: Style.space(3)
              Text {
                text: "REMIND EVERY (MIN)"
                color: Qt.alpha(Commons.Color.foreground, 0.65)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
              }
              TimeChoice {
                id: intervalField
                width: parent.width
                choices: ["30", "45", "60"]
                currentIndex: 1
              }
            }
            Column {
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              spacing: Style.space(3)
              Text {
                text: "GLASS SIZE (ML)"
                color: Qt.alpha(Commons.Color.foreground, 0.65)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
              }
              TimeChoice {
                id: glassField
                width: parent.width
                choices: ["200", "250", "300", "350", "400"]
                currentIndex: 1
              }
            }
            TimePicker {
              id: startField
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              label: "START TIME"
            }
            TimePicker {
              id: endField
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              label: "END TIME"
            }
            FormSelect {
              id: daysField
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              label: "REMINDER DAYS"
            }
            Column {
              width: (settingsGrid.width - settingsGrid.columnSpacing) / 2
              spacing: Style.space(3)
              Text {
                text: "DAILY GOAL (L)"
                color: Qt.alpha(Commons.Color.foreground, 0.65)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
              }
              TimeChoice {
                id: goalField
                width: parent.width
                choices: ["2", "2.5", "3", "3.5", "4", "4.5", "5", "5.5", "6"]
                currentIndex: 0
              }
            }
          }

          Text {
            visible: root.formMessage !== ""
            width: parent.width
            text: root.formMessage
            color: root.formMessage === "Settings saved." ? Commons.Color.accent : "#E08A8A"
            font.family: root.ff
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Row {
            spacing: Style.space(6)
            Chip {
              label: "Save"
              accentFill: true
              fontFamily: root.ff
              onClicked: root.saveSettings()
            }
            Chip {
              label: "Cancel"
              fontFamily: root.ff
              onClicked: { root.loadSettingsIntoForm(); root.showSettings = false }
            }
          }
        }
      }
    }
  }
}
