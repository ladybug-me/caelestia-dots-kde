# Quickshell Keyboard Shortcuts

## Applications
```ini
super + enter
    kstart -- foot
super + w
    kstart -- firefox
super + c
    kstart -- code
super + g
    kstart -- github-desktop
super + alt + e
    kstart -- nemo
```

# Workspaces
```ini
super + 1
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 1
super + 2
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 2
super + 3
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 3
super + 4
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 4
super + 5
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 5
super + 6
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 6
super + 7
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 7
super + 8
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 8
super + 9
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 9
super + 0
    qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop 10
```


## System & Session
```ini
super + shift + l
    systemctl suspend-then-hibernate
ctrl + alt + delete
    caelestia shell drawers toggle session
```
## OLD GUIs
#    caelestia clipboard    

## TO RUN ANY OTHER COMMAND PRESENT IN launcher's command menu
# map any shortcut to qs -c caelestia ipc call launcher action <command name>

## Desktop & Shell UI
```ini
super + space
    caelestia shell drawers toggle launcher
super + v
    qs -c caelestia ipc call launcher action clipboard
super + shift + v
    qs -c caelestia ipc call launcher action emoji
super + alt + v
    caelestia emoji -p
super + slash
    qs -c caelestia ipc call launcher action keybinds
super + ctrl + t
    qs -c caelestia ipc call launcher action wallpaper
```

## Screenshots & Recording
```ini
super + shift + s
    caelestia shell region screenshot
super + ctrl + s
    caelestia record -s
super + shift + a
    caelestia shell region search
super + b
    caelestia shell drawers toggle sidebar
super + shift + c
    ~/.local/bin/kcolorpicker -a
print
    caelestia shell region screenshot
```
