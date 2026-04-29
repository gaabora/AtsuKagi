class AKPlugin extends AKBase {
  Config := {} ; reference to App.Config section with plugin's name
  App := {} ; reference to app
  ; TODO: add callback for plugin config injection into the app
  __New(App) {
    this.App := App
    className := this.__Class
    if (!App.Config.Has(className))
      App.Config[className] := {}
    this.Config := App.Config[className]
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
  _processPluginConfig() {
  }
  _processBlocklistConfig() {
  }
  _init() {
  }
  RunAction(ActionString) {
    return this.App.RunAction(ActionString)
  }
  IsKeyboardHookStealerWindowActive() {
    return this.App.IsKeyboardHookStealerWindowActive()
  }
  IsWindowBlocklisted(params*) {
    return this.App.IsWindowBlocklisted(params*)
  }
  IsInBlocklist(params*) {
    return this.App.IsInBlocklist(params*)
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
    methodName := parts[parts.Length]
    return FormatCamelCaseToSentence(methodName)
  }
}

