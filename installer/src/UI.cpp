#include <functional>
#include "UI.hpp"
#include "Globals.hpp"
#include "Term.hpp"
#include "Input.hpp"
#include "Draw.hpp"
#include "Runner.hpp"
#include <iostream>
#include <fstream>
#include <thread>
#include <chrono>
#include <unordered_map>
#include <vector>
#include <fcntl.h>
#include <unistd.h>

using namespace std;

std::map<std::string, std::string> g_answers;

namespace {

// Writes password to a file with secure permissions (0600) atomically at
// creation time — avoids the TOCTOU race of creating with default umask then
// chmod'ing afterwards.
bool write_password_file_secure(const string& path, const string& password) {
    // Mode 0600 ensures only the owner can read, from the moment of creation.
    // This avoids the TOCTOU window of creating with default umask then chmod.
    int fd = open(path.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (fd == -1) {
        return false;
    }
    string data = password + "\n";
    ssize_t written = write(fd, data.c_str(), data.size());
    close(fd);
    return written == static_cast<ssize_t>(data.size());
}

// Sets up the sudo askpass environment after a successful password
// verification. Creates the password file, askpass helper, sudo wrapper,
// screen inhibitor, and exports SUDO_PASS.
void setup_sudo_environment(const string& pw) {
    system("mkdir -p /tmp/caelestia_bin");

    // Write password with secure permissions from the start (no TOCTOU window)
    write_password_file_secure("/tmp/caelestia_pass.txt", pw);

    // Askpass script
    system("echo '#!/bin/bash\ncat /tmp/caelestia_pass.txt' > /tmp/caelestia_askpass.sh && chmod 700 /tmp/caelestia_askpass.sh");

    // Sudo wrapper to force -A
    system("echo '#!/bin/bash\nexport SUDO_ASKPASS=/tmp/caelestia_askpass.sh\nexec /usr/bin/sudo -A \"$@\"' > /tmp/caelestia_bin/sudo && chmod 700 /tmp/caelestia_bin/sudo");

    // Also export SUDO_PASS for some scripts (like 09-system-tweaks.sh) that might rely on it
    setenv("SUDO_PASS", pw.c_str(), 1);

    // Start background keep-awake for display (sleep inhibitor)
    system("systemd-inhibit --what=idle:sleep --who=\"Caelestia Installer\" --why=\"Installation in progress\" bash -c 'while :; do sleep 600; done' >/dev/null 2>&1 & echo $! > /tmp/caelestia_inhibit.pid");
    system("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Inhibit \"Caelestia Installer\" \"Installation in progress\" > /tmp/caelestia_kde_inhibit.cookie 2>/dev/null");
}

} // anonymous namespace

namespace UI {
    bool loading_text(int x, int y, const string& text, const string& color_name) {
        cout << Draw::to(y, x) << Draw::color(color_name) << text << "..." << flush;
        // Brief check for key press to allow skipping
        for (int j = 0; j < 10; ++j) {
            if (!Input::get().empty()) return true;
            this_thread::sleep_for(chrono::milliseconds(10));
        }
        return false;
    }

    void splash_screen() {
        // Drain any buffered stdin before animating — tmux / terminal setup
        // often leaves escape sequences in the input buffer that would otherwise
        // trigger the skip-early-return below and make the splash vanish instantly.
        for (int drain = 0; drain < 10 && !Input::get().empty(); ++drain) { }

        vector<string> art;
        if (!g_theme.is_null() && g_theme.contains("splash_screen") && g_theme["splash_screen"].contains("art")) {
            for (auto& line : g_theme["splash_screen"]["art"]) {
                art.push_back(line.get<string>());
            }
        }
        if (art.empty()) art.push_back("Caelestia Installer"); // fallback

        int art_width = 0;
        for (const auto& line : art) {
            if (line.length() > art_width) art_width = line.length();
        }
        int art_height = art.size();
        
        cout << Draw::clear();

        int left = (g_term_width - art_width) / 2;
        if (left < 1) left = 1;
        int top = (g_term_height - 18) / 2;
        if (top < 1) top = 1;
        
        // Animate art character by character
        string art_color_name = "magenta";
        int speed_ms = 3;
        if (!g_theme.is_null() && g_theme.contains("splash_screen")) {
            if (g_theme["splash_screen"].contains("art_color")) art_color_name = g_theme["splash_screen"]["art_color"].get<string>();
            if (g_theme["splash_screen"].contains("animation_speed_ms")) speed_ms = g_theme["splash_screen"]["animation_speed_ms"].get<int>();
        }

        cout << Draw::color(art_color_name) << Draw::bold;
        for (size_t i = 0; i < art.size(); ++i) {
            cout << Draw::to(top + i, left);
            cout << art[i] << flush;
            if (!Input::get().empty()) return;
        }
        cout << Draw::reset;

        int text_top = top + art_height + 2;
        int text_left = left + 4;

        string author = "By @ladybug-me";
        string loading_color = "dim";
        if (!g_theme.is_null() && g_theme.contains("splash_screen")) {
            if (g_theme["splash_screen"].contains("author")) author = g_theme["splash_screen"]["author"].get<string>();
            if (g_theme["splash_screen"].contains("loading_text_color")) loading_color = g_theme["splash_screen"]["loading_text_color"].get<string>();
        }

        vector<string> init_texts = { "Initializing installer" };
        if (!g_theme.is_null() && g_theme.contains("splash_screen") && g_theme["splash_screen"].contains("loading_texts")) {
            init_texts.clear();
            for (auto& text : g_theme["splash_screen"]["loading_texts"]) {
                init_texts.push_back(text.get<string>());
            }
        }
        
        cout << Draw::to(text_top, text_left + 10) << author;
        cout << Draw::sync_end() << flush;
        
        for (size_t i = 0; i < init_texts.size(); ++i) {
            if (loading_text(text_left, text_top + i + 1, init_texts[i], loading_color)) return;
        }

// Wait for user confirmation before proceeding to sudo prompt
int prompt_y = text_top + init_texts.size() + 2;
string enter_msg = "Press Enter to continue (Esc to quit)...";
cout << Draw::to(prompt_y, (g_term_width - enter_msg.length()) / 2)
     << Draw::color("dim") << enter_msg << Draw::reset << flush;
while (!g_quit) {
    string key = Input::wait_key();
    if (key == "enter" || key == " ") break;
    if (key == "escape") { g_quit = true; return; }
}
    }

    bool sudo_prompt() {
        int box_width = 54;
        int box_height = 7;
        string pw = "";
        string error_msg = "";
        int attempts = 0;

        bool animated_once = false;

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; animated_once = false; }
            cout << Draw::sync_start() << Draw::clear();
            
            int left = (g_term_width - box_width) / 2;
            if (left < 1) left = 1;
            int top = (g_term_height - box_height) / 2;
            if (top < 1) top = 1;

            string box_title = "PRIVILEGE ESCALATION";
            string box_color = "magenta";
            string title_color = "default";
            string text_color = "default";
            string prompt_color = "cyan";
            if (!g_theme.is_null() && g_theme.contains("layout") && g_theme["layout"].contains("sudo_prompt")) {
                auto& l = g_theme["layout"]["sudo_prompt"];
                if (l.contains("title")) box_title = l["title"].get<string>();
                if (l.contains("color")) box_color = l["color"].get<string>();
                if (l.contains("title_color")) title_color = l["title_color"].get<string>();
                if (l.contains("text_color")) text_color = l["text_color"].get<string>();
                if (l.contains("prompt_color")) prompt_color = l["prompt_color"].get<string>();
            }
            if (!animated_once) {
                Draw::animated_box(left, top, box_width, box_height, box_title, box_color, title_color);
                animated_once = true;
            } else {
                Draw::box(left, top, box_width, box_height, box_title, box_color, title_color);
            }
            Draw::text(left + 2, top + 2, "Root privileges are required to install packages.", text_color);
            Draw::text(left + 2, top + 3, "Password: ", Draw::bold + Draw::color(prompt_color));
            
            // Draw masked password
            string masked(pw.length(), '*');
            masked.resize(30, ' ');
            Draw::text(left + 12, top + 3, masked, Draw::reset);

            if (!error_msg.empty()) {
                Draw::text(left + 2, top + 5, error_msg, Draw::color("red"));
            }
            
            cout << Draw::sync_end() << flush;

            string key = Input::wait_key();
            if (key == "enter") {
                if (pw.empty()) continue;
                
                // Show verifying...
                cout << Draw::sync_start();
                Draw::text(left + 2, top + 5, "Verifying...                             ", Draw::color("yellow"));
                cout << Draw::sync_end() << flush;
                
                FILE* pipe = popen("sudo -S true 2>/dev/null", "w");
                if (pipe) {
                    fprintf(pipe, "%s\n", pw.c_str());
                    fflush(pipe);
                    int status = pclose(pipe);
                    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                        setup_sudo_environment(pw);
                        return true;
                    } else {
                        attempts++;
                        if (attempts >= 3) {
                            Term::restore();
                            cout << "Too many incorrect password attempts.\n";
                            exit(1);
                        }
                        error_msg = "Incorrect password, please try again. (" + to_string(attempts) + "/3)";
                        pw.clear();
                    }
                }
            } else if (key == "backspace" || (key.length() == 1 && (key[0] == '\x7f' || key[0] == '\x08'))) { // Backspace
                if (!pw.empty()) pw.pop_back();
                error_msg.clear();
            } else if (key == "escape") {
                return false;
            } else if (key.find("KEY_") == 0) {
                // ignore internal named keys like KEY_up
            } else {
                // Handle normal printable chars (including pasted text with multiple chars and UTF-8)
                bool all_printable = true;
                for (char c : key) {
                    if ((unsigned char)c < 32 || c == 127) all_printable = false;
                }
                if (all_printable && !key.empty()) {
                    pw += key;
                    error_msg.clear();
                } else if (key.find('\n') != string::npos || key.find('\r') != string::npos) {
                    // Pasted text contained an enter/newline character
                    string cleaned = "";
                    for (char c : key) {
                        if ((unsigned char)c >= 32 && c != 127) cleaned += c;
                    }
                    pw += cleaned;
                    // Trigger enter behavior
                    if (!pw.empty()) {
                        cout << Draw::sync_start();
                        Draw::text(left + 2, top + 5, "Verifying...                             ", Draw::color("yellow"));
                        cout << Draw::sync_end() << flush;
                        FILE* pipe = popen("sudo -S true 2>/dev/null", "w");
                        if (pipe) {
                            fprintf(pipe, "%s\n", pw.c_str());
                            fflush(pipe);
                            int status = pclose(pipe);
                            if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                                setup_sudo_environment(pw);
                                return true;
                            } else {
                                attempts++;
                                if (attempts >= 3) {
                                    Term::restore();
                                    cout << "Too many incorrect password attempts.\n";
                                    exit(1);
                                }
                                error_msg = "Incorrect password, please try again. (" + to_string(attempts) + "/3)";
                                pw.clear();
                            }
                        }
                    }
                }
            }
        }
    }

    string distro_select() {
        vector<string> options = {"Arch-based", "Fedora", "Debian-based", "Exit"};
        int selected = 0;
        int box_width = 63;
        int box_height = 13;

        bool animated_once = false;

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; animated_once = false; }
            cout << Draw::sync_start() << Draw::clear();
            
            int left = (g_term_width - box_width) / 2;
            if (left < 1) left = 1;
            int top = (g_term_height - box_height) / 2;
            if (top < 1) top = 1;

            if (!animated_once) {
                Draw::animated_box(left, top, box_width, box_height, "SELECT DISTRIBUTION");
                animated_once = true;
            } else {
                Draw::box(left, top, box_width, box_height, "SELECT DISTRIBUTION");
            }
            Draw::text(left + 2, top + 2, "Use UP/DOWN to navigate, ENTER to select.");

            for (size_t i = 0; i < options.size(); i++) {
                int opt_y = top + 4 + i;
                if (i == selected) {
                    Draw::text(left + 2, opt_y, " > " + options[i], Draw::color("green"));
                } else {
                    Draw::text(left + 2, opt_y, "   " + options[i]);
                }
            }
            cout << Draw::sync_end() << flush;

            string key = Input::wait_key();
            if (key == "KEY_up") { if (selected > 0) selected--; }
            else if (key == "KEY_down") { if (selected < options.size() - 1) selected++; }
            else if (key == "enter") {
                if (options[selected] == "Arch-based") return "arch";
                if (options[selected] == "Fedora") return "fedora";
                if (options[selected] == "Debian-based") return "debian";
                return "exit";
            }
        }
    }


    bool check_failed(const string& file, const string& target) {
        ifstream f(file);
        string line;
        while (getline(f, line)) {
            if (line.find(target) != string::npos) return true;
        }
        return false;
    }

    void summary_screen() {
        string cache_dir = string(getenv("XDG_CACHE_HOME") ? getenv("XDG_CACHE_HOME") : (string(getenv("HOME")) + "/.cache")) + "/caelestia-kde";
        string steps_file = cache_dir + "/failed_steps.txt";
        string pkgs_file = cache_dir + "/failed_packages.txt";
        string patches_file = cache_dir + "/failed_patches.txt";

        auto fit_line = [](const string& text, size_t max_len) {
            if (max_len == 0) return string();
            if (text.size() <= max_len) return text;
            if (max_len <= 3) return text.substr(0, max_len);
            return text.substr(0, max_len - 3) + "...";
        };

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; }
            cout << Draw::sync_start() << Draw::clear();
            
            int w = g_term_width - 4;
            if (w > 80) w = 80;
            int h = g_term_height - 2;
            int left = (g_term_width - w) / 2;
            int top = 1;
            const size_t content_width = w > 4 ? static_cast<size_t>(w - 4) : 0;
            
            string box_title = "CAELESTIA INSTALLATION SUMMARY";
            string box_color = "green";
            string title_color = "default";
            if (!g_theme.is_null() && g_theme.contains("layout") && g_theme["layout"].contains("summary_screen")) {
                auto& l = g_theme["layout"]["summary_screen"];
                if (l.contains("title")) box_title = l["title"].get<string>();
                if (l.contains("color")) box_color = l["color"].get<string>();
                if (l.contains("title_color")) title_color = l["title_color"].get<string>();
            }

            Draw::box(left, top, w, h, box_title, box_color, title_color);
            
            int y = top + 2;

            auto print_step = [&](const string& name, const string& desc) {
                if (y >= top + h - 2) return;
                bool failed = check_failed(steps_file, name);
                string mark = failed ? "[X]" : "[OK]";
                string color = failed ? Draw::color("red") : Draw::color("green");
                Draw::text(left + 2, y++, color + fit_line(mark + " " + desc, content_width) + Draw::reset);
            };

            auto print_patch = [&](const string& name, const string& desc) {
                if (y >= top + h - 2) return;
                bool failed = check_failed(patches_file, name);
                string mark = failed ? "[X]" : "[OK]";
                string color = failed ? Draw::color("red") : Draw::color("green");
                Draw::text(left + 2, y++, color + fit_line(mark + " " + desc, content_width) + Draw::reset);
            };

            if (g_base_distro == "arch") {
                Draw::text(left + 2, y++, fit_line("[OK] System updated (pacman -Syu)", content_width), Draw::color("green"));
            } else if (g_base_distro == "fedora") {
                Draw::text(left + 2, y++, fit_line("[OK] System updated (dnf upgrade)", content_width), Draw::color("green"));
            } else if (g_base_distro == "debian") {
                Draw::text(left + 2, y++, fit_line("[OK] System updated (apt-get upgrade)", content_width), Draw::color("green"));
            } else {
                Draw::text(left + 2, y++, fit_line("[OK] System updated", content_width), Draw::color("green"));
            }

            print_step("Package installation", fit_line("Packages installed (PKGBUILDs + fonts + deps)", content_width));
            print_step("Config deployment", fit_line("Configs (repo-base + KDE overrides, clean deploy)", content_width));
            print_step("KDE settings", fit_line("Darkly theme + Kvantum + default wallpaper", content_width));
            print_step("System tweaks", fit_line("5 virtual desktops + KDE OSDs disabled", content_width));
            print_step("Keyboard shortcuts", fit_line("Keyboard shortcuts (KDE native + keyd)", content_width));
            print_step("Autostart", fit_line("Quickshell + kde-material-you-colors autostart", content_width));
            print_step("Build Caelestia Shell", fit_line("Caelestia shell built and installed", content_width));

            y++;
            if (y < top + h - 2) {
                Draw::text(left + 2, y++, "PATCH STATUS", Draw::bold + Draw::color("cyan"));
                print_patch("Caelestia CLI Hyprctl Mock Patch", fit_line("Caelestia CLI Hyprctl mock patch", content_width));
                print_patch("Caelestia CLI Record/Dolphin Patch", fit_line("Caelestia CLI record/dolphin patch", content_width));
                print_patch("Caelestia CLI Theme Sequence Patch", fit_line("Caelestia CLI theme sequence patch", content_width));
            }

            ifstream pf(pkgs_file);
            string pkg;
            vector<string> failed_pkgs;
            while (getline(pf, pkg)) {
                if (!pkg.empty()) failed_pkgs.push_back(pkg);
            }
            if (!failed_pkgs.empty() && y < top + h - 4) {
                y++;
                Draw::text(left + 2, y++, "FAILED PACKAGES", Draw::bold + Draw::color("red"));
                for (const auto& p : failed_pkgs) {
                    if (y >= top + h - 2) break;
                    Draw::text(left + 2, y++, fit_line("- " + p, content_width), Draw::color("red"));
                }
            }

            if (check_failed(steps_file, "Build Caelestia Shell") && y < top + h - 4) {
                y++;
                Draw::text(left + 2, y++, "SHELL BUILD FAILED", Draw::bold + Draw::color("red"));
                Draw::text(left + 2, y++, fit_line("Review logs, install missing dependencies, and re-run setup.sh.", content_width), Draw::color("red"));
            }

            y++;
            if (y < top + h - 6) {
                Draw::text(left + 2, y++, "Next steps:", Draw::bold + Draw::color("yellow"));
                Draw::text(left + 2, y++, fit_line("1) Log out now, then log back in.", content_width));
                Draw::text(left + 2, y++, fit_line("2) If a kernel update occurred, reboot immediately.", content_width));
                Draw::text(left + 2, y++, fit_line("3) Remove KDE panels after login (Super+D -> panel config).", content_width));
                Draw::text(left + 2, y++, fit_line("4) Desktop edit mode later: Super+D -> right click desktop.", content_width));
            }

            const char* start_epoch_str = getenv("INSTALL_START_EPOCH");
            if (start_epoch_str && y < top + h - 3) {
                y++;
                long start_epoch = atol(start_epoch_str);
                long elapsed = time(NULL) - start_epoch;
                long h = elapsed / 3600;
                long m = (elapsed % 3600) / 60;
                long s = elapsed % 60;
                char buf[64];
                snprintf(buf, sizeof(buf), "Total installation time: %ldh %ldm %lds", h, m, s);
                Draw::text(left + 2, y++, fit_line(string("[OK] ") + buf, content_width), Draw::color("green"));
            }

            Draw::text(left + 2, top + h - 2, fit_line("Would you like to log out now? (y/N): ", content_width), Draw::bold + Draw::color("default"));
            cout << Draw::sync_end() << flush;
            
            string key = Input::wait_key();
            if (key == "y" || key == "Y") {
                g_logout = true;
                break;
            } else if (key == "n" || key == "N" || key == "enter" || key == "escape") {
                g_logout = false;
                break;
            }
        }
    }
}

namespace UI {
    bool render_menu(const json& menu_items, const std::string& title) {
        struct MenuItemMeta {
            string type;
            string title;
            string id;
            vector<string> options;
            unordered_map<string, int> option_index;
        };

        int selected = 0;
        int num_items = menu_items.size();
        if (num_items == 0) return true;

        string box_title = title;
        string box_color = "cyan";
        string title_color = "default";
        string text_color = "default";
        if (!g_theme.is_null() && g_theme.contains("layout") && g_theme["layout"].contains("config_checklist")) {
            auto& l = g_theme["layout"]["config_checklist"];
            if (l.contains("color")) box_color = l["color"].get<string>();
            if (l.contains("title_color")) title_color = l["title_color"].get<string>();
            if (l.contains("text_color")) text_color = l["text_color"].get<string>();
        }

        // Initialize defaults recursively in g_answers
        std::function<void(const json&)> init_defaults = [&](const json& items) {
            for (size_t i = 0; i < items.size(); ++i) {
                auto& item = items[i];
                if (item.contains("type") && item["type"] == "submenu" && item.contains("items")) {
                    init_defaults(item["items"]);
                } else if (item.contains("id") && item.contains("default") && g_answers.find(item["id"].get<string>()) == g_answers.end()) {
                    if (item["default"].is_boolean()) {
                        g_answers[item["id"].get<string>()] = item["default"].get<bool>() ? "true" : "false";
                    } else if (item["default"].is_string()) {
                        g_answers[item["id"].get<string>()] = item["default"].get<string>();
                    }
                }
            }
        };
        init_defaults(menu_items);

        vector<MenuItemMeta> meta;
        meta.reserve(static_cast<size_t>(num_items));
        for (int i = 0; i < num_items; ++i) {
            auto& item = menu_items[i];
            MenuItemMeta m;
            m.type = item.contains("type") ? item["type"].get<string>() : "action";
            m.title = item.contains("title") ? item["title"].get<string>() : "Unknown";
            m.id = item.contains("id") ? item["id"].get<string>() : "";

            if (m.type == "select" && item.contains("options") && item["options"].is_array()) {
                auto& opts = item["options"];
                m.options.reserve(opts.size());
                for (size_t oi = 0; oi < opts.size(); ++oi) {
                    string opt = opts[oi].get<string>();
                    m.option_index[opt] = static_cast<int>(oi);
                    m.options.push_back(opt);
                }
                if (!m.id.empty() && !m.options.empty() && g_answers[m.id].empty()) {
                    g_answers[m.id] = m.options[0];
                }
            }

            meta.push_back(std::move(m));
        }

        bool typing_mode = false;
        bool needs_full_redraw = true;
        int last_selected = selected;
        bool last_typing_mode = false;
        int last_left = -1;
        int last_top = -1;
        int last_w = -1;
        int last_h = -1;

        auto build_display = [&](int index, int max_len) {
            const auto& m = meta[index];
            string display = m.title;

            if (m.type == "submenu") {
                display += " ->";
            } else if (m.type == "boolean") {
                bool val = (g_answers[m.id] == "true");
                display = (val ? "[x] " : "[ ] ") + m.title;
            } else if (m.type == "select") {
                display = m.title + ": < " + g_answers[m.id] + " >";
            } else if (m.type == "text") {
                display = m.title + ": [" + g_answers[m.id];
                if (typing_mode && index == selected) display += "_";
                display += "]";
            }

            if (static_cast<int>(display.length()) > max_len && max_len >= 3) {
                display = display.substr(0, static_cast<size_t>(max_len - 3)) + "...";
            }

            string line = (index == selected ? "> " : "  ") + display;
            if (static_cast<int>(line.length()) < max_len + 2) {
                line.append(static_cast<size_t>(max_len + 2 - static_cast<int>(line.length())), ' ');
            }
            return line;
        };

        auto draw_row = [&](int index, int left, int start_y, int top, int h, int max_len, const string& box_color, const string& text_color) {
            if (index < 0 || index >= num_items) return;
            if (start_y + index >= top + h - 1) return;
            string color_name = (index == selected) ? ("bold_" + box_color) : text_color;
            Draw::text(left + 4, start_y + index, build_display(index, max_len), color_name);
        };

        while (!g_quit) {
            if (g_resized) { Term::get_size(); g_resized = false; }
            
            int w = 60;
            for (int i = 0; i < num_items; ++i) {
                const auto& m = meta[i];
                int len = static_cast<int>(m.title.length());
                if (m.type == "submenu") {
                    len += 3;
                } else if (m.type == "boolean") {
                    len += 6;
                } else if (m.type == "select") {
                    len += 5 + static_cast<int>(g_answers[m.id].length());
                } else if (m.type == "text") {
                    len += 3 + static_cast<int>(g_answers[m.id].length()) + 2;
                }
                if (len + 8 > w) w = len + 8;
            }
            if (w > g_term_width - 4) w = g_term_width - 4;

            int h = num_items + 6;
            if (h > g_term_height - 4) h = g_term_height - 4;
            int left = (g_term_width - w) / 2;
            int top = (g_term_height - h) / 2;
            int start_y = top + 4;
            int max_len = w - 8;

            bool geometry_changed = left != last_left || top != last_top || w != last_w || h != last_h;
            bool mode_changed = typing_mode != last_typing_mode;

            cout << Draw::sync_start();
            if (needs_full_redraw || geometry_changed || mode_changed) {
                cout << Draw::clear();
                Draw::box(left, top, w, h, box_title, box_color, title_color);

                string inst = "Arrow keys to navigate, Enter/Space to select/toggle";
                if (static_cast<int>(inst.length()) > w - 4) {
                    inst = inst.substr(0, static_cast<size_t>(w - 7)) + "...";
                }
                Draw::text(left + 2, top + 2, inst, text_color);

                for (int i = 0; i < num_items; ++i) {
                    draw_row(i, left, start_y, top, h, max_len, box_color, text_color);
                }
            } else if (selected != last_selected) {
                draw_row(last_selected, left, start_y, top, h, max_len, box_color, text_color);
                draw_row(selected, left, start_y, top, h, max_len, box_color, text_color);
            }

            cout << Draw::sync_end() << flush;

            last_selected = selected;
            last_typing_mode = typing_mode;
            last_left = left;
            last_top = top;
            last_w = w;
            last_h = h;
            
            string key = Input::wait_key();
            auto& item = menu_items[selected];
            auto& selected_meta = meta[selected];
            string type = selected_meta.type;
            string id = selected_meta.id;
            string item_title = selected_meta.title;

            bool selection_changed = false;
            bool content_changed = false;
            bool typing_mode_changed = false;

            if (typing_mode) {
                if (key == "enter" || key == "escape") {
                    typing_mode = false;
                    typing_mode_changed = true;
                } else if (key == "backspace" || (key.length() == 1 && (key[0] == '\x7f' || key[0] == '\x08'))) {
                    if (!g_answers[id].empty()) {
                        g_answers[id].pop_back();
                        content_changed = true;
                    }
                } else if (key.find("KEY_") != 0) {
                    // printable char
                    bool all_printable = true;
                    for (char c : key) {
                        if ((unsigned char)c < 32 || c == 127) all_printable = false;
                    }
                    if (all_printable && !key.empty()) {
                        g_answers[id] += key;
                        content_changed = true;
                    }
                }

                needs_full_redraw = content_changed || typing_mode_changed;
                continue;
            }

            if (key == "KEY_up") {
                if (selected > 0) {
                    selected--;
                    selection_changed = true;
                }
            }
            else if (key == "KEY_down") {
                if (selected < num_items - 1) {
                    selected++;
                    selection_changed = true;
                }
            }
            else if (key == "KEY_right" || key == "enter" || key == " ") {
                if (type == "action") {
                    if (id == "action_back") return false;
                    if (id == "action_proceed") return true;
                } else if (type == "submenu") {
                    if (item.contains("items")) {
                        bool proceed = render_menu(item["items"], item_title);
                        if (proceed) return true; // If they clicked proceed from deep inside, bubble up!
                    }
                } else if (type == "boolean") {
                    g_answers[id] = (g_answers[id] == "true") ? "false" : "true";
                    content_changed = true;
                } else if (type == "select") {
                    if (!selected_meta.options.empty()) {
                        int current_idx = 0;
                        auto it = selected_meta.option_index.find(g_answers[id]);
                        if (it != selected_meta.option_index.end()) current_idx = it->second;
                        current_idx = (current_idx + 1) % static_cast<int>(selected_meta.options.size());
                        g_answers[id] = selected_meta.options[static_cast<size_t>(current_idx)];
                        content_changed = true;
                    }
                } else if (type == "text") {
                    typing_mode = true;
                    typing_mode_changed = true;
                }
            } else if (key == "KEY_left") {
                if (type == "select") {
                    if (!selected_meta.options.empty()) {
                        int current_idx = 0;
                        auto it = selected_meta.option_index.find(g_answers[id]);
                        if (it != selected_meta.option_index.end()) current_idx = it->second;
                        current_idx = (current_idx - 1 + static_cast<int>(selected_meta.options.size())) % static_cast<int>(selected_meta.options.size());
                        g_answers[id] = selected_meta.options[static_cast<size_t>(current_idx)];
                        content_changed = true;
                    }
                } else {
                    return false; // Back out of submenu
                }
            } else if (key == "escape") {
                return false;
            }

            needs_full_redraw = content_changed || typing_mode_changed || !selection_changed;
        }
        return false;
    }

}
