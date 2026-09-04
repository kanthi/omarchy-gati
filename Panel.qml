import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.kanthi.gati"
  ipcTarget: "io.github.kanthi.gati"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var owner: null
  readonly property var barIdentity: hostWidget || root

  property string currentView: "timer"
  readonly property bool showSettings: currentView === "settings"
  readonly property bool showStats: currentView === "stats"

  // Soft Pleasant Pastel Color Palette
  readonly property color focusColor: hostWidget ? hostWidget.focusColor : Qt.rgba(0.96, 0.60, 0.60, 1.0)
  readonly property color shortBreakColor: hostWidget ? hostWidget.shortBreakColor : Qt.rgba(0.60, 0.85, 0.72, 1.0)
  readonly property color longBreakColor: hostWidget ? hostWidget.longBreakColor : Qt.rgba(0.76, 0.68, 0.95, 1.0)
  readonly property color pausedColor: hostWidget ? hostWidget.pausedColor : Qt.rgba(0.98, 0.78, 0.55, 1.0)
  readonly property color normalColor: bar ? bar.barForeground : Color.foreground

  readonly property color activePhaseColor: {
    if (!Service.running && Service.state !== Model.STATE_IDLE) return pausedColor
    switch (Service.state) {
      case Model.STATE_WORK: return focusColor
      case Model.STATE_SHORT_BREAK: return shortBreakColor
      case Model.STATE_LONG_BREAK: return longBreakColor
      default: return focusColor
    }
  }

  // Detect current bar section from host bar layout
  readonly property string currentSection: {
    if (!bar || !bar.layoutConfig) return "right"
    var layout = bar.layoutConfig
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = layout[sections[s]] || []
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        var id = (typeof entry === "string") ? entry : (entry ? entry.id : "")
        if (id === root.moduleName) return sections[s]
      }
    }
    return "right"
  }

  function moveToSection(sec) {
    if (root.bar && root.bar.shell && typeof root.bar.shell.moveBarWidget === "function") {
      root.bar.shell.moveBarWidget(root.moduleName, JSON.stringify({ section: sec }))
    } else {
      Quickshell.execDetached(["omarchy-shell", "shell", "moveBarWidget", root.moduleName, JSON.stringify({ section: sec })])
    }
  }

  function persist(newSettings) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    for (var key in newSettings) entry[key] = newSettings[key]

    root.settings = entry
    if (root.hostWidget) {
      if ("settings" in root.hostWidget) root.hostWidget.settings = entry
      if ("showTimerInBar" in root.hostWidget && "showTimerInBar" in newSettings) {
        root.hostWidget.showTimerInBar = newSettings.showTimerInBar
      }
    }
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function open() { root.controller.show() }
  function close() {
    currentView = "timer"
    root.controller.hide()
  }
  function toggle() { if (root.opened) root.close(); else root.open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem || root.owner
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(310))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // 1. Sub-View Header Row (Visible when Settings or Stats is open)
        Item {
          width: parent.width
          height: (root.showSettings || root.showStats) ? Style.space(26) : 0
          visible: root.showSettings || root.showStats

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.showStats ? "Focus Statistics" : "Settings"
            font.family: bar ? bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: root.activePhaseColor
            style: Text.Sunken
            styleColor: Qt.rgba(0, 0, 0, 0.85)
          }

          // Back / Close button in header returning to Timer view
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            border.color: backMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.2)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              font.family: bar ? bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption + 1
              color: Color.foreground
            }

            MouseArea {
              id: backMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.currentView = "timer"
            }
          }
        }

        // 2. PARADIGM D: The Ambient Zen Rhythm Bar (Flow State Visualizer)
        Column {
          width: parent.width
          spacing: Style.space(14)
          visible: root.currentView === "timer"

          // Top Header Row: Time & Phase + Session Badge
          Item {
            width: parent.width
            height: Style.space(42)

            // Left: Large Monospace/Display Countdown + Uppercase Subtitle
            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: Model.formatTime(Service.remainingSeconds)
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title + 16
                font.bold: true
                color: Color.foreground
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.85)
              }

              Text {
                text: Model.stateLabel(Service.state).toUpperCase()
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                font.letterSpacing: 1.1
                color: root.activePhaseColor
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
                  color: isCompleted ? root.activePhaseColor : Qt.rgba(1, 1, 1, 0.18)

                  Behavior on color { ColorAnimation { duration: 200 } }
                  Behavior on width { NumberAnimation { duration: 150 } }
                  Behavior on height { NumberAnimation { duration: 150 } }
                }
              }
            }
          }

          // Center Stage: Ambient Kinetic Zen Rhythm Bar (Harmonic Waveform)
          Item {
            id: waveContainer
            width: parent.width
            height: Style.space(52)

            property real wavePhase: 0.0
            readonly property int barCount: 26

            Timer {
              interval: 33
              running: panel.open && Service.running
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

                  height: Service.running
                    ? Math.max(Style.space(6), Style.space(8) + (Style.space(42) * sineEnv * (0.45 + 0.55 * Math.sin(waveContainer.wavePhase * 2.2 + normX * 6.2))))
                    : Math.max(Style.space(6), Style.space(8) + (Style.space(26) * sineEnv))

                  color: isElapsed
                    ? root.activePhaseColor
                    : Qt.rgba(1, 1, 1, 0.10)

                  Behavior on color {
                    ColorAnimation { duration: 250 }
                  }
                }
              }
            }
          }

          // Bottom Action Control Strip
          Item {
            width: parent.width
            height: Style.space(34)

            // Centered Controls
            Row {
              anchors.centerIn: parent
              spacing: Style.space(12)

              // Reset Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(34)
                radius: Style.cornerRadius
                color: rstMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                border.color: rstMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰑖"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  color: Color.foreground
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                  id: rstMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Service.reset()
                }
              }

              // Primary Play / Pause Pill Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(58)
                height: Style.space(34)
                radius: Style.cornerRadius
                color: playMouse.containsMouse
                  ? Util.alpha(root.activePhaseColor, 0.22)
                  : (Service.running ? Util.alpha(root.activePhaseColor, 0.12) : "transparent")
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
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  color: root.activePhaseColor
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

              // Skip Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(34)
                radius: Style.cornerRadius
                color: skpMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                border.color: skpMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰒭"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
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

            // Right Edge: Stats & Settings Utility Buttons
            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              // Stats Toggle Button (Placed before Settings)
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.showStats
                  ? Util.alpha(root.activePhaseColor, 0.15)
                  : (statsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                border.color: root.showStats
                  ? root.activePhaseColor
                  : (statsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.15))
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰄫"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  color: root.showStats ? root.activePhaseColor : Color.foreground
                }

                MouseArea {
                  id: statsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentView = (root.currentView === "stats") ? "timer" : "stats"
                }
              }

              // Settings Toggle Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.showSettings
                  ? Util.alpha(root.activePhaseColor, 0.15)
                  : (settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                border.color: root.showSettings
                  ? root.activePhaseColor
                  : (settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.15))
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰒓"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  color: root.showSettings ? root.activePhaseColor : Color.foreground
                }

                MouseArea {
                  id: settingsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentView = (root.currentView === "settings") ? "timer" : "settings"
                }
              }
            }
          }
        }

        // 3. On-Demand Lazy Loaded Stats View
        Loader {
          width: parent.width
          active: root.showStats
          visible: root.showStats
          sourceComponent: statsComponent
        }

        Component {
          id: statsComponent

          Column {
            width: parent.width
            spacing: Style.space(12)

            // Hero Metric Card: Today's Focus & Sessions
            Rectangle {
              width: parent.width
              height: Style.space(90)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.035)
              border.color: Qt.rgba(1, 1, 1, 0.12)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Top Row: 2 Metric Columns
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  // Left: Focus Time Today
                  Item {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(40)

                    Column {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        text: Model.formatHoursMinutes(Service.todayFocusSeconds)
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title + 2
                        font.bold: true
                        color: Color.foreground
                        style: Text.Sunken
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                      }

                      Text {
                        text: "TODAY'S FOCUS"
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        font.letterSpacing: 0.8
                        color: Qt.rgba(1, 1, 1, 0.45)
                      }
                    }
                  }

                  // Right: Sessions Today
                  Item {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(40)

                    Column {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        anchors.right: parent.right
                        text: Service.todayCompletedSessions + " / 8"
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title + 2
                        font.bold: true
                        color: root.activePhaseColor
                        style: Text.Sunken
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                      }

                      Text {
                        anchors.right: parent.right
                        text: "SESSIONS TODAY"
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        font.letterSpacing: 0.8
                        color: Qt.rgba(1, 1, 1, 0.45)
                      }
                    }
                  }
                }

                // Subtle Divider
                Rectangle {
                  width: parent.width
                  height: 1
                  color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Sub-Row: Streak & Goal
                Item {
                  width: parent.width
                  height: Style.space(16)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Text {
                      text: "󰈸"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption + 1
                      color: root.pausedColor
                    }

                    Text {
                      text: Service.streakDays + (Service.streakDays === 1 ? " Day Streak" : " Days Streak")
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.pausedColor
                    }
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.min(100, Math.round((Service.todayCompletedSessions / 8) * 100)) + "% of daily goal"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }
                }
              }
            }

            // 7-Day Activity Sparkline Chart
            Rectangle {
              width: parent.width
              height: Style.space(126)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.035)
              border.color: Qt.rgba(1, 1, 1, 0.12)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "7-DAY ACTIVITY"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                    font.letterSpacing: 0.9
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.formatHoursDecimal(Service.todayFocusSeconds) + " today"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    color: root.activePhaseColor
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(80)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(14)

                    Repeater {
                      model: Service.getWeeklyHistory()

                      Column {
                        required property var modelData
                        spacing: Style.space(4)
                        anchors.bottom: parent.bottom

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.seconds > 0 ? Model.formatHoursDecimal(modelData.seconds) : "-"
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 3
                          color: modelData.isToday ? root.activePhaseColor : Qt.rgba(1, 1, 1, 0.4)
                        }

                        Item {
                          width: Style.space(14)
                          height: Style.space(48)
                          anchors.horizontalCenter: parent.horizontalCenter

                          Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: Math.max(Style.space(4), Style.space(48) * modelData.fraction)
                            radius: Style.space(4)
                            color: modelData.isToday
                              ? root.activePhaseColor
                              : (modelData.seconds > 0 ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.08))

                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                          }
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.dayInitial
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: modelData.isToday
                          color: modelData.isToday ? root.activePhaseColor : Color.foreground
                        }
                      }
                    }
                  }
                }
              }
            }

            // Lifetime Summary Banner
            Rectangle {
              width: parent.width
              height: Style.space(32)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.035)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰋚"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.rgba(1, 1, 1, 0.5)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Lifetime: " + Model.formatHoursMinutes(Service.totalFocusSeconds) + " · " + Service.totalCompletedSessionsLifetime + " sessions"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption - 1
                  color: Qt.rgba(1, 1, 1, 0.6)
                }
              }
            }
          }
        }

        // 4. On-Demand Lazy Loaded Settings View
        Loader {
          width: parent.width
          active: root.showSettings
          visible: root.showSettings
          sourceComponent: settingsComponent
        }

        Component {
          id: settingsComponent

          Column {
            width: parent.width
            spacing: Style.space(16)

            // 1. Workflow Mode Segmented Control
            Column {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "WORKFLOW MODE"
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: Qt.darker(Color.foreground, 1.5)
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }

              // Single Unified Segmented Pill
              Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                readonly property var modes: [
                  { id: "classic", label: "Classic", work: 25, shortBreak: 5, longBreak: 15, sessions: 4, desc: "25m Focus • 5m Break • 4x Cycle" },
                  { id: "deep",    label: "Deep",    work: 50, shortBreak: 10, longBreak: 20, sessions: 2, desc: "50m Focus • 10m Break • 2x Cycle" },
                  { id: "ultra",   label: "Ultra",   work: 90, shortBreak: 20, longBreak: 30, sessions: 2, desc: "90m Sprint • 20m Break • 2x Cycle" },
                  { id: "custom",  label: "Custom",  work: -1, shortBreak: -1, longBreak: -1, sessions: -1, desc: "Custom configured durations" }
                ]

                readonly property string activeModeId: {
                  if (Service.workDurationMin === 25 && Service.shortBreakMin === 5 && Service.maxSessions === 4) return "classic"
                  if (Service.workDurationMin === 50 && Service.shortBreakMin === 10 && Service.maxSessions === 2) return "deep"
                  if (Service.workDurationMin === 90 && Service.shortBreakMin === 20 && Service.maxSessions === 2) return "ultra"
                  return "custom"
                }

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  spacing: Style.space(2)

                  Repeater {
                    model: parent.parent.modes

                    Rectangle {
                      required property var modelData
                      readonly property bool isSelected: parent.parent.activeModeId === modelData.id
                      width: (parent.width - (3 * Style.space(2))) / 4
                      height: parent.height
                      radius: Style.cornerRadius - 1
                      color: isSelected
                        ? Util.alpha(root.activePhaseColor, 0.18)
                        : (modeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                      border.color: isSelected ? root.activePhaseColor : "transparent"
                      border.width: isSelected ? 1 : 0

                      Behavior on color { ColorAnimation { duration: 120 } }

                      Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: isSelected
                        color: isSelected ? root.activePhaseColor : Color.foreground
                        style: Text.Sunken
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                      }

                      MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (modelData.id !== "custom") {
                            Service.workDurationMin = modelData.work
                            Service.shortBreakMin = modelData.shortBreak
                            Service.longBreakMin = modelData.longBreak
                            Service.maxSessions = modelData.sessions
                            if (Service.state === Model.STATE_IDLE && !Service.running) {
                              Service.totalSeconds = modelData.work * 60
                              Service.remainingSeconds = Service.totalSeconds
                            }
                            root.persist({
                              workDurationMin: modelData.work,
                              shortBreakMin: modelData.shortBreak,
                              longBreakMin: modelData.longBreak,
                              longBreakInterval: modelData.sessions
                            })
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Dynamic Workflow Description Tag
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                  if (Service.workDurationMin === 25 && Service.shortBreakMin === 5 && Service.maxSessions === 4)
                    return "25m Focus • 5m Break • 4 Sessions / Cycle"
                  if (Service.workDurationMin === 50 && Service.shortBreakMin === 10 && Service.maxSessions === 2)
                    return "50m Focus • 10m Break • 2 Sessions / Cycle"
                  if (Service.workDurationMin === 90 && Service.shortBreakMin === 20 && Service.maxSessions === 2)
                    return "90m Sprint • 20m Break • 2 Sessions / Cycle"
                  return Service.workDurationMin + "m Focus • " + Service.shortBreakMin + "m Break • " + Service.maxSessions + "x"
                }
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                color: root.activePhaseColor
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }
            }

            // 2. Custom Steppers (Only visible when Custom Mode is selected)
            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: (Service.workDurationMin !== 25 || Service.shortBreakMin !== 5 || Service.maxSessions !== 4) &&
                       (Service.workDurationMin !== 50 || Service.shortBreakMin !== 10 || Service.maxSessions !== 2) &&
                       (Service.workDurationMin !== 90 || Service.shortBreakMin !== 20 || Service.maxSessions !== 2)

              // Focus Stepper Row
              Row {
                width: parent.width
                height: Style.space(28)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Focus Duration"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Item { Layout.fillWidth: true }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(24)
                    height: Style.space(24)
                    radius: Style.cornerRadius
                    color: fMinus.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    border.color: Qt.rgba(1,1,1,0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: fMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nw = Math.max(5, Service.workDurationMin - 5)
                        Service.workDurationMin = nw
                        if (Service.state === Model.STATE_IDLE && !Service.running) { Service.totalSeconds = nw * 60; Service.remainingSeconds = Service.totalSeconds }
                        root.persist({ workDurationMin: nw })
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(48)
                    horizontalAlignment: Text.AlignHCenter
                    text: Service.workDurationMin + " min"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.focusColor
                    style: Text.Sunken
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                  }

                  Rectangle {
                    width: Style.space(24)
                    height: Style.space(24)
                    radius: Style.cornerRadius
                    color: fPlus.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    border.color: Qt.rgba(1,1,1,0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: fPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nw = Math.min(120, Service.workDurationMin + 5)
                        Service.workDurationMin = nw
                        if (Service.state === Model.STATE_IDLE && !Service.running) { Service.totalSeconds = nw * 60; Service.remainingSeconds = Service.totalSeconds }
                        root.persist({ workDurationMin: nw })
                      }
                    }
                  }
                }
              }

              // Short Break Stepper Row
              Row {
                width: parent.width
                height: Style.space(28)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Short Break"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Item { Layout.fillWidth: true }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(24)
                    height: Style.space(24)
                    radius: Style.cornerRadius
                    color: bMinus.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    border.color: Qt.rgba(1,1,1,0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: bMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nb = Math.max(1, Service.shortBreakMin - 1)
                        Service.shortBreakMin = nb
                        root.persist({ shortBreakMin: nb })
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(48)
                    horizontalAlignment: Text.AlignHCenter
                    text: Service.shortBreakMin + " min"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.shortBreakColor
                    style: Text.Sunken
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                  }

                  Rectangle {
                    width: Style.space(24)
                    height: Style.space(24)
                    radius: Style.cornerRadius
                    color: bPlus.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    border.color: Qt.rgba(1,1,1,0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: bPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nb = Math.min(30, Service.shortBreakMin + 1)
                        Service.shortBreakMin = nb
                        root.persist({ shortBreakMin: nb })
                      }
                    }
                  }
                }
              }
            }

            // 3. Top Bar Appearance & Position
            Column {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "TOP BAR DISPLAY & POSITION"
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: Qt.darker(Color.foreground, 1.5)
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                // Display Mode Segmented Pill (Time / Icon)
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.52
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: Qt.rgba(1, 1, 1, 0.04)
                  border.color: Qt.rgba(1, 1, 1, 0.1)
                  border.width: 1

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(2)
                    spacing: Style.space(2)

                    Repeater {
                      model: [
                        { val: true, label: "Time" },
                        { val: false, label: "Icon" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: (root.settings && root.settings.showTimerInBar !== undefined)
                          ? (root.settings.showTimerInBar === modelData.val)
                          : (modelData.val === true)

                        width: (parent.width - Style.space(2)) / 2
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? Util.alpha(root.activePhaseColor, 0.18) : (dm.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: isSelected ? root.activePhaseColor : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: isSelected
                          color: isSelected ? root.activePhaseColor : Color.foreground
                          style: Text.Sunken
                          styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }

                        MouseArea {
                          id: dm
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.persist({ showTimerInBar: modelData.val })
                        }
                      }
                    }
                  }
                }

                // Bar Position Segmented Pill (Left / Center / Right)
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.48
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: Qt.rgba(1, 1, 1, 0.04)
                  border.color: Qt.rgba(1, 1, 1, 0.1)
                  border.width: 1

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(2)
                    spacing: Style.space(2)

                    Repeater {
                      model: [
                        { id: "left", label: "Left" },
                        { id: "center", label: "Center" },
                        { id: "right", label: "Right" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: root.currentSection === modelData.id

                        width: (parent.width - (2 * Style.space(2))) / 3
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? Util.alpha(root.activePhaseColor, 0.18) : (pm.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: isSelected ? root.activePhaseColor : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: isSelected
                          color: isSelected ? root.activePhaseColor : Color.foreground
                          style: Text.Sunken
                          styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }

                        MouseArea {
                          id: pm
                          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: root.moveToSection(modelData.id)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
