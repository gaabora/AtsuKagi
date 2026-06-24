#Requires AutoHotKey v2.0

ReadRepoFile(relativePath) {
   return FileRead(A_ScriptDir "\..\" relativePath)
}

AssertSourceContains(source, needle, message) {
   Yunit.assert(InStr(source, needle) > 0, message)
}

AssertSourceMatches(source, pattern, message) {
   Yunit.assert(RegExMatch(source, pattern), message)
}

AssertSourceContainsAll(source, needles, messagePrefix) {
   for needle in needles {
      AssertSourceContains(source, needle, messagePrefix ": " needle)
   }
}

AssertPluginSourceContract(pluginName, expectedActions, expectedConfigKeys) {
   source := ReadRepoFile("plugins\" pluginName ".ahk")
   AssertSourceMatches(source, "m)^class\s+" pluginName "\s+extends\s+AKPlugin\b", pluginName " class must extend AKPlugin")
   AssertSourceContains(source, "__DescribePlugin()", pluginName " must describe itself")
   AssertSourceContains(source, '"id", "' pluginName '"', pluginName " descriptor id must match filename/class")
   for actionName in expectedActions {
      AssertSourceContains(source, '"action", "' actionName '"', pluginName " descriptor must declare action " actionName)
      AssertSourceMatches(source, "m)^\s*" actionName "\([^`r`n{]*\)\s*\{", pluginName " must implement action " actionName)
   }
   for keyName in expectedConfigKeys {
      AssertSourceContains(source, '"key", "' keyName '"', pluginName " descriptor must declare config key " keyName)
   }
}
