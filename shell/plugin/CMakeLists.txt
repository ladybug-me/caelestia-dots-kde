cmake_minimum_required(VERSION 3.16)
project(Caelestia)

# Unity builds compile many small translation units together, which speeds up
# cold builds of the plugin. Opt-in: the installer enables it, while CI and
# packaging keep per-TU builds for cache friendliness.
option(CAELESTIA_UNITY_BUILD "Compile plugin sources as CMake unity builds" OFF)
if(CAELESTIA_UNITY_BUILD)
    set(CMAKE_UNITY_BUILD ON)
    set(CMAKE_UNITY_BUILD_BATCH_SIZE 16)
endif()

find_package(Qt6 REQUIRED COMPONENTS ShaderTools Core Qml Gui Quick QuickControls2 Concurrent Sql Network DBus WaylandClient)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6GuiAddons REQUIRED)
find_package(KF6NetworkManagerQt REQUIRED)
find_package(KF6PulseAudioQt REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Qalculate IMPORTED_TARGET libqalculate REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava QUIET)
endif()
if(NOT Cava_FOUND)
    # Arch's cava package doesn't ship a .pc file -- find the library
    # and header directly as a fallback.
    find_library(Cava_LIBRARY NAMES cava libcava)
    find_path(Cava_INCLUDE_DIR NAMES cava/cavacore.h)
    if(Cava_LIBRARY AND Cava_INCLUDE_DIR)
        add_library(PkgConfig::Cava UNKNOWN IMPORTED)
        set_target_properties(PkgConfig::Cava PROPERTIES
            IMPORTED_LOCATION "${Cava_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${Cava_INCLUDE_DIR}"
        )
        set(Cava_FOUND TRUE)
        message(STATUS "Found cava (via find_library): ${Cava_LIBRARY}")
    endif()
endif()
include(cmake/sensorslib.cmake)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)

# Header only helpers
add_library(caelestia-util INTERFACE)
target_include_directories(caelestia-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(src/Caelestia)
