// High-Performance Gati Focus Timer Model & Pre-Allocated Lookup Tables
var STATE_IDLE = "idle"
var STATE_WORK = "work"
var STATE_SHORT_BREAK = "shortBreak"
var STATE_LONG_BREAK = "longBreak"

var PAD = []
for (var i = 0; i <= 99; i++) {
  PAD[i] = i < 10 ? "0" + i : "" + i
}

function formatTime(totalSeconds) {
  var s = totalSeconds > 0 ? (totalSeconds | 0) : 0
  var m = (s / 60) | 0
  var rem = s % 60
  var mStr = m < 100 ? PAD[m] : "" + m
  var sStr = rem < 100 ? PAD[rem] : "" + rem
  return mStr + ":" + sStr
}

function stateLabel(state) {
  switch (state) {
    case STATE_WORK: return "Focus"
    case STATE_SHORT_BREAK: return "Short Break"
    case STATE_LONG_BREAK: return "Long Break"
    default: return "Focus"
  }
}

function stateSubtitle(state) {
  switch (state) {
    case STATE_WORK: return "FOCUS SESSION"
    case STATE_SHORT_BREAK: return "SHORT BREAK"
    case STATE_LONG_BREAK: return "LONG BREAK"
    default: return "READY TO FOCUS"
  }
}

function stateIcon(state, running) {
  if (!running && state !== STATE_IDLE) return "󰏤"
  switch (state) {
    case STATE_WORK: return "󰔛"
    case STATE_SHORT_BREAK: return "󰚢"
    case STATE_LONG_BREAK: return "󰒲"
    default: return "󰔛"
  }
}

function isoFromDate(d) {
  var year = d.getFullYear()
  var month = d.getMonth() + 1
  var day = d.getDate()
  var mStr = month < 10 ? "0" + month : "" + month
  var dStr = day < 10 ? "0" + day : "" + day
  return year + "-" + mStr + "-" + dStr
}

function todayIso() {
  return isoFromDate(new Date())
}

function yesterdayIso() {
  var d = new Date()
  d.setDate(d.getDate() - 1)
  return isoFromDate(d)
}

function last7DaysIso() {
  var list = []
  var now = new Date()
  for (var i = 6; i >= 0; i--) {
    var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i)
    list.push(isoFromDate(d))
  }
  return list
}

function dayInitial(iso) {
  if (!iso) return ""
  var parts = iso.split("-")
  if (parts.length !== 3) return ""
  var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
  var initials = ["S", "M", "T", "W", "T", "F", "S"]
  return initials[d.getDay()]
}

function formatHoursMinutes(totalSeconds) {
  var s = totalSeconds > 0 ? (totalSeconds | 0) : 0
  var h = (s / 3600) | 0
  var m = ((s % 3600) / 60) | 0
  if (h > 0) {
    return h + "h " + (m > 0 ? m + "m" : "0m")
  }
  return m + "m"
}

function formatHoursDecimal(totalSeconds) {
  var s = totalSeconds > 0 ? (totalSeconds | 0) : 0
  var h = s / 3600.0
  if (h < 0.1 && s > 0) return "<0.1h"
  return h.toFixed(1) + "h"
}

var MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
var MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTH_INITIALS = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

function currentMonthKey() {
  return todayIso().substring(0, 7)
}

function currentYearKey() {
  return todayIso().substring(0, 4)
}

function currentMonthName() {
  var d = new Date()
  return MONTH_NAMES[d.getMonth()] + " " + d.getFullYear()
}

function currentYearName() {
  return "" + (new Date()).getFullYear()
}

function last28DaysIso() {
  var list = []
  var now = new Date()
  for (var i = 27; i >= 0; i--) {
    var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i)
    list.push(isoFromDate(d))
  }
  return list
}

// Geometric envelope matching the Gati infinity icon silhouette
function gatiWaveEnvelope(normX) {
  var x = Math.max(0.0, Math.min(1.0, normX)) * 24.0
  var topY = 8.0
  var botY = 8.0

  if (x < 3.5) {
    var t = Math.max(0.0, x / 3.5)
    var cap = Math.sqrt(Math.max(0.0, 1.0 - Math.pow(1.0 - t, 2)))
    topY = 8.0 - (6.0 * (0.35 + 0.65 * cap))
    botY = 8.0 + (6.0 * (0.35 + 0.65 * cap))
  } else if (x <= 6.5) {
    topY = 2.0
    botY = 14.0
  } else if (x <= 12.0) {
    var ratio = (x - 6.5) / 5.5
    topY = 2.0 + (6.0 * ratio)
    botY = 14.0 - (6.0 * ratio)
  } else if (x <= 17.5) {
    var ratio2 = (x - 12.0) / 5.5
    topY = 8.0 - (6.0 * ratio2)
    botY = 8.0 + (6.0 * ratio2)
  } else if (x <= 20.5) {
    topY = 2.0
    botY = 14.0
  } else {
    var t2 = Math.max(0.0, (24.0 - x) / 3.5)
    var cap2 = Math.sqrt(Math.max(0.0, 1.0 - Math.pow(1.0 - t2, 2)))
    topY = 8.0 - (6.0 * (0.35 + 0.65 * cap2))
    botY = 8.0 + (6.0 * (0.35 + 0.65 * cap2))
  }

  var span = (botY - topY) / 12.0
  return Math.max(0.0, span)
}

function clamp01(v) {
  return Math.max(0.0, Math.min(1.0, v))
}

function smoothstep(edge0, edge1, x) {
  var span = edge1 - edge0
  if (span === 0.0) return x < edge0 ? 0.0 : 1.0
  var t = clamp01((x - edge0) / span)
  return t * t * (3.0 - 2.0 * t)
}

// Soft elapsed fill plus a leading glow band. No hard left/right clip.
function progressGlow(normX, progressFraction) {
  var p = clamp01(progressFraction)
  var x = clamp01(normX)
  var elapsed = 1.0 - smoothstep(p, p + 0.12, x)
  var band = Math.exp(-Math.pow((x - p) / 0.07, 2.0))
  return clamp01(0.28 + 0.50 * elapsed + 0.55 * band)
}

// Continuous ocean-swell sample in 0..1.
function waveY(normX, phase) {
  var x = clamp01(normX)
  var breath = 0.58 + 0.42 * Math.sin(phase)
  var y = 0.50 + 0.20 * Math.sin(x * Math.PI * 2.0 + phase * 0.70) * breath
  y += 0.09 * Math.sin(x * Math.PI * 3.15 + phase * 1.12)
  return clamp01(y)
}

// Two cycles of the current workflow, capped so the daily track still fits.
function dailyGoalSessions(maxSessions) {
  var cycle = Math.max(1, Math.min(16, maxSessions | 0))
  return Math.max(1, Math.min(12, cycle * 2))
}

function goalPercent(completed, goal) {
  var g = Math.max(1, goal | 0)
  var c = Math.max(0, completed | 0)
  return Math.min(100, Math.round((c / g) * 100))
}

function cycleSessionNumber(sessionIndex, maxSessions) {
  var max = Math.max(1, maxSessions | 0)
  return Math.min(max, Math.max(1, sessionIndex | 0))
}

var MAX_TODAY_BLOCKS = 32
var BLOCK_STATUSES = { completed: true, skipped: true, pending: true }
var WORKFLOW_MODES = { classic: true, deep: true, ultra: true, custom: true }

function sanitizeWorkflowMode(mode) {
  if (typeof mode === "string" && WORKFLOW_MODES[mode]) return mode
  return "classic"
}

function sanitizeBlockStatus(value) {
  if (typeof value === "string" && BLOCK_STATUSES[value]) return value
  return "pending"
}

function sanitizeTodayBlocks(raw, workMin, shortMin, longMin, maxSessions) {
  if (!raw || typeof raw.length !== "number") return []
  var w = Math.min(180, Math.max(1, workMin | 0))
  var s = Math.min(60, Math.max(1, shortMin | 0))
  var l = Math.min(120, Math.max(1, longMin | 0))
  var cycle = Math.max(1, Math.min(16, maxSessions | 0))
  var n = Math.min(MAX_TODAY_BLOCKS, raw.length)
  var out = []
  for (var i = 0; i < n; i++) {
    var b = raw[i]
    if (!b || typeof b !== "object") continue
    var pomoDur = (typeof b.pomoDuration === "number" && isFinite(b.pomoDuration))
      ? Math.min(180, Math.max(1, Math.floor(b.pomoDuration)))
      : w
    var breakDur = (typeof b.breakDuration === "number" && isFinite(b.breakDuration))
      ? Math.min(120, Math.max(1, Math.floor(b.breakDuration)))
      : ((out.length % cycle === cycle - 1) ? l : s)
    out.push({
      pomo: sanitizeBlockStatus(b.pomo),
      break: sanitizeBlockStatus(b.break),
      pomoDuration: pomoDur,
      breakDuration: breakDur
    })
  }
  return out
}


