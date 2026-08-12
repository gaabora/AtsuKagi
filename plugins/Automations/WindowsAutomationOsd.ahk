class WindowsAutomationOsd {
  __New() {
    this._channels := Map()
  }

  Show(channel, title, body, progressPercent:=-1, urgency:="normal", durationMs:=5000) {
    channelText := Trim("" channel)
    if (channelText = "")
      throw ValueError("OSD channel cannot be empty")
    if (!this._channels.Has(channelText))
      this._channels[channelText] := this._createChannel(channelText)

    state := this._channels[channelText]
    state["titleControl"].Text := "" title
    state["bodyControl"].Text := "" body
    state["progressControl"].Visible := progressPercent >= 0
    if (progressPercent >= 0)
      state["progressControl"].Value := Min(100, Max(0, Integer(progressPercent)))
    state["progressControl"].Opt("c" this._getUrgencyColor(urgency))

    this._cancelChannelTimers(state)
    this._positionAndShow(state)
    state["opacity"] := 0
    state["phase"] := "enter"
    WinSetTransparent(0, "ahk_id " state["gui"].Hwnd)
    SetTimer(state["animationFn"], 20)
    SetTimer(state["closeFn"], -Max(800, Integer(durationMs)))
    return true
  }

  Hide(channel) {
    channelText := Trim("" channel)
    if (!this._channels.Has(channelText))
      return false
    state := this._channels[channelText]
    SetTimer(state["closeFn"], 0)
    state["phase"] := "exit"
    SetTimer(state["animationFn"], 20)
    return true
  }

  StopAll() {
    for channelText, state in this._channels {
      this._cancelChannelTimers(state)
      try state["gui"].Destroy()
    }
    this._channels := Map()
  }

  _createChannel(channel) {
    osdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000", "Automations " channel)
    osdGui.BackColor := "202020"
    osdGui.MarginX := 18
    osdGui.MarginY := 14
    osdGui.SetFont("s11 cFFFFFF", "Segoe UI")
    titleControl := osdGui.AddText("w340 +0x200", "")
    titleControl.SetFont("s12 bold cFFFFFF", "Segoe UI")
    bodyControl := osdGui.AddText("y+7 w340 h56", "")
    bodyControl.SetFont("s10 norm cF0F0F0", "Segoe UI")
    progressControl := osdGui.AddProgress("y+9 w340 h6 Range0-100 c4CC2FF Background404040", 0)
    state := Map("gui", osdGui, "titleControl", titleControl, "bodyControl", bodyControl, "progressControl", progressControl, "opacity", 0, "phase", "enter")
    state["animationFn"] := this._animate.Bind(this, channel)
    state["closeFn"] := this._startExit.Bind(this, channel)
    return state
  }

  _positionAndShow(state) {
    monitorIndex := this._getPointerMonitorIndex()
    MonitorGetWorkArea(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    osdWidth := 376
    osdHeight := 150
    osdLeft := monitorRight - osdWidth - 24
    osdTop := monitorBottom - osdHeight - 24
    state["gui"].Show("x" osdLeft " y" osdTop " w" osdWidth " h" osdHeight " NoActivate")
  }

  _getPointerMonitorIndex() {
    MouseGetPos(&mouseLeft, &mouseTop)
    monitorCount := MonitorGetCount()
    Loop monitorCount {
      monitorIndex := A_Index
      MonitorGet(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
      if (mouseLeft >= monitorLeft && mouseLeft < monitorRight && mouseTop >= monitorTop && mouseTop < monitorBottom)
        return monitorIndex
    }
    return MonitorGetPrimary()
  }

  _startExit(channel, *) {
    if (!this._channels.Has(channel))
      return
    state := this._channels[channel]
    state["phase"] := "exit"
    SetTimer(state["animationFn"], 20)
  }

  _animate(channel, *) {
    if (!this._channels.Has(channel))
      return
    state := this._channels[channel]
    if (!WinExist("ahk_id " state["gui"].Hwnd)) {
      SetTimer(state["animationFn"], 0)
      return
    }

    if (state["phase"] = "enter") {
      state["opacity"] := Min(230, state["opacity"] + 38)
      WinSetTransparent(state["opacity"], "ahk_id " state["gui"].Hwnd)
      if (state["opacity"] >= 230)
        SetTimer(state["animationFn"], 0)
      return
    }

    state["opacity"] := Max(0, state["opacity"] - 38)
    WinSetTransparent(state["opacity"], "ahk_id " state["gui"].Hwnd)
    if (state["opacity"] <= 0) {
      SetTimer(state["animationFn"], 0)
      state["gui"].Hide()
    }
  }

  _cancelChannelTimers(state) {
    SetTimer(state["animationFn"], 0)
    SetTimer(state["closeFn"], 0)
  }

  _getUrgencyColor(urgency) {
    urgencyText := StrLower(Trim("" urgency))
    if (urgencyText = "critical")
      return "E5484D"
    if (urgencyText = "warning")
      return "F5A524"
    if (urgencyText = "success")
      return "45B26B"
    return "4CC2FF"
  }
}
