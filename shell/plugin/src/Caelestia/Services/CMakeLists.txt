find_package(KF6GlobalAccel REQUIRED)
find_package(X11 REQUIRED)
qml_module(caelestia-services
    URI Caelestia.Services
    SOURCES
        service.cpp
        serviceref.cpp
        beattracker.cpp
        audiocollector.cpp
        audioprovider.cpp
        cavaprovider.cpp
        tickingservice.cpp
        sensorslib.cpp
        usagefmt.cpp
        cpu.cpp
        gpu.cpp
        memory.cpp
        diskinfo.cpp
        storage.cpp
        lyriccandidate.cpp
        lyrics.cpp
        sessionmanager.cpp
        sessionmanager.hpp
        discordipc.cpp
        discordipc.hpp
        hyprlandstate.cpp
        hyprlandstate.hpp
        keybindsmodel.cpp
        keybindsmodel.hpp
        emojidb.cpp
        emojidb.hpp
        brightnesswatcher.cpp
        brightnesswatcher.hpp
        clipboardmanager.cpp
        clipboardmanager.hpp
        schemeloader.cpp
        schemeloader.hpp
        palettemanager.cpp
        palettemanager.hpp
        dinogame.cpp
        dinogame.hpp
        kwinworkspacestate.cpp
        kwinworkspacestate.hpp
        kwinactivewindowbridge.cpp
        windowicon.cpp
        kwinactivewindowbridge.hpp
        nightcolorbridge.cpp
        nightcolorbridge.hpp
        globalshortcut.cpp
        globalshortcut.hpp
        krohnkiteconfig.cpp
        krohnkiteconfig.hpp
        windowscreencast.cpp
        windowscreencast.hpp
        windowicon.hpp
    LIBRARIES
        Qt::DBus
        Qt::Gui
        Qt::WaylandClient
        KF6::GlobalAccel
        X11::X11
        PkgConfig::Pipewire
        PkgConfig::Aubio
        PkgConfig::Cava
        Sensors::Sensors
        caelestia-core
        caelestia-config
        caelestia-internal
)



qt6_generate_wayland_protocol_client_sources(caelestia-services FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/../protocols/zkde-screencast-unstable-v1.xml
)
set_source_files_properties(
    ${CMAKE_CURRENT_BINARY_DIR}/wayland-zkde-screencast-unstable-v1-protocol.c
    PROPERTIES SKIP_PRECOMPILE_HEADERS ON
)
