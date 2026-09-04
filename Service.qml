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

  readonly property string ioScript: {
    var url = String(Qt.resolvedUrl("safe_state_io.py"))
    if (url.indexOf("file://") === 0)
      return url.slice(7)
    return url
  }

  property bool stateLoaded: false
  property bool isWriting: false
  property var pendingWritePayload: null

  Process {
    id: readProc
    command: ["python3", service.ioScript, "read", service.statePath]
    stdout: StdioCollector {
      id: readOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        service.loadPersistedState(readOut.text || "")
      } else {
        service.loadPersistedState("")
      }
    }
  }

  Process {
    id: writeProc
    stdout: StdioCollector {
      waitForEnd: true
    }
    stderr: StdioCollector {
      waitForEnd: true
    }
    onExited: function(exitCode) {
      service.isWriting = false
      if (service.pendingWritePayload !== null) {
        var next = service.pendingWritePayload
        service.pendingWritePayload = null
        service.executeWrite(next)
      }
    }
  }

  function executeWrite(payload) {
    if (!payload || service.ioScript.length === 0) return
    service.isWriting = true
    writeProc.command = ["python3", service.ioScript, "write", service.statePath, payload]
    writeProc.running = true
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
    var payload = JSON.stringify(data)
    if (service.isWriting || writeProc.running) {
      service.pendingWritePayload = payload
      return
    }
    service.executeWrite(payload)
  }

  function loadPersistedState(raw) {
    if (service.stateLoaded) return
    service.stateLoaded = true

    if (!raw || typeof raw !== "string" || raw.trim().length === 0) return

    try {
      var data = JSON.parse(raw)
      if (!data || typeof data !== "object") return

      var validStates = [Model.STATE_IDLE, Model.STATE_WORK, Model.STATE_SHORT_BREAK, Model.STATE_LONG_BREAK]
      service.state = (typeof data.state === "string" && validStates.indexOf(data.state) !== -1)
        ? data.state
        : Model.STATE_IDLE

      var maxSess = (typeof data.maxSessions === "number" && Number.isFinite(data.maxSessions))
        ? Math.floor(data.maxSessions)
        : 4
      service.maxSessions = Math.min(16, Math.max(1, maxSess))

      var sessIdx = (typeof data.sessionIndex === "number" && Number.isFinite(data.sessionIndex))
        ? Math.floor(data.sessionIndex)
        : 1
      service.sessionIndex = Math.min(service.maxSessions, Math.max(1, sessIdx))

      var compSess = (typeof data.completedSessions === "number" && Number.isFinite(data.completedSessions))
        ? Math.floor(data.completedSessions)
        : 0
      service.completedSessions = Math.min(10000, Math.max(0, compSess))

      var totSec = (typeof data.totalSeconds === "number" && Number.isFinite(data.totalSeconds))
        ? Math.floor(data.totalSeconds)
        : (service.workDurationMin * 60)
      service.totalSeconds = Math.min(86400, Math.max(1, totSec))

      service.breakComplete = (data.breakComplete === true)

      var isRunning = (data.running === true)
      var targetEndTime = (typeof data.targetEndTime === "number" && Number.isFinite(data.targetEndTime))
        ? data.targetEndTime
        : 0

      if (isRunning && targetEndTime > 0) {
        var now = Date.now()
        if (targetEndTime <= now + (86400 * 1000)) {
          var diff = Math.round((targetEndTime - now) / 1000)
          if (diff > 0) {
            service.targetEndTime = targetEndTime
            service.remainingSeconds = Math.min(service.totalSeconds, diff)
            service.running = true
            timer.start()
          } else {
            // Timer finished while shell was restarting
            service.running = false
            service.remainingSeconds = 0
            service.targetEndTime = 0
            service.finishSession()
          }
        } else {
          service.running = false
          service.targetEndTime = 0
          service.remainingSeconds = service.totalSeconds
        }
      } else {
        service.running = false
        service.targetEndTime = 0
        var remSec = (typeof data.remainingSeconds === "number" && Number.isFinite(data.remainingSeconds))
          ? Math.floor(data.remainingSeconds)
          : (service.workDurationMin * 60)
        service.remainingSeconds = Math.min(service.totalSeconds, Math.max(0, remSec))
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
    var dur = (typeof minutes === "number" && Number.isFinite(minutes) && minutes > 0)
      ? Math.min(180, Math.floor(minutes))
      : shortBreakMin
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
    var extra = (typeof extraMinutes === "number" && Number.isFinite(extraMinutes) && extraMinutes > 0)
      ? Math.min(60, Math.floor(extraMinutes))
      : 5
    breakComplete = false
    remainingSeconds = Math.min(86400, remainingSeconds + (extra * 60))
    totalSeconds = Math.min(86400, totalSeconds + (extra * 60))
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
      if (!service.stateLoaded && !readProc.running) {
        readProc.command = ["python3", service.ioScript, "read", service.statePath]
        readProc.running = true
      }
    })
  }

  Component.onDestruction: {
    if (readProc.running) readProc.running = false
    if (writeProc.running) writeProc.running = false
  }
}
