
conf := IniFile("sconfig.ini")
conf.GENERAL :=  {
  testInt: -123,
  testFloat: 123.456,
  testString: "Hello World =) `;",
}


class IniFile {
  ;#region Meta
  __New(filePath, debounceWriteMs:=1000) {
		this.DefineProp("__rawData", { Value: Map() })
		this.DefineProp("__data", { Value: Map() })
		this.DefineProp("__lastSaved", { Value: Map() })
		this.DefineProp("__path", { Value: filePath })

    this.Load(filePath)
  }
  __Get(Name, Params) {
    this.__data[Name] := IniFile.IniSection(Name, {}, this)
    return this.__data[Name]
  }
  __Set(Name, Params, Value) {
    this.__data[Name] := IniFile.IniSection(Name, Value, this)    
    return this.__data[Name]
  }
  
  __Enum(Params*) {
    throw Error("WTF __Enum")
    ; ass := Params
  }
  __Item[Params*] {
    get {
      throw Error("WTF __Item get")
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
  getterFactory(gName) {
    return (this) => this.__data[gName]
  }
  setterFactory(sName) {
    setterFn(this, Params*) {
      outputDebug(">>> setterFn " sName ")`n")
      Value := Params[1]
            ; for index,param in Params
            ;   a := param
            ; return this.__Set(sName, {}, Value)

      ; isObj := IsObject(Value)
      ; valueObjClassName := isObj ? Value.__Class : ""
      ; if (valueObjClassName = "IniSection") {
      ;   ; this.DefineProp(Name, { Value: Value })
      ;   this.__data[sName] := Value
      ; } else {
      ;   ; this.DefineProp(Name, { Value: IniSection(Name, Value, this) })
      ;   this.__data[sName] := IniFile.IniSection(sName, Value, this)
      ; }
      this.__data[sName] := IniFile.IniSection(sName, Value, this)

      return this.__data[sName]
    }
    return setterFn
  }
  ;#region Public
  Load(filePath) {
    outputDebug("IniRead(" filePath ")`n")
    buffer := IniRead(filePath)

    for idx, sectionName in StrSplit(buffer, "`n") {
      outputDebug("IniRead(" filePath ", " sectionName ")`n")
      sectionContent := IniRead(filePath, sectionName)
      this.__rawData[sectionName] := sectionContent

      ; sectionData := IniSection.Parse(sectionContent)
      this.__data[sectionName] := IniFile.IniSection(sectionName, sectionContent, this)

      
      ; callFunction(this, cName) {
      ;   return this.__data[cName]
      ; }

      this.DefineProp(sectionName, {
        Get: this.getterFactory(sectionName),
        Set: this.setterFactory(sectionName),
        ; Value: IniSection(sectionName, sectionContent, this),
        ; Call: callFunction(this,sectionName),
      })

      ; this[sectionName] := sectionData


      ;   __New(ptr, count, type := "ptr") {
      ;     static _ := DllCall("LoadLibrary", "str", "ole32.dll")
      ;     static bits := { UInt: 4, UInt64: 8, Int: 4, Int64: 8, Short: 2, UShort: 2, Char: 1, UChar: 1, Double: 8, Float: 4, Ptr: A_PtrSize, UPtr: A_PtrSize }
      ;     this.size := (this.count := count) * (bit := bits.%type%), this.ptr := ptr || DllCall("ole32\CoTaskMemAlloc", "uint", this.size, "ptr")
      ;     this.DefineProp("__Item", { get: (s, i) => NumGet(s, i * bit, type) })
      ;     this.DefineProp("__Enum", { call: (s, i) => (i = 1 ?
      ;             (i := 0, (&v) => i < count ? (v := NumGet(s, i * bit, type), ++i) : false) :
      ;                 (i := 0, (&k, &v) => (i < count ? (k := i, v := NumGet(s, i * bit, type), ++i) : false))
      ;         ) })
      ; }
    
      ; ; getter := this.__GET.bind(this)
      ; ; setter := this.__SET.bind(this)
			; this.DefineProp(sectionName, {
			; 	; Value: IniSection(sectionName, sectionContent, this),

      ;   ; get: getter,
      ;   ; set: setter,
			; 	; Get: (Name, Params) => { return this._Get(Name, Params, Value) },
			; 	; Set: (Name, Params, Value) => { this._Set(Name, Params, Value) },

			; 	; Set: (Name, Params, Value) { => outputDebug("s=" s "i=" i)
			;   ; Get:(o)=>this[o]
			;   ; Set: objBindMethod(this, 'gsProp').bind(name)
			; })
    }
    ; this.Sync(Sync)
  }
  Save() {
    buffer := IniRead(this.__path)
    outputDebug("IniRead " this.__path "`n")
    sections := Map()
    for _, name in StrSplit(buffer, "`n")
      sections[name] := true
    for name in this.__data {
      this[name].Save()
      sections.Delete(name)
    }
    for name in sections {
      IniDelete(this.__path, name)
      outputDebug("IniDelete " this.__path " " name "`n")
    }
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
  Delete(dName) {
    if (!this.__data.Has(dName))
      throw PropertyError("Can not delete a section that does not exist. Path: " dName)
    this.__data.Delete(dName)
    ; if (this.__sync) {
    ;   IniDelete(this.__path, Name)
    ;   outputDebug("IniDelete " this.__path " " name "`n")
    ; }
  }
  ;#endregion
  
  class IniSection extends Map { ; extends IniObject {
    ;#region Meta
    __New(sectionName, Data, parent := false) {
      this.DefineProp("__name", { Value: sectionName })
      this.DefineProp("__data", { Value: Map() })
      this.DefineProp("__parent", { Value: parent })
      ; this.DefineProp("__sync", { Value: AutoSync })
      dataObject := IsObject(Data) ? Data : IniFile.IniSection.Parse(Data)

      dataProps := (dataObject.__Class = "Map") ? dataObject : dataObject.OwnProps()
      for propName, value in dataProps {
        this[propName] := value
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
        this.Save()
      }
      
    }
                
              __Enum(Params*) {
                throw Error("WTF __Enum")
                ; ass := Params
              }
              __Item[Params*] {
                get {
                  throw Error("WTF __Item get")
                  ; ass := 1
                  ; local el, _, param, i, arr, found, path, m
                  ; el := this
                  ; for _, param in params {
                  ;   m := param
                  ; }

                }
                set {
                  ; throw Error("WTF __Item set")

                  newValue := value
                  newName := params[1]
                  this.%newName% := newValue
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
    
    static Parse(content) {
      dataObj := map()
      for _, pair in StrSplit(content, "`n") {
        pair := StrSplit(pair, "=",, 2)
        dataObj[pair[1]] := pair.Length = 2 ? pair[2] : ""
      }
      return dataObj
    }

    ;#region Public
    ToString() {
      iniString := ""
      for propName, propValue in this.__data {
        iniString .= propName "=" propValue "`n"
      }
      return iniString
    }
    Save() {
      outputDebug("TODO Save section [" this.__name "]`n" this.ToString() "`n")
    }
    _Write() {
      buffer := IniRead(this.__path, this.__name)
      outputDebug("IniRead " this.__path " " this.__name "`n")
      keys := Map()
      for _, key in StrSplit(buffer, "`n") {
          key := StrSplit(key, "=")[1]
          keys[key] := true
      }
      for key, value in this {
          keys.Delete(key)
          IniWrite(value, this.__path, this.__name, key)
          outputDebug("IniWrite " this.__path " " this.__name " k=" key " v=" value "`n")
      }
      for key in keys {
        IniDelete(this.__path, this.__name, key)
        outputDebug("IniDelete " this.__path " " this.__name " k=" key "`n")
      }
    }
    ; Sync(Force := "") {
    ;   if (Force = "")
    ;     return this.__sync
    ;   return this.__sync := !!Force
    ; }
    ;#endregion

    ;#region Overload

    Delete(dName) {
      if (!this.__data.Has(dName))
        throw PropertyError("Can not delete a property that does not exist. Path: " this.__name "." dName)
      this.__data.Delete(dName)
      ; if (this.__sync) {
      ;   IniDelete(this.__path, this.__name, Key)
      ;   outputDebug("IniDelete " this.__path " " this.__name " k=" key "`n")
      ; }
    }
    ;#endregion

  }
}


class IniObject {
  ;#region Public
  ; Clone() {
  ;   className := ObjGetBase(this).__Class
  ;   clonedObj := new %className%()
  ;   clonedObj.__data := this.__data.Clone()
  ;   return clonedObj
  ; }
  Count() {
    return this.__data.Count
  }
  Delete(Parameters*) {
    return this.__data.Delete(Parameters*)
  }
  GetAddress(Key) {
    return this.__data.GetAddress(Key)
  }
  GetCapacity(Parameters*) {
    return this.__data.GetCapacity(Parameters*)
  }
  HasKey(Key) {
    return this.__data.Has(Key)
  }
  Insert(_*) {
    throw Error("Deprecated.", -1, A_ThisFunc)
  }
  InsertAt(Parameters*) {
    this.__data.InsertAt(Parameters*)
  }
  Length() {
    return this.__data.Length
  }
  MaxIndex() {
    return this.__data.MaxIndex()
  }
  MinIndex() {
    return this.__data.MinIndex()
  }
  Pop() {
    return this.__data.Pop()
  }
  Push(Parameters*) {
    return this.__data.Push(Parameters*)
  }
  Remove(_*) {
    throw Error("Deprecated.", -1, A_ThisFunc)
  }
  RemoveAt(Parameters*) {
    return this.__data.RemoveAt(Parameters*)
  }
  SetCapacity(Parameters*) {
    return this.__data.SetCapacity(Parameters*)
  }
  ;#endregion

  ;#region Private
  _NewEnum() {
    return this.__data._NewEnum()
  }
  ;#endregion

  ;#region Meta
  __Init() {
		this.DefineProp("__data", { value: Map() })
  }
  __Get(Parameters*) { ; Key[, Key...]
    return this.__data[Parameters*]
  }
  __Set(Parameters*) { ; Key, Value[, Value...]
    value := Parameters.Pop()
    this.__data[Parameters*] := value
    return value
  }
  ;#endregion
}
 