#pragma once
#include <map>
#include <string>
#include "json.hpp"

extern std::map<std::string, std::string> g_answers;

namespace UI {
    void welcome_screen();
    bool sudo_prompt();

    // Top-level action: "install", "update", "uninstall", or "exit".
    std::string action_select();

    // Profiles from menu.json: picker, overrides, display title.
    std::string profile_select();
    void apply_profile(const std::string& profile_id);
    std::string profile_title(const std::string& profile_id);

    // Seeds g_answers from menu item defaults (idempotent).
    void init_menu_defaults(const nlohmann::json& menu_items);

    // Returns true when the user asks to proceed to the review screen.
    bool render_menu(const nlohmann::json& menu_items, const std::string& title, const std::string& profile_title);

    // Returns true to begin installation, false to go back to configuration.
    bool review_screen();

    // Full-screen live tail of the install log; returns on L/Tab/Esc.
    void log_view(const std::string& log_path);

    void complete_screen();
}
