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

  // Focus Statistics & Momentum Analytics
  property string todayDate: Model.todayIso()
  property int todayFocusSeconds: 0
  property int todayCompletedSessions: 0
  property int streakDays: 0
  property string lastActiveDate: ""
  property int totalFocusSeconds: 0
  property int totalCompletedSessionsLifetime: 0
  property var dailyHistory: ({})
  property var monthlyHistory: ({})
  property var yearlyHistory: ({})
  property var todayBlocks: []
  property bool resetDaily: true
  property string workflowMode: "classic"

  // Sound and Notification Settings
  property bool soundEnabled: true
  property int soundVolume: 80
  property string soundTheme: "zen"
  property bool notificationsEnabled: true
  property bool breakWarningNotified: false
  property bool autoStartBreaks: true
  property bool autoStartWork: false

  onStateChanged: {
    breakWarningNotified = false
  }

  onWorkDurationMinChanged: {
    if (!running && (state === Model.STATE_IDLE || state === Model.STATE_WORK)) {
      totalSeconds = workDurationMin * 60
      remainingSeconds = totalSeconds
    }
    saveState()
  }
  onShortBreakMinChanged: {
    if (!running && state === Model.STATE_SHORT_BREAK) {
      totalSeconds = shortBreakMin * 60
      remainingSeconds = totalSeconds
    }
    saveState()
  }
  onLongBreakMinChanged: {
    if (!running && state === Model.STATE_LONG_BREAK) {
      totalSeconds = longBreakMin * 60
      remainingSeconds = totalSeconds
    }
    saveState()
  }
  onWorkflowModeChanged: saveState()
  onMaxSessionsChanged: saveState()
  onResetDailyChanged: saveState()
  onSoundEnabledChanged: saveState()
  onSoundVolumeChanged: saveState()
  onSoundThemeChanged: saveState()
  onNotificationsEnabledChanged: saveState()
  onAutoStartBreaksChanged: saveState()
  onAutoStartWorkChanged: saveState()

  readonly property var todayDisplayBlocks: {
    var _b = service.todayBlocks
    var _st = service.state
    var _r = service.running
    var _cs = service.todayCompletedSessions
    var _wm = service.workDurationMin
    var _sm = service.shortBreakMin
    var _lm = service.longBreakMin
    var _ms = service.maxSessions
    var _rd = service.resetDaily
    return service.getTodayDisplayBlocks()
  }

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

  readonly property string soundsDir: {
    var url = String(Qt.resolvedUrl("assets/sounds"))
    if (url.indexOf("file://") === 0)
      return url.slice(7)
    return url
  }

  Process {
    id: soundProc
  }

  Process {
    id: notifyProc
  }

  function playSound(soundType) {
    if (!service.soundEnabled) return
    var filename = "zen_bell.wav"
    if (soundType === "break_done") {
      filename = "break_done.wav"
    } else if (soundType === "tick") {
      filename = "tick.wav"
    } else {
      if (service.soundTheme === "crystal") filename = "crystal_chime.wav"
      else if (service.soundTheme === "marimba") filename = "marimba.wav"
      else filename = "zen_bell.wav"
    }
    var filePath = service.soundsDir + "/" + filename
    var vol = Math.max(0.05, Math.min(1.0, (service.soundVolume || 80) / 100.0))
    if (soundProc.running) {
      soundProc.running = false
    }
    soundProc.command = [
      "bash", "-c",
      "pw-play --volume \"$1\" \"$2\" 2>/dev/null || paplay \"$2\" 2>/dev/null || aplay \"$2\" 2>/dev/null",
      "gati-sound",
      vol.toFixed(2),
      filePath
    ]
    soundProc.running = true
  }

  function sendNotification(title, message, urgency) {
    if (!service.notificationsEnabled) return
    var urg = urgency || "normal"
    if (notifyProc.running) {
      notifyProc.running = false
    }
    notifyProc.command = [
      "notify-send",
      "-a", "Gati",
      "-u", urg,
      title,
      message
    ]
    notifyProc.running = true
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
      workDurationMin: service.workDurationMin,
      shortBreakMin: service.shortBreakMin,
      longBreakMin: service.longBreakMin,
      sessionIndex: service.sessionIndex,
      completedSessions: service.completedSessions,
      maxSessions: service.maxSessions,
      workflowMode: service.workflowMode,
      breakComplete: service.breakComplete,
      soundEnabled: service.soundEnabled,
      soundVolume: service.soundVolume,
      soundTheme: service.soundTheme,
      notificationsEnabled: service.notificationsEnabled,
      autoStartBreaks: service.autoStartBreaks,
      autoStartWork: service.autoStartWork,
      lastSaved: Date.now(),
      stats: {
        resetDaily: service.resetDaily,
        todayDate: service.todayDate,
        todaySeconds: service.todayFocusSeconds,
        todaySessions: service.todayCompletedSessions,
        todayBlocks: service.todayBlocks,
        streakDays: service.streakDays,
        lastActiveDate: service.lastActiveDate,
        totalFocusSeconds: service.totalFocusSeconds,
        totalSessionsCompleted: service.totalCompletedSessionsLifetime,
        history: service.dailyHistory,
        monthlyHistory: service.monthlyHistory,
        yearlyHistory: service.yearlyHistory
      }
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

      if (typeof data.workflowMode === "string" && data.workflowMode.length > 0) {
        service.workflowMode = data.workflowMode
      }

      if (typeof data.soundEnabled === "boolean") service.soundEnabled = data.soundEnabled
      if (typeof data.soundVolume === "number" && Number.isFinite(data.soundVolume)) {
        service.soundVolume = Math.min(100, Math.max(0, Math.floor(data.soundVolume)))
      }
      if (typeof data.soundTheme === "string" && data.soundTheme.length > 0) {
        service.soundTheme = data.soundTheme
      }
      if (typeof data.notificationsEnabled === "boolean") service.notificationsEnabled = data.notificationsEnabled
      if (typeof data.autoStartBreaks === "boolean") service.autoStartBreaks = data.autoStartBreaks
      if (typeof data.autoStartWork === "boolean") service.autoStartWork = data.autoStartWork

      if (typeof data.workDurationMin === "number" && Number.isFinite(data.workDurationMin)) {
        service.workDurationMin = Math.min(180, Math.max(1, Math.floor(data.workDurationMin)))
      }
      if (typeof data.shortBreakMin === "number" && Number.isFinite(data.shortBreakMin)) {
        service.shortBreakMin = Math.min(60, Math.max(1, Math.floor(data.shortBreakMin)))
      }
      if (typeof data.longBreakMin === "number" && Number.isFinite(data.longBreakMin)) {
        service.longBreakMin = Math.min(120, Math.max(1, Math.floor(data.longBreakMin)))
      }

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

      // Restore and validate Focus Analytics
      if (data.stats && typeof data.stats === "object") {
        var s = data.stats
        if (typeof s.resetDaily === "boolean") {
          service.resetDaily = s.resetDaily
        }
        var today = Model.todayIso()
        service.todayDate = today

        service.streakDays = (typeof s.streakDays === "number" && Number.isFinite(s.streakDays))
          ? Math.max(0, Math.min(10000, Math.floor(s.streakDays)))
          : 0

        service.lastActiveDate = (typeof s.lastActiveDate === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s.lastActiveDate))
          ? s.lastActiveDate
          : ""

        service.totalFocusSeconds = (typeof s.totalFocusSeconds === "number" && Number.isFinite(s.totalFocusSeconds))
          ? Math.max(0, Math.min(100000000, Math.floor(s.totalFocusSeconds)))
          : 0

        service.totalCompletedSessionsLifetime = (typeof s.totalSessionsCompleted === "number" && Number.isFinite(s.totalSessionsCompleted))
          ? Math.max(0, Math.min(1000000, Math.floor(s.totalSessionsCompleted)))
          : 0

        var hist = {}
        if (s.history && typeof s.history === "object") {
          var histKeys = Object.keys(s.history).slice(0, 90)
          for (var k = 0; k < histKeys.length; k++) {
            var dateKey = histKeys[k]
            if (/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
              var dayObj = s.history[dateKey]
              if (dayObj && typeof dayObj === "object") {
                var sec = (typeof dayObj.seconds === "number" && Number.isFinite(dayObj.seconds))
                  ? Math.max(0, Math.min(86400 * 2, Math.floor(dayObj.seconds)))
                  : 0
                var sess = (typeof dayObj.sessions === "number" && Number.isFinite(dayObj.sessions))
                  ? Math.max(0, Math.min(100, Math.floor(dayObj.sessions)))
                  : 0
                hist[dateKey] = { seconds: sec, sessions: sess }
              }
            }
          }
        }
        service.dailyHistory = hist

        var mHist = {}
        if (s.monthlyHistory && typeof s.monthlyHistory === "object") {
          var mKeys = Object.keys(s.monthlyHistory).slice(0, 36)
          for (var mi = 0; mi < mKeys.length; mi++) {
            var mKey = mKeys[mi]
            if (/^\d{4}-\d{2}$/.test(mKey)) {
              var mObj = s.monthlyHistory[mKey]
              if (mObj && typeof mObj === "object") {
                var mSec = (typeof mObj.seconds === "number" && Number.isFinite(mObj.seconds))
                  ? Math.max(0, Math.min(86400 * 31, Math.floor(mObj.seconds)))
                  : 0
                var mSess = (typeof mObj.sessions === "number" && Number.isFinite(mObj.sessions))
                  ? Math.max(0, Math.min(10000, Math.floor(mObj.sessions)))
                  : 0
                mHist[mKey] = { seconds: mSec, sessions: mSess }
              }
            }
          }
        }

        var yHist = {}
        if (s.yearlyHistory && typeof s.yearlyHistory === "object") {
          var yKeys = Object.keys(s.yearlyHistory).slice(0, 10)
          for (var yi = 0; yi < yKeys.length; yi++) {
            var yKey = yKeys[yi]
            if (/^\d{4}$/.test(yKey)) {
              var yObj = s.yearlyHistory[yKey]
              if (yObj && typeof yObj === "object") {
                var ySec = (typeof yObj.seconds === "number" && Number.isFinite(yObj.seconds))
                  ? Math.max(0, Math.min(86400 * 366, Math.floor(yObj.seconds)))
                  : 0
                var ySess = (typeof yObj.sessions === "number" && Number.isFinite(yObj.sessions))
                  ? Math.max(0, Math.min(100000, Math.floor(yObj.sessions)))
                  : 0
                yHist[yKey] = { seconds: ySec, sessions: ySess }
              }
            }
          }
        }

        // Backfill monthly and yearly from daily history if not yet present
        for (var dK in hist) {
          var dEntry = hist[dK]
          var monthPrefix = dK.substring(0, 7)
          var yearPrefix = dK.substring(0, 4)
          if (!mHist[monthPrefix]) {
            mHist[monthPrefix] = { seconds: 0, sessions: 0 }
          }
          if (!yHist[yearPrefix]) {
            yHist[yearPrefix] = { seconds: 0, sessions: 0 }
          }
        }
        service.monthlyHistory = mHist
        service.yearlyHistory = yHist

        if (service.resetDaily) {
          var todayEntry = hist[today]
          service.todayFocusSeconds = todayEntry ? todayEntry.seconds : 0
          service.todayCompletedSessions = todayEntry ? todayEntry.sessions : 0

          if (s.todayBlocks && Array.isArray(s.todayBlocks) && s.todayDate === today) {
            service.todayBlocks = s.todayBlocks
          } else if (service.todayCompletedSessions > 0) {
            var initialBlocks = []
            for (var bIdx = 0; bIdx < service.todayCompletedSessions; bIdx++) {
              initialBlocks.push({
                pomo: "completed",
                pomoDuration: service.workDurationMin,
                break: "completed",
                breakDuration: (bIdx % service.maxSessions === service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
              })
            }
            service.todayBlocks = initialBlocks
          } else {
            service.todayBlocks = []
          }
        } else {
          // Reset daily disabled: retain accumulated focus stats & blocks across days
          service.todayDate = s.todayDate || today
          var todayE = hist[today]
          var savedSec = (typeof s.todaySeconds === "number" && Number.isFinite(s.todaySeconds))
            ? s.todaySeconds
            : (todayE ? todayE.seconds : 0)
          var savedSess = (typeof s.todaySessions === "number" && Number.isFinite(s.todaySessions))
            ? s.todaySessions
            : (todayE ? todayE.sessions : 0)
          service.todayFocusSeconds = Math.max(0, Math.floor(savedSec))
          service.todayCompletedSessions = Math.max(0, Math.floor(savedSess))

          if (s.todayBlocks && Array.isArray(s.todayBlocks)) {
            service.todayBlocks = s.todayBlocks
          } else if (service.todayCompletedSessions > 0) {
            var initialB = []
            for (var bi = 0; bi < service.todayCompletedSessions; bi++) {
              initialB.push({
                pomo: "completed",
                pomoDuration: service.workDurationMin,
                break: "completed",
                breakDuration: (bi % service.maxSessions === service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
              })
            }
            service.todayBlocks = initialB
          } else {
            service.todayBlocks = []
          }
        }

        // Check if streak was broken (last active date was before yesterday)
        if (service.lastActiveDate && service.lastActiveDate !== today) {
          var yesterday = Model.yesterdayIso()
          if (service.lastActiveDate !== yesterday && service.todayCompletedSessions === 0) {
            service.streakDays = 0
          }
        }
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
      breakWarningNotified = false
    } else if (remainingSeconds > 10) {
      breakWarningNotified = false
    }
    breakComplete = false
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    service.playSound("tick")
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
    breakWarningNotified = false
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

  function getTodayBlocks() {
    var today = Model.todayIso()
    if (service.resetDaily && service.todayDate !== today) {
      service.todayDate = today
      service.todayBlocks = []
      service.todayFocusSeconds = 0
      service.todayCompletedSessions = 0
    }
    var list = []
    if (service.todayBlocks && Array.isArray(service.todayBlocks)) {
      for (var i = 0; i < service.todayBlocks.length; i++) {
        list.push(service.todayBlocks[i])
      }
    }
    return list
  }

  function recordPomoCompleted() {
    var blocks = getTodayBlocks()
    var currentIdx = blocks.length > 0 ? blocks.length - 1 : 0
    if (blocks.length === 0 || blocks[currentIdx].pomo === "completed" || blocks[currentIdx].pomo === "skipped") {
      blocks.push({
        pomo: "completed",
        pomoDuration: service.workDurationMin,
        break: "pending",
        breakDuration: (blocks.length % service.maxSessions === service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
      })
    } else {
      blocks[currentIdx].pomo = "completed"
      blocks[currentIdx].pomoDuration = service.workDurationMin
      blocks[currentIdx].break = "pending"
    }
    service.todayBlocks = blocks
    saveState()
  }

  function recordPomoSkipped() {
    var blocks = getTodayBlocks()
    var currentIdx = blocks.length > 0 ? blocks.length - 1 : 0
    if (blocks.length === 0 || blocks[currentIdx].pomo === "completed" || blocks[currentIdx].pomo === "skipped") {
      blocks.push({
        pomo: "skipped",
        pomoDuration: service.workDurationMin,
        break: "pending",
        breakDuration: (blocks.length % service.maxSessions === service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
      })
    } else {
      blocks[currentIdx].pomo = "skipped"
      blocks[currentIdx].pomoDuration = service.workDurationMin
      blocks[currentIdx].break = "pending"
    }
    service.todayBlocks = blocks
    saveState()
  }

  function recordBreakCompleted() {
    var blocks = getTodayBlocks()
    if (blocks.length > 0) {
      var currentIdx = blocks.length - 1
      blocks[currentIdx].break = "completed"
      service.todayBlocks = blocks
      saveState()
    }
  }

  function recordBreakSkipped() {
    var blocks = getTodayBlocks()
    if (blocks.length > 0) {
      var currentIdx = blocks.length - 1
      blocks[currentIdx].break = "skipped"
      service.todayBlocks = blocks
      saveState()
    }
  }

  function getTodayBreakSeconds() {
    var blocks = getTodayBlocks()
    var sec = 0
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].break === "completed") {
        sec += (blocks[i].breakDuration || service.shortBreakMin) * 60
      }
    }
    return sec
  }

  function getTodayCompletedBreaks() {
    var blocks = getTodayBlocks()
    var count = 0
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].break === "completed") count++
    }
    return count
  }

  function getTodayDisplayBlocks() {
    var blocks = getTodayBlocks()
    var target = Math.max(8, blocks.length + (service.state === Model.STATE_WORK || service.isBreakState ? 1 : 0))
    target = Math.max(8, target)
    var result = []

    var activeBlockIndex = -1
    if (service.running || service.state !== Model.STATE_IDLE) {
      if (blocks.length === 0) {
        activeBlockIndex = 0
      } else {
        var last = blocks[blocks.length - 1]
        if (service.state === Model.STATE_WORK) {
          if (last.pomo === "completed" || last.pomo === "skipped") {
            activeBlockIndex = blocks.length
          } else {
            activeBlockIndex = blocks.length - 1
          }
        } else if (service.isBreakState) {
          activeBlockIndex = blocks.length - 1
        }
      }
    }

    for (var i = 0; i < target; i++) {
      var pomoStatus = "pending"
      var breakStatus = "pending"
      var pomoDur = service.workDurationMin
      var breakDur = (i % service.maxSessions === service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin

      if (i < blocks.length) {
        var b = blocks[i]
        pomoStatus = b.pomo || "pending"
        breakStatus = b.break || "pending"
        if (b.pomoDuration) pomoDur = b.pomoDuration
        if (b.breakDuration) breakDur = b.breakDuration
      }

      if (i === activeBlockIndex) {
        if (service.state === Model.STATE_WORK) {
          if (pomoStatus !== "completed" && pomoStatus !== "skipped") {
            pomoStatus = "active"
          }
        } else if (service.isBreakState) {
          if (breakStatus !== "completed" && breakStatus !== "skipped") {
            breakStatus = "active"
          }
        }
      }

      result.push({
        index: i,
        pomo: pomoStatus,
        pomoMin: pomoDur,
        break: breakStatus,
        breakMin: breakDur
      })
    }
    return result
  }

  function advanceToBreakAfterSkip() {
    timer.stop()
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
    saveState()
  }

  function skip() {
    if (isBreakState) {
      recordBreakSkipped()
      continueToNextFocus()
    } else {
      recordPomoSkipped()
      advanceToBreakAfterSkip()
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
    service.playSound("tick")
    timer.start()
    saveState()
  }

  function continueToNextFocus() {
    breakComplete = false
    breakWarningNotified = false
    if (completedSessions >= maxSessions) {
      completedSessions = 0
      sessionIndex = 1
    }
    state = Model.STATE_WORK
    totalSeconds = workDurationMin * 60
    remainingSeconds = totalSeconds
    targetEndTime = Date.now() + remainingSeconds * 1000
    running = true
    service.playSound("tick")
    timer.start()
    saveState()
  }

  function finishSession() {
    breakWarningNotified = false
    if (state === Model.STATE_WORK) {
      service.playSound("focus_complete")
      var breakMinVal = (completedSessions >= maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
      recordPomoCompleted()
      // Focus session finished -> Update Focus Analytics
      var today = Model.todayIso()
      var sessionSeconds = service.workDurationMin * 60
      if (service.resetDaily && service.todayDate !== today) {
        service.todayDate = today
        service.todayFocusSeconds = 0
        service.todayCompletedSessions = 0
        service.todayBlocks = []
      }
      service.todayDate = today
      service.todayFocusSeconds += sessionSeconds
      service.todayCompletedSessions += 1
      service.totalFocusSeconds += sessionSeconds
      service.totalCompletedSessionsLifetime += 1

      // Streak tracking
      if (service.lastActiveDate !== today) {
        var yesterday = Model.yesterdayIso()
        if (service.lastActiveDate === yesterday) {
          service.streakDays = Math.max(1, service.streakDays + 1)
        } else {
          service.streakDays = 1
        }
        service.lastActiveDate = today
      } else if (service.streakDays === 0) {
        service.streakDays = 1
      }

      // Rolling daily history (keep up to 90 days)
      var hist = {}
      for (var dKey in service.dailyHistory) {
        hist[dKey] = service.dailyHistory[dKey]
      }
      var curEntry = hist[today] || { seconds: 0, sessions: 0 }
      hist[today] = {
        seconds: (curEntry.seconds || 0) + sessionSeconds,
        sessions: (curEntry.sessions || 0) + 1
      }
      var sortedKeys = Object.keys(hist).sort()
      while (sortedKeys.length > 90) {
        delete hist[sortedKeys.shift()]
      }
      service.dailyHistory = hist

      // Monthly history (keep up to 24 months)
      var month = today.substring(0, 7)
      var mHist = {}
      for (var mk in service.monthlyHistory) {
        mHist[mk] = service.monthlyHistory[mk]
      }
      var curM = mHist[month] || { seconds: 0, sessions: 0 }
      mHist[month] = {
        seconds: (curM.seconds || 0) + sessionSeconds,
        sessions: (curM.sessions || 0) + 1
      }
      var sortedMKeys = Object.keys(mHist).sort()
      while (sortedMKeys.length > 24) {
        delete mHist[sortedMKeys.shift()]
      }
      service.monthlyHistory = mHist

      // Yearly history (keep up to 10 years)
      var year = today.substring(0, 4)
      var yHist = {}
      for (var yk in service.yearlyHistory) {
        yHist[yk] = service.yearlyHistory[yk]
      }
      var curY = yHist[year] || { seconds: 0, sessions: 0 }
      yHist[year] = {
        seconds: (curY.seconds || 0) + sessionSeconds,
        sessions: (curY.sessions || 0) + 1
      }
      service.yearlyHistory = yHist

      // Switch to break
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
      running = service.autoStartBreaks
      if (running) {
        targetEndTime = Date.now() + remainingSeconds * 1000
        timer.restart()
      } else {
        targetEndTime = 0
        timer.stop()
      }
    } else if (isBreakState) {
      timer.stop()
      service.playSound("break_done")
      recordBreakCompleted()
      // Break finished -> Wait for user in FULL SCREEN WAITING
      running = false
      breakComplete = true
      remainingSeconds = 0
      targetEndTime = 0
      if (service.autoStartWork) {
        continueToNextFocus()
        return
      }
    } else {
      timer.stop()
      running = false
    }
    saveState()
  }

  function resetDailyStats() {
    service.todayDate = Model.todayIso()
    service.todayFocusSeconds = 0
    service.todayCompletedSessions = 0
    service.todayBlocks = []
    saveState()
  }

  // --- WEEKLY METRICS & HELPERS ---
  function getWeeklyTotalSeconds() {
    var days = Model.last7DaysIso()
    var tot = 0
    for (var i = 0; i < days.length; i++) {
      var e = service.dailyHistory[days[i]]
      if (e && e.seconds) tot += e.seconds
    }
    return tot
  }

  function getWeeklyTotalSessions() {
    var days = Model.last7DaysIso()
    var tot = 0
    for (var i = 0; i < days.length; i++) {
      var e = service.dailyHistory[days[i]]
      if (e && e.sessions) tot += e.sessions
    }
    return tot
  }

  function getWeeklyDailyAverageSeconds() {
    return Math.round(getWeeklyTotalSeconds() / 7)
  }

  function getWeeklyActiveDaysCount() {
    var days = Model.last7DaysIso()
    var cnt = 0
    for (var i = 0; i < days.length; i++) {
      var e = service.dailyHistory[days[i]]
      if (e && e.seconds > 0) cnt++
    }
    return cnt
  }

  function getWeeklyHistory() {
    var days = Model.last7DaysIso()
    var result = []
    var maxSec = 60
    for (var i = 0; i < days.length; i++) {
      var iso = days[i]
      var entry = service.dailyHistory[iso] || { seconds: 0, sessions: 0 }
      var sec = entry.seconds || 0
      if (sec > maxSec) maxSec = sec
      result.push({
        iso: iso,
        dayInitial: Model.dayInitial(iso),
        seconds: sec,
        sessions: entry.sessions || 0,
        isToday: (iso === service.todayDate)
      })
    }
    for (var j = 0; j < result.length; j++) {
      result[j].fraction = Math.max(0.08, result[j].seconds / maxSec)
    }
    return result
  }

  // --- MONTHLY METRICS & HELPERS ---
  function getMonthlyTotalSeconds() {
    var mKey = Model.currentMonthKey()
    var mEntry = service.monthlyHistory[mKey]
    if (mEntry && mEntry.seconds > 0) return mEntry.seconds
    var tot = 0
    for (var dKey in service.dailyHistory) {
      if (dKey.indexOf(mKey) === 0) {
        var e = service.dailyHistory[dKey]
        if (e && e.seconds) tot += e.seconds
      }
    }
    return tot
  }

  function getMonthlyTotalSessions() {
    var mKey = Model.currentMonthKey()
    var mEntry = service.monthlyHistory[mKey]
    if (mEntry && mEntry.sessions > 0) return mEntry.sessions
    var tot = 0
    for (var dKey in service.dailyHistory) {
      if (dKey.indexOf(mKey) === 0) {
        var e = service.dailyHistory[dKey]
        if (e && e.sessions) tot += e.sessions
      }
    }
    return tot
  }

  function getMonthlyDailyAverageSeconds() {
    var d = new Date()
    var daysPassed = Math.max(1, d.getDate())
    return Math.round(getMonthlyTotalSeconds() / daysPassed)
  }

  function getMonthlyActiveDaysCount() {
    var mKey = Model.currentMonthKey()
    var cnt = 0
    for (var dKey in service.dailyHistory) {
      if (dKey.indexOf(mKey) === 0) {
        var e = service.dailyHistory[dKey]
        if (e && e.seconds > 0) cnt++
      }
    }
    return cnt
  }

  function getMonthly4WeeksHistory() {
    var days28 = Model.last28DaysIso()
    var labels = ["3w ago", "2w ago", "Last Wk", "This Wk"]
    var result = []
    var maxSec = 60
    for (var w = 0; w < 4; w++) {
      var wSec = 0
      var wSess = 0
      var slice = days28.slice(w * 7, (w + 1) * 7)
      for (var d = 0; d < slice.length; d++) {
        var dayEntry = service.dailyHistory[slice[d]]
        if (dayEntry) {
          wSec += (dayEntry.seconds || 0)
          wSess += (dayEntry.sessions || 0)
        }
      }
      if (wSec > maxSec) maxSec = wSec
      result.push({
        label: labels[w],
        seconds: wSec,
        sessions: wSess,
        isCurrent: (w === 3)
      })
    }
    for (var i = 0; i < result.length; i++) {
      result[i].fraction = Math.max(0.08, result[i].seconds / maxSec)
    }
    return result
  }

  // --- YEARLY METRICS & HELPERS ---
  function getYearlyTotalSeconds() {
    var yKey = Model.currentYearKey()
    var yEntry = service.yearlyHistory[yKey]
    if (yEntry && yEntry.seconds > 0) return yEntry.seconds
    var tot = 0
    for (var mKey in service.monthlyHistory) {
      if (mKey.indexOf(yKey) === 0) {
        var me = service.monthlyHistory[mKey]
        if (me && me.seconds) tot += me.seconds
      }
    }
    return tot > 0 ? tot : service.totalFocusSeconds
  }

  function getYearlyTotalSessions() {
    var yKey = Model.currentYearKey()
    var yEntry = service.yearlyHistory[yKey]
    if (yEntry && yEntry.sessions > 0) return yEntry.sessions
    var tot = 0
    for (var mKey in service.monthlyHistory) {
      if (mKey.indexOf(yKey) === 0) {
        var me = service.monthlyHistory[mKey]
        if (me && me.sessions) tot += me.sessions
      }
    }
    return tot > 0 ? tot : service.totalCompletedSessionsLifetime
  }

  function getYearlyMonthlyAverageSeconds() {
    var currentMonthIndex = (new Date()).getMonth() + 1
    return Math.round(getYearlyTotalSeconds() / Math.max(1, currentMonthIndex))
  }

  function getYearlyBestMonth() {
    var yKey = Model.currentYearKey()
    var bestName = "-"
    var bestSec = 0
    for (var m = 0; m < 12; m++) {
      var mNum = (m + 1) < 10 ? "0" + (m + 1) : "" + (m + 1)
      var key = yKey + "-" + mNum
      var entry = service.monthlyHistory[key]
      if (entry && entry.seconds > bestSec) {
        bestSec = entry.seconds
        bestName = Model.MONTH_SHORT[m] + " (" + Model.formatHoursDecimal(bestSec) + ")"
      }
    }
    return bestName
  }

  function getYearly12MonthsHistory() {
    var yKey = Model.currentYearKey()
    var curMonthIdx = (new Date()).getMonth()
    var result = []
    var maxSec = 60
    for (var m = 0; m < 12; m++) {
      var mNum = (m + 1) < 10 ? "0" + (m + 1) : "" + (m + 1)
      var key = yKey + "-" + mNum
      var entry = service.monthlyHistory[key] || { seconds: 0, sessions: 0 }
      var sec = entry.seconds || 0
      if (sec > maxSec) maxSec = sec
      result.push({
        monthKey: key,
        initial: Model.MONTH_INITIALS[m],
        name: Model.MONTH_SHORT[m],
        seconds: sec,
        sessions: entry.sessions || 0,
        isCurrentMonth: (m === curMonthIdx)
      })
    }
    for (var i = 0; i < result.length; i++) {
      result[i].fraction = Math.max(0.08, result[i].seconds / maxSec)
    }
    return result
  }

  // --- SUMMARY STRINGS & JSON PAYLOADS ---
  function statsSummary(period) {
    var p = (period && typeof period === "string") ? period.toLowerCase().trim() : "all"
    if (p === "daily" || p === "day" || p === "today") {
      return "Today: " + Model.formatHoursMinutes(service.todayFocusSeconds) +
        " (" + service.todayCompletedSessions + " sessions) · Streak: " +
        service.streakDays + (service.streakDays === 1 ? " day" : " days") +
        " · Daily Goal: " + Math.min(100, Math.round((service.todayCompletedSessions / 8) * 100)) + "%"
    } else if (p === "weekly" || p === "week") {
      return "Past 7 Days: " + Model.formatHoursMinutes(service.getWeeklyTotalSeconds()) +
        " (" + service.getWeeklyTotalSessions() + " sessions) · Daily Avg: " +
        Model.formatHoursMinutes(service.getWeeklyDailyAverageSeconds()) +
        " · Active: " + service.getWeeklyActiveDaysCount() + "/7 days"
    } else if (p === "monthly" || p === "month") {
      return Model.currentMonthName() + ": " + Model.formatHoursMinutes(service.getMonthlyTotalSeconds()) +
        " (" + service.getMonthlyTotalSessions() + " sessions) · Daily Avg: " +
        Model.formatHoursMinutes(service.getMonthlyDailyAverageSeconds()) +
        " · Active: " + service.getMonthlyActiveDaysCount() + " days"
    } else if (p === "yearly" || p === "year") {
      return Model.currentYearName() + ": " + Model.formatHoursMinutes(service.getYearlyTotalSeconds()) +
        " (" + service.getYearlyTotalSessions() + " sessions) · Monthly Avg: " +
        Model.formatHoursDecimal(service.getYearlyMonthlyAverageSeconds()) + " · Best: " +
        service.getYearlyBestMonth()
    }

    return "Daily: " + Model.formatHoursMinutes(service.todayFocusSeconds) + " (" + service.todayCompletedSessions + " sess, streak " + service.streakDays + "d) | " +
      "Weekly: " + Model.formatHoursMinutes(service.getWeeklyTotalSeconds()) + " (" + service.getWeeklyTotalSessions() + " sess) | " +
      "Monthly: " + Model.formatHoursMinutes(service.getMonthlyTotalSeconds()) + " (" + service.getMonthlyTotalSessions() + " sess) | " +
      "Yearly: " + Model.formatHoursMinutes(service.getYearlyTotalSeconds()) + " (" + service.getYearlyTotalSessions() + " sess)"
  }

  function getStatsObject(period) {
    return {
      period: period || "all",
      daily: {
        date: service.todayDate,
        focusSeconds: service.todayFocusSeconds,
        sessions: service.todayCompletedSessions,
        streakDays: service.streakDays,
        goalPercentage: Math.min(100, Math.round((service.todayCompletedSessions / 8) * 100))
      },
      weekly: {
        totalSeconds: service.getWeeklyTotalSeconds(),
        totalSessions: service.getWeeklyTotalSessions(),
        dailyAverageSeconds: service.getWeeklyDailyAverageSeconds(),
        activeDays: service.getWeeklyActiveDaysCount(),
        history: service.getWeeklyHistory()
      },
      monthly: {
        month: Model.currentMonthName(),
        totalSeconds: service.getMonthlyTotalSeconds(),
        totalSessions: service.getMonthlyTotalSessions(),
        dailyAverageSeconds: service.getMonthlyDailyAverageSeconds(),
        activeDays: service.getMonthlyActiveDaysCount(),
        weeks: service.getMonthly4WeeksHistory()
      },
      yearly: {
        year: Model.currentYearName(),
        totalSeconds: service.getYearlyTotalSeconds(),
        totalSessions: service.getYearlyTotalSessions(),
        monthlyAverageSeconds: service.getYearlyMonthlyAverageSeconds(),
        bestMonth: service.getYearlyBestMonth(),
        months: service.getYearly12MonthsHistory()
      },
      lifetime: {
        totalFocusSeconds: service.totalFocusSeconds,
        totalSessions: service.totalCompletedSessionsLifetime
      }
    }
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

        // Dispatch desktop notification exactly 10 seconds before break begins
        if (service.state === Model.STATE_WORK && service.totalSeconds > 10 && diff <= 10 && diff > 0 && !service.breakWarningNotified) {
          service.breakWarningNotified = true
          var breakMinVal = (service.completedSessions >= service.maxSessions - 1) ? service.longBreakMin : service.shortBreakMin
          service.sendNotification("Break in 10s ☕", "Wrap up your work — your " + breakMinVal + "-minute break is about to begin.", "normal")
        }

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
