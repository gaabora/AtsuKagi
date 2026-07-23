#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk
#Include ..\lib\helpers.ahk
#Include ..\lib\Notify.ahk
#Include ..\includes\AKBase.ahk
#Include ..\includes\AKPlugin.ahk
#Include ..\includes\WindowsConstants.ahk
#Include ..\plugins\TextLocaleManager.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(TextLocaleManagerTests)
else
   Yunit.Use(YunitWindow).Test(TextLocaleManagerTests)


class TextLocaleManagerTestApp {
   Config := Map()

   IsInBlocklist(*) {
      return false
   }
}

CreateTextLocaleLayout(klid, name, value, hkl) {
   return {alias: "0x" klid, klid: klid, name: name, value: value, hkl: hkl}
}

CreateStandardTextLocaleLayouts() {
   return [
      CreateTextLocaleLayout("00000409", "ENG", 0x0409, 0x04090409),
      CreateTextLocaleLayout("00000419", "RUS", 0x0419, 0x04190419)
   ]
}

class TextLocaleManagerTestPlugin extends TextLocaleManager {
   _getUsersKeyboardLayouts() {
      return CreateStandardTextLocaleLayouts()
   }

   _getKeyboardLayoutTargetHwnd() {
      return 100
   }

   _requestKeyboardLayout(layoutHkl, requestFlags, targetHwnd) {
   }

   ShowCurrentKeyboardLayout() {
   }
}

class TextLocaleManagerSpy extends TextLocaleManagerTestPlugin {
   SelectedText := ''
   PastedText := ''
   RequestedLayoutHkl := -1
   RequestedFlags := -1
   RequestedTargetHwnd := 0

   _getSelectedText() {
      return this.SelectedText
   }

   _putText(text) {
      this.PastedText := text
   }

   _requestKeyboardLayout(layoutHkl, requestFlags, targetHwnd) {
      this.RequestedLayoutHkl := layoutHkl
      this.RequestedFlags := requestFlags
      this.RequestedTargetHwnd := targetHwnd
   }
}

class TextLocaleManagerEnumerationTestPlugin extends TextLocaleManager {
   ActiveLayoutHandles := []
   ConfiguredLayoutKlids := []

   _getActiveKeyboardLayoutHandles() {
      return this.ActiveLayoutHandles
   }

   _getConfiguredKeyboardLayoutKlids() {
      return this.ConfiguredLayoutKlids
   }
}

class TextLocaleManagerTests {
   T01_PluginDescriptorContract() {
      global Yunit
      AssertPluginSourceContract("TextLocaleManager", [
         "ShowCurrentKeyboardLayout",
         "ShowUsersKeyboardLayouts",
         "GetCurrentKeyboardLayoutName",
         "SwitchKeyboardLayout",
         "SwapTextLayout",
         "SwitchSelectedTextLayout",
         "SwitchSelectedTextCase"
      ], [])
   }

   T02_SwapTextLayoutConvertsMixedEnRuText() {
      global Yunit
      plugin := this._newPlugin()
      converted := plugin.SwapTextLayout("ghbdtn! руддщ", "EN", "RU")
      Yunit.assert(converted.newText = "привет! hello", "mixed EN/RU text should convert each run")
      Yunit.assert(converted.newLayout = "EN", "final layout should match the last converted run")
   }

   T02b_SwapTextLayoutUsesFirstIdentifyingCharacter() {
      global Yunit
      plugin := this._newPlugin()
      converted := plugin.SwapTextLayout("..Q", "EN", "RU")
      Yunit.assert(converted.newText = "ююЙ", "first strong EN character should choose RU output")
      Yunit.assert(converted.newLayout = "RU", "target layout should come from first strong identifying character")
   }
   T03_ImplicitLineCopyGuardSkipsCodeLineCopy() {
      global Yunit
      plugin := this._newPlugin()
      Yunit.assert(plugin._isLikelyImplicitLineCopy("ghbdtn! руддщ`r`n", "Code.exe"), "VS Code line-copy clipboard should be treated as no selection")
      Yunit.assert(plugin._isLikelyImplicitLineCopy("ghbdt|n! руддщ`r`n", "Code.exe"), "VS Code cursor-line copy should be treated as no selection")
      Yunit.assert(!plugin._isLikelyImplicitLineCopy("ghbdtn! руддщ", "Code.exe"), "single-line selected text should still be allowed")
      Yunit.assert(!plugin._isLikelyImplicitLineCopy("first`r`nsecond`r`n", "Code.exe"), "multi-line selected text should still be allowed")
      Yunit.assert(!plugin._isLikelyImplicitLineCopy("ghbdtn! руддщ`r`n", "notepad.exe"), "line endings alone should not block other apps")
   }

   T04_SupportedPairsComeFromInstalledLayouts() {
      global Yunit
      plugin := this._newPlugin()
      plugin._refreshSupportedLayoutPairs()
      pair := plugin._getTextLayoutPair()
      Yunit.assert(plugin.SUPPORTED_USER_LAYOUTS.Has("EN"), "ENG should be supported as EN")
      Yunit.assert(plugin.SUPPORTED_USER_LAYOUTS.Has("RU"), "RUS should be supported as RU")
      Yunit.assert(plugin.SUPPORTED_LAYOUT_PAIRS.Length = 1, "EN/RU installed layouts should create one supported pair")
      Yunit.assert(pair.layoutA = "EN" && pair.layoutB = "RU", "auto pair should use canonical EN/RU names")
      Yunit.assert(pair.installedLayoutA.hkl = 0x04090409 && pair.installedLayoutB.hkl = 0x04190419, "pair should preserve exact installed HKLs")
      explicitPair := plugin._getTextLayoutPair("RUS", "ENG")
      Yunit.assert(explicitPair.layoutA = "RU" && explicitPair.layoutB = "EN", "explicit compatible aliases should preserve requested order")
   }

   T05_ExplicitPairRequiresInstalledSupportedLayouts() {
      global Yunit
      plugin := this._newPlugin()
      plugin.USER_KEYBOARD_LAYOUTS := []
      plugin._refreshSupportedLayoutPairs()
      pair := plugin._getTextLayoutPair("ENG", "RUS")
      Yunit.assert(!pair, "explicit aliases should not bypass installed-layout checks")
   }

   T06_NoSupportedPairSkipsSelectedTextSwitch() {
      global Yunit
      plugin := this._newSpyPlugin()
      plugin.SelectedText := "ghbdtn"
      plugin.SUPPORTED_LAYOUT_PAIRS := []
      plugin.SwitchSelectedTextLayout()
      Yunit.assert(plugin.PastedText = "", "no supported pair should not paste")
      Yunit.assert(plugin.RequestedLayoutHkl = -1, "no supported pair should not switch layout")
   }

   T07_AmbiguousTextIsSkipped() {
      global Yunit
      plugin := this._newPlugin()
      converted := plugin.SwapTextLayout("123 !!!", "EN", "RU")
      Yunit.assert(converted.newText = "123 !!!", "ambiguous text should stay unchanged")
      Yunit.assert(converted.newLayout = "", "ambiguous text should not choose a target layout")
   }

   T08_AutoPairConvertsSelectedTextAndSwitchesToFinalLayout() {
      global Yunit
      plugin := this._newSpyPlugin()
      plugin.SelectedText := "ghbdtn"
      plugin.SwitchSelectedTextLayout()
      Yunit.assert(plugin.PastedText = "привет", "auto pair should convert selected text")
      Yunit.assert(plugin.RequestedLayoutHkl = 0x04190419, "layout switch should use the exact installed Russian HKL")
      Yunit.assert(plugin.RequestedFlags = KeyboardInputFlags.INPUTLANGCHANGE_SYSCHARSET, "named layout switch should use the charset request flag")
   }

   T09_LayoutVariantsAreNotSupportedByStandardMap() {
      global Yunit
      plugin := this._newPlugin()
      plugin.USER_KEYBOARD_LAYOUTS := [
         CreateTextLocaleLayout("00010409", "ENG", 0x00010409, 0xF0020409),
         CreateTextLocaleLayout("00000419", "RUS", 0x0419, 0x04190419)
      ]
      plugin._refreshSupportedLayoutPairs()
      Yunit.assert(plugin.SUPPORTED_LAYOUT_PAIRS.Length = 0, "US Dvorak should not use the standard EN/RU map")
      plugin.USER_KEYBOARD_LAYOUTS := [
         CreateTextLocaleLayout("00000409", "ENG", 0x0409, 0x04090409),
         CreateTextLocaleLayout("00020419", "RUS", 0x00020419, 0xF0030419)
      ]
      plugin._refreshSupportedLayoutPairs()
      Yunit.assert(plugin.SUPPORTED_LAYOUT_PAIRS.Length = 0, "Russian Mnemonic should not use the standard EN/RU map")
   }

   T10_MissingTargetLayoutDoesNotPaste() {
      global Yunit
      plugin := this._newSpyPlugin()
      plugin.USER_KEYBOARD_LAYOUTS := [CreateTextLocaleLayout("00000409", "ENG", 0x0409, 0x04090409)]
      plugin._refreshSupportedLayoutPairs()
      plugin.SelectedText := "ghbdtn"
      plugin.SwitchSelectedTextLayout("EN", "RU")
      Yunit.assert(plugin.PastedText = "", "missing target layout should not paste")
      Yunit.assert(plugin.RequestedLayoutHkl = -1, "missing target layout should not request a switch")
   }

   T11_NextLayoutUsesForwardRequest() {
      global Yunit
      plugin := this._newSpyPlugin()
      plugin.SwitchKeyboardLayout()
      Yunit.assert(plugin.RequestedLayoutHkl = 0, "next layout should not provide a named HKL")
      Yunit.assert(plugin.RequestedFlags = KeyboardInputFlags.INPUTLANGCHANGE_FORWARD, "next layout should use the forward request flag")
   }

   T12_NamedLayoutUsesExactInstalledHkl() {
      global Yunit
      plugin := this._newSpyPlugin()
      plugin.SwitchKeyboardLayout("RU")
      Yunit.assert(plugin.RequestedLayoutHkl = 0x04190419, "named layout should use its exact installed HKL")
      Yunit.assert(plugin.RequestedFlags = KeyboardInputFlags.INPUTLANGCHANGE_SYSCHARSET, "named layout should use the charset request flag")
   }

   T13_DetectionUsesClearCharactersFromEveryMappingGroup() {
      global Yunit
      plugin := this._newPlugin()
      converted := plugin.SwapTextLayout("жбю", "EN", "RU")
      Yunit.assert(converted.newText = ";,.", "clear Russian characters outside group 1 should convert")
      Yunit.assert(converted.newLayout = "EN", "converted Russian text should return EN as final layout")
   }

   T14_AmbiguousSameLanguageHandlesAreNotGuessed() {
      global Yunit
      global TextLocaleManagerEnumerationTestPlugin, TextLocaleManagerTestApp
      plugin := TextLocaleManagerEnumerationTestPlugin(TextLocaleManagerTestApp())
      plugin.ActiveLayoutHandles := [0x04090409, 0xF0020409, 0x04190419]
      plugin.ConfiguredLayoutKlids := ["00000409", "00010409", "00000419"]
      layouts := plugin._getUsersKeyboardLayouts()
      layoutsByKlid := Map()
      for layoutData in layouts
         layoutsByKlid[layoutData.klid] := layoutData
      Yunit.assert(layoutsByKlid["00000409"].hkl = 0, "standard US HKL should stay unresolved when another US layout is active")
      Yunit.assert(layoutsByKlid["00010409"].hkl = 0, "US Dvorak HKL should stay unresolved when matching is ambiguous")
      Yunit.assert(layoutsByKlid["00000419"].hkl = 0x04190419, "unique Russian layout should keep its exact active HKL")
   }

   T15_DefaultBindingUsesAutomaticPairSelection() {
      global Yunit
      defaultConfigSource := ReadRepoFile("includes\defaultConfig.ahk")
      pluginSource := ReadRepoFile("plugins\TextLocaleManager.ahk")
      Yunit.assert(InStr(defaultConfigSource, 'config["^CapsLock"]    := "SwitchSelectedTextLayout()"'), "default binding should use automatic pair selection")
      Yunit.assert(InStr(pluginSource, 'Map("name", "layoutA", "default", "")'), "layoutA descriptor parameter should be optional")
      Yunit.assert(InStr(pluginSource, 'Map("name", "layoutB", "default", "")'), "layoutB descriptor parameter should be optional")
   }

   T16_SingleExplicitLayoutIsRejected() {
      this.ExpectedException := ValueError("Both text layout names are required")
      plugin := this._newPlugin()
      plugin._getTextLayoutPair("EN", "")
   }

   _newPlugin() {
      global TextLocaleManagerTestPlugin, TextLocaleManagerTestApp
      plugin := TextLocaleManagerTestPlugin(TextLocaleManagerTestApp())
      plugin._init()
      return plugin
   }

   _newSpyPlugin() {
      global TextLocaleManagerSpy, TextLocaleManagerTestApp
      plugin := TextLocaleManagerSpy(TextLocaleManagerTestApp())
      plugin._init()
      return plugin
   }
}
