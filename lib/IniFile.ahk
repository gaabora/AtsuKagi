#Requires AutoHotkey >=2.0.18

; ass := Map('GE', 123)
; OutputDebug(ass['GE'] . "`n")
; ; OutputDebug(ass['GR'] . "`n")
; OutputDebug(ass.GE . "`n")

aconf := IniFile("sconfig.ini")
aconf['ass'] := 'aaa=123'
; OutputDebug(aconf['D']["xxx"] . "`n")
; OutputDebug(aconf['D'].xxx . "`n")
; OutputDebug(aconf.D["xxx"] . "`n")
; OutputDebug(aconf.D.xxx . "`n")

OutputDebug(aconf['GENERAL']["xxx"] . "`n")
; OutputDebug(aconf['GENERAL']["yyy"] . "`n")
OutputDebug(aconf['GENERAL'].xxx . "`n")
; OutputDebug(aconf['GENERAL'].yyy . "`n")
OutputDebug(aconf.GENERAL["xxx"] . "`n")
; OutputDebug(aconf.GENERAL["yyy"] . "`n")
OutputDebug(aconf.GENERAL.xxx . "`n")
; OutputDebug(aconf.GENERAL.yyy . "`n")
; OutputDebug("---yyy=" . aconf.GENERAL.yyy . ".")

For Key , Val in aconf {
  OutputDebug(key . '=' . Val.ToString() .  "`n")
}
For Key , Val in aconf.GENERAL {
  OutputDebug(key . '=' . Val .  "`n")
}
For Key , Val in aconf['GENERAL'] {
  OutputDebug(key . '=' . Val .  "`n")
}


; aconf.GENERAL :=  {
;   testInt: -123,
;   testFloat: 123.456,
;   testString: "Hello World =) `;",
; }
; aconf.GENERAL :=  {
;   testInt: -1234,
;   testFloat: 123.456,
;   testString: "Hello World =) `;",
; }

ass := aconf['GENERAL'].Has("HotkeyInterval")


; make_greeter(f) {
;     greet(subject) {
;       OutputDebug(Format(f, subject))
;     }
;     return greet
; }

; g := make_greeter("Hello, {}!")
; g(A_UserName)
; g("World")


num := 1
#a::
{
  global num
  global aconf
  num := num+1
  OutputDebug("ASS" num)
  aconf.GENERAL.wtf := num  
}

class IniFileProto {
  class IniSection {
    static Parse(content) {
      dataObj := map()
      for _, pair in StrSplit(content, "`n") {
        pair := StrSplit(pair, "=",, 2)
        dataObj[pair[1]] := pair.Length = 2 ? pair[2] : ""
      }
      return dataObj
    }
    __pIniSection_Name := ''
    __pIniSection_Data := Map()
    __pIniSection_Owner := {}
    _addSectionItem(name) {
      this.DefineProp(name, {
        Get: this._getterFactory(name),
        Set: this._setterFactory(name),
      })
    }
    _getterFactory(Name) {
      return (this) => this.__pIniSection_Data[Name]
    }
    _setterFactory(Name) {
      setterFn(this, Params*) {
        Value := Params[1]
        if (this.__pIniSection_Data[Name] != Value) {
          this.__pIniSection_Data[Name] := Value
          if (this.__pIniSection_Owner)
            this.__pIniSection_Owner._autosave()
        }
        return this.__pIniSection_Data[Name]
      }
      return setterFn
    }
  }
  static _defaultSettings := Map(
    'SAVE_AUTOMATICALLY', true,
    'SECTION_ITEM_EMPTY_VALUE', '',
    'WRITE_DEBOUNCE_TIMEOUT_MS', 3000,
  )
  __pIniFile_Path := ''
  __pIniFile_Data := Map()
  __pIniFile_PrevData := Map()
  __pIniFile_Settings := Map()
  _initSettings(settingsObject:=-1) {
    this.__pIniFile_Settings := IniFileProto._defaultSettings.Clone()
    if (settingsObject = -1)
      return
    if (!IsObject(settingsObject))
      throw TypeError("Provided settingsObject is not an object")
    for settingName, settingValue in IniFileProto._defaultSettings {
      this.__pIniFile_Settings[settingName] := settingValue
    }
  }
  _autosave() {
    OutputDebug('_autosave triggered')
  }
  _addSection(name) {
    this.DefineProp(name, {
      Get: this._getterFactory(name),
      Set: this._setterFactory(name),
    })
  }
  _getterFactory(Name) {
    return (this) => this.__pIniFile_Data[Name]
  }
  _setterFactory(Name) {
    setterFn(this, Params*) {
      Value := Params[1]
      this.__pIniFile_Data[Name] := IniFile.IniSection(this, Name, Value)
      this._autosave()
      return this.__pIniFile_Data[Name]
    }
    return setterFn
  }
  _writeIni() {
    outputDebug("______TODO: _writeIni`n" )
    ; outputDebug("______TODO: _writeIni`n" this.ToString())
    ; buffer := IniRead(this.__pIniFile_Path)
    ; outputDebug("IniRead " this.__pIniFile_Path "`n")
    ; sections := Map()
    ; for _, name in StrSplit(buffer, "`n")
    ;   sections[name] := true
    ; for name in this.__pIniFile_Data {
    ;   this[name].Save()
    ;   sections.Delete(name)
    ; }
    ; for name in sections {
    ;   IniDelete(this.__pIniFile_Path, name)
    ;   outputDebug("IniDelete " this.__pIniFile_Path " " name "`n")
    ; }
    ;   buffer := IniRead(this.__pIniFile_Path, this.__pIniSection_Name)
    ;   outputDebug("IniRead " this.__pIniFile_Path " " this.__pIniSection_Name "`n")
    ;   keys := Map()
    ;   for _, key in StrSplit(buffer, "`n") {
    ;       key := StrSplit(key, "=")[1]
    ;       keys[key] := true
    ;   }
    ;   for key, value in this {
    ;       keys.Delete(key)
    ;       IniWrite(value, this.__pIniFile_Path, this.__pIniSection_Name, key)
    ;       outputDebug("IniWrite " this.__pIniFile_Path " " this.__pIniSection_Name " k=" key " v=" value "`n")
    ;   }
    ;   for key in keys {
    ;     IniDelete(this.__pIniFile_Path, this.__pIniSection_Name, key)
    ;     outputDebug("IniDelete " this.__pIniFile_Path " " this.__pIniSection_Name " k=" key "`n")
    ;   }
    ; }
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
}
class IniFile extends IniFileProto {
  ;#region Public
  Has(Name) {
    return this.__pIniFile_Data.Has(Name)
  }
  Load(filePath) {
    outputDebug("IniRead(" filePath ")`n")
    buffer := IniRead(filePath)

    for idx, sectionName in StrSplit(buffer, "`n") {
      outputDebug("IniRead(" filePath ", " sectionName ")`n")
      sectionContent := IniRead(filePath, sectionName)
      this.__pIniFile_PrevData[sectionName] := sectionContent

      this.__pIniFile_Data[sectionName] := IniFile.IniSection(this, sectionName, sectionContent)

      this._addSection(sectionName)
    }
  }
  Save() {
    outputDebug("Save`n")

    outputDebug("TODO: SaveDebounced >>> debounce Save()`n")
    ; outputDebug("TODO: SaveDebounced >>> debounce Save()`n" this.ToString())
    debounceFn := this._debounceFn
    writeFn := this._writeIni.bind(this)
    debounceFn(writeFn)
  }

  ToString() {
    iniString := ""
    for sectionName, iniSection in this.__pIniFile_Data {
      iniString .= "[" sectionName "]`n" iniSection.ToString()
    }
    return iniString
  }

  Delete(Name) {
    if (!this.__pIniFile_Data.Has(Name))
      throw PropertyError("Can not delete a section that does not exist. Path: " Name)
    this.__pIniFile_Data.Delete(Name)
    this._autosave()
  }
  ;#endregion

  ;#region Meta

  __New(filePath, settingsObject:=-1) {
    this._initSettings(settingsObject)
    
    ; this.DefineMethod( "__Enum", (this, NumberOfVars) => this.OwnProps() )
    
    debounceFn := this._debounceFactory(this.__pIniFile_Settings["WRITE_DEBOUNCE_TIMEOUT_MS"])
    this.DefineProp("_debounceFn", { Call: debounceFn })
    this.Load(filePath)



  }
  ; __Get(Name, Params*) {
  ;   this.__pIniFile_Data[Name] := IniFile.IniSection(Name, {}, this)
  ;   OutputDebug("IniFile __GET(" . Name . ")`n")
  ;   this.DefineProp(Name, {
  ;     Get: this._getterFactory(Name),
  ;     Set: this._setterFactory(Name),
  ;   })
  ;   return this.__pIniFile_Data[Name]
  ; }
  ; __Set(Name, Params, Value*) {
  ;   this.__pIniFile_Data[Name] := IniFile.IniSection(Name, Value, this)
  ;   this.DefineProp(Name, {
  ;     Get: this._getterFactory(Name),
  ;     Set: this._setterFactory(Name),
  ;   })
  ;   return this.__pIniFile_Data[Name]
  ; }
  
                  __Enum(NumberOfVars) {
                    total := this.__pIniFile_Data.Count
                    remained := total

                    EnumerateVals(&LoopVal) {
                      if (remained = 0)
                        return false
                      idx := 1
                      For Key in this.__pIniFile_Data {
                        if (idx == (total + 1 - remained)) {
                          LoopVal := Key
                          break
                        }
                        idx += 1
                      }
                      remained -= 1
                      return true
                    }

                    EnumerateKeysVals(&LoopKey, &LoopVal) {
                      if (remained = 0)
                        return false
                      idx := 1
                      For Key, Val in this.__pIniFile_Data {
                        if (idx == (total + 1 - remained)) {
                          LoopKey := Key
                          LoopVal := Val
                          break
                        }
                        idx += 1
                      }
                      remained -= 1
                      return true
                    }

                    return (NumberOfVars = 1)
                      ? EnumerateVals
                      : EnumerateKeysVals
                    
                  }
                  __Item[Params*] {
                    get {
                      name := Params[1]
                      return this.__pIniFile_Data[name]
                    }
                    set {
                      name := params[1]
                      this.__pIniFile_Data[name] := IniFile.IniSection(this, name, value)
                      if (!this.HasOwnProp(name))
                        this._addSection(name)
                    }
                  }
                  static get(Params*) {
                    throw Error("WTF get")
                  }
                  static set(Params*) {
                    throw Error("WTF set")
                  }
  ;#endregion

  class IniSection extends IniFileProto.IniSection {
    

    ;#region Public
    Has(Name) {
      return this.__pIniSection_Data.Has(Name)
    }
    ToString() {
      iniString := ""
      for propName, propValue in this.__pIniSection_Data {
        iniString .= propName "=" propValue "`n"
      }
      return iniString
    }
    ;#endregion

    ;#region Overload
    Delete(Name) {
      if (!this.__pIniSection_Data.Has(Name))
        throw PropertyError("Can not delete a property that does not exist. Path: " this.__pIniSection_Name "." Name)
      this.__pIniSection_Data.Delete(Name)
      this._autosave()
    }
    ;#endregion

    ;#region Meta
    __New(Owner, Name, Data) {
      this.__pIniSection_Owner := Owner
      this.__pIniSection_Name := Name
      dataObject := IsObject(Data) ? Data : IniFile.IniSection.Parse(Data)

      dataProps := (dataObject.__Class = "Map") ? dataObject : dataObject.OwnProps()
      for propName, value in dataProps {
        ; if (propName = "__pIniSection_Name" || propName = "__pIniSection_Data" || propName = "__pIniSection_Owner")
        ;   Continue
        ; this[propName] := value ; will call __Item[Params*] { set()
        this.__pIniSection_Data[propName] := value
        this.DefineProp(propName, {
          Get: this._getterFactory(propName),
          Set: this._setterFactory(propName),
        })
      }
      
    }
    ; __Get(Name, Params*) {
    ;   if (Name == '__pIniSection_Data')
    ;     return this.__pIniSection_Data
    ;   if (Name == '__pIniFile_Settings')
    ;     return this.__pIniFile_Settings

    ;   val := (this.__pIniSection_Data.Has(Name)) ? this.__pIniSection_Data[Name] : this.__pIniFile_Settings['SECTION_ITEM_EMPTY_VALUE']
    ;   return val
    ; }
    ; __Set(Name, Params, Value) {
    ;   if (IsObject(Value))
    ;     throw TypeError("You can not set Object as a value to ini prop. Path: " this.__pIniSection_Name "." Name)
    ;   if (!this.__pIniSection_Data.Has(Name) || Value != this.__pIniSection_Data[Name]) {
    ;     this.__pIniSection_Data[Name] := Value
    ;     this._autosave()
    ;   }
    ; }
 
              __Enum(Params*) {
                return this.__pIniSection_Data.__Enum(Params*)
              }
              __Item[Params*] {
                get {
                  name := Params[1]
                  return this.__pIniSection_Data[name]
                  ; val := (this.__pIniSection_Data.Has(name)) ? this.__pIniSection_Data[name] : this.__pIniSection_Owner.__pIniFile_Settings['SECTION_ITEM_EMPTY_VALUE']
                  ; return val
                }
                set {
                  ; called by this[propName] := ...

                  ; throw Error("WTF __Item set")

                  newValue := value
                  newName := params[1]
                  this.%newName% := newValue
                  ; this.%newName% := IniFile.IniSection(this, newName, newValue)


                  ; this._autosave() ;nnada???

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
