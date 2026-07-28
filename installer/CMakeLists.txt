cmake_minimum_required(VERSION 3.10)
project(CaelestiaInstaller CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Use ccache if available for dramatically faster rebuilds
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    message(STATUS "ccache found — compiler caching enabled")
endif()

# Set compile flags
set(CMAKE_CXX_FLAGS_RELEASE "-O2")

# Find all source files
file(GLOB SOURCES "src/*.cpp")
include_directories(src)

# Define executable
add_executable(caelestia-install ${SOURCES})
