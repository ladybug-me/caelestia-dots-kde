cmake_minimum_required(VERSION 3.10)
project(CaelestiaInstaller CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Set compile flags
set(CMAKE_CXX_FLAGS_RELEASE "-O2")

# Find all source files
file(GLOB SOURCES "src/*.cpp")
include_directories(src)

# Define executable
add_executable(caelestia-install ${SOURCES})

# Link libraries
target_link_libraries(caelestia-install util)
