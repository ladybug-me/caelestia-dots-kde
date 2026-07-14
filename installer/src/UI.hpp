#pragma once
#include <string>

namespace UI {
    bool loading_text(int x, int y, const std::string& text, const std::string& color);
    void splash_screen();
    bool sudo_prompt();
    std::string distro_select();
    void config_checklist();
    void summary_screen();
}
