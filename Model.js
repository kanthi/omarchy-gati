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

