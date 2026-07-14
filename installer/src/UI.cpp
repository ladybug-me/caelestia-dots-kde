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
#include <vector>

using namespace std;

std::map<std::string, std::string> g_answers;

namespace UI {
    bool loading_text(int x, int y, const string& text, const string& color_name) {
        cout << Draw::to(y, x) << Draw::color(color_name) << text << "   " << flush;
        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 20; ++j) {
                if (!Input::get().empty()) return true;
                this_thread::sleep_for(chrono::milliseconds(10));
            }
            cout << Draw::to(y, x + text.length() + i) << "." << flush;
        }
        for (int j = 0; j < 30; ++j) {
            if (!Input::get().empty()) return true;
            this_thread::sleep_for(chrono::milliseconds(10));
        }
        cout << Draw::to(y, x + text.length()) << "..." << flush;
        return false;
    }

    void splash_screen() {
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
            for (char c : art[i]) {
                if (!Input::get().empty()) return;
                cout << c << flush;
                this_thread::sleep_for(chrono::milliseconds(speed_ms));
            }
        }
        cout << Draw::reset;
        for (int j = 0; j < 20; ++j) {
            if (!Input::get().empty()) return;
            this_thread::sleep_for(chrono::milliseconds(10));
        }

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
        
        for (int j = 0; j < 50; ++j) {
            if (!Input::get().empty()) return;
            this_thread::sleep_for(chrono::milliseconds(10));
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
            string title_color = "white";
            string text_color = "white";
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
                                // Create askpass wrapper instead of relying on /etc/sudoers.d
                                system("mkdir -p /tmp/caelestia_bin");
                                
                                // Write password securely using C++ streams
                                {
                                    std::ofstream pass_file("/tmp/caelestia_pass.txt");
                                    if (pass_file.is_open()) {
                                        pass_file << pw << "\n";
                                        pass_file.close();
                                    }
                                }
                                system("chmod 600 /tmp/caelestia_pass.txt");
                                
                                // Askpass script
                                system("echo '#!/bin/bash\ncat /tmp/caelestia_pass.txt' > /tmp/caelestia_askpass.sh && chmod 700 /tmp/caelestia_askpass.sh");
                                
                                // Sudo wrapper to force -A
                                system("echo '#!/bin/bash\nexport SUDO_ASKPASS=/tmp/caelestia_askpass.sh\nexec /usr/bin/sudo -A \"$@\"' > /tmp/caelestia_bin/sudo && chmod 700 /tmp/caelestia_bin/sudo");
                                
                                // Also export SUDO_PASS for some scripts (like 09-system-tweaks.sh) that might rely on it
                                setenv("SUDO_PASS", pw.c_str(), 1);
                        // Start background keep-awake for display (sleep inhibitor)
                        system("systemd-inhibit --what=idle:sleep --who=\"Caelestia Installer\" --why=\"Installation in progress\" bash -c 'while :; do sleep 600; done' >/dev/null 2>&1 & echo $! > /tmp/caelestia_inhibit.pid");
                        system("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Inhibit \"Caelestia Installer\" \"Installation in progress\" > /tmp/caelestia_kde_inhibit.cookie 2>/dev/null");
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
                                // Create askpass wrapper instead of relying on /etc/sudoers.d
                                system("mkdir -p /tmp/caelestia_bin");
                                
                                // Write password securely using C++ streams
                                {
                                    std::ofstream pass_file("/tmp/caelestia_pass.txt");
                                    if (pass_file.is_open()) {
                                        pass_file << pw << "\n";
                                        pass_file.close();
                                    }
                                }
                                system("chmod 600 /tmp/caelestia_pass.txt");
                                
                                // Askpass script
                                system("echo '#!/bin/bash\ncat /tmp/caelestia_pass.txt' > /tmp/caelestia_askpass.sh && chmod 700 /tmp/caelestia_askpass.sh");
                                
                                // Sudo wrapper to force -A
                                system("echo '#!/bin/bash\nexport SUDO_ASKPASS=/tmp/caelestia_askpass.sh\nexec /usr/bin/sudo -A \"$@\"' > /tmp/caelestia_bin/sudo && chmod 700 /tmp/caelestia_bin/sudo");
                                
                                // Also export SUDO_PASS for some scripts
                                setenv("SUDO_PASS", pw.c_str(), 1);
                                
                                system("systemd-inhibit --what=idle:sleep --who=\"Caelestia Installer\" --why=\"Installation in progress\" bash -c 'while :; do sleep 600; done' >/dev/null 2>&1 & echo $! > /tmp/caelestia_inhibit.pid");
                                system("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Inhibit \"Caelestia Installer\" \"Installation in progress\" > /tmp/caelestia_kde_inhibit.cookie 2>/dev/null");
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
        vector<string> options = {"Arch-based", "Fedora", "Exit"};
        int selected = 0;
        int box_width = 63;
        int box_height = 12;

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
                return options[selected];
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

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; }
            cout << Draw::sync_start() << Draw::clear();
            
            int w = g_term_width - 4;
            if (w > 80) w = 80;
            int h = g_term_height - 2;
            int left = (g_term_width - w) / 2;
            int top = 1;
            
            string box_title = "CAELESTIA INSTALLATION SUMMARY";
            string box_color = "green";
            string title_color = "white";
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
                Draw::text(left + 2, y++, color + mark + Draw::reset + " " + desc);
            };

            auto print_patch = [&](const string& name, const string& desc) {
                if (y >= top + h - 2) return;
                bool failed = check_failed(patches_file, name);
                string mark = failed ? "[X]" : "[OK]";
                string color = failed ? Draw::color("red") : Draw::color("green");
                Draw::text(left + 2, y++, color + mark + Draw::reset + " " + desc);
            };

            if (g_base_distro == "arch") {
                Draw::text(left + 2, y++, Draw::color("green") + "[OK]" + Draw::reset + " System updated (pacman -Syu)");
            } else {
                Draw::text(left + 2, y++, Draw::color("green") + "[OK]" + Draw::reset + " System updated (dnf upgrade)");
            }

            print_step("Package installation", "Packages installed (PKGBUILDs + fonts + deps)");
            print_step("Config deployment", "Configs (repo-base + KDE overrides, clean deploy)");
            print_step("KDE settings", "Darkly theme + Kvantum + default wallpaper");
            print_step("System tweaks", "5 virtual desktops + KDE OSDs disabled");
            print_step("Keyboard shortcuts", "Keyboard shortcuts (KDE native + keyd)");
            print_step("Autostart", "Quickshell + kde-material-you-colors autostart");
            print_step("Build Caelestia Shell", "Caelestia shell built and installed");

            y++;
            if (y < top + h - 2) {
                Draw::text(left + 2, y++, "PATCH STATUS", Draw::bold + Draw::color("cyan"));
                print_patch("Caelestia CLI Hyprctl Mock Patch", "Caelestia CLI Hyprctl mock patch");
                print_patch("Caelestia CLI Record/Dolphin Patch", "Caelestia CLI record/dolphin patch");
                print_patch("Caelestia CLI Theme Sequence Patch", "Caelestia CLI theme sequence patch");
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
                    Draw::text(left + 2, y++, "- " + p, Draw::color("red"));
                }
            }

            if (check_failed(steps_file, "Build Caelestia Shell") && y < top + h - 4) {
                y++;
                Draw::text(left + 2, y++, "SHELL BUILD FAILED", Draw::bold + Draw::color("red"));
                Draw::text(left + 2, y++, "Review logs, install missing dependencies, and re-run setup.sh.", Draw::color("red"));
            }

            y++;
            if (y < top + h - 6) {
                Draw::text(left + 2, y++, "Next steps:", Draw::bold + Draw::color("yellow"));
                Draw::text(left + 2, y++, "1) Log out now, then log back in.");
                Draw::text(left + 2, y++, "2) If a kernel update occurred, reboot immediately.");
                Draw::text(left + 2, y++, "3) Remove all KDE panels after login (Super+D -> panel config).");
                Draw::text(left + 2, y++, "4) To enter desktop edit mode later: Super+D -> right click desktop.");
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
                snprintf(buf, sizeof(buf), "[OK] Total installation time: %ldh %ldm %lds", h, m, s);
                Draw::text(left + 2, y++, buf, Draw::color("green"));
            }

            Draw::text(left + 2, top + h - 2, "Would you like to log out now? (y/N): ", Draw::bold + Draw::color("white"));
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
        int selected = 0;
        int num_items = menu_items.size();
        if (num_items == 0) return true;

        string box_title = title;
        string box_color = "cyan";
        string title_color = "white";
        string text_color = "white";
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

        bool typing_mode = false;

        while (!g_quit) {
            if (g_resized) { Term::get_size(); g_resized = false; }
            
            int w = 60;
            for (int i = 0; i < num_items; ++i) {
                auto& item = menu_items[i];
                string type = item.contains("type") ? item["type"].get<string>() : "action";
                string item_title = item.contains("title") ? item["title"].get<string>() : "Unknown";
                string id = item.contains("id") ? item["id"].get<string>() : "";
                int len = item_title.length();
                if (type == "submenu") {
                    len += 3;
                } else if (type == "boolean") {
                    len += 6;
                } else if (type == "select") {
                    len += 5 + g_answers[id].length();
                } else if (type == "text") {
                    len += 3 + g_answers[id].length() + 2;
                }
                if (len + 8 > w) w = len + 8;
            }
            if (w > g_term_width - 4) w = g_term_width - 4;

            int h = num_items + 6;
            if (h > g_term_height - 4) h = g_term_height - 4;
            int left = (g_term_width - w) / 2;
            int top = (g_term_height - h) / 2;
            
            cout << Draw::sync_start() << Draw::clear();
            Draw::box(left, top, w, h, box_title, box_color, title_color);

            string inst = "Arrow keys to navigate, Enter/Space to select/toggle";
            if ((int)inst.length() > w - 4) {
                inst = inst.substr(0, w - 7) + "...";
            }
            Draw::text(left + 2, top + 2, inst, text_color);
            
            int start_y = top + 4;
            for (int i = 0; i < num_items; ++i) {
                if (start_y + i >= top + h - 1) break;
                auto& item = menu_items[i];
                string type = item.contains("type") ? item["type"].get<string>() : "action";
                string item_title = item.contains("title") ? item["title"].get<string>() : "Unknown";
                string id = item.contains("id") ? item["id"].get<string>() : "";
                
                string display = item_title;
                if (type == "submenu") {
                    display += " ->";
                } else if (type == "boolean") {
                    bool val = (g_answers[id] == "true");
                    display = (val ? "[x] " : "[ ] ") + item_title;
                } else if (type == "select") {
                    display = item_title + ": < " + g_answers[id] + " >";
                } else if (type == "text") {
                    display = item_title + ": [" + g_answers[id];
                    if (typing_mode && i == selected) display += "_";
                    display += "]";
                }

                int max_len = w - 8;
                if ((int)display.length() > max_len) {
                    display = display.substr(0, max_len - 3) + "...";
                }

                if (i == selected) {
                    Draw::text(left + 4, start_y + i, "> " + display, "bold_" + box_color);
                } else {
                    Draw::text(left + 4, start_y + i, "  " + display, text_color);
                }
            }
            
            cout << Draw::sync_end() << flush;
            
            string key = Input::wait_key();
            auto& item = menu_items[selected];
            string type = item.contains("type") ? item["type"].get<string>() : "action";
            string id = item.contains("id") ? item["id"].get<string>() : "";
            string item_title = item.contains("title") ? item["title"].get<string>() : "Unknown";

            if (typing_mode) {
                if (key == "enter" || key == "escape") {
                    typing_mode = false;
                } else if (key == "backspace" || (key.length() == 1 && (key[0] == '\x7f' || key[0] == '\x08'))) {
                    if (!g_answers[id].empty()) g_answers[id].pop_back();
                } else if (key.find("KEY_") != 0) {
                    // printable char
                    bool all_printable = true;
                    for (char c : key) {
                        if ((unsigned char)c < 32 || c == 127) all_printable = false;
                    }
                    if (all_printable && !key.empty()) g_answers[id] += key;
                }
                continue;
            }

            if (key == "KEY_up") { if (selected > 0) selected--; }
            else if (key == "KEY_down") { if (selected < num_items - 1) selected++; }
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
                } else if (type == "select") {
                    if (item.contains("options")) {
                        auto& opts = item["options"];
                        int current_idx = 0;
                        for (size_t i = 0; i < opts.size(); ++i) {
                            if (opts[i].get<string>() == g_answers[id]) { current_idx = i; break; }
                        }
                        if (key == "KEY_right" || key == "enter" || key == " ") {
                            current_idx = (current_idx + 1) % opts.size();
                        }
                        g_answers[id] = opts[current_idx].get<string>();
                    }
                } else if (type == "text") {
                    typing_mode = true;
                }
            } else if (key == "KEY_left") {
                if (type == "select") {
                    if (item.contains("options")) {
                        auto& opts = item["options"];
                        int current_idx = 0;
                        for (size_t i = 0; i < opts.size(); ++i) {
                            if (opts[i].get<string>() == g_answers[id]) { current_idx = i; break; }
                        }
                        current_idx = (current_idx - 1 + opts.size()) % opts.size();
                        g_answers[id] = opts[current_idx].get<string>();
                    }
                } else {
                    return false; // Back out of submenu
                }
            } else if (key == "escape") {
                return false;
            }
        }
        return false;
    }

}
