import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// High-Performance Optimized Gati Focus Timer Top Bar Widget
BarWidget {
  id: root
  moduleName: "io.github.kanthi.gati"

  property bool panelRequested: false

  // Soft Pleasant Pastel Color Palette
  readonly property color normalColor: bar ? bar.barForeground : Color.foreground
  readonly property color focusTargetColor: Qt.rgba(0.96, 0.60, 0.60, 1.0)      // Pastel Coral / Rose
  readonly property color shortBreakTargetColor: Qt.rgba(0.60, 0.85, 0.72, 1.0) // Pastel Mint / Sage
  readonly property color longBreakTargetColor: Qt.rgba(0.76, 0.68, 0.95, 1.0)  // Pastel Lavender / Lilac
  readonly property color pausedColor: Qt.rgba(0.98, 0.78, 0.55, 1.0)          // Pastel Peach / Warm Amber

  readonly property color focusColor: focusTargetColor
  readonly property color shortBreakColor: shortBreakTargetColor
  readonly property color longBreakColor: longBreakTargetColor

  readonly property color targetPhaseColor: {
    switch (Service.state) {
      case Model.STATE_WORK: return focusTargetColor
      case Model.STATE_SHORT_BREAK: return shortBreakTargetColor
      case Model.STATE_LONG_BREAK: return longBreakTargetColor
      default: return focusTargetColor
    }
  }

  function lerpColor(c1, c2, fraction) {
    var f = Math.max(0.0, Math.min(1.0, fraction))
    var r = c1.r + (c2.r - c1.r) * f
    var g = c1.g + (c2.g - c1.g) * f
    var b = c1.b + (c2.b - c1.b) * f
    var a1 = c1.a !== undefined ? c1.a : 1.0
    var a2 = c2.a !== undefined ? c2.a : 1.0
    var a = a1 + (a2 - a1) * f
    return Qt.rgba(r, g, b, a)
  }

  readonly property color activePhaseColor: {
    if (Service.state === Model.STATE_IDLE || (!Service.running && Service.remainingSeconds === Service.totalSeconds)) {
      return normalColor
    }
    if (!Service.running && Service.state !== Model.STATE_IDLE) {
      return pausedColor
    }
    return targetPhaseColor
  }

  // Responsive HiDPI Icon Metrics mapped to bar font and DPI scale
  readonly property real baseIconSize: Math.max(12, Style.font.icon)
  readonly property real iconHeight: Math.max(9.5, Math.round(baseIconSize * 0.72))
  readonly property real iconWidth: Math.round(iconHeight * 1.45)
  readonly property real iconStrokeWidth: Math.max(1.2, Math.round((iconHeight / 11.0) * 1.35 * 10) / 10)

  property bool showTimerInBar: (root.settings && root.settings.showTimerInBar !== undefined) ? (root.settings.showTimerInBar === true) : true
  readonly property real measuredWidth: showTimerInBar
    ? (iconWidth + Style.space(6) + timerText.implicitWidth + Style.space(16))
    : Style.bar.iconSlot

  implicitWidth: measuredWidth
  implicitHeight: button.implicitHeight

  readonly property string infinityPath: "M 12 8 L 6.5 2 L 3.5 2 C 1.5 2 0 3.8 0 6 L 0 10 C 0 12.2 1.5 14 3.5 14 L 6.5 14 L 17.5 2 L 20.5 2 C 22.5 2 24 3.8 24 6 L 24 10 C 24 12.2 22.5 14 20.5 14 L 17.5 14 L 12 8 Z"
  readonly property string displayText: showTimerInBar ? ("∞  " + Model.formatTime(Service.remainingSeconds)) : "∞"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    panelRequested = true
    if (panelLoader.item) panelLoader.item.open()
    else Qt.callLater(function() { if (panelLoader.item) panelLoader.item.open() })
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (!panelRequested) {
      panelRequested = true
      Qt.callLater(function() { if (panelLoader.item) panelLoader.item.open() })
    } else {
      if (panelLoader.item) panelLoader.item.toggle()
    }
  }

  function syncSettings() {
    var rawWork = setting("workDurationMin", 25)
    var rawShort = setting("shortBreakMin", 5)
    var rawLong = setting("longBreakMin", 15)
    var rawMax = setting("longBreakInterval", 4)
    var rawReset = setting("resetDaily", true)
    var rawMode = setting("workflowMode", "classic")
    var rawAutoBreak = setting("autoStartBreaks", true)
    var rawAutoWork = setting("autoStartWork", false)

    if (root.settings && root.settings.workflowMode !== undefined) {
      Service.workflowMode = rawMode || "classic"
    }
    if (root.settings && root.settings.workDurationMin !== undefined) {
      Service.workDurationMin = (typeof rawWork === "number" && Number.isFinite(rawWork)) ? Math.min(180, Math.max(1, Math.floor(rawWork))) : 25
    }
    if (root.settings && root.settings.shortBreakMin !== undefined) {
      Service.shortBreakMin = (typeof rawShort === "number" && Number.isFinite(rawShort)) ? Math.min(60, Math.max(1, Math.floor(rawShort))) : 5
    }
    if (root.settings && root.settings.longBreakMin !== undefined) {
      Service.longBreakMin = (typeof rawLong === "number" && Number.isFinite(rawLong)) ? Math.min(120, Math.max(1, Math.floor(rawLong))) : 15
    }
    if (root.settings && root.settings.longBreakInterval !== undefined) {
      Service.maxSessions = (typeof rawMax === "number" && Number.isFinite(rawMax)) ? Math.min(16, Math.max(1, Math.floor(rawMax))) : 4
    }
    if (root.settings && root.settings.resetDaily !== undefined) {
      Service.resetDaily = (typeof rawReset === "boolean") ? rawReset : true
    }
    if (root.settings && root.settings.autoStartBreaks !== undefined) {
      Service.autoStartBreaks = (typeof rawAutoBreak === "boolean") ? rawAutoBreak : true
    }
    if (root.settings && root.settings.autoStartWork !== undefined) {
      Service.autoStartWork = (typeof rawAutoWork === "boolean") ? rawAutoWork : false
    }

    showTimerInBar = (settings && settings.showTimerInBar !== undefined) ? (settings.showTimerInBar === true) : true
    if (!Service.running && (Service.state === Model.STATE_IDLE || Service.state === Model.STATE_WORK)) {
      Service.totalSeconds = Service.workDurationMin * 60
      Service.remainingSeconds = Service.totalSeconds
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("owner" in target) target.owner = button
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    syncSettings()
  }
  Component.onCompleted: syncSettings()

  // On-Demand Lazy Loaded Popout Panel (Loaded only on first click / request)
  Loader {
    id: panelLoader
    active: root.panelRequested || root.opened
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Fullscreen Break Overlay (Maps to Quickshell screens on break)
  BreakOverlay {}

  IpcHandler {
    target: "io.github.kanthi.gati"

    function start(): string { Service.start(); return "started" }
    function startBreak(minutes: int): string {
      var minVal = (typeof minutes === "number" && Number.isFinite(minutes) && minutes > 0) ? Math.min(180, Math.floor(minutes)) : 5
      Service.startBreak(minVal)
      return "break_started"
    }
    function pause(): string { Service.pause(); return "paused" }
    function toggle(): string { Service.toggle(); return "toggled" }
    function reset(): string { Service.reset(); return "reset" }
    function skip(): string { Service.skip(); return "skipped" }
    function extendBreak(): string { Service.extendBreak(5); return "extended" }
    function continueFocus(): string { Service.continueToNextFocus(); return "continued" }
    function toggleSound(): string {
      Service.soundEnabled = !Service.soundEnabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ soundEnabled: Service.soundEnabled })
      return Service.soundEnabled ? "sound_on" : "sound_muted"
    }
    function setSound(enabled: bool): string {
      Service.soundEnabled = enabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ soundEnabled: Service.soundEnabled })
      return enabled ? "sound_on" : "sound_muted"
    }
    function setSoundVolume(volume: int): string {
      var vol = Math.max(0, Math.min(100, Math.floor(volume)))
      Service.soundVolume = vol
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ soundVolume: vol })
      return "volume_set:" + vol
    }
    function setSoundTheme(theme: string): string {
      if (theme === "zen" || theme === "crystal" || theme === "marimba") {
        Service.soundTheme = theme
        Service.saveState()
        if (panelLoader.item) panelLoader.item.persist({ soundTheme: theme })
        Service.playSound("focus_complete")
        return "theme_set:" + theme
      }
      return "invalid_theme"
    }
    function testSound(): string {
      Service.playSound("focus_complete")
      return "playing"
    }
    function testNotification(): string {
      Service.sendNotification("Break in 10s ☕", "Wrap up your work — your 5-minute break is about to begin.", "normal")
      return "notified"
    }
    function toggleNotifications(): string {
      Service.notificationsEnabled = !Service.notificationsEnabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ notificationsEnabled: Service.notificationsEnabled })
      return Service.notificationsEnabled ? "notifications_on" : "notifications_off"
    }
    function setNotifications(enabled: bool): string {
      Service.notificationsEnabled = enabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ notificationsEnabled: Service.notificationsEnabled })
      return enabled ? "notifications_on" : "notifications_off"
    }
    function toggleAutoBreak(): string {
      Service.autoStartBreaks = !Service.autoStartBreaks
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ autoStartBreaks: Service.autoStartBreaks })
      return Service.autoStartBreaks ? "auto_break_on" : "auto_break_off"
    }
    function setAutoBreak(enabled: bool): string {
      Service.autoStartBreaks = enabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ autoStartBreaks: Service.autoStartBreaks })
      return enabled ? "auto_break_on" : "auto_break_off"
    }
    function toggleAutoFocus(): string {
      Service.autoStartWork = !Service.autoStartWork
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ autoStartWork: Service.autoStartWork })
      return Service.autoStartWork ? "auto_focus_on" : "auto_focus_off"
    }
    function setAutoFocus(enabled: bool): string {
      Service.autoStartWork = enabled
      Service.saveState()
      if (panelLoader.item) panelLoader.item.persist({ autoStartWork: Service.autoStartWork })
      return enabled ? "auto_focus_on" : "auto_focus_off"
    }
    function open(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.currentView = "timer"
      else Qt.callLater(function() { if (panelLoader.item) panelLoader.item.currentView = "timer" })
    }
    function close(): void { root.close() }
    function openSettings(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.currentView = "settings"
      else Qt.callLater(function() { if (panelLoader.item) panelLoader.item.currentView = "settings" })
    }
    function openStats(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.currentView = "stats"
      else Qt.callLater(function() { if (panelLoader.item) panelLoader.item.currentView = "stats" })
    }
    function status(): string {
      var stateLbl = Model.stateLabel(Service.state)
      var modeStr = Service.running ? "Running" : "Paused"
      return modeStr + " [" + stateLbl + "]: " + Model.formatTime(Service.remainingSeconds)
        + " (Session " + (Service.sessionIndex + 1) + "/" + Service.maxSessions + ")"
    }
    function statusJson(): string {
      return JSON.stringify({
        state: Service.state,
        stateLabel: Model.stateLabel(Service.state),
        running: Service.running,
        remainingSeconds: Service.remainingSeconds,
        totalSeconds: Service.totalSeconds,
        sessionIndex: Service.sessionIndex,
        completedSessions: Service.completedSessions,
        maxSessions: Service.maxSessions,
        workflowMode: Service.workflowMode,
        soundEnabled: Service.soundEnabled,
        soundVolume: Service.soundVolume,
        soundTheme: Service.soundTheme,
        notificationsEnabled: Service.notificationsEnabled,
        autoStartBreaks: Service.autoStartBreaks,
        autoStartWork: Service.autoStartWork
      })
    }
    function statsSummary(): string { return Service.statsSummary("day") }
    function stats(period: string): string { return Service.statsSummary(period) }
    function statsJson(period: string): string { return JSON.stringify(Service.getStatsObject(period)) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    labelVisible: false
    hasVisualContent: true
    foreground: root.activePhaseColor
    activeColor: root.activePhaseColor
    active: Service.running
    fontFamily: bar ? bar.fontFamily : Style.font.family
    fontSize: Style.font.body
    fixedWidth: root.measuredWidth

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      // Pixel-Perfect HiDPI Scalable Geometric Infinity Mark
      Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.iconWidth
        implicitHeight: root.iconHeight
        width: root.iconWidth
        height: root.iconHeight

        Shape {
          width: 24
          height: 16
          anchors.centerIn: parent
          transform: Scale {
            origin.x: 12
            origin.y: 8
            xScale: root.iconWidth / 24.0
            yScale: root.iconHeight / 16.0
          }
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            fillColor: "transparent"
            strokeColor: root.activePhaseColor
            strokeWidth: root.iconStrokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            Behavior on strokeColor {
              ColorAnimation { duration: 250 }
            }

            PathSvg {
              path: root.infinityPath
            }
          }
        }
      }

      // Countdown Timer Text (only visible when showTimerInBar is true)
      Text {
        id: timerText
        visible: root.showTimerInBar
        anchors.verticalCenter: parent.verticalCenter
        text: Model.formatTime(Service.remainingSeconds)
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: Service.running
        color: root.activePhaseColor
        renderType: Text.NativeRendering

        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 250 }
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) Service.toggle()
      else if (b === Qt.MiddleButton) Service.reset()
      else root.togglePanel()
    }
  }
}
