based on code from:
AtsuiKagi ()

features:


TODO:
1. KeyboardHookStealerApps=mstsc.exe ? WinWaitActive 
4. adjustable timer for repeatable action
5|0800|1900=SendKey(Shift)
15|0800|1900=SpeakCurrentTime(hm)
5. toglable timer action?
6. exclusions list per action or maybe group? like RestrictWindowResize / move / minimize / maximize / frame / ... ?

- ShellMessageHook plugin
- c# wrapper to launch script without need to compile
- add per-device hotkeys https://github.com/evilC/AutoHotInterception
- config support/injection for AKPlugins
. exclusion app format, maybe like this? - WindowClass@appname.exe,@another.exe,SomeClassName
- GUI table with human readabkle-keys
off|hotkey|action|exclusions|showInMenu(+menuType:action/launch//toggleTimer/selectWindow?)
- json config?
- v2 port?

- take some ideas from https://www.highrez.co.uk/downloads/xmousebuttoncontrol.htm

*Credits*
Thanks to people for sharing the code.
sorry if someone's name is missing, feel free to add it here for example

BTT tooltips by telppa https://github.com/telppa/BeautifulToolTip
Ini class by anonymous1184 https://github.com/anonymous1184/bitwarden-autotype
KDE Mover-Sizer v2.9 2014-09-10 by various authors http://corz.org/windows/software/accessories/KDE-resizing-moving-for-Windows.php
RDP-Key v1.0 by gildorwang https://github.com/gildorwang/RDP-Key/tree/master"
VirtualDesktopAccessor by Ciantic https://github.com/Ciantic/VirtualDesktopAccessor/releases



post fix here
https://superuser.com/questions/1046767/windows-10-switch-virtual-deskop-while-in-fullscreen-remote-desktop