A minimal quickshell launcher that was fully vibe coded. 

It is a minimal shell(To an extent), that has the following options:

- App launcher
- Wallpaper selector
- Power Menu
- Notification Center
- Clipboard (This is actually a full lightweight clipboard fully written in QML, not based on cliphist)
- Screenshot and screenrecord utility
- Lockscreen (Still being worked on, also will be integrated with greetd)

Install quickshell

Clone Repo, move folder to the ./config/quickshell folder.

In terminal run, qs -c super-shell

IPC calls:

- qs -c super-shell ipc call launcher toggle
- qs -c super-shell ipc call wallpaper toggle
- qs -c super-shell ipc call clipboard toggle
- qs -c super-shell ipc call power toggle
- qs -c super-shell ipc call notif toggle
- qs -c super-shell ipc call screenshot toggle
- qs -c super-shell ipc call screenshot settings toggle
- qs -c super-shell ipc call lock lock


For more information about the available IPC calls and different options, run the below command in a terminal:

- qs -c super-shell ipc call help display
