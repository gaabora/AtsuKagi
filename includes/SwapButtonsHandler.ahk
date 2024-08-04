class SwapButtonsHandler extends AKPlugin {
  __UsageHelp() {
    return "swap buttons thru tray menu"
  }

  __ActionsHelp() {
    texts := Map()
    texts["IsRDPClientWindowActive"] :=           "IsRDPClientWindowActive()"
    texts["MinimizeRestoreRDPClientWindows"] :=   "MinimizeRestoreRDPClientWindows()"
    texts["RestoreFullscreenRDPClientWindow"] :=  "RestoreFullscreenRDPClientWindow()"
    texts["LoopRDPClientWindows"] :=              "LoopRDPClientWindows()"
    texts["SwitchToNextRDPClientWindow"] :=       "SwitchToNextRDPClientWindow()"
    return texts
  }

  IsRDPClientWindowActive() { ;;;
    Menu, Tray, ToggleCheck, Disable


    fn := this.menuHandler.bind(this)
    if (!this.debugLevel)
      Menu, Tray, NoStandard
    Menu, Tray, Icon, % this.TrayIconDefault,, 1
    this.runMenuHooks()
    
  
  }
}