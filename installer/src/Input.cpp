#include "Input.hpp"
#include "Term.hpp"
#include "Globals.hpp"
#include <unistd.h>
#include <sys/select.h>
#include <unordered_map>

using namespace std;

namespace Input {
    unordered_map<string, string> Key_escapes = {
        {"\x1b", "escape"}, {"\n", "enter"}, {"\r", "enter"},
        {"\x1b[A", "KEY_up"}, {"\x1b[B", "KEY_down"}, {"\x1b[C", "KEY_right"}, {"\x1b[D", "KEY_left"},
        {"\x1b[Z", "KEY_shift_tab"}
    };

    string get() {
        char buf[256];
        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
        if (n <= 0) return "";
        string key(buf, n);
        
        if (key.length() == 1 && key[0] == 3) { // Ctrl+C
            Term::restore();
            exit(130);
        }
        
        if (Key_escapes.count(key)) return Key_escapes[key];
        return key;
    }

    string wait_key(int timeout_ms) {
        while (!g_quit) {
            fd_set fds;
            FD_ZERO(&fds);
            FD_SET(STDIN_FILENO, &fds);
            timeval tv;
            timeval* ptv = nullptr;
            if (timeout_ms >= 0) {
                tv.tv_sec = timeout_ms / 1000;
                tv.tv_usec = (timeout_ms % 1000) * 1000;
                ptv = &tv;
            }
            int res = select(STDIN_FILENO + 1, &fds, nullptr, nullptr, ptv);
            if (res > 0) {
                return get();
            } else if (res == 0) {
                return ""; // timeout
            } else {
                if (errno == EINTR && g_resized) return "resize";
            }
        }
        return "";
    }
}
