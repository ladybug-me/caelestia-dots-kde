#pragma once
#include <string>

namespace Draw {
    extern const std::string esc;
    extern const std::string reset;
    extern const std::string bold;
    extern const std::string dim;
    
    // Colors
    std::string color(const std::string& name);
    
    // Box chars
    extern const std::string h_line;
    extern const std::string v_line;
    extern const std::string corner;

    std::string to(int line, int col);
    std::string clear();
    std::string sync_start();
    std::string sync_end();

    void box(int x, int y, int w, int h, const std::string& title = "", const std::string& border_color = "cyan", const std::string& title_color = "");
    void animated_box(int x, int y, int w, int h, const std::string& title = "", const std::string& border_color = "cyan", const std::string& title_color = "");
    void text(int x, int y, const std::string& txt, const std::string& color_name = "");
}
