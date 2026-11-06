# 🥤 Hydrate — Drink Water Reminder for Linux

> *Vibe-coded water reminder and intake tracker for Linux desktops.*

Hydrate is an unobtrusive, lightweight hydration tracker and periodic reminder engine tailored for modern Linux desktops. It displays a live progress counter directly in your status bar, features a vector-rendered water glass that fills as you drink, and triggers persistent reminder notifications that stay on screen until acknowledged.

<table align="center">
  <tr valign="top">
    <td align="center">
      <img src="images/status_on_menu_bar.png" width="320" alt="Status on Menu Bar">
      <br>
      <em>Live Bar Widget with Progress</em>
    </td>
    <td align="center">
      <img src="images/panel.png" width="320" alt="Interactive Panel">
      <br>
      <em>Flyout Panel with 7-Day History & Accordion Settings</em>
    </td>
  </tr>
</table>

---

## ✨ Features

- **Live Status Bar Counter**: Shows real-time intake progress (e.g. `🥤 1.25/2.5 L`) right on your panel.
- **Interactive Flyout Panel**: Vector-rendered animated glass fluid graphic, 7-day intake bar chart, and collapsible settings accordion.
- **Native Bar Integrations**:
  - **Omarchy (Quickshell)**: First-class QML bar widget (`hydrate`) with native styling and fast IPC.
  - **Waybar**: Lightweight JSON module configuration with right-click quick logging.
  - **Polybar, Eww, i3blocks**: Plain-text status outputs via CLI.
- **Persistent Reminders**: Alerts stay visible until you log a glass or snooze for 10 minutes.
- **Keyboard Shortcuts**: Built-in hotkeys (<kbd>Space</kbd> to log, <kbd>U</kbd> to undo, <kbd>P</kbd> to pause/resume).
- **Cross-Distro Ready**: Automated dependency detection for `pacman`, `apt`, `dnf`, `yum`, and `zypper`.
- **Systemd Scheduler**: Robust background checking using user-level systemd timers with zero memory overhead.

---

## 📦 Project Structure

```text
hydrate-linux/
├── install.sh                  # Universal installer and diagnostics tool
├── bin/
│   └── hydrate                 # Main CLI tracking, state manager & scheduler engine
├── omarchy/                    # Native Quickshell (Omarchy) bar & panel plugin
│   ├── manifest.json           # Plugin descriptor (id: "hydrate")
│   ├── BarWidget.qml           # Clickable bar icon, hover tooltip & mouse controls
│   ├── Panel.qml               # Flyout panel, 7-day chart & settings accordion
│   ├── Chip.qml                # Rounded interactive buttons
│   └── GlassView.qml           # Vector fluid graphic rendered via QtQuick.Shapes
├── systemd/                    # User-level timer units
│   ├── hydrate.service
│   └── hydrate.timer
├── waybar/
│   └── hydrate.jsonc           # Custom Waybar module configuration
└── images/                     # Screenshots and assets
```

---

## 🚀 Installation

Clone the repository and run the setup script:

```bash
git clone https://github.com/TejaNune1998/hydrate-linux.git
cd hydrate-linux
chmod +x install.sh
./install.sh install
```

The installer detects your desktop environment and package manager automatically:
- **Quickshell**: Deploys and registers the native QML bar widget (`hydrate`) and themed panel.
- **Waybar**: Writes `~/.config/waybar/hydrate.jsonc` and wires signals to reload the bar.
- **Traditional Desktops (GNOME, KDE Plasma, XFCE)**: Deploys `hydrate.desktop` so you can launch the settings panel directly from your application launcher or bind a global shortcut to `hydrate panel`.

### Setup Options & Flags

```bash
# Force specific front ends:
./install.sh install --quickshell
./install.sh install --waybar

# Skip specific front ends:
./install.sh install --no-quickshell
./install.sh install --no-waybar

# Run diagnostics and verify system dependencies:
./install.sh doctor

# Uninstall binaries and services (preserves intake logs and settings):
./install.sh uninstall

# Completely wipe everything (removes binaries, settings, and daily history):
./install.sh purge
```

---

## 🎮 Usage & Controls

### Bar Controls

| Action | Result |
| :--- | :--- |
| **Hover** | Displays status tooltip with daily total, active schedule, and next reminder time |
| **Left-Click** | Opens the interactive settings panel (or GTK popup via `yad` on Waybar) |
| **Right-Click** | Instantly logs one glass of water (`+250 ml` default) |

### Keyboard Shortcuts (Inside Omarchy Panel)

- <kbd>Space</kbd> — Log one glass
- <kbd>U</kbd> — Undo last entry
- <kbd>P</kbd> — Pause / Resume reminders

---

## ⚙️ CLI & Configuration

You can control Hydrate completely from your terminal or bind individual commands to desktop keybindings:

```bash
# Tracking & Actions
hydrate log       # Add one glass
hydrate undo      # Subtract one glass
hydrate pause     # Pause reminders
hydrate resume    # Resume reminders
hydrate stats     # Show 7-day intake history
hydrate alert     # Trigger a test alert

# Adjust Configuration
hydrate set interval 30   # Remind every 30 minutes
hydrate set start 9       # Start at 9:00 AM
hydrate set end 18        # Stop at 6:00 PM
hydrate set glass 300     # Set glass volume to 300 ml
hydrate set goal 3000     # Set daily target to 3.0 L
```

### Configuration File

Stored at `~/.config/hydrate/config`:

```ini
GOAL_ML=2500
GLASS_ML=250
INTERVAL=45
START_HOUR=8
END_HOUR=22
PAUSED=0
ALERT_STYLE=auto
```

*`ALERT_STYLE` can be set to `auto`, `notify`, or `dialog` (forces a dialog window for environments where notifications dismiss automatically).*

### Daily Intake History

Intake is stored in millilitres per day inside `~/.local/state/hydrate/YYYY-MM-DD.ml`:

```text
~/.local/state/hydrate/
├── 2026-11-04.ml
├── 2026-11-05.ml
├── changed
└── next_due
```

---

## 🐧 Distribution Support

| System / Distribution | Package Manager | Status |
| :--- | :--- | :--- |
| **Arch Linux / Omarchy / EndeavourOS** | `pacman` | ✅ Tested |
| **Debian / Ubuntu / Linux Mint / Pop!_OS** | `apt` | ✅ Supported |
| **Fedora / RHEL / Rocky / AlmaLinux** | `dnf` / `yum` | ✅ Supported (`yad` via EPEL) |
| **openSUSE / Tumbleweed / SLE** | `zypper` | ✅ Supported |

*Core dependencies installed automatically: `libnotify`, `jq`, `util-linux`, `procps`, and optionally `yad`.*

---

## 🔧 Troubleshooting

- **Check setup status**:
  ```bash
  ./install.sh doctor
  ```

- **Inspect background timers & services**:
  ```bash
  systemctl --user list-timers hydrate.timer
  journalctl --user -u hydrate.service -n 20 --no-pager
  ```

- **Omarchy bar widget not showing**:
  Ensure the plugin is enabled and restart the shell:
  ```bash
  omarchy plugin enable hydrate right
  omarchy-restart-shell
  ```

- **Check live Quickshell logs**:
  ```bash
  qs log -p "$OMARCHY_PATH/shell" --tail 50 2>/dev/null || qs log --tail 50
  ```

- **Popup window opens tiled under tiling window managers (Hyprland / Sway)**:
  Add a float rule for windows with app ID / class `hydrate`:
  - **Hyprland:** `windowrule = float, class:^(hydrate)$`
  - **Sway:** `for_window [app_id="hydrate"] floating enable`

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
