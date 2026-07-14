#include "Globals.hpp"
#include <iostream>
#include <fstream>

std::atomic<bool> g_resized{false};
std::atomic<bool> g_quit{false};
int g_term_width = 80;
int g_term_height = 24;
std::string g_base_distro = "unknown";
std::string g_bundle_dir = ".";
bool g_confirm_arg = false;

Config g_config;
bool g_logout = false;
json g_theme;
json g_menu;

void load_theme() {
    std::string path = g_bundle_dir + "/installer/theme.json";
    std::ifstream f(path);
    if (f.is_open()) {
        try {
            g_theme = json::parse(f, nullptr, true, true);
        } catch (...) {
            std::cerr << "Failed to parse theme.json" << std::endl;
        }
    } else {
        std::cerr << "Could not open theme.json at " << path << std::endl;
    }
    
    std::string menu_path = g_bundle_dir + "/installer/menu.json";
    std::ifstream f2(menu_path);
    if (f2.is_open()) {
        try {
            g_menu = json::parse(f2, nullptr, true, true);
        } catch (...) {
            std::cerr << "Failed to parse menu.json" << std::endl;
        }
    } else {
        std::cerr << "Could not open menu.json at " << menu_path << std::endl;
    }
}

