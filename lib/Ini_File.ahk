class Ini_File extends Object_Sortable {

	AtomicGet() {
		return this.__sync
	}

	AtomicSet(Mode) {
		for name in this
			this[name].AtomicSet(Mode)
		this.__sync := !!Mode
		return this.__sync
	}

	Commit() {
		IniRead buffer, % this.__path
		sections := new Object()
		loop parse, buffer, `n
			sections[A_LoopField] := true
		for name in this.__data
		{
			this[name].Commit()
			sections.Delete(name)
		}
		for name in sections
			IniDelete % this.__path, % name
	}

	Delete(Name) {
		if (this.__sync)
			IniDelete % this.__path, % Name
	}

	__New(Path, Sync:= true) {
		ObjRawSet(this, "__path", Path)
		ObjRawSet(this, "__sync", false)
		IniRead buffer, % Path
		loop parse, buffer, `n
		{
			name := A_LoopField
			IniRead data, % Path, % name
			this[name] := Ini_Section(Path, name, data)
		}
		this.AtomicSet(Sync)
	}

	__Set(Key, Val) {
		if (IsObject(Val) && ObjGetBase(Val).__Class != "Ini_Section") {
			obj := Ini_Section(this.__path, Key, Val, this.__sync)
			this[Key] := obj
			return obj ; Overload Base.__Set
		}
	}

}

Ini_Section(Parameters*) {
	return new Ini_Section(Parameters*)
}

class Ini_Section extends Object_Sortable {

	AtomicGet() {
		return this.__sync
	}

	AtomicSet(Mode) {
		Mode := !!Mode
		this.__sync := Mode
		return Mode
	}

	Commit() {
		IniRead buffer, % this.__path, % this.__name
		keys := new Object()
		loop parse, buffer, `n
		{
			key := StrSplit(A_LoopField, "=")[1]
			keys[key] := true
		}
		for key,val in this
		{
			keys.Delete(key)
			this._Write(key, val)
		}
		for key in keys
			IniDelete % this.__path, % this.__name, % key
	}

	Delete(Key) {
		if (this.__sync)
			IniDelete % this.__path, % this.__name, % Key
	}

	__New(Path, Name, Data, Sync := false) {
		ObjRawSet(this, "__path", Path)
		ObjRawSet(this, "__name", Name)
		ObjRawSet(this, "__sync", Sync)
		if !IsObject(Data)
			this._ToObject(Data)
		for key,val in Data
			this[key] := val
	}

	__Set(Key, Val) {
		if (this.__sync)
			this._Write(Key, Val)
	}

	_ToObject(ByRef Data) {
		copy := Data
		Data := new Object()
		loop parse, copy, `n
		{
			pair := StrSplit(A_LoopField, "=",, 2)
			ObjRawSet(Data, pair*)
		}
	}

	_Write(Key, Val) {
		; http://is.gd/uhoQqu ↓
		Val := StrLen(Val) ? " " Val : ""
		IniWrite % Val, % this.__path, % this.__name, % Key
	}

}


class Object
{

	__Init() {
		ObjSetBase(this, "")
	}

}

Object_Sortable(Parameters*) {
	total := Parameters.Count()
	if (total & 1)
		return
	obj := new Object_Sortable()
	loop % total / 2
	{
		key := Parameters[A_Index * 2 - 1]
		obj[key] := Parameters[A_Index * 2]
	}
	return obj
}

class Object_Sortable
{

	Clone() {
		clone := new Object_Sortable()
		clone.__keys := this.__keys.Clone()
		clone.__data := this.__data.Clone()
		return clone
	}

	Count() {
		return this.__keys.Count()
	}

	Delete(FirstKey, LastKey := "") {
		index := ObjIndex(this, FirstKey)
		length := 0
		if StrLen(LastKey) {
			length := ObjIndex(this, LastKey)
			length -= index
		}
		return this.RemoveAt(index, length + 1)
	}

	GetAddress(Key) {
		return this.__data.GetAddress(Key)
	}

	GetCapacity(Key*) {
		switch Key.Count() {
			case 0: return this.__data.GetCapacity()
			case 1: return this.__data.GetCapacity(Key)
		}
		throw Exception("Too many parameters passed to function.", -1)
	}

	HasKey(Key) {
		return this.__data.HasKey(Key)
	}

	Insert(Parameters*) {
		throw Exception("Deprecated", -1)
	}

	InsertAt(Pos, Values*) {
		keysIndex := ObjIndex(this, Pos)
		dataKey := this.__data.MaxIndex()
		for _,value in Values
		{
			keysIndex++, dataKey++
			this.__data[dataKey] := value
			this.__keys.InsertAt(keysIndex, dataKey)
		}
	}

	Length() {
		return this.__data.Length()
	}

	MaxIndex() {
		return this.__data.MaxIndex()
	}

	MinIndex() {
		return this.__data.MinIndex()
	}

	Pop() {
		key := this.__keys.Pop()
		if (key)
			return this.__data.Delete(key)
	}

	Push(Values*) {
		key := this.__data.MaxIndex()
		for _,value in Values
		{
			key++
			this.__keys.Push(key)
			this.__data[key] := value
		}
	}

	Remove(Parameters*) {
		throw Exception("Deprecated", -1)
	}

	RemoveAt(Pos, Length := 1) {
		removed := 0
		loop % Length
		{
			key := this.__keys.RemoveAt(Pos)
			value := this.__data.Delete(key)
			removed += key ? 1 : 0
		}
		if (removed > 1)
			return removed
		return value
	}

	SetCapacity(Parameters*) {
		if (Parameters.Count() = 1) {
			this.__keys.SetCapacity(Parameters[1])
			max := this.__data.SetCapacity(Parameters[1])
			return max
		}
		if (Parameters.Count() != 2)
			return
		key := Parameters[1]
		size := Parameters[2]
		if !this.__data.HasKey(key)
			this[key] := ""
		max := this.__data.SetCapacity(key, size)
		return max
	}

	; Private

	_NewEnum() {
		return new Object_SortableEnum(this.__keys, this.__data)
	}

	; Meta

	__Get(Parameters*) ; Key[, Key...]
	{
		return this.__data[Parameters*]
	}

	__Init() {
		ObjRawSet(this, "__data", new Object())
		ObjRawSet(this, "__keys", new Object())
	}

	__Set(Parameters*) ; Key, Value[, Value...]
	{
		key := Parameters[1]
		value := Parameters.Pop()
		if !this.__data.HasKey(key)
			this.__keys.Push(key)
		this.__data[Parameters*] := value
		return value
	}

}

class Object_SortableEnum
{

	__New(Keys, Data) {
		this.index := 1
		this.keys := Keys
		this.data := Data
		this.count := Data.Count()
	}

	Next(ByRef Key, ByRef Value := "") {
		index := this.index++
		if (index > this.count)
			return false
		Key := this.keys[index]
		Value := this.data[Key]
		return true
	}

}

; Auxiliary
ObjIndex(this, Position) {
	for index,key in this.__keys
	{
		if (key = Position)
			return index
	}
	return this.__keys.MaxIndex() + 1
}

