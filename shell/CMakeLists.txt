cmake_minimum_required(VERSION 3.19)

if(NOT DEFINED VERSION)
    # 1. Prefer version.env — canonical source of truth, kept in sync by CI
    set(_VERSION_ENV "${CMAKE_SOURCE_DIR}/../.github/version.env")
    if(EXISTS "${_VERSION_ENV}")
        file(STRINGS "${_VERSION_ENV}" _VER_LINE REGEX "^VERSION=")
        if(_VER_LINE)
            string(REGEX REPLACE "^VERSION=" "" VERSION "${_VER_LINE}")
        endif()
    endif()

    # 2. Fallback: git describe (nearest tag)
    if(NOT VERSION OR "${VERSION}" STREQUAL "")
        execute_process(COMMAND git describe --tags --match "v*" --abbrev=0
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE VERSION
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
    endif()

    # Last resort hardcoded
    if("${VERSION}" STREQUAL "" OR "${VERSION}" STREQUAL "rolling")
        set(VERSION "2.3.2")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    execute_process(COMMAND git rev-parse HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE GIT_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    if("${GIT_REVISION}" STREQUAL "")
        set(GIT_REVISION "unknown")
    endif()
endif()

set(DISPLAY_VERSION "${VERSION}")

# On dev branch: append -dev+<short-hash> to distinguish from stable
execute_process(COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET
)
if("${_GIT_BRANCH}" STREQUAL "dev")
    execute_process(COMMAND git rev-parse --short HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _SHORT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET
    )
    if(NOT "${_SHORT_HASH}" STREQUAL "")
        set(DISPLAY_VERSION "${VERSION}-dev+${_SHORT_HASH}")
    endif()
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")
string(REGEX REPLACE "^v" "" DISPLAY_VERSION "${DISPLAY_VERSION}")

project(caelestia-shell VERSION ${VERSION} LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Use ccache if available for dramatically faster rebuilds
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    message(STATUS "ccache found — compiler caching enabled")
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(ENABLE_MODULES "extras;plugin;shell;m3shapes" CACHE STRING "Modules to build/install")
set(INSTALL_LIBDIR "usr/lib/caelestia" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "etc/xdg/quickshell/caelestia" CACHE STRING "Quickshell config install dir")

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture)
endif()

if("extras" IN_LIST ENABLE_MODULES)
    add_subdirectory(extras)
endif()

if("plugin" IN_LIST ENABLE_MODULES)
    add_subdirectory(plugin)
endif()

if("shell" IN_LIST ENABLE_MODULES)
    foreach(dir assets components modules scripts services utils)
        install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir}
                DESTINATION ${INSTALL_QSCONFDIR})
    endforeach()

    install(PROGRAMS assets/wrap_term_launch.sh DESTINATION "${INSTALL_QSCONFDIR}/assets")

    file(READ shell.qml SHELL_QML)
    string(REPLACE "settings.watchFiles: true" "settings.watchFiles: false" SHELL_QML "${SHELL_QML}")
    file(WRITE "${CMAKE_BINARY_DIR}/qml/shell.qml" "${SHELL_QML}")
    install(FILES "${CMAKE_BINARY_DIR}/qml/shell.qml" DESTINATION "${INSTALL_QSCONFDIR}")

    install(FILES lockscreen.qml DESTINATION "${INSTALL_QSCONFDIR}")
    install(FILES LICENSE DESTINATION "${INSTALL_QSCONFDIR}")
endif()

if("m3shapes" IN_LIST ENABLE_MODULES)
    message(STATUS "Fetching M3Shapes module")
    include(FetchContent)
    set(M3SHAPES_REV bdc327b29f95394a732baf3c9b19658ba23755b6)

    # Opt-in persistent checkout. When enabled, the source is cloned into the
    # user cache so wiping the build dir doesn't force a re-clone (the
    # installer enables this). Off by default so CI/packaging/reproducible
    # builds keep sources inside the build tree via FetchContent's default
    # _deps location.
    option(CAELESTIA_CACHE_DEPS "Keep FetchContent sources outside the build tree" OFF)

    if(CAELESTIA_CACHE_DEPS)
        if(DEFINED ENV{XDG_CACHE_HOME} AND NOT "$ENV{XDG_CACHE_HOME}" STREQUAL "")
            set(_CAELESTIA_CACHE "$ENV{XDG_CACHE_HOME}/caelestia-kde")
        else()
            set(_CAELESTIA_CACHE "$ENV{HOME}/.cache/caelestia-kde")
        endif()
        set(_M3SHAPES_SOURCE_DIR "${_CAELESTIA_CACHE}/m3shapes-${M3SHAPES_REV}")
    else()
        set(_M3SHAPES_SOURCE_DIR "${CMAKE_BINARY_DIR}/_deps/m3shapes-${M3SHAPES_REV}")
    endif()

    FetchContent_Declare(
        m3shapes_external
        GIT_REPOSITORY https://github.com/soramanew/m3shapes.git
        GIT_TAG        ${M3SHAPES_REV}
        SOURCE_DIR     "${_M3SHAPES_SOURCE_DIR}"
    )
    FetchContent_MakeAvailable(m3shapes_external)
    message(STATUS "Done fetching M3Shapes module")

    # Fix m3shapes wrong rpath
    if(TARGET m3shapesplugin)
        set_target_properties(m3shapesplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
    endif()
endif()
