class AKPlugin extends AKBase {
  App := {} ; reference to app
  ; TODO: add callback for plugin config injection into the app
  __New() {
    this.processConfig()
  }
  __ConfigHelp() {
    return [] ; TODO
  }
  __UsageHelp() {
    return "wtite help message for the plugin"
  }
  __ActionsHelp() {
    return [] ; MUST return array like ["FnName": "FnName(params) description", ...] for all actions you want to register in the app
  }
  __HooksHelp() {
    return [] ; MUST return array like ["FnName": "FnName(params) description", ...] for all hooks you want to register in the app
  }
  processConfig() {
  }
  IsKeyboardHookStealerWindowActive() {
    return this.App.IsKeyboardHookStealerWindowActive()
  }
  IsWindowBlacklisted(params*) {
    return this.App.IsWindowBlacklisted(params*)
  }
  Speak(params*) {
    return this.App.Speak(params*)
  }
  ToolTip(params*) {
    return this.App.ToolTip(params*)
  }
  AddMenuHook(handlerFn, order:=-1) {
    this.App.AddMenuHook
  }
  beautifyActionName(fnName) {
    parts := StrSplit(fnName, ".")
    methodName := (parts.Length() = 2) ? parts[2] : parts[1]
    return FormatCamelCaseToSentence(methodName)
  }
}

