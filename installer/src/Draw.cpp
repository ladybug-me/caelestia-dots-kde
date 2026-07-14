#include "Draw.hpp"
#include "Globals.hpp"
#include <iostream>
#include <thread>
#include <chrono>

using namespace std;

namespace Draw {
    const string esc = "\x1b[";
    const string reset = esc + "0m";
    const string bold = esc + "1m";
    const string dim = esc + "2m";
    
    // Colors
    string color(const string& name) {
        if (!g_theme.is_null() && g_theme.contains("colors") && g_theme["colors"].contains(name)) {
            return esc + g_theme["colors"][name].get<string>();
        }
        return esc + "37m"; // fallback white
    }
    
    // Box chars
    const string h_line = "-";
    const string v_line = "|";
    const string corner = "+";

    string to(int line, int col) {
        return esc + to_string(line) + ";" + to_string(col) + "H";
    }

    string clear() {
        return esc + "2J" + to(1, 1);
    }

    string sync_start() { return esc + "?2026h"; }
    string sync_end()   { return esc + "?2026l"; }

    void box(int x, int y, int w, int h, const string& title, const string& border_color, const string& title_color) {
        if (w < 2 || h < 2) return;
        string c = color(border_color);
        string tc = title_color.empty() ? reset : color(title_color);
        string out = c;
        
        string h_str(w - 2, '-');
        out += to(y, x) + corner + h_str + corner;
        out += to(y + h - 1, x) + corner + h_str + corner;
        
        for (int i = 1; i < h - 1; i++) {
            out += to(y + i, x) + v_line;
            out += to(y + i, x + w - 1) + v_line;
        }

        if (!title.empty()) {
            int pad = (w - title.length()) / 2;
            if (pad > 0) {
                out += to(y, x + pad) + bold + reset + c + "[" + reset + bold + tc + title + reset + c + "]" + reset;
            }
        }
        cout << out << reset;
    }

    void animated_box(int x, int y, int w, int h, const string& title, const string& border_color, const string& title_color) {
        if (w < 2 || h < 2) return;
        string c = color(border_color);
        string tc = title_color.empty() ? reset : color(title_color);
        
        // Disable sync for animation
        cout << sync_end() << c;
        
        // Draw top line left to right
        cout << to(y, x) << corner << flush;
        this_thread::sleep_for(chrono::milliseconds(5));
        for (int i = 1; i < w - 1; i++) {
            cout << to(y, x + i) << h_line << flush;
            this_thread::sleep_for(chrono::milliseconds(5));
        }
        cout << to(y, x + w - 1) << corner << flush;
        
        // Draw sides top to bottom simultaneously
        for (int i = 1; i < h - 1; i++) {
            cout << to(y + i, x) << v_line << flush;
            cout << to(y + i, x + w - 1) << v_line << flush;
            this_thread::sleep_for(chrono::milliseconds(10));
        }
        
        // Draw bottom line right to left
        cout << to(y + h - 1, x + w - 1) << corner << flush;
        this_thread::sleep_for(chrono::milliseconds(5));
        for (int i = w - 2; i > 0; i--) {
            cout << to(y + h - 1, x + i) << h_line << flush;
            this_thread::sleep_for(chrono::milliseconds(5));
        }
        cout << to(y + h - 1, x) << corner << flush;

        if (!title.empty()) {
            int pad = (w - title.length()) / 2;
            if (pad > 0) {
                cout << to(y, x + pad) << bold << reset << c << "[" << reset << bold << title << reset << c << "]" << reset << flush;
            }
        }
        
        cout << reset << sync_start();
        this_thread::sleep_for(chrono::milliseconds(30));
    }

    void text(int x, int y, const string& txt, const string& color_name) {
        string c = color_name.empty() ? "" : color(color_name);
        cout << to(y, x) << c << txt << reset << flush;
    }
}
