#pragma once
#include <string>

namespace Input {
    std::string get();
    std::string wait_key(int timeout_ms = -1);
}
