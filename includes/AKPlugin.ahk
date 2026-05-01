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

  ; ── Descriptor API ─────────────────────────────────────────────────────────────
  ; Override in plugin to return structured metadata. This is the new source of truth.
  __DescribePlugin() {
    return Map() ; Empty by default; plugins override to provide descriptor
  }

  ; Get normalized descriptor with defaults filled in
  __GetPluginDescriptor() {
    descriptor := this.__DescribePlugin()
    if (!descriptor || descriptor.Count = 0)
      return Map()
    
    ; Ensure config array exists
    if (!descriptor.Has("config"))
      descriptor["config"] := []
    
    ; Ensure actions array exists
    if (!descriptor.Has("actions"))
      descriptor["actions"] := []
    
    return descriptor
  }

  ; Extract config schema from descriptor
  __GetConfigSchema() {
    descriptor := this.__GetPluginDescriptor()
    return descriptor.Has("config") ? descriptor["config"] : []
  }

  ; Extract actions from descriptor
  __GetActionDefinitions() {
    descriptor := this.__GetPluginDescriptor()
    return descriptor.Has("actions") ? descriptor["actions"] : []
  }

  ; Get settings page definition
  __GetSettingsPageDefinition() {
    descriptor := this.__GetPluginDescriptor()
    if (!descriptor.Has("settingsPage"))
      return Map()
    
    page := descriptor["settingsPage"]
    
    ; Apply defaults
    if (!page.Has("visible"))
      page["visible"] := true
    if (!page.Has("navOrder"))
      page["navOrder"] := 100
    
    return page
  }

  ; Apply descriptor defaults to Config
  __ApplyDefaultConfig() {
    schema := this.__GetConfigSchema()
    for fieldDesc in schema {
      key := fieldDesc.Has("key") ? fieldDesc["key"] : ""
      if (key && !this.Config.Has(key) && fieldDesc.Has("default")) {
        this.Config[key] := fieldDesc["default"]
      }
    }
  }

  ; Reset a single config value to descriptor default
  __ResetConfigValue(key) {
    schema := this.__GetConfigSchema()
    for fieldDesc in schema {
      if (fieldDesc.Has("key") && fieldDesc["key"] = key && fieldDesc.Has("default")) {
        this.Config[key] := fieldDesc["default"]
        return true
      }
    }
    return false
  }

  ; Reset all config values to descriptor defaults
  __ResetAllConfig() {
    schema := this.__GetConfigSchema()
    for fieldDesc in schema {
      key := fieldDesc.Has("key") ? fieldDesc["key"] : ""
      if (key && fieldDesc.Has("default")) {
        this.Config[key] := fieldDesc["default"]
      }
    }
  }

  ; Validate config value against schema
  __ValidateConfigValue(key, value) {
    schema := this.__GetConfigSchema()
    for fieldDesc in schema {
      if (fieldDesc.Has("key") && fieldDesc["key"] = key) {
        ; Basic validation: check required
        if (fieldDesc.Has("validation")) {
          validation := fieldDesc["validation"]
          if (validation.Has("required") && validation["required"] && (!value || value = "")) {
            return false
          }
        }
        return true
      }
    }
    return true
  }

  __ConfigHelp() { ; TODO: obsolete, remove everywhere
    
    descriptor := this.__GetPluginDescriptor()
    if (!descriptor || descriptor.Count = 0)
      return ""
    
    schema := this.__GetConfigSchema()
    result := ""
    for fieldDesc in schema {
      if (fieldDesc.Has("key") && fieldDesc.Has("description")) {
        if (result)
          result .= "`n"
        key := fieldDesc["key"]
        desc := fieldDesc["description"]
        defaultVal := fieldDesc.Has("default") ? fieldDesc["default"] : ""
        result .= key " (default: '" defaultVal "'): " desc
      }
    }
    return result
  }

  __UsageHelp() { ; TODO: obsolete, remove everywhere
    descriptor := this.__GetPluginDescriptor()
    if (descriptor && descriptor.Has("plugin")) {
      plugin := descriptor["plugin"]
      if (plugin.Has("description"))
        return plugin["description"]
    }
    return "write help message for the plugin"
  }

  __ActionsHelp() { ; TODO: obsolete, remove everywhere
    results := Map()
    descriptor := this.__GetPluginDescriptor()
    if (!descriptor || descriptor.Count = 0)
      return results
    
    actions := this.__GetActionDefinitions()
    for actionDesc in actions {
      if (actionDesc.Has("action")) {
        actionName := actionDesc["action"]
        label := actionDesc.Has("label") ? actionDesc["label"] : this._beautifyActionName(actionName)
        description := actionDesc.Has("description") ? actionDesc["description"] : ""
        params := actionDesc.Has("params") ? actionDesc["params"] : []
        
        ; Build signature string
        paramsStr := ""
        for param in params {
          if (paramsStr)
            paramsStr .= ", "
          if (IsObject(param) && param.Has("name")) {
            paramsStr .= param["name"]
            if (param.Has("default"))
              paramsStr .= ":=" param["default"]
          } else {
            paramsStr .= param ""
          }
        }
        
        sig := actionName "(" paramsStr ")"
        results[actionName] := sig " - " description
      }
    }
    return results
  }

  __HooksHelp() { ; TODO: obsolete, remove everywhere
    descriptor := this.__GetPluginDescriptor()
    if (descriptor && descriptor.Has("hooks"))
      return descriptor["hooks"]
    return []
  }

  _processPluginConfig() {  ; TODO: obsolete, remove everywhere
  }
  _processBlocklistConfig() {
  }
  _init() {
  }

  ; ── Helper: Convert PascalCase to "Sentence case" ──────────────────────────────
  _beautifyActionName(fnName) {
    ; Convert "EnterWindowMovingMode" to "Enter window moving mode"
    result := ""
    for i, char in StrSplit(fnName) {
      if (i > 1 && char = StrUpper(char)) {
        result .= " " StrLower(char)
      } else {
        result .= i = 1 ? StrUpper(char) : StrLower(char)
      }
    }
    return result
  }

  ; ── App Bridge Methods ──────────────────────────────────────────────────────────
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

