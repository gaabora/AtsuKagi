class TextToSpeech extends AKPlugin { ; TODO: not yet implemented
  _textToSpeechObj := ComObject("SAPI.SpVoice")
  
  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "TextToSpeech",
        "title", "Text-to-Speech",
        "description", "Convert text to speech using Windows SAPI (Speech API) service. Experimental implementation.",
        "icon", "icons10-audio",
        "category", "Accessibility"
      ),
      "settingsPage", Map(
        "description", "Configure text-to-speech service and voice settings.",
        "icon", "icons10-audio"
      ),
      "config", [],
      "actions", [],
      "hooks", []
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    ; No plugin-specific config to apply
  }

  Speak(text) {
    this._textToSpeechObj.Speak(text)
  }



  
}




; CONFIG := {
;   DEFAULT_LOCALE: 'en-US',
;   SpeachVoices: '<voice xml:lang="ru-RU" gender="female">',
  
; }

; MsgBox(_getVoicesList())
; ; Microsoft David Desktop - English (United States)
; ; Microsoft Hazel Desktop - English (Great Britain)
; ; Microsoft Zira Desktop - English (United States)
; ; Microsoft Haruka Desktop - Japanese
; ; Microsoft Irina Desktop - Russian

; _textToWhatNameThisFunction(text, lang:='auto', voice:='auto', someAdditionalParamsIfNeeded*) {

; }

; Speak(text, lang:='auto', voice:='auto') {
;   if (lang = 'auto') {
;     mainLocale := CONFIG.DEFAULT_LOCALE
;   }
;   ssmlText := '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="' . mainLocale . '">' . _textToWhatNameThisFunction(text, lang, voice) . '</speak>'

;   voice := ComObject("SAPI.SpVoice")
;   voice.Speak(ssmlText)
; }



; Speak("time is 19:23. вреия 19:23. 時刻は19:23です")



