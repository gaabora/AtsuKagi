#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include ExecScript.ahk

#Include ..\lib\IniFile.ahk


Yunit.Use(YunitWindow).Test(IniFileTests)


class IniFileTests {
   Begin() {
      this.ConfFile := "test.ini"
      this.EmptySettings := ""
   }
   
   EmptyIniToString() {
      RecreateIniFile(this.ConfFile, this.EmptySettings)
      conf := IniFile(this.ConfFile)
      expected := this.EmptySettings
      executed := conf.ToString()
      Yunit.assert(executed = expected)
      conf := ""
   }

   NonEmptyIniToString() {
      DefaultSettings := "[GENERAL]`ntest=1"
      RecreateIniFile(this.ConfFile, DefaultSettings)      
      WHITESPACE_CHARS := "`t`n "
      conf := IniFile(this.ConfFile)
      expected := Trim(DefaultSettings, WHITESPACE_CHARS)
      executed := Trim(conf.ToString(), WHITESPACE_CHARS)
      Yunit.assert(executed = expected)
      conf := ""
   }

   TypeErrorIfSetObjectAsNewIniProperty() {
      this.ExpectedException := TypeError("You can not set Object as a value to ini prop. Path: GENERAL.new")
      RecreateIniFile(this.ConfFile, this.EmptySettings)  
      conf := IniFile(this.ConfFile)
      try {
         conf.GENERAL := {test: 123}
         conf.GENERAL.new := {test: 123}
      } finally {
         conf := ""
      }
   }
   TypeErrorIfSetObjectAsExistingIniProperty() {
      this.ExpectedException := TypeError("You can not set Object as a value to ini prop. Path: GENERAL.test")
      RecreateIniFile(this.ConfFile, this.EmptySettings)  
      conf := IniFile(this.ConfFile)
      try {
         conf.GENERAL := {test: 123}
         conf.GENERAL.test := {test: 123}
      } finally {
         conf := ""
      }
   }
  
   PropertyErrorIfDeleteIniSectionThatNotExist() {
      this.ExpectedException := PropertyError("Can not delete a section that does not exist. Path: NOTEXIST")
      conf := IniFile(this.ConfFile)
      try {
         conf.Delete('NOTEXIST')
      } finally {
         conf := ""
      }
   }
  
   PropertyErrorIfDeleteIniPropertyThatNotExist() {
      this.ExpectedException := PropertyError("Can not delete a property that does not exist. Path: GENERAL.no")
      conf := IniFile(this.ConfFile)
      conf.GENERAL.yes := '123'
      try {
         conf.GENERAL.Delete('no')
      } finally {
         conf := ""
      }
   }

   CreateSectionFromObject() {
      RecreateIniFile(this.ConfFile, this.EmptySettings)
      conf := IniFile(this.ConfFile)
      expected := {
         testInt: -123,
         testFloat: 123.456,
         testString: "Hello World =) `;",
      }
      conf.SOME_SECTION := expected

      Yunit.assert(conf.SOME_SECTION.testInt = expected.testInt)
      Yunit.assert(conf.SOME_SECTION.testFloat = expected.testFloat)
      Yunit.assert(conf.SOME_SECTION.testString = expected.testString)
      conf := ""
   }











   SavingWorks() {
      RecreateIniFile(this.ConfFile, this.EmptySettings)
      conf := IniFile(this.ConfFile)
      expected := {
         testInt: -123,
         testFloat: 123.456,
         testString: "Hello World =) `;",
      }
      conf.SOME_SECTION := expected
      conf.Save()

      conf := ""
      conf := IniFile(this.ConfFile)
      Yunit.assert(conf.SOME_SECTION.testInt = expected.testInt)
      Yunit.assert(conf.SOME_SECTION.testFloat = expected.testFloat)
      Yunit.assert(conf.SOME_SECTION.testString = expected.testString)
      conf := ""
   }
   
   ; LoopThruSectionsAndValues() {
   ;    RecreateIniFile(this.ConfFile, this.EmptySettings)
   ;    conf := IniFile(this.ConfFile)
   ;    expected := {
   ;       sectionB: "bb=-123`nbbb=123",
   ;       sectionA: "a=1",
   ;       sectionC: "Hello World =) `;",
   ;    }
   ;    conf.SOME_SECTION := expected
         
   ;    i := 1
   ;    For Key , Val in conf {
   ;       OutputDebug(key . '=' . Val.ToString() .  "`n")
   ;       Switch (i) {
   ;          Case 1:
   ;            Yunit.assert(Key = "sectionA")
   ;            Yunit.assert(Val.ToString() = expected.sectionA)
   ;            break
   ;          Case 2:
   ;            Yunit.assert(Key = "sectionB")
   ;            Yunit.assert(Val.ToString() = expected.sectionB)
   ;            break
   ;          Case 3:
   ;            Yunit.assert(Key = "sectionC")
   ;            Yunit.assert(Val.ToString() = expected.sectionC)
   ;            break
   ;       }
   ;       i += 1
   ;    }
   ;    ; For Key , Val in conf.GENERAL {
   ;    ; OutputDebug(key . '=' . Val .  "`n")
   ;    ; }
   ;    ; For Key , Val in conf['GENERAL'] {
   ;    ; OutputDebug(key . '=' . Val .  "`n")
   ;    ; }
    
   ;    conf := ""
   ; }


   
; ; ass := Map('GE', 123)
; ; OutputDebug(ass['GE'] . "`n")
; ; ; OutputDebug(ass['GR'] . "`n")
; ; OutputDebug(ass.GE . "`n")

; aconf := IniFile("sconfig.ini")
; aconf['ass'] := 'aaa=123'
; ; OutputDebug(aconf['D']["xxx"] . "`n")
; ; OutputDebug(aconf['D'].xxx . "`n")
; ; OutputDebug(aconf.D["xxx"] . "`n")
; ; OutputDebug(aconf.D.xxx . "`n")

; OutputDebug(aconf['GENERAL']["xxx"] . "`n")
; ; OutputDebug(aconf['GENERAL']["yyy"] . "`n")
; OutputDebug(aconf['GENERAL'].xxx . "`n")
; ; OutputDebug(aconf['GENERAL'].yyy . "`n")
; OutputDebug(aconf.GENERAL["xxx"] . "`n")
; ; OutputDebug(aconf.GENERAL["yyy"] . "`n")
; OutputDebug(aconf.GENERAL.xxx . "`n")
; ; OutputDebug(aconf.GENERAL.yyy . "`n")
; ; OutputDebug("---yyy=" . aconf.GENERAL.yyy . ".")



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

; ass := aconf['GENERAL'].Has("HotkeyInterval")

}


RecreateIniFile(Path, Content) {
   FileDelete(Path)
   FileAppend(Content, Path)
}
