#pragma once
#include <atomic>
#include <string>
#include <vector>
#include "json.hpp"

using json = nlohmann::json;

extern json g_theme;
extern json g_menu;

extern std::atomic<bool> g_resized;
extern std::atomic<bool> g_quit;
extern int g_term_width;
extern int g_term_height;
extern std::string g_base_distro;
extern std::string g_bundle_dir;
extern bool g_confirm_arg;

void load_bundle_dir();
void load_theme();

struct Config {
    bool enable_transaction_confirm = true;
    bool remove_cache = false;
    bool enable_polonium = false;
    bool apply_darkly = true;
    bool enable_material_you = true;
    bool apply_custom_fonts = true;
};

extern Config g_config;
extern bool g_logout;
