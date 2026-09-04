import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

ShellRoot {
  id: root

  property bool open: false
  property var data: ({})
  property int hoveredProfile: -1

  readonly property var pal: QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color surface: "#313244"
    readonly property color text: "#cdd6f4"
    readonly property color sub: "#a6adc8"
    readonly property color blue: "#89b4fa"
    readonly property color green: "#a6e3a1"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color overlay: "#6c7086"
  }

  readonly property var bat: UPower.displayDevice
  readonly property real frac: {
    if (bat && bat.ready && bat.percentage > 0)
      return Math.max(0, Math.min(1, bat.percentage))
    const p = data.pct
    return (typeof p === "number") ? Math.max(0, Math.min(1, p / 100)) : 0
  }
  readonly property int pct: Math.round(frac * 100)
  readonly property string mode: data.mode || "unknown"
  readonly property bool charging: mode === "charging"
  readonly property bool full: mode === "full"
  readonly property bool discharging: mode === "discharging"
  readonly property var profiles: data.profiles || ["power-saver", "balanced", "performance"]
  readonly property string activeProfile: data.profile || "balanced"

  readonly property color fillColor: {
    if (pct <= 15 && discharging)
      return pal.red
    if (pct <= 30 && discharging)
      return pal.peach
    if (charging || full)
      return pal.green
    return pal.blue
  }

  // Suspends leave holes in UPower's history, so a session that reaches back
  // into one is only known to be *at least* this long.
  function atLeast(v) {
    return (root.data.sessionBounded ? "≥" : "") + v
  }

  function dash(v) {
    return (v === undefined || v === null || v === "") ? "—" : String(v)
  }

  function icon() {
    if (charging)
      return "󰂄"
    if (full)
      return "󰂅"
    const n = Math.round(frac * 9)
    const glyphs = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂"]
    return glyphs[Math.max(0, Math.min(9, n))]
  }

  function statusLine() {
    if (full)
      return "FULLY CHARGED"
    if (charging)
      return "CHARGING"
    if (discharging)
      return "ON BATTERY"
    return (mode || "").toUpperCase()
  }

  function profileLabel(name) {
    if (name === "power-saver")
      return "Saver"
    if (name === "performance")
      return "Perf"
    return "Balanced"
  }

  function refresh() {
    if (!dataProc.running)
      dataProc.running = true
  }

  function applyJson(text) {
    try {
      const next = JSON.parse(text)
      if (next && typeof next === "object")
        data = next
    } catch (e) {}
  }

  function setProfile(name) {
    if (!name || setProc.running)
      return
    setProc.command = [Quickshell.env("HOME") + "/.config/sway/scripts/power-profile.sh", name]
    setProc.running = true
  }

  function toggle() {
    open = !open
    if (open)
      refresh()
  }

  IpcHandler {
    target: "panel"
    function toggle(): void { root.toggle() }
    function open(): void { root.open = true; root.refresh() }
    function close(): void { root.open = false }
  }

  Process {
    id: dataProc
    command: ["python3", Quickshell.env("HOME") + "/.config/sway/scripts/battery-panel-data.py"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyJson(text)
    }
  }

  Process {
    id: setProc
    onExited: root.refresh()
  }

  Process {
    id: notifyProc
  }

  // A rejected hot reload otherwise draws Quickshell's own white panel in the
  // top-left corner, which ignores the session's notification styling. Suppress
  // it and hand the error to the notification daemon instead. The surviving
  // (old) instance is what raises this, so the handler has to live here rather
  // than in the config that failed to load.
  Connections {
    target: Quickshell

    function onReloadFailed(errorString: string): void {
      Quickshell.inhibitReloadPopup()
      const escape = t => String(t)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
      notifyProc.command = [
        "notify-send",
        "-u", "critical",
        "-a", "quickshell",
        "Quickshell: config reload failed",
        escape(errorString) + "\n\nqs log -i " + Quickshell.instanceId
      ]
      notifyProc.running = true
    }
  }

  Timer {
    interval: 4000
    running: root.open
    repeat: true
    onTriggered: root.refresh()
  }

  // Click-outside scrim
  PanelWindow {
    visible: root.open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    Component.onCompleted: {
      if (this.WlrLayershell != null) {
        this.WlrLayershell.layer = WlrLayer.Top
        this.WlrLayershell.namespace = "battery-scrim"
        this.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.open = false
    }
  }

  PanelWindow {
    id: win
    visible: root.open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 392
    implicitHeight: col.implicitHeight + 36
    focusable: true
    anchors {
      top: true
      right: true
    }
    // Waybar's exclusive zone already pushes the surface down, so this is the
    // gap below the bar, not the distance from the top of the screen.
    margins {
      top: 8
      right: 10
    }

    Component.onCompleted: {
      if (this.WlrLayershell != null) {
        this.WlrLayershell.layer = WlrLayer.Overlay
        this.WlrLayershell.namespace = "battery-panel"
        this.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
      }
    }

    Rectangle {
      id: card
      anchors.fill: parent
      color: Qt.rgba(0.118, 0.118, 0.180, 0.96)
      border.width: 2
      border.color: pal.surface

      Column {
        id: col
        x: 18
        y: 18
        width: 356
        spacing: 14

        focus: true
        Keys.onEscapePressed: root.open = false

        // Hero
        Item {
          width: parent.width
          height: 52

          Text {
            id: heroIcon
            text: root.icon()
            color: root.fillColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 28
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.left: heroIcon.right
            anchors.leftMargin: 12
            anchors.right: heroPct.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              text: "Battery"
              color: pal.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 15
              font.bold: true
            }
            Text {
              text: root.statusLine()
              color: pal.sub
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.bold: true
              font.letterSpacing: 1.1
            }
          }

          Text {
            id: heroPct
            text: root.pct + "%"
            color: pal.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 28
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Charge bar
        Item {
          width: parent.width
          height: 8

          Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0.804, 0.839, 0.957, 0.12)
          }
          Rectangle {
            id: fill
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            height: track.height
            radius: track.radius
            color: root.fillColor
            width: Math.max(track.height, track.width * root.frac)

            Behavior on width {
              NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
              }
            }

            SequentialAnimation on opacity {
              running: root.charging && root.open
              loops: Animation.Infinite
              NumberAnimation {
                from: 1
                to: 0.55
                duration: 900
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                from: 0.55
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
              }
            }
          }
        }

        Text {
          width: parent.width
          text: {
            const bits = []
            if (root.data.vendor)
              bits.push(root.data.vendor)
            if (root.data.model)
              bits.push(root.data.model)
            if (root.data.fullWh)
              bits.push(root.data.fullWh + " Wh")
            return bits.length ? bits.join(" · ") : ""
          }
          color: pal.sub
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          elide: Text.ElideRight
          visible: text.length > 0
        }

        Row {
          width: parent.width
          spacing: 18

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: 7
            Stat {
              label: "Cycles"
              value: root.dash(root.data.cycles)
            }
            Stat {
              label: "Health"
              value: root.data.health != null ? (root.data.health + "%") : "—"
            }
            Stat {
              label: "Temp"
              value: root.data.tempC != null ? (root.data.tempC + "°C") : "—"
            }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: 7
            Stat {
              label: root.discharging ? "Time left" : "To full"
              value: root.discharging ? root.dash(root.data.timeToEmpty) : (root.full ? "—" : root.dash(root.data.timeToFull))
            }
            Stat {
              label: root.discharging ? "Draw" : "Rate"
              value: root.data.rateW != null ? (root.data.rateW + " W") : "—"
            }
            Stat {
              label: "AC"
              value: root.data.ac ? "Plugged in" : "Unplugged"
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: pal.surface
        }

        Text {
          text: "THIS SESSION"
          color: pal.overlay
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 1.2
        }

        Row {
          width: parent.width
          spacing: 18

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: 7
            Stat {
              label: root.charging ? "Charging for" : "On battery"
              value: {
                const v = root.charging ? root.data.chargeFor : root.data.unpluggedFor
                return v ? root.atLeast(v) : "—"
              }
            }
            Stat {
              label: root.charging ? "Added" : "Used"
              value: {
                if (root.charging && root.data.addedPct != null)
                  return root.atLeast("+" + root.data.addedPct + "%")
                if (root.discharging && root.data.usedPct != null)
                  return root.atLeast("−" + root.data.usedPct + "%")
                return "—"
              }
            }
          }
          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: 7
            Stat {
              label: "Last full"
              value: root.data.lastFull ? (root.data.lastFull + " ago") : "—"
            }
            Stat {
              label: "Now"
              value: root.data.energyWh != null ? (root.data.energyWh + " Wh") : "—"
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: pal.surface
        }

        Text {
          text: "POWER PROFILE"
          color: pal.overlay
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 1.2
        }

        Row {
          id: profileRow
          width: parent.width
          spacing: 6

          Repeater {
            model: root.profiles
            Rectangle {
              required property var modelData
              required property int index
              readonly property bool active: root.activeProfile === modelData
              readonly property bool hovered: root.hoveredProfile === index
              width: (profileRow.width - profileRow.spacing * Math.max(0, root.profiles.length - 1)) / Math.max(1, root.profiles.length)
              height: 36
              color: active ? Qt.rgba(0.537, 0.706, 0.980, 0.16) : pal.mantle
              border.width: 1
              border.color: active ? pal.blue : (hovered ? pal.overlay : pal.surface)

              Text {
                anchors.centerIn: parent
                text: root.profileLabel(String(modelData))
                color: parent.active ? pal.blue : pal.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: parent.active
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredProfile = index
                onExited: if (root.hoveredProfile === index)
                  root.hoveredProfile = -1
                onClicked: root.setProfile(String(modelData))
              }
            }
          }
        }

        // Proof the buttons landed: ppd reports only the profile name, this is
        // what the CPU is actually doing.
        Text {
          width: parent.width
          text: {
            const c = root.data.cpu
            if (!c)
              return ""
            const bits = [c.gov, "max " + c.maxGhz + " GHz"]
            if (c.turbo != null)
              bits.push("turbo " + (c.turbo ? "on" : "off"))
            return bits.join(" · ")
          }
          color: root.data.cpu && root.data.cpu.capped ? pal.peach : pal.overlay
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 10
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          visible: text.length > 0
        }
      }
    }
  }

  component Stat: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: 8

    Text {
      text: label
      color: root.pal.sub
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      elide: Text.ElideRight
      width: parent.width * 0.48
    }
    Text {
      text: value
      color: root.pal.text
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      width: parent.width * 0.52 - parent.spacing
    }
  }
}
