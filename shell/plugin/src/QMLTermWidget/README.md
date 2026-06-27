# QMLTermWidget

This project is a QML port of qtermwidget. I'm trying to keep it close to the upstream project. The main branch as been migrated to Qt6, please check the qt5 branch for the latest qt5 version.

At the moment this plugin is powering cool-retro-term and some other QML terminal emulators.

## Building

`qmake && make`, then try the included minimal terminal application `qml -I . test-app/test-app.qml`.

## Licensing

The project is released under GPL-2.0-or-later. Some files are under compatible licenses inherited from upstream QTermWidget; see `LICENSE` and file headers for details.
