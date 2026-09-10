import QtQuick
import "Model.js" as Model

// Shared Gati ocean swell for the pop panel and break overlay.
Item {
  id: root

  property bool running: false
  property bool complete: false
  property real progressFraction: 0.0
  property color phaseColor: Qt.rgba(0.96, 0.60, 0.60, 1.0)
  property real wavePhase: 0.0

  readonly property bool animating: visible && running && !complete

  function cssColor(c, alpha, lift) {
    var l = (lift !== undefined) ? lift : 0.0
    var r = Math.round(Math.max(0, Math.min(1, c.r + (1.0 - c.r) * l)) * 255)
    var g = Math.round(Math.max(0, Math.min(1, c.g + (1.0 - c.g) * l)) * 255)
    var b = Math.round(Math.max(0, Math.min(1, c.b + (1.0 - c.b) * l)) * 255)
    var a = (alpha !== undefined) ? alpha : 1.0
    return "rgba(" + r + "," + g + "," + b + "," + a + ")"
  }

  function swellCrest(phaseOffset, ampScale, baseFromBottom) {
    var pts = []
    var n = 80
    var flatten = root.complete ? 0.14 : (root.running ? 1.0 : 0.40)
    for (var i = 0; i <= n; i++) {
      var nx = i / n
      var y = Model.waveY(nx, root.wavePhase + phaseOffset)
      var fromBottom = baseFromBottom + (y - 0.5) * ampScale * flatten
      pts.push({ x: nx, y: Math.max(0.16, Math.min(0.92, fromBottom)) })
    }
    return pts
  }

  function crestY(pt, h) {
    return h * (1.0 - pt.y)
  }

  function paintSwellLayer(ctx, w, h, pts, fillAlpha, strokeAlpha) {
    var n = pts.length
    ctx.beginPath()
    ctx.moveTo(0, h)
    for (var i = 0; i < n; i++) {
      ctx.lineTo(pts[i].x * w, crestY(pts[i], h))
    }
    ctx.lineTo(w, h)
    ctx.closePath()
    var g = ctx.createLinearGradient(0, h * 0.08, 0, h)
    g.addColorStop(0.0, cssColor(root.phaseColor, fillAlpha, 0.58))
    g.addColorStop(0.42, cssColor(root.phaseColor, fillAlpha * 0.28, 0.32))
    g.addColorStop(1.0, cssColor(root.phaseColor, 0.0))
    ctx.fillStyle = g
    ctx.fill()

    ctx.beginPath()
    for (var j = 0; j < n; j++) {
      var px = pts[j].x * w
      var py = crestY(pts[j], h)
      if (j === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.lineWidth = Math.max(1.6, h * 0.028)
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.strokeStyle = cssColor(root.phaseColor, strokeAlpha, 0.42)
    ctx.stroke()
  }

  function paintProgressCrest(ctx, w, h, pts, progress) {
    var n = pts.length
    var until = Math.max(2, Math.floor(progress * (n - 1)))
    ctx.beginPath()
    for (var i = 0; i <= until; i++) {
      var px = pts[i].x * w
      var py = crestY(pts[i], h)
      if (i === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.lineWidth = Math.max(2.0, h * 0.038)
    ctx.strokeStyle = cssColor(root.phaseColor, 0.92, 0.48)
    ctx.stroke()

    var lead = pts[until]
    var gx = lead.x * w
    var gy = crestY(lead, h)
    var rad = Math.max(10, h * 0.18)
    var halo = ctx.createRadialGradient(gx, gy, 0, gx, gy, rad)
    halo.addColorStop(0.0, cssColor(root.phaseColor, 0.35, 0.55))
    halo.addColorStop(1.0, cssColor(root.phaseColor, 0.0, 0.55))
    ctx.fillStyle = halo
    ctx.beginPath()
    ctx.arc(gx, gy, rad, 0, Math.PI * 2.0)
    ctx.fill()
  }

  function paintSwell(ctx, w, h) {
    var back = swellCrest(0.90, 0.85, 0.62)
    var front = swellCrest(0.0, 1.15, 0.52)
    paintSwellLayer(ctx, w, h, back, 0.14, 0.38)
    paintSwellLayer(ctx, w, h, front, 0.22, 0.82)

    var p = Math.max(0.0, Math.min(1.0, root.progressFraction))
    if (p > 0.01 && !root.complete)
      paintProgressCrest(ctx, w, h, front, p)
  }

  Timer {
    interval: 50
    running: root.animating
    repeat: true
    onTriggered: {
      root.wavePhase += 0.025
      waveCanvas.requestPaint()
    }
  }

  onVisibleChanged: if (visible) waveCanvas.requestPaint()
  onWidthChanged: waveCanvas.requestPaint()
  onHeightChanged: waveCanvas.requestPaint()
  onPhaseColorChanged: waveCanvas.requestPaint()
  onProgressFractionChanged: waveCanvas.requestPaint()
  onRunningChanged: waveCanvas.requestPaint()
  onCompleteChanged: waveCanvas.requestPaint()
  Component.onCompleted: waveCanvas.requestPaint()

  Canvas {
    id: waveCanvas
    anchors.fill: parent
    antialiasing: true
    contextType: "2d"

    onPaint: {
      var ctx = getContext("2d")
      if (!ctx) return
      ctx.clearRect(0, 0, width, height)
      if (width < 8 || height < 8) return
      root.paintSwell(ctx, width, height)
    }
  }
}
