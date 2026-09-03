import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// High-Performance Singleton Timer Engine with Seamless Restart Recovery
pragma Singleton

Item {
  id: service

  property string state: Model.STATE_IDLE
  property bool running: false
  property int workDurationMin: 5
  property int shortBreakMin: 2
  property int longBreakMin: 15
  property int remainingSeconds: 5 * 60
  property int totalSeconds: 5 * 60
  property int sessionIndex: 1
  property int completedSessions: 0
  property int maxSessions: 4
  property bool breakComplete: false
  property double targetEndTime: 0

  readonly property bool isBreakState: state === Model.STATE_SHORT_BREAK || state === Model.STATE_LONG_BREAK
  readonly property bool isBreakOverlayVisible: isBreakState || breakComplete
  readonly property real progressFraction: totalSeconds > 0 ? (totalSeconds - remainingSeconds) / totalSeconds : 0.0

  readonly property string statePath: {
    var base = Quickshell.env("XDG_STATE_HOME")
    if (!base || base.length === 0) base = Quickshell.env("HOME") + "/.local/state"
    return base + "/omarchy/gati-state.json"
  }

  property bool stateLoaded: false

  FileView {
    id: stateFile
    path: service.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: service.loadPersistedState(text())
    onLoadFailed: service.loadPersistedState("")
  }

  function saveState() {
    if (!service.stateLoaded) return
    var data = {
      version: 1,
      state: service.state,
      running: service.running,
      targetEndTime: service.targetEndTime,
      remainingSeconds: service.remainingSeconds,
      totalSeconds: service.totalSeconds,
      sessionIndex: service.sessionIndex,
      completedSessions: service.completedSessions,
      maxSessions: service.maxSessions,
      breakComplete: service.breakComplete,
      lastSaved: Date.now()
    }
    stateFile.setText(JSON.stringify(data, null, 2) + "\n")
  }

  function loadPersistedState(raw) {
    if (service.stateLoaded) return
    service.stateLoaded = true

    if (!raw || raw.trim().length === 0) return

    try {
      var data = JSON.parse(raw)
      if (!data || typeof data !== "object") return

      service.state = data.state || Model.STATE_IDLE
      service.sessionIndex = data.sessionIndex || 1
      service.completedSessions = (typeof data.completedSessions === "number") ? data.completedSessions : 0
      service.maxSessions = data.maxSessions || 4
      service.totalSeconds = data.totalSeconds || (service.workDurationMin * 60)
      service.breakComplete = data.breakComplete === true

      if (data.running && data.targetEndTime > 0) {
        var now = Date.now()
        var diff = Math.max(0, Math.round((data.targetEndTime - now) / 1000))
        if (diff > 0) {
          service.targetEndTime = data.targetEndTime
          service.remainingSeconds = diff
          service.running = true
          timer.start()
        } else {
          // Timer finished while shell was restarting
          service.remainingSeconds = 0
          service.finishSession()
        }
      } else {
        service.running = false
        service.targetEndTime = 0
        service.remainingSeconds = data.remainingSeconds !== undefined ? data.remainingSeconds : (service.workDurationMin * 60)
      }
    } catch (e) {
      console.warn("Gati: failed to parse persisted state:", e)
    }
  }

  function start() {
    if (state === Model.STATE_IDLE) {
      state = Model.STATE_WORK
      totalSeconds = workDurationMin * 60
      remainingSeconds = totalSeconds
    }
    breakComplete = false
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    timer.start()
    saveState()
  }

  function pause() {
    if (running) {
      var now = Date.now()
      remainingSeconds = Math.max(0, Math.round((targetEndTime - now) / 1000))
    }
    running = false
    timer.stop()
    saveState()
  }

  function toggle() {
    if (running) pause()
    else start()
  }

  function reset() {
    running = false
    timer.stop()
    breakComplete = false
    state = Model.STATE_IDLE
    completedSessions = 0
    sessionIndex = 1
    totalSeconds = workDurationMin * 60
    remainingSeconds = totalSeconds
    targetEndTime = 0
    saveState()
  }

  function startBreak(minutes) {
    var dur = (minutes !== undefined && minutes > 0) ? minutes : shortBreakMin
    state = Model.STATE_SHORT_BREAK
    breakComplete = false
    totalSeconds = dur * 60
    remainingSeconds = totalSeconds
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    timer.start()
    saveState()
  }

  function skip() {
    if (isBreakState) {
      continueToNextFocus()
    } else {
      finishSession()
    }
  }

  function extendBreak(extraMinutes) {
    breakComplete = false
    remainingSeconds += extraMinutes * 60
    totalSeconds += extraMinutes * 60
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    timer.start()
    saveState()
  }

  function continueToNextFocus() {
    breakComplete = false
    if (completedSessions >= maxSessions) {
      completedSessions = 0
      sessionIndex = 1
    }
    state = Model.STATE_WORK
    totalSeconds = workDurationMin * 60
    remainingSeconds = totalSeconds
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    timer.start()
    saveState()
  }

  function finishSession() {
    timer.stop()

    if (state === Model.STATE_WORK) {
      // Focus session finished -> start Break Overlay Takeover
      breakComplete = false
      completedSessions++
      if (completedSessions >= maxSessions) {
        state = Model.STATE_LONG_BREAK
        totalSeconds = longBreakMin * 60
        sessionIndex = 1
      } else {
        state = Model.STATE_SHORT_BREAK
        totalSeconds = shortBreakMin * 60
        sessionIndex++
      }
      remainingSeconds = totalSeconds
      targetEndTime = Date.now() + remainingSeconds * 1000
      running = true
      timer.start()
    } else if (isBreakState) {
      // Break finished -> Wait for user in FULL SCREEN WAITING
      running = false
      breakComplete = true
      remainingSeconds = 0
      targetEndTime = 0
    }
    saveState()
  }

  Timer {
    id: timer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      if (service.running) {
        var now = Date.now()
        var diff = Math.max(0, Math.round((service.targetEndTime - now) / 1000))
        service.remainingSeconds = diff
        if (diff <= 0) {
          service.finishSession()
        }
      }
    }
  }

  Component.onCompleted: {
    Qt.callLater(function() {
      stateFile.reload()
    })
  }
}
