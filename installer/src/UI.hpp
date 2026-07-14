#include <map>
#include "json.hpp"

extern std::map<std::string, std::string> g_answers;

#pragma once
#include <string>

namespace UI {
    bool loading_text(int x, int y, const std::string& text, const std::string& color);
    void splash_screen();
    bool sudo_prompt();
    void summary_screen();
    bool render_menu(const nlohmann::json& menu_items, const std::string& title = "CONFIGURATION");
}
