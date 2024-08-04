
; aconf := IniFile("sconfig.ini")
; ; OutputDebug(aconf["GENERAL"]["xxx"])
; ; OutputDebug(aconf["GENERAL"].xxx)
; ; OutputDebug(aconf["GENERAL"]["xx"])
; ; OutputDebug(aconf["GENERAL"].xx)
; ; OutputDebug(aconf.GENERAL["xxx"])
; OutputDebug(aconf.GENERAL.xxx)
; ; OutputDebug(aconf.GENERAL["xx"])
; OutputDebug("---xx=" . aconf.GENERAL.xx . ".")
; ; aconf.GENERAL :=  {
; ;   testInt: -123,
; ;   testFloat: 123.456,
; ;   testString: "Hello World =) `;",
; ; }
; ; aconf.GENERAL :=  {
; ;   testInt: -1234,
; ;   testFloat: 123.456,
; ;   testString: "Hello World =) `;",
; ; }

; ass := aconf.GENERAL.HasKey("HotkeyInterval")


; ; make_greeter(f) {
; ;     greet(subject) {
; ;       OutputDebug(Format(f, subject))
; ;     }
; ;     return greet
; ; }

; ; g := make_greeter("Hello, {}!")
; ; g(A_UserName)
; ; g("World")


; num := 1
; #a::
; {
;   global num
;   global aconf
;   num := num+1
;   OutputDebug("ASS" num)
;   aconf.GENERAL.wtf := num  
; }

class IniFile {  
  ;#region Public
  Has(Name) {
    return this.__data.Has(Name)
  }
  Load(filePath) {
    outputDebug("IniRead(" filePath ")`n")
    buffer := IniRead(filePath)

    for idx, sectionName in StrSplit(buffer, "`n") {
      outputDebug("IniRead(" filePath ", " sectionName ")`n")
      sectionContent := IniRead(filePath, sectionName)
      this.__rawData[sectionName] := sectionContent

      this.__data[sectionName] := IniFile.IniSection(sectionName, sectionContent, this)

      this.DefineProp(sectionName, {
        Get: this._getterFactory(sectionName),
        Set: this._setterFactory(sectionName),
      })
    }
  }
  Save() {
    outputDebug("Save`n")
    this._writeIni()
  }
  SaveDebounced() {
    outputDebug("TODO: SaveDebounced >>> debounce Save()`n")
    ; outputDebug("TODO: SaveDebounced >>> debounce Save()`n" this.ToString())
    debounceFn := this.__debounceFn
    saveFn := this.Save.bind(this)
    debounceFn(saveFn)
  }
  ToString() {
    iniString := ""
    for sectionName, iniSection in this.__data {
      iniString .= "[" sectionName "]`n" iniSection.ToString()
    }
    return iniString
  }
  ;#endregion

  ;#region Overload
  Delete(Name) {
    if (!this.__data.Has(Name))
      throw PropertyError("Can not delete a section that does not exist. Path: " Name)
    this.__data.Delete(Name)
    this.SaveDebounced()
  }
  ;#endregion

  ;#region Meta

  __New(filePath, settingsObject:=-1) {
    this._initSettings(settingsObject)
		this.DefineProp("__path", { Value: filePath })
		this.DefineProp("__data", { Value: Map() })
		this.DefineProp("__rawData", { Value: Map() })
		this.DefineProp("__lastSaved", { Value: Map() })
    debounceFn := this._debounceFactory(this._SETTINGS["SaveDebounceTimeoutMs"])

    this.DefineProp("__debounceFn", { Call: debounceFn })
    this.Load(filePath)
  }
  __Get(Name, Params) {
    this.__data[Name] := IniFile.IniSection(Name, {}, this)
    OutputDebug("IniFile __GET(" . Name . ")`n")
    this.DefineProp(Name, {
      Get: this._getterFactory(Name),
      Set: this._setterFactory(Name),
    })
    return this.__data[Name]
  }
  __Set(Name, Params, Value) {
    this.__data[Name] := IniFile.IniSection(Name, Value, this)
    this.DefineProp(Name, {
      Get: this._getterFactory(Name),
      Set: this._setterFactory(Name),
    })
    return this.__data[Name]
  }
  
                  __Enum(Params*) {
                    throw Error("WTF __Enum")
                    ; ass := Params
                  }
                  __Item[Params*] {
                    get {
                      return this._getterFactory(Params[1])
                      ; throw Error("WTF __Item get")
                      ; ass := 1
                      ; local el, _, param, i, arr, found, path, m
                      ; el := this
                      ; for _, param in params {
                      ;   m := param
                      ; }

                    }
                    set {
                      throw Error("WTF __Item set")
                      ; newValue := value
                      ; newName := params[1]
                      ; this.%newName% := IniFile.IniSection(newName, newValue, this)

                      ; local el, _, param, i, arr, found, path, m
                      ; el := this
                      ; for _, param in params {
                      ;   m := param
                      ; }
                    }
                  }
                  static get(Params*) {
                    throw Error("WTF get")
                  }
                  static set(Params*) {
                    throw Error("WTF set")
                  }
  ;#endregion

  ;#region Private

  _initSettings(settingsObject:=-1) {
    
    defaultSettings := Map()
    defaultSettings['SaveDebounceTimeoutMs'] := 3000

    currentSettings := defaultSettings.Clone()

      ; getterFactory(Name) {
      ;   return (this) => currentSettings[Name]
      ; }
      ; setterFactory(Name) {
      ;   setterFn(this, Params*) {
      ;     Value := Params[1]
      ;     currentSettings[Name] := Value
      ;     return currentSettings[Name]
      ;   }
      ;   return setterFn
      ; }
      ; this.DefineProp("SETTINGS", {
      ;   Get: getterFactory(Name),
      ;   Set: setterFactory(Name),
      ; })
    this.DefineProp("_SETTINGS", { Value: currentSettings })

    if (settingsObject = -1)
      return
    if (!IsObject(settingsObject))
      throw TypeError("Provided settingsObject is not an object")
    
    for settingName, settingValue in defaultSettings {
      currentSettings[settingName] := settingValue
    }
  }
  _getterFactory(Name) {
    return (this) => this.__data[Name]
  }
  _setterFactory(Name) {
    setterFn(this, Params*) {
      Value := Params[1]
      this.__data[Name] := IniFile.IniSection(Name, Value, this)
      this.SaveDebounced()
      return this.__data[Name]
    }
    return setterFn
  }
  _debounceFactory(TimeoutMs := 800) {
    static lastCallback := 0

    resetTimerFn() {
      if (lastCallback != 0) {
        OutputDebug("--------- RESET DEBOUNCE TIMER ---------`n")
        SetTimer(lastCallback, 0)
        lastCallback := 0
      }
    }

    debounceFn(Callback) {
      resetTimerFn()
      lastCallback := Callback

      OutputDebug("--------- SET DEBOUNCE " . TimeoutMs . " ---------`n" )
      SetTimer(Callback, -1 * TimeoutMs)
      SetTimer(resetTimerFn, -1 * (TimeoutMs + 1))
      
    }
    return debounceFn
  }
  _writeIni() {
    outputDebug("______TODO: _writeIni`n" )
    ; outputDebug("______TODO: _writeIni`n" this.ToString())

    ; buffer := IniRead(this.__path)
    ; outputDebug("IniRead " this.__path "`n")
    ; sections := Map()
    ; for _, name in StrSplit(buffer, "`n")
    ;   sections[name] := true
    ; for name in this.__data {
    ;   this[name].Save()
    ;   sections.Delete(name)
    ; }
    ; for name in sections {
    ;   IniDelete(this.__path, name)
    ;   outputDebug("IniDelete " this.__path " " name "`n")
    ; }


      ;   buffer := IniRead(this.__path, this.__name)
      ;   outputDebug("IniRead " this.__path " " this.__name "`n")
      ;   keys := Map()
      ;   for _, key in StrSplit(buffer, "`n") {
      ;       key := StrSplit(key, "=")[1]
      ;       keys[key] := true
      ;   }
      ;   for key, value in this {
      ;       keys.Delete(key)
      ;       IniWrite(value, this.__path, this.__name, key)
      ;       outputDebug("IniWrite " this.__path " " this.__name " k=" key " v=" value "`n")
      ;   }
      ;   for key in keys {
      ;     IniDelete(this.__path, this.__name, key)
      ;     outputDebug("IniDelete " this.__path " " this.__name " k=" key "`n")
      ;   }
      ; }
  }
  ;#endregion

  class IniSection {
    static Parse(content) {
      dataObj := map()
      for _, pair in StrSplit(content, "`n") {
        pair := StrSplit(pair, "=",, 2)
        dataObj[pair[1]] := pair.Length = 2 ? pair[2] : ""
      }
      return dataObj
    }

    ;#region Public
    Has(Name) {
      return this.__data.Has(Name)
    }
    ToString() {
      iniString := ""
      for propName, propValue in this.__data {
        iniString .= propName "=" propValue "`n"
      }
      return iniString
    }
    Save() {
      this.__parent.Save()
    }
    SaveDebounced() {
      this.__parent.SaveDebounced()
    }
    ;#endregion

    ;#region Overload
    Delete(Name) {
      if (!this.__data.Has(Name))
        throw PropertyError("Can not delete a property that does not exist. Path: " this.__name "." Name)
      this.__data.Delete(Name)
      this.SaveDebounced()
    }
    ;#endregion

    ;#region Meta
    __New(sectionName, Data, parent:=false) {
      this.DefineProp("__name", { Value: sectionName })
      this.DefineProp("__data", { Value: Map() })
      this.DefineProp("__parent", { Value: parent })
      dataObject := IsObject(Data) ? Data : IniFile.IniSection.Parse(Data)

      dataProps := (dataObject.__Class = "Map") ? dataObject : dataObject.OwnProps()
      for propName, value in dataProps {
        ; if (propName = "__name" || propName = "__data" || propName = "__parent")
        ;   Continue
        ; this[propName] := value ; will call __Item[Params*] { set()
        this.__data[propName] := value
      }
    }
    __Get(Name, Params) {
      val := (this.__data.Has(Name)) ? this.__data[Name] : ""
      return val
    }
    __Set(Name, Params, Value) {
      if (IsObject(Value))
        throw TypeError("You can not set Object as a value to ini prop. Path: " this.__name "." Name)
      if (!this.__data.Has(Name) || Value != this.__data[Name]) {
        this.__data[Name] := Value
        this.SaveDebounced()
      }
    }
 
              __Enum(Params*) {
                ; throw Error("WTF __Enum")
                ass := Params
              }
              __Item[Params*] {
                get {
                  ; throw Error("WTF __Item get")
                  ass := 1
                  ; local el, _, param, i, arr, found, path, m
                  ; el := this
                  ; for _, param in params {
                  ;   m := param
                  ; }

                }
                set {
                  ; called by this[propName] := ...

                  ; throw Error("WTF __Item set")

                  newValue := value
                  newName := params[1]
                  this.%newName% := newValue
                  ; this.%newName% := IniFile.IniSection(newName, newValue, this)


                  ; this.SaveDebounced() ;nnada???

                  ; local el, _, param, i, arr, found, path, m
                  ; el := this
                  ; for _, param in params {
                  ;   m := param
                  ; }
                }
              }
              static get(Params*) {
                throw Error("WTF get")
              }
              static set(Params*) {
                throw Error("WTF set")
              }
    ;#endregion
  }
}
