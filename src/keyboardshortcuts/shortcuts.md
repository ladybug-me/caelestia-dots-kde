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

## Desktop & Shell UI
```ini
super + space
    caelestia shell drawers toggle launcher
super + v
    caelestia clipboard
super + shift + v
    caelestia emoji -p
super + slash
    caelestia shell shortcuts open
```

## Screenshots & Recording
```ini
super + shift + s
    caelestia shell drawers toggle screenshot
super + ctrl + s
    caelestia record -s
super + shift + a
    caelestia shell region search
super + b
    caelestia shell drawers toggle sidebar
super + shift + c
    ~/.local/bin/kcolorpicker -a
print
    caelestia shell drawers toggle screenshot
```
