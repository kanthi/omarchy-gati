# Gati (गति) — Focus Timer for Omarchy Shell

<p align="center">
  <img src="assets/gati_demo.gif" alt="Gati Focus Timer Walkthrough" width="100%" />
</p>

<p align="center">
  <em>Steady momentum, effortless flow, and purposeful deep work directly inside the Omarchy top bar.</em><br/>
  <strong>🎬 High-Definition Video Walkthrough:</strong> <a href="assets/gati_demo.mp4"><code>assets/gati_demo.mp4</code></a> (1080p / 60s detailed walkthrough)
</p>

---

## 🧘 What is Gati?

Gati (गति) is a dynamic Sanskrit word from the root verb *gam*, meaning "to move," "to progress," or "to flow." In productivity and deep work, Gati represents:

- **Forward Momentum:** Uninterrupted focus blocks moving you steadily toward completion.
- **The Pace of Flow:** The optimal tempo where you are neither rushing nor lagging—immersed completely in the zone.
- **Attainment:** Structured cycles guiding each session toward your ultimate daily goals.

---

## 🖱️ Top Bar Quick Interactions

Gati lives directly in your Omarchy status bar as a scalable geometric infinity mark with live phase coloring and an optional countdown timer:

| Action | Interaction | Description |
| :--- | :--- | :--- |
| **Left Click** | `Toggle Panel` | Opens or closes the floating Popout Control Panel. |
| **Right Click** | `Quick Start / Pause` | Starts or pauses the active timer directly from the status bar without opening the panel. |
| **Middle Click** | `Quick Reset` | Resets the active session and timer back to the initial duration. |

---

## 🔄 Complete Workflow Lifecycle

### 1. Top Bar Status & Live Indicator
- Minimalist geometric infinity glyph with optional countdown text.
- Fluid color transitions reflecting timer phase:
  - **Focus Mode:** Pastel Coral (`#f59999`)
  - **Paused State:** Warm Amber / Peach (`#fad28c`)
  - **Break Mode:** Pastel Mint / Sage (`#99d9b8`)
  - **Long Break:** Pastel Lavender / Lilac (`#c2aef2`)

### 2. Focus Session & Harmonic Kinetic Waveform
- Large monospace countdown display with embossed `FOCUS` subtitle.
- **28-Bar Harmonic Kinetic Waveform:** Smoothly oscillates in real time according to physical harmonic frequencies while active, freezing gently when paused.
- **Session Dots:** Minimalist floating dots tracking progress through the current interval cycle (e.g. 4 focus sessions per cycle).
- **Integrated Control Strip:** Instant buttons for **Reset**, **Play/Pause**, **Skip**, **Focus Stats** (`󰄧`), and **Settings** (`󰒓`).

### 3. Focus Statistics & Momentum Analytics Dashboard
Switch instantly to the analytics dashboard directly from the panel:
- **Hero Metrics:** Today's total focus time, completed sessions, daily goal completion bar, and active streak flame counter (`󰈸`).
- **Daily Flow Track Matrix:** Interactive visual matrix displaying all focus sessions and break blocks for today with remaining session projections.
- **Multi-Period Analytics:** Dedicated tabs for **Daily**, **Weekly** (rolling 7-day sparkline bar chart), **Monthly**, and **Yearly** performance.
- **Lifetime Tracking:** Persisted cumulative focus hours and lifetime sessions completed across reboots.

### 4. Workflow Presets, Audio Themes & Settings
Configure your optimal workflow directly from the settings view:
- **Workflow Presets:**
  - **Classic:** 25m Focus / 5m Short Break / 15m Long Break (every 4 sessions)
  - **Deep:** 50m Focus / 10m Short Break / 20m Long Break (every 3 sessions)
  - **Ultra:** 90m Focus / 15m Short Break / 30m Long Break (every 2 sessions)
  - **Custom:** Independent duration sliders (1–180m focus, 1–60m break, 1–16 interval count)
- **Acoustic Sound Cues:**
  - **Zen Bowl:** Resonant Tibetan singing bell (`zen_bell.wav`)
  - **Crystal:** Clear acoustic glass chime (`crystal_chime.wav`)
  - **Marimba:** Soft wooden marimba tone (`marimba.wav`)
  - Volume slider (0–100%) and instant audio preview test (`Play`).
- **Automation & Notifications:**
  - **Auto-start Breaks:** Automatically initiate break countdown when focus ends.
  - **Auto-start Focus:** Automatically begin next focus block when break countdown expires.
  - **Desktop Alerts:** Gentle 10-second notification toast before each break starts.
  - **Daily Reset:** Automatic midnight statistics reset or manual on demand.

### 5. Fullscreen Glass Break Overlay
- Automatic full-screen takeover when a rest break begins.
- **GPU-Accelerated Wallpaper Shader Blur:** Softly blurs your current desktop wallpaper behind an elegant translucent glass card.
- Monospace break countdown, breathing harmonic wave, session progress dots, and active sound indicator pill.
- **Action Controls:** Instant **`+5 min`** extension, **Pause/Resume**, and **`Skip`**.
- **Break Done State:** Displays **`00:00 BREAK COMPLETE`** with a prominent **`▶ Start Focus`** action pill to immediately jump into the next focus session.

---

## 📹 Demo Walkthrough Breakdown

The included 64-second walkthrough ([`assets/gati_demo.mp4`](assets/gati_demo.mp4)) demonstrates each workflow stage in detail:

1. **0:00 – 0:05:** Top Bar presence on desktop with infinity glyph and countdown.
2. **0:05 – 0:15:** Popout Panel activation, focus mode start, and real-time 28-bar harmonic kinetic waveform oscillation.
3. **0:15 – 0:23:** Live session controls (instant pause with peach color transition, resume, and reset).
4. **0:23 – 0:32:** Focus Statistics dashboard (Daily tab, streak flame, daily goal completion bar, and flow matrix blocks).
5. **0:32 – 0:42:** Settings & Audio customization (Workflow presets: Classic/Deep/Ultra/Custom, Zen Bowl/Crystal/Marimba chimes, and volume toggles).
6. **0:42 – 0:47:** Fluid transition back to timer view.
7. **0:47 – 0:59:** Fullscreen glass Break Overlay with blurred desktop backdrop, breathing wave, `+5 min` extension, and skip/start focus.
8. **0:59 – 1:04:** Cycle completion and return to steady desktop flow.

---

## ⌨️ IPC Interface & Headless Automation

Control Gati headlessly, query analytics, or bind actions to your window manager keyboard shortcuts via `omarchy-shell`:

```bash
# Timer Controls
omarchy-shell io.github.kanthi.gati start              # Start focus session
omarchy-shell io.github.kanthi.gati pause              # Pause session
omarchy-shell io.github.kanthi.gati toggle             # Toggle between start and pause
omarchy-shell io.github.kanthi.gati reset              # Reset current session
omarchy-shell io.github.kanthi.gati skip               # Skip to next phase
omarchy-shell io.github.kanthi.gati startBreak 5       # Trigger immediate break with custom minutes
omarchy-shell io.github.kanthi.gati extendBreak        # Extend active break by 5 minutes
omarchy-shell io.github.kanthi.gati continueFocus      # Begin next focus session after break

# Query Status & Analytics
omarchy-shell io.github.kanthi.gati status             # Formatted string: "Paused [Focus]: 25:00 (Session 2/4)"
omarchy-shell io.github.kanthi.gati statusJson         # Machine-readable JSON status payload
omarchy-shell io.github.kanthi.gati stats              # Today's stats summary string
omarchy-shell io.github.kanthi.gati stats day          # Query period stats: day, week, month, year
omarchy-shell io.github.kanthi.gati statsJson          # Detailed statistics in JSON format

# View Navigation
omarchy-shell io.github.kanthi.gati open               # Open popout panel (Timer view)
omarchy-shell io.github.kanthi.gati close              # Close popout panel
omarchy-shell io.github.kanthi.gati openStats          # Open popout panel directly to Focus Statistics
omarchy-shell io.github.kanthi.gati openSettings       # Open popout panel directly to Settings

# Sound Themes & Audio
omarchy-shell io.github.kanthi.gati toggleSound        # Toggle sound on/off
omarchy-shell io.github.kanthi.gati setSound true      # Enable or mute sound
omarchy-shell io.github.kanthi.gati setSoundTheme zen  # Set theme: zen, crystal, marimba
omarchy-shell io.github.kanthi.gati setSoundVolume 80  # Set volume: 0 to 100
omarchy-shell io.github.kanthi.gati testSound          # Play test chime

# Notifications & Automation
omarchy-shell io.github.kanthi.gati toggleNotifications # Toggle break notification toasts
omarchy-shell io.github.kanthi.gati testNotification   # Dispatch test notification
omarchy-shell io.github.kanthi.gati toggleAutoBreak    # Toggle auto-starting breaks
omarchy-shell io.github.kanthi.gati toggleAutoFocus    # Toggle auto-starting next focus session
```

---

## 🧪 Testing

Run the reproducible portable test suite:

```bash
./tests/run
```

The test runner validates:
- Manifest syntax, schema compliance, and setting defaults.
- Core QML components, entry points, and audio assets.
- `safe_state_io.py` persistence boundaries (rejection of symlinks, path traversals, non-JSON data, and oversized payloads).
- Pure JavaScript calculation tables and geometric wave functions via Node.
- Live `omarchy-shell` IPC endpoints (`status`, `statusJson`, `statsSummary`).
- Official host validator (`omarchy plugin validate`).

---

## 📦 Installation & Management

Install and enable Gati using the official Omarchy plugin manager:

```bash
# Install and enable Gati directly from GitHub
omarchy plugin add https://github.com/kanthi/omarchy-gati --enable
```

### Managing Gati

```bash
# Update Gati to the latest release
omarchy plugin update io.github.kanthi.gati

# Enable or disable the widget in your top bar
omarchy plugin enable io.github.kanthi.gati
omarchy plugin disable io.github.kanthi.gati

# Remove Gati
omarchy plugin remove io.github.kanthi.gati
```

*(CLI shorthand aliases like `omarchy-plugin-add` and `omarchy-plugin-remove` are also supported.)*

---

## 🔒 Security, Data & Persistence

- **Zero Network Activity:** Gati operates entirely locally and makes zero outbound network requests.
- **Strict Bounded Persistence:** State is persisted to `${XDG_STATE_HOME:-~/.local/state}/omarchy/gati-state.json`.
- **Safe I/O Helper (`safe_state_io.py`):**
  - Enforces `O_NOFOLLOW` and `O_NONBLOCK` to prevent symlink attacks and blocking calls.
  - Constrains file paths strictly within `$XDG_STATE_HOME` or `$HOME`.
  - Verifies file and parent directory ownership against the current user UID.
  - Hard byte cap of 64 KiB on all reads and writes to eliminate buffer or memory exhaustion risks.
  - Validates JSON grammar before disk write and emission.
  - Performs atomic replacement via fsync'd `0600` temporary files (`os.replace`).
- **Input Sanitization & Range Checks:** All timer fields are strictly validated against numeric limits and permitted enum states.

---

## 📋 Dependencies

| Dependency | Purpose |
| :--- | :--- |
| **Omarchy Desktop** | `omarchy-shell`, `Quickshell`, `QtQuick` |
| **Python 3** | Standard Python 3 interpreter for executing `safe_state_io.py` |

Runs entirely with standard user permissions; no administrative privileges, background daemons, or third-party packages required.

---

## 📄 License

MIT. See [LICENSE](LICENSE).
