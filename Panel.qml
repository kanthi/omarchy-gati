import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

  property string selectedWorkflowMode: (root.settings && root.settings.workflowMode) ? root.settings.workflowMode : (Service.workflowMode || "classic")

  onSettingsChanged: {
    if (root.settings) {
      if (root.settings.workflowMode) {
        root.selectedWorkflowMode = root.settings.workflowMode
        Service.workflowMode = root.settings.workflowMode
      }
      if (root.settings.resetDaily !== undefined) Service.resetDaily = (root.settings.resetDaily === true)
      if (root.settings.soundEnabled !== undefined) Service.soundEnabled = (root.settings.soundEnabled === true)
      if (root.settings.soundVolume !== undefined) Service.soundVolume = root.settings.soundVolume
      if (root.settings.soundTheme !== undefined) Service.soundTheme = root.settings.soundTheme
      if (root.settings.notificationsEnabled !== undefined) Service.notificationsEnabled = (root.settings.notificationsEnabled === true)
      if (root.settings.autoStartBreaks !== undefined) Service.autoStartBreaks = (root.settings.autoStartBreaks === true)
      if (root.settings.autoStartWork !== undefined) Service.autoStartWork = (root.settings.autoStartWork === true)
    }
  }

  function updateWorkDuration(mins) {
    var nw = Math.min(180, Math.max(1, Math.floor(mins)))
    Service.workDurationMin = nw
    Service.workflowMode = "custom"
    root.selectedWorkflowMode = "custom"
    if (!Service.running && (Service.state === Model.STATE_IDLE || Service.state === Model.STATE_WORK)) {
      Service.totalSeconds = nw * 60
      Service.remainingSeconds = Service.totalSeconds
    }
    root.persist({ workflowMode: "custom", workDurationMin: nw })
  }

  function updateShortBreak(mins) {
    var nb = Math.min(60, Math.max(1, Math.floor(mins)))
    Service.shortBreakMin = nb
    Service.workflowMode = "custom"
    root.selectedWorkflowMode = "custom"
    if (!Service.running && Service.state === Model.STATE_SHORT_BREAK) {
      Service.totalSeconds = nb * 60
      Service.remainingSeconds = Service.totalSeconds
    }
    root.persist({ workflowMode: "custom", shortBreakMin: nb })
  }

  function updateLongBreak(mins) {
    var nl = Math.min(120, Math.max(1, Math.floor(mins)))
    Service.longBreakMin = nl
    Service.workflowMode = "custom"
    root.selectedWorkflowMode = "custom"
    if (!Service.running && Service.state === Model.STATE_LONG_BREAK) {
      Service.totalSeconds = nl * 60
      Service.remainingSeconds = Service.totalSeconds
    }
    root.persist({ workflowMode: "custom", longBreakMin: nl })
  }

  function updateMaxSessions(count) {
    var ns = Math.min(16, Math.max(1, Math.floor(count)))
    Service.maxSessions = ns
    Service.workflowMode = "custom"
    root.selectedWorkflowMode = "custom"
    root.persist({ workflowMode: "custom", longBreakInterval: ns })
  }

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

  // Subtle, calm settings button palette (eliminating intimidating bright red/coral highlights)
  readonly property color settingActiveColor: shortBreakColor // Calm Zen Sage/Mint: rgba(0.60, 0.85, 0.72, 1.0)
  readonly property color settingActiveBg: Util.alpha(settingActiveColor, 0.12)
  readonly property color settingActiveBorder: Util.alpha(settingActiveColor, 0.35)

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
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(24))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // 1. Sub-View Header Row (Visible when Settings or Stats is open)
        Item {
          width: parent.width
          height: (root.showSettings || root.showStats) ? Style.space(34) : 0
          visible: root.showSettings || root.showStats

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: root.showStats ? "󰄧" : "󰒓"
              font.family: bar ? bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              color: root.settingActiveColor
            }

            Text {
              text: root.showStats ? "Focus Statistics" : "Settings"
              font.family: bar ? bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              color: Color.foreground
              style: Text.Sunken
              styleColor: Qt.rgba(0, 0, 0, 0.85)
            }
          }

          // Back / Close button in header returning to Timer view
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32)
            height: Style.space(32)
            radius: Style.cornerRadius
            color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            border.color: backMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.2)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              font.family: bar ? bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
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
          spacing: Style.space(16)
          visible: root.currentView === "timer"

          // Top Header Row: Time & Phase + Session Badge
          Item {
            width: parent.width
            height: Style.space(80)

            // Left: Large Monospace/Display Countdown + Uppercase Subtitle
            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                id: clockText
                text: Model.formatTime(Service.remainingSeconds)
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: (Style.font.title + 16) * 2
                font.bold: true
                color: Color.foreground
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.85)
              }

              Text {
                text: Model.stateLabel(Service.state).toUpperCase()
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
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

          // Center Stage: Ambient Kinetic Zen Rhythm Bar (Gati Infinity Icon Waveform)
          Item {
            id: waveContainer
            width: parent.width
            height: Style.space(70)

            property real wavePhase: 0.0
            readonly property int barCount: 28

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

                Item {
                  id: colDelegate
                  required property int index
                  readonly property real normX: index / (waveContainer.barCount - 1)
                  readonly property real gatiEnv: Model.gatiWaveEnvelope(normX)
                  readonly property bool isElapsed: Service.progressFraction > 0.0 && normX <= Service.progressFraction

                  readonly property real amp: Service.running
                    ? Math.max(0.0, Math.min(1.0, gatiEnv * (0.45 + 0.55 * Math.sin(waveContainer.wavePhase * 2.2 + normX * 6.2))))
                    : (gatiEnv * 0.95)

                  readonly property int level: {
                    if (amp < 0.16) return 0
                    if (amp < 0.38) return 1
                    if (amp < 0.62) return 2
                    if (amp < 0.86) return 3
                    return 4
                  }

                  width: Math.max(3, (waveContainer.width - (waveContainer.barCount - 1) * Style.space(4)) / waveContainer.barCount)
                  height: waveContainer.height

                  readonly property real segH: Style.space(4.5)
                  readonly property real segG: Style.space(2)
                  readonly property real centerY: waveContainer.height / 2.0
                  readonly property color segColor: colDelegate.isElapsed ? root.activePhaseColor : Qt.rgba(1, 1, 1, 0.20)

                  // Center Baseline Dot (level === 0)
                  Rectangle {
                    visible: colDelegate.level === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width, Style.space(3))
                    height: Style.space(3)
                    radius: width / 2.0
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }

                  // Center Baseline Segment (level > 0)
                  Rectangle {
                    visible: colDelegate.level > 0
                    anchors.centerIn: parent
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }

                  // Tier 1 (1 step above / below)
                  Rectangle {
                    visible: colDelegate.level >= 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY - (colDelegate.segH + colDelegate.segG) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                  Rectangle {
                    visible: colDelegate.level >= 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY + (colDelegate.segH + colDelegate.segG) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }

                  // Tier 2 (2 steps above / below)
                  Rectangle {
                    visible: colDelegate.level >= 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY - (2 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                  Rectangle {
                    visible: colDelegate.level >= 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY + (2 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }

                  // Tier 3 (3 steps above / below)
                  Rectangle {
                    visible: colDelegate.level >= 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY - (3 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                  Rectangle {
                    visible: colDelegate.level >= 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY + (3 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }

                  // Tier 4 (4 steps above / below)
                  Rectangle {
                    visible: colDelegate.level >= 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY - (4 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                  Rectangle {
                    visible: colDelegate.level >= 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(colDelegate.centerY + (4 * (colDelegate.segH + colDelegate.segG)) - colDelegate.segH / 2.0)
                    width: parent.width
                    height: colDelegate.segH
                    radius: Style.space(1)
                    color: colDelegate.segColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                  }
                }
              }
            }
          }

          // Bottom Action Control Strip
          Item {
            width: parent.width
            height: Style.space(44)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)

              // 1. Reset Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(36)
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

              // 2. Primary Play / Pause Pill Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(62)
                height: Style.space(36)
                radius: Style.cornerRadius
                color: playMouse.containsMouse
                  ? Util.alpha(root.activePhaseColor, 0.24)
                  : (Service.running ? Util.alpha(root.activePhaseColor, 0.14) : Qt.rgba(1, 1, 1, 0.04))
                border.color: playMouse.containsMouse
                  ? root.activePhaseColor
                  : (Service.running ? root.activePhaseColor : Qt.rgba(1, 1, 1, 0.25))
                border.width: 1.5

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  anchors.horizontalCenterOffset: Service.running ? 0 : 1
                  text: Service.running ? "󰏤" : "󰐊"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title + 2
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

              // 3. Skip Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(36)
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

              // Subtle Divider
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Style.space(20)
                color: Qt.rgba(1, 1, 1, 0.15)
              }

              // 4. Stats Toggle Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(36)
                radius: Style.cornerRadius
                color: root.showStats
                  ? root.settingActiveBg
                  : (statsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                border.color: root.showStats
                  ? root.settingActiveBorder
                  : (statsMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22))
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰄧"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body + 1
                  color: root.showStats ? root.settingActiveColor : Color.foreground
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                  id: statsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentView = (root.currentView === "stats") ? "timer" : "stats"
                }
              }

              // 5. Settings Toggle Button
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(36)
                radius: Style.cornerRadius
                color: root.showSettings
                  ? root.settingActiveBg
                  : (settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                border.color: root.showSettings
                  ? root.settingActiveBorder
                  : (settingsMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.22))
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                  anchors.centerIn: parent
                  text: "󰒓"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body + 1
                  color: root.showSettings ? root.settingActiveColor : Color.foreground
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
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

          // Bottom breathing room spacer in timer view
          Item {
            width: parent.width
            height: Style.space(10)
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
            id: statsRoot
            width: parent.width
            spacing: Style.space(10)

            property string selectedPeriod: "daily"

            // 1. Sleek 4-Way Segmented Period Selector
            Rectangle {
              width: parent.width
              height: Style.space(32)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(3)
                spacing: Style.space(4)

                Repeater {
                  model: [
                    { id: "daily", label: "Daily" },
                    { id: "weekly", label: "Weekly" },
                    { id: "monthly", label: "Monthly" },
                    { id: "yearly", label: "Yearly" }
                  ]

                  Rectangle {
                    required property var modelData
                    required property int index
                    width: (parent.width - (3 * Style.space(4))) / 4
                    height: parent.height
                    radius: Style.cornerRadius - 2
                    color: statsRoot.selectedPeriod === modelData.id
                      ? root.settingActiveBg
                      : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                    border.color: statsRoot.selectedPeriod === modelData.id
                      ? root.settingActiveBorder
                      : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: statsRoot.selectedPeriod === modelData.id
                      color: statsRoot.selectedPeriod === modelData.id
                        ? root.settingActiveColor
                        : (tabMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.6))
                    }

                    MouseArea {
                      id: tabMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: statsRoot.selectedPeriod = modelData.id
                    }
                  }
                }
              }
            }

            // 2. HERO METRIC CARD (Dynamically adapts to selectedPeriod)
            Rectangle {
              width: parent.width
              height: Style.space(90)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Top Row: Primary Metric & Secondary Metric
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  // Left: Focus Time
                  Item {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(40)

                    Column {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        text: {
                          switch (statsRoot.selectedPeriod) {
                            case "daily": return Model.formatHoursMinutes(Service.todayFocusSeconds)
                            case "weekly": return Model.formatHoursMinutes(Service.getWeeklyTotalSeconds())
                            case "monthly": return Model.formatHoursMinutes(Service.getMonthlyTotalSeconds())
                            case "yearly": return Model.formatHoursMinutes(Service.getYearlyTotalSeconds())
                            default: return Model.formatHoursMinutes(Service.todayFocusSeconds)
                          }
                        }
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title + 2
                        font.bold: true
                        color: Color.foreground
                        style: Text.Sunken
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                      }

                      Text {
                        text: {
                          switch (statsRoot.selectedPeriod) {
                            case "daily": return "FOCUS (" + Service.todayCompletedSessions + "/8 SESS)"
                            case "weekly": return "PAST 7 DAYS"
                            case "monthly": return Model.currentMonthName().toUpperCase()
                            case "yearly": return Model.currentYearName() + " TOTAL"
                            default: return "FOCUS TIME"
                          }
                        }
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        font.letterSpacing: 0.8
                        color: Qt.rgba(1, 1, 1, 0.45)
                      }
                    }
                  }

                  // Right: Break Time (Daily) or Sessions Count (Weekly/Monthly/Yearly)
                  Item {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(40)

                    Column {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        anchors.right: parent.right
                        text: {
                          switch (statsRoot.selectedPeriod) {
                            case "daily": return Model.formatHoursMinutes(Service.getTodayBreakSeconds())
                            case "weekly": return Service.getWeeklyTotalSessions() + " sess"
                            case "monthly": return Service.getMonthlyTotalSessions() + " sess"
                            case "yearly": return Service.getYearlyTotalSessions() + " sess"
                            default: return Service.todayCompletedSessions + " sess"
                          }
                        }
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title + 2
                        font.bold: true
                        color: root.settingActiveColor
                        style: Text.Sunken
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                      }

                      Text {
                        anchors.right: parent.right
                        text: {
                          switch (statsRoot.selectedPeriod) {
                            case "daily": return "BREAK (" + Service.getTodayCompletedBreaks() + " COMPLETED)"
                            case "weekly": return "WEEKLY SESSIONS"
                            case "monthly": return "MONTHLY SESSIONS"
                            case "yearly": return "ANNUAL SESSIONS"
                            default: return "SESSIONS"
                          }
                        }
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

                // Sub-Row: Streak / Average / Pace
                Item {
                  width: parent.width
                  height: Style.space(16)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Text {
                      text: statsRoot.selectedPeriod === "daily" ? "󰈸" : (statsRoot.selectedPeriod === "yearly" ? "󰞅" : "󰓅")
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption + 1
                      color: root.settingActiveColor
                    }

                    Text {
                      text: {
                        switch (statsRoot.selectedPeriod) {
                          case "daily":
                            return Service.streakDays + (Service.streakDays === 1 ? " Day Streak" : " Days Streak")
                          case "weekly":
                            return "Avg " + Model.formatHoursMinutes(Service.getWeeklyDailyAverageSeconds()) + " / day"
                          case "monthly":
                            return "Avg " + Model.formatHoursMinutes(Service.getMonthlyDailyAverageSeconds()) + " / day"
                          case "yearly":
                            return "Avg " + Model.formatHoursDecimal(Service.getYearlyMonthlyAverageSeconds()) + " / mo"
                          default:
                            return ""
                        }
                      }
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.settingActiveColor
                    }
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                      switch (statsRoot.selectedPeriod) {
                        case "daily":
                          return Math.min(100, Math.round((Service.todayCompletedSessions / 8) * 100)) + "% of daily goal"
                        case "weekly":
                          return Service.getWeeklyActiveDaysCount() + " / 7 days active"
                        case "monthly":
                          return Service.getMonthlyActiveDaysCount() + " active days this month"
                        case "yearly":
                          return "Top: " + Service.getYearlyBestMonth()
                        default:
                          return ""
                      }
                    }
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }
                }
              }
            }

            // 3. PERIOD-SPECIFIC VISUALIZATION CARD
            // A. DAILY: Modern Linear Twin Focus & Break Capsule Track
            Rectangle {
              visible: statsRoot.selectedPeriod === "daily"
              width: parent.width
              height: Style.space(136)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                // Header Row
                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DAILY FLOW TRACK (" + Service.workDurationMin + "m + " + Service.shortBreakMin + "m)"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                    font.letterSpacing: 0.9
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Service.todayCompletedSessions >= 8 ? "Goal Achieved! 󰄳" : (8 - Service.todayCompletedSessions) + " to daily goal"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    color: root.settingActiveColor
                  }
                }

                // Row 1: FOCUS Capsules
                Row {
                  width: parent.width
                  spacing: Style.space(4)

                  Text {
                    width: Style.space(40)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "FOCUS"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                    font.letterSpacing: 0.6
                    color: Qt.rgba(1, 1, 1, 0.45)
                  }

                  Repeater {
                    model: Service.todayDisplayBlocks

                    Rectangle {
                      required property var modelData
                      required property int index

                      width: Math.floor((parent.width - Style.space(44) - 7 * Style.space(4)) / 8)
                      height: Style.space(16)
                      radius: Style.space(4)

                      readonly property bool isFinished: modelData.pomo === "completed"
                      readonly property bool isSkipped: modelData.pomo === "skipped"
                      readonly property bool isActive: modelData.pomo === "active"

                      color: isFinished
                        ? root.settingActiveColor
                        : (isActive ? root.settingActiveBg : (isSkipped ? Qt.rgba(0.42, 0.44, 0.48, 0.35) : Qt.rgba(1, 1, 1, 0.06)))
                      border.color: isFinished
                        ? root.settingActiveColor
                        : (isActive ? root.settingActiveColor : (isSkipped ? Qt.rgba(0.55, 0.58, 0.62, 0.4) : Qt.rgba(1, 1, 1, 0.08)))
                      border.width: isActive ? 1.5 : 1

                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: parent.isFinished ? "✓" : (parent.isActive ? "▶" : (parent.isSkipped ? "–" : ""))
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 4
                        font.bold: true
                        color: parent.isFinished
                          ? Qt.rgba(0.08, 0.08, 0.12, 0.95)
                          : (parent.isActive ? root.settingActiveColor : (parent.isSkipped ? Qt.rgba(0.85, 0.85, 0.88, 0.75) : "transparent"))
                      }
                    }
                  }
                }

                // Row 2: BREAK Capsules
                Row {
                  width: parent.width
                  spacing: Style.space(4)

                  Text {
                    width: Style.space(40)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BREAK"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                    font.letterSpacing: 0.6
                    color: Qt.rgba(1, 1, 1, 0.45)
                  }

                  Repeater {
                    model: Service.todayDisplayBlocks

                    Rectangle {
                      required property var modelData
                      required property int index

                      width: Math.floor((parent.width - Style.space(44) - 7 * Style.space(4)) / 8)
                      height: Style.space(16)
                      radius: Style.space(4)

                      readonly property bool isFinished: modelData.break === "completed"
                      readonly property bool isSkipped: modelData.break === "skipped"
                      readonly property bool isActive: modelData.break === "active"

                      color: isFinished
                        ? Util.alpha(root.settingActiveColor, 0.80)
                        : (isActive ? root.settingActiveBg : (isSkipped ? Qt.rgba(0.42, 0.44, 0.48, 0.35) : Qt.rgba(1, 1, 1, 0.04)))
                      border.color: isFinished
                        ? Util.alpha(root.settingActiveColor, 0.80)
                        : (isActive ? root.settingActiveColor : (isSkipped ? Qt.rgba(0.55, 0.58, 0.62, 0.4) : Qt.rgba(1, 1, 1, 0.06)))
                      border.width: isActive ? 1.5 : 1

                      Behavior on color { ColorAnimation { duration: 150 } }

                      Text {
                        anchors.centerIn: parent
                        text: parent.isFinished ? "✓" : (parent.isActive ? "▶" : (parent.isSkipped ? "–" : ""))
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 4
                        font.bold: true
                        color: parent.isFinished
                          ? Qt.rgba(0.08, 0.08, 0.12, 0.95)
                          : (parent.isActive ? root.settingActiveColor : (parent.isSkipped ? Qt.rgba(0.85, 0.85, 0.88, 0.75) : "transparent"))
                      }
                    }
                  }
                }

                // Row 3: Column Numbers & Long Break Markers
                Row {
                  width: parent.width
                  spacing: Style.space(4)

                  Item {
                    width: Style.space(40)
                    height: Style.space(12)
                  }

                  Repeater {
                    model: 8

                    Text {
                      required property int index
                      width: Math.floor((parent.width - Style.space(44) - 7 * Style.space(4)) / 8)
                      horizontalAlignment: Text.AlignHCenter
                      text: (index === 3 || index === 7) ? ((index + 1) + "★") : ("" + (index + 1))
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 4
                      font.bold: (index === 3 || index === 7)
                      color: (index === 3 || index === 7) ? root.settingActiveColor : Qt.rgba(1, 1, 1, 0.35)
                    }
                  }
                }

                // Row 4: Status / Rhythm Line
                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: {
                    if (Service.isBreakState) {
                      return "☕ Break in progress · " + Model.formatTime(Service.remainingSeconds) + " remaining"
                    } else if (Service.state === Model.STATE_WORK && Service.running) {
                      return "🎯 Focus session in progress · " + Model.formatTime(Service.remainingSeconds) + " remaining"
                    } else if (Service.todayCompletedSessions >= 8) {
                      return "🎉 Daily goal achieved! Excellent focus rhythm today."
                    } else {
                      var nextSess = Service.todayCompletedSessions + 1
                      return "Next: Focus Session " + nextSess + " of 8 (" + Service.workDurationMin + " min)"
                    }
                  }
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption - 2
                  color: Qt.rgba(1, 1, 1, 0.6)
                }
              }
            }

            // B. WEEKLY: 7-Day Sparkline Bar Chart
            Rectangle {
              visible: statsRoot.selectedPeriod === "weekly"
              width: parent.width
              height: Style.space(136)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

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
                    color: root.settingActiveColor
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(88)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(20)

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
                          color: modelData.isToday ? root.settingActiveColor : Qt.rgba(1, 1, 1, 0.4)
                        }

                        Item {
                          width: Style.space(18)
                          height: Style.space(52)
                          anchors.horizontalCenter: parent.horizontalCenter

                          Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: Math.max(Style.space(4), Style.space(52) * modelData.fraction)
                            radius: Style.space(4)
                            color: modelData.isToday
                              ? root.settingActiveColor
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
                          color: modelData.isToday ? root.settingActiveColor : Color.foreground
                        }
                      }
                    }
                  }
                }
              }
            }

            // C. MONTHLY: Rolling 4-Weeks Sparkline Bar Chart
            Rectangle {
              visible: statsRoot.selectedPeriod === "monthly"
              width: parent.width
              height: Style.space(136)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ROLLING 4-WEEKS TREND"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                    font.letterSpacing: 0.9
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.formatHoursDecimal(Service.getMonthlyTotalSeconds()) + " this month"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    color: root.settingActiveColor
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(88)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(36)

                    Repeater {
                      model: Service.getMonthly4WeeksHistory()

                      Column {
                        required property var modelData
                        spacing: Style.space(4)
                        anchors.bottom: parent.bottom

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.seconds > 0 ? Model.formatHoursDecimal(modelData.seconds) : "-"
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 3
                          color: modelData.isCurrent ? root.settingActiveColor : Qt.rgba(1, 1, 1, 0.4)
                        }

                        Item {
                          width: Style.space(28)
                          height: Style.space(52)
                          anchors.horizontalCenter: parent.horizontalCenter

                          Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: Math.max(Style.space(4), Style.space(52) * modelData.fraction)
                            radius: Style.space(4)
                            color: modelData.isCurrent
                              ? root.settingActiveColor
                              : (modelData.seconds > 0 ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.08))

                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                          }
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: modelData.isCurrent
                          color: modelData.isCurrent ? root.settingActiveColor : Color.foreground
                        }
                      }
                    }
                  }
                }
              }
            }

            // D. YEARLY: 12-Month Sparkline Bar Chart
            Rectangle {
              visible: statsRoot.selectedPeriod === "yearly"
              width: parent.width
              height: Style.space(136)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                Item {
                  width: parent.width
                  height: Style.space(14)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "12-MONTH ACTIVITY (" + Model.currentYearName() + ")"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                    font.letterSpacing: 0.9
                    color: Qt.rgba(1, 1, 1, 0.5)
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.formatHoursDecimal(Service.getYearlyTotalSeconds()) + " total"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    color: root.settingActiveColor
                  }
                }

                Item {
                  width: parent.width
                  height: Style.space(88)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(10)

                    Repeater {
                      model: Service.getYearly12MonthsHistory()

                      Column {
                        required property var modelData
                        spacing: Style.space(4)
                        anchors.bottom: parent.bottom

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.seconds > 0 ? Model.formatHoursDecimal(modelData.seconds) : "-"
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 4
                          color: modelData.isCurrentMonth ? root.settingActiveColor : Qt.rgba(1, 1, 1, 0.4)
                        }

                        Item {
                          width: Style.space(12)
                          height: Style.space(52)
                          anchors.horizontalCenter: parent.horizontalCenter

                          Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: Math.max(Style.space(4), Style.space(52) * modelData.fraction)
                            radius: Style.space(3)
                            color: modelData.isCurrentMonth
                              ? root.settingActiveColor
                              : (modelData.seconds > 0 ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.08))

                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                          }
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.initial
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 2
                          font.bold: modelData.isCurrentMonth
                          color: modelData.isCurrentMonth ? root.settingActiveColor : Color.foreground
                        }
                      }
                    }
                  }
                }
              }
            }

            // 4. LIFETIME SUMMARY BANNER (Consistent across all tabs)
            Rectangle {
              width: parent.width
              height: Style.space(34)
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.04)
              border.color: Qt.rgba(1, 1, 1, 0.1)
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
                id: modePill
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
                  if (root.selectedWorkflowMode) return root.selectedWorkflowMode
                  if (Service.workflowMode) return Service.workflowMode
                  if (Service.workDurationMin === 25 && Service.shortBreakMin === 5 && Service.maxSessions === 4 && Service.longBreakMin === 15) return "classic"
                  if (Service.workDurationMin === 50 && Service.shortBreakMin === 10 && Service.maxSessions === 2 && Service.longBreakMin === 20) return "deep"
                  if (Service.workDurationMin === 90 && Service.shortBreakMin === 20 && Service.maxSessions === 2 && Service.longBreakMin === 30) return "ultra"
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
                      readonly property bool isSelected: modePill.activeModeId === modelData.id
                      width: (parent.width - (3 * Style.space(2))) / 4
                      height: parent.height
                      radius: Style.cornerRadius - 1
                      color: isSelected
                        ? root.settingActiveBg
                        : (modeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                      border.color: isSelected ? root.settingActiveBorder : "transparent"
                      border.width: isSelected ? 1 : 0

                      Behavior on color { ColorAnimation { duration: 120 } }
                      Behavior on border.color { ColorAnimation { duration: 120 } }

                      Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: bar ? bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: isSelected
                        color: isSelected ? root.settingActiveColor : Color.foreground
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
                            root.selectedWorkflowMode = modelData.id
                            Service.workflowMode = modelData.id
                            Service.workDurationMin = modelData.work
                            Service.shortBreakMin = modelData.shortBreak
                            Service.longBreakMin = modelData.longBreak
                            Service.maxSessions = modelData.sessions
                            if (!Service.running && (Service.state === Model.STATE_IDLE || Service.state === Model.STATE_WORK)) {
                              Service.totalSeconds = modelData.work * 60
                              Service.remainingSeconds = Service.totalSeconds
                            }
                            root.persist({
                              workflowMode: modelData.id,
                              workDurationMin: modelData.work,
                              shortBreakMin: modelData.shortBreak,
                              longBreakMin: modelData.longBreak,
                              longBreakInterval: modelData.sessions
                            })
                          } else {
                            root.selectedWorkflowMode = "custom"
                            Service.workflowMode = "custom"
                            if (!Service.running && (Service.state === Model.STATE_IDLE || Service.state === Model.STATE_WORK)) {
                              Service.totalSeconds = Service.workDurationMin * 60
                              Service.remainingSeconds = Service.totalSeconds
                            }
                            root.persist({
                              workflowMode: "custom",
                              workDurationMin: Service.workDurationMin,
                              shortBreakMin: Service.shortBreakMin,
                              longBreakMin: Service.longBreakMin,
                              longBreakInterval: Service.maxSessions
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
                  if (modePill.activeModeId === "classic")
                    return "25m Focus • 5m Break • 4 Sessions / Cycle"
                  if (modePill.activeModeId === "deep")
                    return "50m Focus • 10m Break • 2 Sessions / Cycle"
                  if (modePill.activeModeId === "ultra")
                    return "90m Sprint • 20m Break • 2 Sessions / Cycle"
                  return Service.workDurationMin + "m Focus • " + Service.shortBreakMin + "m Short • " + Service.longBreakMin + "m Long • " + Service.maxSessions + "x"
                }
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                color: root.settingActiveColor
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }
            }

            // 2. Custom Steppers (Visible when Custom Mode is selected)
            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: modePill.activeModeId === "custom"

              // Focus Stepper Row
              Item {
                width: parent.width
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Focus Duration"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: fMinus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: fMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nw = Service.workDurationMin <= 5 ? Math.max(1, Service.workDurationMin - 1) : Math.max(5, Service.workDurationMin - 5)
                        root.updateWorkDuration(nw)
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(56)
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
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: fPlus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: fPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nw = Service.workDurationMin < 5 ? (Service.workDurationMin + 1) : Math.min(180, Service.workDurationMin + 5)
                        root.updateWorkDuration(nw)
                      }
                    }
                  }
                }
              }

              // Short Break Stepper Row
              Item {
                width: parent.width
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Short Break"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: bMinus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: bMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nb = Math.max(1, Service.shortBreakMin - 1)
                        root.updateShortBreak(nb)
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(56)
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
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: bPlus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: bPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nb = Math.min(60, Service.shortBreakMin + 1)
                        root.updateShortBreak(nb)
                      }
                    }
                  }
                }
              }

              // Long Break Stepper Row
              Item {
                width: parent.width
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Long Break"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: lbMinus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: lbMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nl = Service.longBreakMin <= 5 ? Math.max(1, Service.longBreakMin - 1) : Math.max(5, Service.longBreakMin - 5)
                        root.updateLongBreak(nl)
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(56)
                    horizontalAlignment: Text.AlignHCenter
                    text: Service.longBreakMin + " min"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.longBreakColor
                    style: Text.Sunken
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                  }

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: lbPlus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: lbPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var nl = Service.longBreakMin < 5 ? (Service.longBreakMin + 1) : Math.min(90, Service.longBreakMin + 5)
                        root.updateLongBreak(nl)
                      }
                    }
                  }
                }
              }

              // Cycle Sessions Stepper Row
              Item {
                width: parent.width
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Cycle Sessions"
                  font.family: bar ? bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.foreground
                  style: Text.Sunken
                  styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: sMinus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "–"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: sMinus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var ns = Math.max(1, Service.maxSessions - 1)
                        root.updateMaxSessions(ns)
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(56)
                    horizontalAlignment: Text.AlignHCenter
                    text: Service.maxSessions + " sess"
                    font.family: bar ? bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.pausedColor
                    style: Text.Sunken
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                  }

                  Rectangle {
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: sPlus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: Style.font.caption; color: Color.foreground; style: Text.Sunken; styleColor: Qt.rgba(0, 0, 0, 0.8) }
                    MouseArea {
                      id: sPlus
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var ns = Math.min(12, Service.maxSessions + 1)
                        root.updateMaxSessions(ns)
                      }
                    }
                  }
                }
              }
            }

            // 3. Daily Stats Reset Setting
            Column {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "DAILY STATS RESET"
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

                // Segmented Pill: Every Day vs Manual
                Rectangle {
                  width: parent.width - Style.space(86)
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
                        { val: true, label: "Every Day" },
                        { val: false, label: "Manual" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: Service.resetDaily === modelData.val
                        width: (parent.width - Style.space(2)) / 2
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? root.settingActiveBg : (rdm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: isSelected
                          color: isSelected ? root.settingActiveColor : Color.foreground
                          style: Text.Sunken
                          styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }

                        MouseArea {
                          id: rdm
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            Service.resetDaily = modelData.val
                            Service.saveState()
                            root.persist({ resetDaily: modelData.val })
                          }
                        }
                      }
                    }
                  }
                }

                // Reset Now Button
                Rectangle {
                  width: Style.space(78)
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: rstMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                  border.color: rstMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.15)
                  border.width: 1

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: "󰑖"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Color.foreground
                    }

                    Text {
                      text: "Reset"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      color: Color.foreground
                      style: Text.Sunken
                      styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }
                  }

                  MouseArea {
                    id: rstMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      Service.resetDailyStats()
                    }
                  }
                }
              }

              Text {
                text: Service.resetDaily
                  ? "Daily stats automatically reset at midnight."
                  : "Daily stats accumulate until manual reset."
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 2
                color: Qt.darker(Color.foreground, 1.6)
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }
            }

            // 4. Sound & Audio Alerts
            Column {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "SOUND & NOTIFICATIONS"
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                color: Qt.darker(Color.foreground, 1.5)
                style: Text.Sunken
                styleColor: Qt.rgba(0, 0, 0, 0.8)
              }

              // Sound Toggle (On / Mute) + Notification Toggle (On / Off)
              Row {
                width: parent.width
                spacing: Style.space(8)

                // Sound On/Mute Pill
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.5
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
                        { val: true, label: "Sound On", icon: "󰎆" },
                        { val: false, label: "Mute", icon: "󰝟" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: Service.soundEnabled === modelData.val
                        width: (parent.width - Style.space(2)) / 2
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? root.settingActiveBg : (sndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                          anchors.centerIn: parent
                          spacing: Style.space(3)

                          Text {
                            text: modelData.icon
                            font.family: bar ? bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption - 1
                            color: isSelected ? root.settingActiveColor : Qt.darker(Color.foreground, 1.3)
                          }

                          Text {
                            text: modelData.label
                            font.family: bar ? bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption - 2
                            font.bold: isSelected
                            color: isSelected ? root.settingActiveColor : Color.foreground
                            style: Text.Sunken
                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                          }
                        }

                        MouseArea {
                          id: sndMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            Service.soundEnabled = modelData.val
                            Service.saveState()
                            root.persist({ soundEnabled: modelData.val })
                            if (modelData.val) Service.playSound("tick")
                          }
                        }
                      }
                    }
                  }
                }

                // Desktop Notification Toasts Pill
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.5
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
                        { val: true, label: "Alerts On", icon: "󰂚" },
                        { val: false, label: "Off", icon: "󰂛" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: Service.notificationsEnabled === modelData.val
                        width: (parent.width - Style.space(2)) / 2
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? root.settingActiveBg : (notifMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                          anchors.centerIn: parent
                          spacing: Style.space(3)

                          Text {
                            text: modelData.icon
                            font.family: bar ? bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption - 1
                            color: isSelected ? root.settingActiveColor : Qt.darker(Color.foreground, 1.3)
                          }

                          Text {
                            text: modelData.label
                            font.family: bar ? bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption - 2
                            font.bold: isSelected
                            color: isSelected ? root.settingActiveColor : Color.foreground
                            style: Text.Sunken
                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                          }
                        }

                        MouseArea {
                          id: notifMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            Service.notificationsEnabled = modelData.val
                            Service.saveState()
                            root.persist({ notificationsEnabled: modelData.val })
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Sound Theme Selector + Test Button
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: Service.soundEnabled

                Rectangle {
                  width: parent.width - Style.space(78)
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
                        { id: "zen", label: "Zen Bowl" },
                        { id: "crystal", label: "Crystal" },
                        { id: "marimba", label: "Marimba" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: Service.soundTheme === modelData.id
                        width: (parent.width - (2 * Style.space(2))) / 3
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? root.settingActiveBg : (thmMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 2
                          font.bold: isSelected
                          color: isSelected ? root.settingActiveColor : Color.foreground
                          style: Text.Sunken
                          styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }

                        MouseArea {
                          id: thmMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            Service.soundTheme = modelData.id
                            Service.saveState()
                            root.persist({ soundTheme: modelData.id })
                            Service.playSound("focus_complete")
                          }
                        }
                      }
                    }
                  }
                }

                // Test Chime Button
                Rectangle {
                  width: Style.space(70)
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: testMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                  border.color: testMouse.containsMouse ? Color.foreground : Qt.rgba(1, 1, 1, 0.15)
                  border.width: 1

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: "󰎆"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.foreground
                    }

                    Text {
                      text: "Play"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      color: Color.foreground
                      style: Text.Sunken
                      styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }
                  }

                  MouseArea {
                    id: testMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      Service.playSound("focus_complete")
                    }
                  }
                }
              }

              // Sound Volume Row
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: Service.soundEnabled

                Rectangle {
                  width: parent.width
                  height: Style.space(28)
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
                        { val: 40, label: "Soft (40%)" },
                        { val: 75, label: "Medium (75%)" },
                        { val: 100, label: "Full (100%)" }
                      ]

                      Rectangle {
                        required property var modelData
                        readonly property bool isSelected: Math.abs((Service.soundVolume || 75) - modelData.val) <= 15
                        width: (parent.width - (2 * Style.space(2))) / 3
                        height: parent.height
                        radius: Style.cornerRadius - 1
                        color: isSelected ? root.settingActiveBg : (volMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 2
                          font.bold: isSelected
                          color: isSelected ? root.settingActiveColor : Color.foreground
                          style: Text.Sunken
                          styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }

                        MouseArea {
                          id: volMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            Service.soundVolume = modelData.val
                            Service.saveState()
                            root.persist({ soundVolume: modelData.val })
                            Service.playSound("tick")
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Auto-Start Automation Row
              Row {
                width: parent.width
                spacing: Style.space(8)

                // Auto-start Breaks
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.5
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: Service.autoStartBreaks
                    ? root.settingActiveBg
                    : (autoBMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                  border.color: Service.autoStartBreaks ? root.settingActiveBorder : Qt.rgba(1, 1, 1, 0.1)
                  border.width: 1

                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: Service.autoStartBreaks ? "󰄲" : "󰄱"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Service.autoStartBreaks ? root.settingActiveColor : Qt.darker(Color.foreground, 1.5)
                    }

                    Text {
                      text: "Auto-break"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 2
                      font.bold: Service.autoStartBreaks
                      color: Service.autoStartBreaks ? root.settingActiveColor : Color.foreground
                    }
                  }

                  MouseArea {
                    id: autoBMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      Service.autoStartBreaks = !Service.autoStartBreaks
                      Service.playSound("tick")
                      Service.saveState()
                      root.persist({ autoStartBreaks: Service.autoStartBreaks })
                    }
                  }
                }

                // Auto-start Focus
                Rectangle {
                  width: (parent.width - Style.space(8)) * 0.5
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: Service.autoStartWork
                    ? root.settingActiveBg
                    : (autoFMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                  border.color: Service.autoStartWork ? root.settingActiveBorder : Qt.rgba(1, 1, 1, 0.1)
                  border.width: 1

                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: Service.autoStartWork ? "󰄲" : "󰄱"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Service.autoStartWork ? root.settingActiveColor : Qt.darker(Color.foreground, 1.5)
                    }

                    Text {
                      text: "Auto-focus"
                      font.family: bar ? bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption - 2
                      font.bold: Service.autoStartWork
                      color: Service.autoStartWork ? root.settingActiveColor : Color.foreground
                    }
                  }

                  MouseArea {
                    id: autoFMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      Service.autoStartWork = !Service.autoStartWork
                      Service.playSound("tick")
                      Service.saveState()
                      root.persist({ autoStartWork: Service.autoStartWork })
                    }
                  }
                }
              }
            }

            // 5. Top Bar Appearance & Position
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
                        color: isSelected ? root.settingActiveBg : (dm.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: isSelected
                          color: isSelected ? root.settingActiveColor : Color.foreground
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
                        color: isSelected ? root.settingActiveBg : (pm.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: isSelected ? root.settingActiveBorder : "transparent"
                        border.width: isSelected ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          text: modelData.label
                          font.family: bar ? bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption - 1
                          font.bold: isSelected
                          color: isSelected ? root.settingActiveColor : Color.foreground
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
