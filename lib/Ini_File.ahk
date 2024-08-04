class Ini_File extends Object {

	__New(Path, Sync := true) {
		this.Path := Path
		this.Sync := false
		this.Sections := {}
		
		buffer := IniRead(Path)
		Loop Parse, buffer, "`n"
		{
			name := A_LoopField
			data := IniRead(Path, name)
			this.Sections[name] := Ini_Section(Path, name, data)
		}
		
		this.Sync := !!Sync
	}

	GetSections() {
		return this.Sections
	}
	
	__Get(Name) {
		return this.Sections[Name]	
	}
	
	__Set(Name, Value) {
		if (IsObject(Value) && !(Value instanceof Ini_Section)) {
			Value := Ini_Section(this.Path, Name, Value, this.Sync)
		}
		
		return this.Sections[Name] := Value
	}

	Delete(Name) {
		if (this.Sync)
			IniDelete(this.Path, Name)
	}

	Commit() {
		for Name, Section in this.Sections {
			Section.Commit()
		}
		
		ExistingSections := IniRead(this.Path)
		
		Loop Parse, ExistingSections, "`n"
		{
			if not this.Sections.Has(A_LoopField)
				IniDelete(this.Path, A_LoopField)
		}
	}
	
}

class Ini_Section {

	__New(Path, Name, Data := "", Sync := false) {
		this.Path := Path
		this.Name := Name
		this.Sync := !!Sync
		
		if !IsObject(Data)
			Data := this._ToObject(Data)
		
		for Key, Value in Data
			this[Key] := Value
	}
	
	__Get(Key) {
		return this[Key]	
	}
	
	__Set(Key, Value) {
		if (this.Sync)
			this._Write(Key, Value)
		
		return this[Key] := Value
	}
	
	_ToObject(&Data) {
		Loop Parse, Data, "`n"
		{
			Pair := StrSplit(A_LoopField, "=",, 2)
			Data[Pair[1]] := Pair[2]
		}
		
		return Data
	}
	
	_Write(Key, Value) {
		IniWrite(Value, this.Path, this.Name, Key)
	}
	
	Commit() {
		ExistingKeys := IniRead(this.Path, this.Name)
		
		Loop Parse, ExistingKeys, "`n"
		{
			Key := StrSplit(A_LoopField, "=")[1]
			
			if not this.Has(Key)
				IniDelete(this.Path, this.Name, Key)
		}
		
		for Key, Value in this
			this._Write(Key, Value)
	}
	
}
