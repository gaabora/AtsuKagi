inspired by:


AtsuiKagi ()

features:

from ike:
^!vkDD::RotateScreen("cw",0,1)  ; Alt+Shift+]
^!vkDB::RotateScreen("ccw",0,1) ; Alt+Shift+[
#Esc::TurnOffScreen(0,1)

Pause::SwitchTextLocale()
^CapsLock::SwitchTextLocale()

CapsLock Up::SwitchLocale()

*~^Shift::
*~!Shift::
*~+Control::
*~+Alt::
	ShowLayout()
return



TODO:
write readme on wtf is this app

StartFakeScreensaver(hotkeyToExit:=Escape,hotkeyToKeepAwake:=Shift,sendHotkeyIntervalSec=10) create black fullscreen windows on top unfocused and send shift 

DisgracePopupWindow() to make some annoying window not on top and remove other forced attributes?

UIA UI automation? https://github.com/Descolada/UIA-v2/tree/main/Examples
OSD

1. KeyboardHookStealerApps=mstsc.exe ? WinWaitActive 
4. adjustable timer for repeatable action
5|0800|1900=SendKey(Shift)
15|0800|1900=SpeakCurrentTime(hm)
5. toglable timer action?
6. exclusions list per action or maybe group? like RestrictWindowResize / move / minimize / maximize / frame / ... ?


plugins ideas:
universal monitor brightness control https://github.com/xanderfrangos/twinkle-tray
universal battery charging limits control https://github.com/XYUU/BatteryUtils/blob/master/BatteryUtils/FormMain.cs
improve kde mover-sizer https://github.com/RamonUnch/AltSnap
screen corners actions https://github.com/vhanla/winxcorners

- ShellMessageHook plugin
- c# wrapper to launch script without need to compile
- add per-device hotkeys https://github.com/evilC/AutoHotInterception
- config support/injection for AKPlugins
. exclusion app format, maybe like this? - WindowClass@appname.exe,@another.exe,SomeClassName
- GUI table with human readabkle-keys
off|hotkey|action|exclusions|showInMenu(+menuType:action/launch//toggleTimer/selectWindow?)
- json config?
- v2 port

- take some ideas from https://www.highrez.co.uk/downloads/xmousebuttoncontrol.htm

*Credits*
Thanks to people for sharing the code.
sorry if someone's name is missing, feel free to add it here for example

Ini class by anonymous1184 https://github.com/anonymous1184/bitwarden-autotype
KDE Mover-Sizer v2.9 2014-09-10 by various authors http://corz.org/windows/software/accessories/KDE-resizing-moving-for-Windows.php
Notify_Class by XMCQCX https://github.com/XMCQCX/Notify_Class
RDP-Key v1.0 by gildorwang https://github.com/gildorwang/RDP-Key/tree/master"
VirtualDesktopAccessor by Ciantic https://github.com/Ciantic/VirtualDesktopAccessor/releases




post fix here
https://superuser.com/questions/1046767/windows-10-switch-virtual-deskop-while-in-fullscreen-remote-desktop
https://www.reddit.com/r/AutoHotkey/comments/1ag8wd8/autohotkey_v2_need_script_to_change_keyboard/



# 🚀 AtsuKagi

 Windows 

## 🎥  Demo

See AtsuKagi in action:

[![Demo of AtsuKagi on YouTube](https://img.youtube.com/vi/aaaaa/0.jpg)](https://www.youtube.com/shorts/aaaaa)

## ✨ Features

- 🖱️ Easily accessible menu via mouse Right Click and hold 500 milliseconds
- 🌐 Integrated web search capabilities
- 🤖 AI-powered text enhancement with ChatGPT integration
- 📊 Multi-source news aggregation
- 🛒 Cross-platform shopping comparison
- 📁 Bulk file and folder operations
- 💬 Desktop WhatsApp integration
- ⌨️ Customizable hotkeys for quick actions

replacement for https://github.com/Codeusa/Borderless-Gaming
## 🛠️ Development

1. Ensure you have [AutoHotkey v2.0+](https://www.autohotkey.com/) installed on your system.
2. Clone this repository
   ```
   git clone https://github.com/gaabora/AtsuKagi.git
   ```
3. Double-click the `.ahk` file to run the script.

## 🎯 Usage

1. **Activate the Menu**: Mouse Right Click Press and hold for 500 millisecond  
2. **Use Features**: Select text (if required) and choose an option from the menu
3. **Quick Actions**: Utilize hotkeys for instant actions without opening the menu

## 🗝️ Key Functions

### 🤖 AI Writing Assistant (ChatGPT Integration)
Transform your writing with AI-powered features:
- ✍️ Automated grammar and spelling correction
- 💎 Text enhancement and style improvement
- 📚 Summarization and explanation of complex topics
- 🎭 Tone adjustment and content expansion

### 📝 Text Manipulation
- 🔠 **Format Text**: Convert case (Alt+L/U/T) and clean formatting (Alt+S)
- 🔣 **Wrap Text**: Quickly enclose text in various brackets or quotes


- 🔍 Instant searches on Google (Alt+G), YouTube (Alt+Y), and Google Maps (Alt+M)
- ⚡ Works with or without text selection



### 📂 File Management
- 📁 Bulk file and folder creation
- 📄 Quick file content copying without opening

### 💬 Notification

## 👥 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

💡 **Pro Tip**: Combine hotkeys for ultra-fast text manipulation. For example, `Alt+U` followed by `Alt+'` to get "UPPERCASE QUOTED TEXT"!

Ready to supercharge your productivity? Let's go! 🚀

## 📄 License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.



install extension
zero-plusplus.vscode-autohotkey-debug
F5 to run