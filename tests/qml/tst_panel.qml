import QtQuick
import QtTest

// Keyboard and week-navigation tests for omarchy/Panel.qml, run against stand-in shell modules (see run-qml.sh)
Item {
  id: root; width: 480; height: 1000
  property var calls: []
  property var weekRequests: []

  QtObject {
    id: host
    property var weekData: null
    property var st: ({ ml: 500, goal: 2500, glass: 250, interval: 45, snooze: 10, start: 8, end: 22, start_minute: 0, end_minute: 0,
                        paused: 0, days: "all", custom: 0, off: 0, next: "", today: 2, week: [2250, 1750, 500, -1, -1, -1, -1],
                        dayoff: [0, 0, 0, 0, 0, 0, 0], prev_avg: 2700, min_offset: -2 })
    function act(a) { root.calls.push(a.join(" ")) }
    function loadWeek(o) { root.weekRequests.push(o) }
  }

  Loader { id: ld; source: "../../omarchy/Panel.qml"; onLoaded: item.hostWidget = host }

  TestCase {
    name: "Panel"; when: windowShown
    property var panel: ld.item

    function init() {
      root.calls = []; root.weekRequests = []
      panel.weekOffset = 0; panel.kbIndex = -1; panel.showSettings = false
      host.weekData = null
      wait(60)
    }
    function stopItems() { return panel.stops().map(function(s) { return s.item }) }

    // ---- plain shortcuts
    function test_space_logs()   { keyClick(Qt.Key_Space); compare(root.calls, ["log"]) }
    function test_u_undoes()     { keyClick(Qt.Key_U); compare(root.calls, ["undo"]) }
    function test_p_pauses()     { keyClick(Qt.Key_P); compare(root.calls, ["pause"]) }
    function test_p_resumes() {
      host.st = Object.assign({}, host.st, { paused: 1 }); keyClick(Qt.Key_P); compare(root.calls, ["resume"])
      host.st = Object.assign({}, host.st, { paused: 0 })
    }
    function test_modifiers_and_other_keys_are_ignored() {
      keyClick(Qt.Key_U, Qt.ShiftModifier); keyClick(Qt.Key_Space, Qt.ControlModifier); keyClick(Qt.Key_X); keyClick(Qt.Key_Return)
      compare(root.calls, [])
    }

    // ---- weeks
    function test_left_goes_to_the_previous_week() {
      keyClick(Qt.Key_Left)
      compare(panel.weekOffset, -1); compare(root.weekRequests, [-1])
    }
    function test_right_returns_and_never_passes_this_week() {
      keyClick(Qt.Key_Left); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
      compare(panel.weekOffset, 0)
    }
    function test_left_stops_at_the_oldest_week_with_data() {
      keyClick(Qt.Key_Left); keyClick(Qt.Key_Left); keyClick(Qt.Key_Left); keyClick(Qt.Key_Left)
      compare(panel.weekOffset, -2)
    }
    function test_scrolled_week_shows_its_own_data_and_title() {
      keyClick(Qt.Key_Left)
      host.weekData = { offset: -1, start: "2026-10-26", week: [2000, 3000, 0, 2500, 2000, 4000, 0], avg: 2700, prev_avg: 1000, min_offset: -2, today: -1 }
      wait(60)
      compare(panel.week[1], 3000); compare(panel.weekTitle(), "LAST WEEK"); compare(panel.viewToday, -1)
      keyClick(Qt.Key_Left)
      host.weekData = { offset: -2, start: "2026-10-19", week: [1000, 0, 0, 0, 0, 0, 0], avg: 1000, prev_avg: -1, min_offset: -2, today: -1 }
      wait(60)
      compare(panel.weekTitle(), "OCT 19 - OCT 25")
    }
    function test_chart_shows_all_seven_days_even_with_weekdays_only() {
      host.st = Object.assign({}, host.st, { days: "weekdays", dayoff: [0, 0, 0, 0, 0, 1, 1] })
      compare(panel.weekCount, 7)
      host.st = Object.assign({}, host.st, { days: "all", dayoff: [0, 0, 0, 0, 0, 0, 0] })
    }

    // ---- keyboard selection of controls
    function test_down_selects_and_space_uses_the_selected_control() {
      keyClick(Qt.Key_Down); compare(panel.kbIndex, 0)
      keyClick(Qt.Key_Down); compare(panel.kbIndex, 1)          // undo
      keyClick(Qt.Key_Space); compare(root.calls, ["undo"])      // Space uses the selection, it does not log
    }
    function test_enter_uses_the_selected_control() {
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Down)   // pause
      keyClick(Qt.Key_Return); compare(root.calls, ["pause"])
    }
    function test_up_from_nothing_selects_the_last_control() {
      keyClick(Qt.Key_Up); compare(panel.kbIndex, panel.stops().length - 1)
    }
    function test_selection_is_clamped() {
      for (var i = 0; i < 40; i++) keyClick(Qt.Key_Down)
      compare(panel.kbIndex, panel.stops().length - 1)
    }
    function test_escape_clears_the_selection_first() {
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Escape)
      compare(panel.kbIndex, -1)
    }
    function test_week_arrows_are_reachable_by_keyboard() {
      for (var i = 0; i < 4; i++) keyClick(Qt.Key_Down)                    // week-back button
      compare(stopItems()[panel.kbIndex], panel.stops()[3].item)
      keyClick(Qt.Key_Return); compare(panel.weekOffset, -1)
    }
    function test_selection_ring_follows_the_control() {
      keyClick(Qt.Key_Down); wait(60)
      var ring = panel.stops()[0].item
      verify(ring.width > 0)
    }

    // ---- settings form by keyboard
    function openSettings() {
      for (var i = 0; i < 6; i++) keyClick(Qt.Key_Down)                    // settings row
      keyClick(Qt.Key_Return); wait(120)
    }
    function test_settings_row_opens_and_closes_by_keyboard() {
      openSettings(); compare(panel.showSettings, true)
      compare(panel.stops().length, 19)
      keyClick(Qt.Key_Up); keyClick(Qt.Key_Return); wait(60)               // back on the row: Enter closes
    }
    function test_left_right_change_the_selected_setting_and_save_applies_it() {
      openSettings()
      keyClick(Qt.Key_Down)                                                // interval (45)
      keyClick(Qt.Key_Right)                                               // 60
      for (var i = 0; i < 11; i++) keyClick(Qt.Key_Down)                   // Save
      keyClick(Qt.Key_Return); wait(60)
      compare(root.calls, ["set interval 60"])
      compare(panel.showSettings, false)
    }
    function test_time_parts_are_adjusted_one_by_one() {
      openSettings()
      for (var i = 0; i < 3; i++) keyClick(Qt.Key_Down)                    // start hour
      keyClick(Qt.Key_Right)                                               // 08 -> 09
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)                        // start minutes 00 -> 15
      for (i = 0; i < 8; i++) keyClick(Qt.Key_Down)                        // Save
      keyClick(Qt.Key_Return); wait(60)
      compare(root.calls, ["set start 9", "set start_minute 15"])
    }
    function test_snooze_and_days_can_be_set() {
      openSettings()
      for (var i = 0; i < 9; i++) keyClick(Qt.Key_Down)                    // days
      keyClick(Qt.Key_Right)                                               // weekdays
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Right) // snooze 10 -> 15
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); wait(60)
      compare(root.calls, ["set days weekdays", "set snooze 15"])
    }
    function test_cancel_discards_changes() {
      openSettings()
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)
      for (var i = 0; i < 12; i++) keyClick(Qt.Key_Down)                   // Cancel
      keyClick(Qt.Key_Return); wait(60)
      compare(root.calls, []); compare(panel.showSettings, false)
    }

    // ---- dropdowns never keep the keyboard focus
    function test_shortcuts_work_after_a_dropdown_was_used_with_the_mouse() {
      panel.showSettings = true; wait(120)
      var combo = panel.stops()[6].item
      combo.popup.open(); wait(60); combo.popup.close(); wait(60)
      keyClick(Qt.Key_Space); compare(root.calls, ["log"])
    }
    function test_shortcuts_work_after_the_form_was_closed() {
      panel.showSettings = true; wait(120)
      panel.showSettings = false; wait(120)
      keyClick(Qt.Key_U); compare(root.calls, ["undo"])
    }
    function test_p_does_not_change_the_am_pm_box() {
      panel.showSettings = true; wait(120)
      var before = panel.stops()[10].item.currentText
      keyClick(Qt.Key_P)
      compare(panel.stops()[10].item.currentText, before)
      compare(root.calls, ["pause"])
    }
  }
}
