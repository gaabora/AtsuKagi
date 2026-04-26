class TextToSpeech extends AKPlugin { ; TODO: not yet implemented
  _textToSpeechObj := ComObject("SAPI.SpVoice")
  Speak(text) {
    this._textToSpeechObj.Speak(text)
  }


  __ConfigHelp() {
    return "No config keys. Uses Windows SAPI (Speech API) TTS service if available. Status: experimental, disabled by default."
  }

  __UsageHelp() {
    return "Text-to-speech placeholder. Currently stub implementation using Windows SAPI. Not implemented for hotkey actions. Status: experimental/disabled."
  }

  __ActionsHelp() {
    texts := Map()
    return texts
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



