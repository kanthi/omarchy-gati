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
