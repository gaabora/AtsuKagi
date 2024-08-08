#Requires AutoHotkey >=2.0.18

class IniFileProto {
  class IniSectionProto {
    __Set(Name, Params, Value) {
      if (this.__isReservedPropName(Name)) {
        this.DefineProp(name, {
          Value: Value,
        })
        return this.%Name%
      }
      if (IsObject(Value))
        throw TypeError("You can not set Object as a value to ini prop. Path: " this.__pIniSection_Name "." Name)
      if (!this.__pIniSection_Data.Has(Name) || Value != this.__pIniSection_Data[Name]) {
        this.__pIniSection_Data[Name] := Value
        this.__pIniSection_Owner._autosave()
      }
    }
    __pIniSection_Name := ''
    __pIniSection_Data := Map()
    __pIniSection_Owner := {}
    __isReservedPropName(Name) {
      return Name = "__pIniSection_Name"
        || Name = "__pIniSection_Data"
        || Name = "__pIniSection_Owner"
    }
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
        if (IsObject(Value))
          throw TypeError("You can not set Object as a value to ini prop. Path: " this.__pIniSection_Name "." Name)
        if (this.__pIniSection_Data[Name] != Value) {
          this.__pIniSection_Data[Name] := Value
          if (this.__pIniSection_Owner)
            this.__pIniSection_Owner._autosave()
        }
        return this.__pIniSection_Data[Name]
      }
      return setterFn
    }
    static Parse(content) {
      dataObj := map()
      for _, pair in StrSplit(content, "`n") {
        pair := StrSplit(pair, "=",, 2)
        dataObj[pair[1]] := pair.Length = 2 ? pair[2] : ""
      }
      return dataObj
    }
    ToString() {
      iniString := ""
      for propName, propValue in this.__pIniSection_Data {
        iniString .= propName "=" propValue "`n"
      }
      return iniString
    }
    Has(Name) {
      return this.__pIniSection_Data.Has(Name)
    }
    Delete(Name) {
      if (!this.__pIniSection_Data.Has(Name))
        throw PropertyError("Can not delete a property that does not exist. Path: " this.__pIniSection_Name "." Name)
      this.__pIniSection_Data.Delete(Name)
      this.__pIniSection_Owner._autosave()
    }
  }

  __Set(Name, Params, Value) {
    if (this.__isReservedPropName(Name)) {
      this.DefineProp(name, {
        Value: Value,
      })
      return this.%Name%
    }
    this.__pIniFile_Data[Name] := IniFile.IniSection(this, Name, Value)
    this._addSection(Name)
    return this.__pIniFile_Data[Name]
  }
  __pIniFile_Path := ''
  __pIniFile_Data := Map()
  __pIniFile_PrevData := Map()
  __pIniFile_Settings := Map()
  __isReservedPropName(Name) {
    return Name = "__pIniFile_Data"
      || Name = "__pIniFile_Path"
      || Name = "__pIniFile_PrevData"
      || Name = "__pIniFile_Settings"
  }
  _initSettings(settingsObject:=-1) {
    static _defaultSettings := Map(
      'SAVE_AUTOMATICALLY', false,
      'WRITE_DEBOUNCE_TIMEOUT_MS', 3000,
    )
    this.__pIniFile_Settings := _defaultSettings.Clone()
    if (settingsObject = -1)
      return
    if (!IsObject(settingsObject))
      throw TypeError("Provided settingsObject is not an object")
    for settingName, settingValue in _defaultSettings {
      this.__pIniFile_Settings[settingName] := settingValue
    }
  }
  _autosave() {
    OutputDebug('_autosave triggered')
    if (!this.__pIniFile_Settings["SAVE_AUTOMATICALLY"]) {
      OutputDebug('SAVE_AUTOMATICALLY is off')
      return
    }
    debounceFn := this._debounceFn
    writeFn := this._writeIni.bind(this)
    debounceFn(writeFn)
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
    oldContent := ""
    for sectionName, sectionContent in this.__pIniFile_PrevData {
      oldContent .= "[" sectionName "]`n" sectionContent
    }
    newContent := this.ToString()
    if (oldContent = newContent) {
      outputDebug("_writeIni: no changes made`n" )
      return
    }
    if (FileExist(this.__pIniFile_Path))
      FileDelete(this.__pIniFile_Path)
    FileAppend(newContent, this.__pIniFile_Path)
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
  Load(filePath) {
    this.__pIniFile_Path := filePath
    outputDebug("IniRead(" filePath ")`n")
    buffer := IniRead(filePath)
    for idx, sectionName in StrSplit(buffer, "`n") {
      if (this.__isReservedPropName(sectionName))
        throw TypeError("Not allowed to use reserved name for section name " . sectionName . " found in file " . filePath)
      outputDebug("IniRead(" filePath ", " sectionName ")`n")
      sectionContent := IniRead(filePath, sectionName)
      this.__pIniFile_PrevData[sectionName] := sectionContent
      this.__pIniFile_Data[sectionName] := IniFile.IniSection(this, sectionName, sectionContent)
      this._addSection(sectionName)
    }
  }
  Save() {
    this._writeIni()
  }
  ToString() {
    iniString := ""
    for sectionName, iniSection in this.__pIniFile_Data {
      iniString .= "[" sectionName "]`n" iniSection.ToString()
    }
    return iniString
  }
  Has(Name) {
    return this.__pIniFile_Data.Has(Name)
  }
  Delete(Name) {
    if (!this.__pIniFile_Data.Has(Name))
      throw PropertyError("Can not delete a section that does not exist. Path: " Name)
    this.__pIniFile_Data.Delete(Name)
    this._autosave()
  }
}
class IniFile extends IniFileProto {
  __New(filePath, settingsObject:=-1) {
    this._initSettings(settingsObject)
    if (this.__pIniFile_Settings["SAVE_AUTOMATICALLY"]) {
      debounceFn := this._debounceFactory(this.__pIniFile_Settings["WRITE_DEBOUNCE_TIMEOUT_MS"])
      this.DefineProp("_debounceFn", { Call: debounceFn })
    }
    this.Load(filePath)
  }
  __Delete() {
    debounceFn := this._debounceFn
    doNothing() {
      nothing := 0
    }
    OutputDebug('debounce nothing`n')
    debounceFn(doNothing)
  }
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

  class IniSection extends IniFileProto.IniSectionProto {
    __New(Owner, Name, Data) {
      this.__pIniSection_Owner := Owner
      this.__pIniSection_Name := Name
      dataObject := IsObject(Data) ? Data : IniFile.IniSection.Parse(Data)

      dataProps := (dataObject.__Class = "Map") ? dataObject : dataObject.OwnProps()
      for propName, value in dataProps {
        if (propName = "__pIniSection_Name" || propName = "__pIniSection_Data" || propName = "__pIniSection_Owner")
          throw TypeError("Not allowed to use internal propName " . propName . " found in section " . Name)
        this.__pIniSection_Data[propName] := value
        this._addSectionItem(propName)
      }
    }
    __Enum(Params*) {
      return this.__pIniSection_Data.__Enum(Params*)
    }
    __Item[Params*] {
      get {
        name := Params[1]
        return this.__pIniSection_Data[name]
      }
      set {
        newValue := value
        newName := params[1]
        this.%newName% := newValue
        
      }
    }
  }
}
