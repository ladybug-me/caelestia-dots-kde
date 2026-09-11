#pragma once
#include <string>

namespace Draw {
    extern const std::string reset;
    extern const std::string bold;
    extern const std::string dim;

    // Colors: resolves a palette name from theme.json (hex -> 24-bit ANSI)
    // or a legacy ANSI suffix. Supports "bold_<name>" prefixes.
    std::string color(const std::string& name);

    std::string to(int line, int col);
    std::string clear();
    std::string sync_start();
    std::string sync_end();

    // Theme status markers (plain text, e.g. [OK], [WARN], [SKIP]):
    // pending, running, ok, warn, failed, skipped, checkbox_on,
    // checkbox_off, select_left, select_right.
    std::string glyph(const std::string& name);

    // Status -> glyph / color name. Status is one of PENDING, RUNNING, OK,
    // WARN, FAILED, SKIPPED.
    std::string status_glyph(const std::string& status);
    std::string status_color(const std::string& status);

    // Utility: repeat a string n times, truncate with "...", and strip
    // ANSI sequences from log output.
    std::string repeat(const std::string& s, int n);
    std::string fit(const std::string& text, size_t max_len);
    std::string strip_ansi(const std::string& text);

    void box(int x, int y, int w, int h, const std::string& title = "", const std::string& border_color = "container", const std::string& title_color = "");
    void text(int x, int y, const std::string& txt, const std::string& color_name = "");
    void text_center(int y, const std::string& txt, const std::string& color_name = "");
}
