#include "Globals.hpp"

std::atomic<bool> g_resized{false};
std::atomic<bool> g_quit{false};
int g_term_width = 80;
int g_term_height = 24;
std::string g_base_distro = "unknown";
std::string g_bundle_dir = ".";
bool g_confirm_arg = false;

Config g_config;
bool g_logout = false;
