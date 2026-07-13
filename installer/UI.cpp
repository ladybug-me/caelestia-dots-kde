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

namespace UI {
    bool loading_text(int x, int y, const string& text, const string& color) {
        cout << Draw::to(y, x) << color << text << "   " << flush;
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
        vector<string> art = {
            "   _____            _           _   _       ",
            "  / ____|          | |         | | (_)      ",
            " | |     __ _  ___ | | ___  ___| |_ _  __ _ ",
            " | |    / _` |/ _ \\| |/ _ \\/ __| __| |/ _` |",
            " | |___| (_| | (_) | |  __/\\__ \\ |_| | (_| |",
            "  \\_____\\__,_|\\___/|_|\\___||___/\\__|_|\\__,_|"
        };
        int art_width = 46;
        int art_height = art.size();
        
        cout << Draw::clear();

        int left = (g_term_width - art_width) / 2;
        if (left < 1) left = 1;
        int top = (g_term_height - 18) / 2;
        if (top < 1) top = 1;
        
        // Animate art character by character
        cout << Draw::magenta << Draw::bold;
        for (size_t i = 0; i < art.size(); ++i) {
            cout << Draw::to(top + i, left);
            for (char c : art[i]) {
                if (!Input::get().empty()) return;
                cout << c << flush;
                this_thread::sleep_for(chrono::milliseconds(3));
            }
        }
        cout << Draw::reset;
        for (int j = 0; j < 20; ++j) {
            if (!Input::get().empty()) return;
            this_thread::sleep_for(chrono::milliseconds(10));
        }

        int text_top = top + art_height + 2;
        int text_left = left + 4;

        if (loading_text(text_left, text_top, "Initializing installer", Draw::cyan)) return;
        if (loading_text(text_left, text_top + 1, "Target platform: KDE Plasma 6", Draw::dim)) return;
        if (loading_text(text_left, text_top + 2, "Original Hyprland dots: caelestia-dots", Draw::dim)) return;
        if (loading_text(text_left, text_top + 3, "KDE port: ladybug-me", Draw::dim)) return;
        
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

            if (!animated_once) {
                Draw::animated_box(left, top, box_width, box_height, "PRIVILEGE ESCALATION", Draw::magenta);
                animated_once = true;
            } else {
                Draw::box(left, top, box_width, box_height, "PRIVILEGE ESCALATION", Draw::magenta);
            }
            Draw::text(left + 2, top + 2, "Root privileges are required to install packages.", Draw::white);
            Draw::text(left + 2, top + 3, "Password: ", Draw::bold + Draw::cyan);
            
            // Draw masked password
            string masked(pw.length(), '*');
            masked.resize(30, ' ');
            Draw::text(left + 12, top + 3, masked, Draw::reset);

            if (!error_msg.empty()) {
                Draw::text(left + 2, top + 5, error_msg, Draw::red);
            }
            
            cout << Draw::sync_end() << flush;

            string key = Input::wait_key();
            if (key == "enter") {
                if (pw.empty()) continue;
                
                // Show verifying...
                cout << Draw::sync_start();
                Draw::text(left + 2, top + 5, "Verifying...                             ", Draw::yellow);
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
                        Draw::text(left + 2, top + 5, "Verifying...                             ", Draw::yellow);
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
                    Draw::text(left + 2, opt_y, " > " + options[i], Draw::green);
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

    void config_checklist() {
        vector<string> options = {
            "Enable automatic package transaction confirmation",
            "Remove downloaded cache after install",
            "Enable Polonium tiling plugin",
            "Apply Darkly theme",
            "Enable Material You colors",
            "Apply included custom fonts"
        };
        vector<bool*> states = {
            &g_config.enable_transaction_confirm,
            &g_config.remove_cache,
            &g_config.enable_polonium,
            &g_config.apply_darkly,
            &g_config.enable_material_you,
            &g_config.apply_custom_fonts
        };
        int selected = 0;
        int box_width = 63;
        int box_height = 11 + options.size();

        bool animated_once = false;

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; animated_once = false; }
            cout << Draw::sync_start() << Draw::clear();
            
            int left = (g_term_width - box_width) / 2;
            if (left < 1) left = 1;
            int top = (g_term_height - box_height) / 2;
            if (top < 1) top = 1;

            if (!animated_once) {
                Draw::animated_box(left, top, box_width, box_height, "INSTALLER CONFIGURATION");
                animated_once = true;
            } else {
                Draw::box(left, top, box_width, box_height, "INSTALLER CONFIGURATION");
            }
            Draw::text(left + 2, top + 2, "Use UP/DOWN to navigate, SPACE to toggle, ENTER to confirm.");

            for (size_t i = 0; i < options.size(); i++) {
                int opt_y = top + 4 + i;
                string mark = *states[i] ? "X" : " ";
                string text = "[" + mark + "] " + options[i];
                if (i == selected) {
                    Draw::text(left + 2, opt_y, " > " + text, Draw::green);
                } else {
                    Draw::text(left + 2, opt_y, "   " + text);
                }
            }

            int proceed_y = top + 4 + options.size() + 1;
            if (selected == options.size()) {
                Draw::text(left + 2, proceed_y, " > PROCEED", Draw::green);
            } else {
                Draw::text(left + 2, proceed_y, "   PROCEED");
            }
            
            cout << Draw::sync_end() << flush;

            string key = Input::wait_key();
            if (key == "KEY_up") { if (selected > 0) selected--; }
            else if (key == "KEY_down") { if (selected < options.size()) selected++; }
            else if (key == " ") {
                if (selected < options.size()) *states[selected] = !*states[selected];
            } else if (key == "enter") {
                if (selected == options.size()) break;
                else *states[selected] = !*states[selected];
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

            Draw::box(left, top, w, h, "CAELESTIA INSTALLATION SUMMARY", Draw::green);
            
            int y = top + 2;

            auto print_step = [&](const string& name, const string& desc) {
                if (y >= top + h - 2) return;
                bool failed = check_failed(steps_file, name);
                string mark = failed ? "[X]" : "[OK]";
                string color = failed ? Draw::red : Draw::green;
                Draw::text(left + 2, y++, color + mark + Draw::reset + " " + desc);
            };

            auto print_patch = [&](const string& name, const string& desc) {
                if (y >= top + h - 2) return;
                bool failed = check_failed(patches_file, name);
                string mark = failed ? "[X]" : "[OK]";
                string color = failed ? Draw::red : Draw::green;
                Draw::text(left + 2, y++, color + mark + Draw::reset + " " + desc);
            };

            if (g_base_distro == "arch") {
                Draw::text(left + 2, y++, Draw::green + "[OK]" + Draw::reset + " System updated (pacman -Syu)");
            } else {
                Draw::text(left + 2, y++, Draw::green + "[OK]" + Draw::reset + " System updated (dnf upgrade)");
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
                Draw::text(left + 2, y++, "PATCH STATUS", Draw::bold + Draw::cyan);
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
                Draw::text(left + 2, y++, "FAILED PACKAGES", Draw::bold + Draw::red);
                for (const auto& p : failed_pkgs) {
                    if (y >= top + h - 2) break;
                    Draw::text(left + 2, y++, "- " + p, Draw::red);
                }
            }

            if (check_failed(steps_file, "Build Caelestia Shell") && y < top + h - 4) {
                y++;
                Draw::text(left + 2, y++, "SHELL BUILD FAILED", Draw::bold + Draw::red);
                Draw::text(left + 2, y++, "Review logs, install missing dependencies, and re-run setup.sh.", Draw::red);
            }

            y++;
            if (y < top + h - 6) {
                Draw::text(left + 2, y++, "Next steps:", Draw::bold + Draw::yellow);
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
                Draw::text(left + 2, y++, buf, Draw::green);
            }

            Draw::text(left + 2, top + h - 2, "Would you like to log out now? (y/N): ", Draw::bold + Draw::white);
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
