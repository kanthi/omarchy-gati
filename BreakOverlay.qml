import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Full-Screen Takeover Overlay for Focus Breaks
PanelWindow {
  id: overlayWindow

  visible: Service.isBreakOverlayVisible

  WlrLayershell.namespace: "omarchy-gati-break"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  color: "transparent"

  readonly property string backgroundPath: {
    var base = Quickshell.env("XDG_STATE_HOME")
    if (!base || base.length === 0) base = Quickshell.env("HOME") + "/.local/state"
    return base + "/omarchy/current/background"
  }

  // Soft Pleasant Pastel Color Palette
  readonly property color focusColor: Qt.rgba(0.96, 0.60, 0.60, 1.0)      // Pastel Coral / Rose
  readonly property color shortBreakColor: Qt.rgba(0.60, 0.85, 0.72, 1.0) // Pastel Mint / Sage
  readonly property color longBreakColor: Qt.rgba(0.76, 0.68, 0.95, 1.0)  // Pastel Lavender / Lilac
  readonly property color breakColor: Service.state === Model.STATE_LONG_BREAK
    ? longBreakColor
    : shortBreakColor

  // Wallpaper Backdrop for Shader Blur
  Image {
    id: wallpaper
    anchors.fill: parent
    source: overlayWindow.visible ? Util.fileUrl(overlayWindow.backgroundPath) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    visible: false
  }

  // GPU Hardware Accelerated Soft Focus Blur
  MultiEffect {
    anchors.fill: parent
    source: wallpaper
    autoPaddingEnabled: false
    blurEnabled: overlayWindow.visible && wallpaper.status === Image.Ready
    blur: 0.85
    blurMax: 64
    blurMultiplier: 1.25
    contrast: -0.06
    brightness: -0.12
  }

  // Fullscreen Dark Scrim with Reduced Opacity
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0.04, 0.05, 0.07, 0.65)
  }

  // Keyboard shortcuts for break overlay (Continue, Skip, Extend)
  Item {
    anchors.fill: parent
    focus: overlayWindow.visible

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_S || event.key === Qt.Key_C) {
        if (Service.breakComplete) {
          Service.continueToNextFocus()
        } else {
          Service.skip()
        }
        event.accepted = true
      } else if (event.key === Qt.Key_E) {
        Service.extendBreak(5)
        event.accepted = true
      }
    }
  }

  // Primary Center Stage: Zen Rhythm Break Card (Matching Panel.qml Paradigm D)
  Rectangle {
    anchors.centerIn: parent
    width: Style.space(380)
    implicitHeight: cardContent.implicitHeight + Style.space(32)
    radius: Style.cornerRadius
    color: Qt.rgba(0.08, 0.10, 0.13, 0.88)
    border.color: Qt.rgba(1, 1, 1, 0.16)
    border.width: 1

    Column {
      id: cardContent
      anchors.centerIn: parent
      width: parent.width - Style.space(32)
      spacing: Style.space(16)

      // 1. Top Header Row: Time & Phase Title + Floating Session Dots
      Item {
        width: parent.width
        height: Style.space(42)

        // Left: Large Countdown + Uppercase Subtitle
        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            text: Service.breakComplete ? "00:00" : Model.formatTime(Service.remainingSeconds)
            font.family: Style.font.family
            font.pixelSize: Style.font.title + 16
            font.bold: true
            color: Color.foreground
            style: Text.Sunken
            styleColor: Qt.rgba(0, 0, 0, 0.85)
          }

          Text {
            text: Service.breakComplete ? "BREAK COMPLETE" : Model.stateLabel(Service.state).toUpperCase()
            font.family: Style.font.family
            font.pixelSize: Style.font.caption - 1
            font.bold: true
            font.letterSpacing: 1.1
            color: overlayWindow.breakColor
            style: Text.Sunken
            styleColor: Qt.rgba(0, 0, 0, 0.85)
          }
        }

        // Right: Minimalist Floating Session Indicator Dots
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Repeater {
            model: Service.maxSessions

            Rectangle {
              required property int index
              readonly property bool isCompleted: index < Service.completedSessions
              readonly property bool isCurrent: !isCompleted && (index === Service.completedSessions)
              width: isCurrent ? Style.space(6.5) : Style.space(5)
              height: isCurrent ? Style.space(6.5) : Style.space(5)
              radius: width / 2.0
              anchors.verticalCenter: parent.verticalCenter
              color: isCompleted ? overlayWindow.breakColor : Qt.rgba(1, 1, 1, 0.18)

              Behavior on color { ColorAnimation { duration: 200 } }
              Behavior on width { NumberAnimation { duration: 150 } }
              Behavior on height { NumberAnimation { duration: 150 } }
            }
          }
        }
      }

      // 2. Center Stage: Ambient Kinetic Zen Rhythm Bar (Harmonic Waveform)
      Item {
        id: waveContainer
        width: parent.width
        height: Style.space(52)

        property real wavePhase: 0.0
        readonly property int barCount: 28

        Timer {
          interval: 33
          running: overlayWindow.visible && Service.running && !Service.breakComplete
          repeat: true
          onTriggered: waveContainer.wavePhase += 0.08
        }

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Repeater {
            model: waveContainer.barCount

            Rectangle {
              required property int index
              readonly property real normX: index / (waveContainer.barCount - 1)
              readonly property real sineEnv: Math.sin(normX * Math.PI)
              readonly property bool isElapsed: Service.progressFraction > 0.0 && normX <= Service.progressFraction

              width: Math.max(3, (waveContainer.width - (waveContainer.barCount - 1) * Style.space(4)) / waveContainer.barCount)
              radius: width / 2.0
              anchors.verticalCenter: parent.verticalCenter

              height: Service.running && !Service.breakComplete
                ? Math.max(Style.space(6), Style.space(8) + (Style.space(42) * sineEnv * (0.45 + 0.55 * Math.sin(waveContainer.wavePhase * 2.2 + normX * 6.2))))
                : Math.max(Style.space(6), Style.space(8) + (Style.space(26) * sineEnv))

              color: isElapsed
                ? overlayWindow.breakColor
                : Qt.rgba(1, 1, 1, 0.10)

              Behavior on color {
                ColorAnimation { duration: 250 }
              }
            }
          }
        }
      }

      // 3. Bottom Action Controls
      Item {
        width: parent.width
        height: Style.space(34)

        // State A: Break Running Controls
        Row {
          visible: !Service.breakComplete
          anchors.centerIn: parent
          spacing: Style.space(12)

          // Extend +5 Min Button
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: extMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.color: extMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "+5 min"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.foreground
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: extMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Service.extendBreak(5)
            }
          }

          // Primary Play / Pause Pill Button
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(58)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: playMouse.containsMouse
              ? Util.alpha(overlayWindow.breakColor, 0.22)
              : (Service.running ? Util.alpha(overlayWindow.breakColor, 0.12) : "transparent")
            border.color: playMouse.containsMouse
              ? Qt.rgba(0.7, 0.72, 0.76, 0.5)
              : Qt.rgba(0.5, 0.53, 0.58, 0.35)
            border.width: 1.5

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              anchors.horizontalCenterOffset: Service.running ? 0 : 1
              text: Service.running ? "󰏤" : "󰐊"
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              color: overlayWindow.breakColor
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: playMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Service.toggle()
            }
          }

          // Skip Break Button
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: skpMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.color: skpMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "Skip"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.foreground
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: skpMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Service.skip()
            }
          }
        }

        // State B: Break Complete Controls (Ready for Focus)
        Row {
          visible: Service.breakComplete
          anchors.centerIn: parent
          spacing: Style.space(12)

          // Primary Continue / Begin Focus Pill
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(160)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: contMouse.containsMouse
              ? Qt.lighter(overlayWindow.breakColor, 1.08)
              : overlayWindow.breakColor

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰐊"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Qt.rgba(0.08, 0.12, 0.1, 1.0)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Start Focus"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Qt.rgba(0.08, 0.12, 0.1, 1.0)
              }
            }

            MouseArea {
              id: contMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Service.continueToNextFocus()
            }
          }

          // Secondary Extend +5m
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            height: Style.space(34)
            radius: Style.cornerRadius
            color: extMoreMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.color: extMoreMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "+5 min"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.foreground
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: extMoreMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Service.extendBreak(5)
            }
          }
        }
      }
    }
  }
}
