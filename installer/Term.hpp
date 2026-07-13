#pragma once
#include <termios.h>

namespace Term {
    extern termios initial_settings;
    extern bool initialized;

    void get_size();
    void restore();
    void init();
}
