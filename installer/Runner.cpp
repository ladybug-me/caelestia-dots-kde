#include "Runner.hpp"
#include "Globals.hpp"
#include "Term.hpp"
#include "Input.hpp"
#include "Draw.hpp"
#include <iostream>
#include <thread>
#include <chrono>
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdlib>
#include <pty.h>
#include <termios.h>
#include <algorithm>

using namespace std;

namespace Runner {
    vector<Step> steps = {
        {"System update", "scripts/00a-system-update.sh", "PENDING"},
        {"Ensure prerequisites", "scripts/01-ensure-prereqs.sh", "PENDING"},
        {"Install packages", "scripts/02-packages.sh", "PENDING"},
        {"Backup KDE Settings", "scripts/00-backup-themes.sh", "PENDING"},
        {"Update submodules", "scripts/02a-submodules.sh", "PENDING"},
        {"Deploy configs", "scripts/03-deploy-configs.sh", "PENDING"},
        {"Deploy KDE tweaks", "scripts/04-deploy-kde.sh", "PENDING"},
        {"Keyboard shortcuts", "src/keyboardshortcuts/register.sh", "PENDING"},
        {"Enable services", "scripts/06-services.sh", "PENDING"},
        {"Configure KDE apps", "scripts/07-kde-apps.sh", "PENDING"},
        {"Build shell", "scripts/08-build-shell.sh", "PENDING"},
        {"System tweaks", "scripts/09-system-tweaks.sh", "PENDING"},
        {"Autostart entries", "scripts/10-autostart.sh", "PENDING"},
    };

    string show_error_dialog(const string& step_name, int term_w, int term_h) {
        int w = 50, h = 8;
        int x = (term_w - w) / 2;
        int y = (term_h - h) / 2;
        int selected = 0;
        vector<string> opts = {"Retry", "Ignore", "Exit"};

        while (true) {
            if (g_resized) { Term::get_size(); g_resized = false; x = (g_term_width - w) / 2; y = (g_term_height - h) / 2; }
            
            cout << Draw::sync_start();
            for(int i=0; i<h; ++i) {
                cout << Draw::to(y+i, x) << string(w, ' ');
            }
            Draw::box(x, y, w, h, "ERROR", Draw::red);
            Draw::text(x + 2, y + 2, "Step failed: " + step_name, Draw::white);
            
            for (size_t i = 0; i < opts.size(); ++i) {
                if (i == selected) {
                    Draw::text(x + 5 + i*12, y + 5, "> " + opts[i], Draw::green);
                } else {
                    Draw::text(x + 5 + i*12, y + 5, "  " + opts[i]);
                }
            }
            cout << Draw::sync_end() << flush;
            
            string key = Input::wait_key();
            if (key == "KEY_left") { if (selected > 0) selected--; }
            else if (key == "KEY_right") { if (selected < opts.size() - 1) selected++; }
            else if (key == "enter") return opts[selected];
        }
    }

    void draw_progress_ui(int current_step) {
        if (g_resized) { Term::get_size(); g_resized = false; }
        cout << Draw::sync_start() << Draw::clear();
        
        int w = g_term_width;
        int h = g_term_height;
        
        string title = " INSTALLATION PROGRESS ";
        int pad = (w - title.length()) / 2;
        Draw::text(pad, 1, title, Draw::bold + Draw::cyan);
        
        int bar_w = w - 20;
        int progress = (current_step * bar_w) / steps.size();
        string bar = string(progress, '=') + (progress < bar_w ? ">" : "") + string(max(0, bar_w - progress - 1), ' ');
        Draw::text(2, 2, "[" + bar + "] " + to_string(current_step) + "/" + to_string(steps.size()));

        int lw = w - 4; // Use full width of the pane
        Draw::box(1, 4, lw, h - 4, "STEPS");
        for (size_t i = 0; i < steps.size(); ++i) {
            int y = 5 + i;
            if (y >= h - 1) break;
            string status_mark = "[ ]";
            string color = "";
            if (steps[i].status == "RUNNING") { status_mark = "[*]"; color = Draw::yellow; }
            else if (steps[i].status == "OK") { status_mark = "[OK]"; color = Draw::green; }
            else if (steps[i].status == "FAILED") { status_mark = "[!!]"; color = Draw::red; }
            else if (steps[i].status == "IGNORED") { status_mark = "[!!]"; color = Draw::dim; }
            
            string text = status_mark + " " + steps[i].name;
            if (text.length() > lw - 4) text = text.substr(0, lw - 7) + "...";
            Draw::text(3, y, text, color);
        }

        cout << Draw::sync_end() << flush;
    }

    void execute() {
        string cache_dir = string(getenv("XDG_CACHE_HOME") ? getenv("XDG_CACHE_HOME") : (string(getenv("HOME")) + "/.cache")) + "/caelestia-kde";
        setenv("CACHE_DIR", cache_dir.c_str(), 1);
        setenv("BUILDDIR", (cache_dir + "/makepkg-build").c_str(), 1);
        setenv("PKGDEST", (cache_dir + "/makepkg-packages").c_str(), 1);
        setenv("SRCDEST", (cache_dir + "/makepkg-sources").c_str(), 1);
        setenv("SRCPKGDEST", (cache_dir + "/makepkg-srcpackages").c_str(), 1);

        system(("mkdir -p \"" + cache_dir + "\" \"$BUILDDIR\" \"$PKGDEST\" \"$SRCDEST\" \"$SRCPKGDEST\"").c_str());
        system(("rm -f \"" + cache_dir + "/failed_steps.txt\" \"" + cache_dir + "/failed_packages.txt\"").c_str());

        setenv("BASE_DISTRO", g_base_distro.c_str(), 1);
        setenv("BUNDLE_DIR", g_bundle_dir.c_str(), 1);
        
        // Inject our sudo wrapper into the PATH
        string current_path = getenv("PATH") ? getenv("PATH") : "/usr/bin";
        setenv("PATH", ("/tmp/caelestia_bin:" + current_path).c_str(), 1);
        
        setenv("CONFIRM_ARG", g_config.enable_transaction_confirm ? "-y" : "", 1);
        setenv("REMOVE_CACHE", g_config.remove_cache ? "true" : "false", 1);
        setenv("ENABLE_POLONIUM", g_config.enable_polonium ? "true" : "false", 1);
        setenv("APPLY_DARKLY", g_config.apply_darkly ? "true" : "false", 1);
        setenv("ENABLE_MATYOU", g_config.enable_material_you ? "true" : "false", 1);
        setenv("APPLY_FONTS", g_config.apply_custom_fonts ? "true" : "false", 1);
        
        if (getenv("CAELESTIA_TMUX_MASTER") != nullptr) {
            system("tmux split-window -h -t caelestia_install \"bash -c 'clear; echo \\\"Waiting for installer...\\\"; exec 3<> /tmp/caelestia_cmd; while read -u 3 -r cmd; do if [[ \\\"\\$cmd\\\" == \\\"EXIT\\\" ]]; then break; fi; eval \\\"\\$cmd\\\"; echo \\$? > /tmp/caelestia_status; done'\"");
            system("tmux select-pane -t caelestia_install:0.0");
            this_thread::sleep_for(chrono::milliseconds(50)); // tiny wait for terminal resize propagation
            g_resized = true; // force UI redraw after split
        }

        for (size_t i = 0; i < steps.size(); ++i) {
retry_step:
            steps[i].status = "RUNNING";
            draw_progress_ui(i);
            
            string cmd = "bash " + g_bundle_dir + "/" + steps[i].script_path;
            
            // Forward command to the right pane
            if (getenv("CAELESTIA_TMUX_MASTER") != nullptr) {
                FILE* cmd_fifo = fopen("/tmp/caelestia_cmd", "w");
                if (cmd_fifo) {
                    string exports = "export PATH=\"/tmp/caelestia_bin:$PATH\" SUDO_ASKPASS=\"/tmp/caelestia_askpass.sh\"";
                    exports += " CACHE_DIR=\"" + string(getenv("CACHE_DIR")) + "\"";
                    exports += " BUILDDIR=\"" + string(getenv("BUILDDIR")) + "\"";
                    exports += " PKGDEST=\"" + string(getenv("PKGDEST")) + "\"";
                    exports += " SRCDEST=\"" + string(getenv("SRCDEST")) + "\"";
                    exports += " SRCPKGDEST=\"" + string(getenv("SRCPKGDEST")) + "\"";
                    exports += " BASE_DISTRO=\"" + string(getenv("BASE_DISTRO")) + "\"";
                    exports += " BUNDLE_DIR=\"" + string(getenv("BUNDLE_DIR")) + "\"";
                    exports += " CONFIRM_ARG=\"" + string(getenv("CONFIRM_ARG")) + "\"";
                    exports += " REMOVE_CACHE=\"" + string(getenv("REMOVE_CACHE")) + "\"";
                    exports += " ENABLE_POLONIUM=\"" + string(getenv("ENABLE_POLONIUM")) + "\"";
                    exports += " APPLY_DARKLY=\"" + string(getenv("APPLY_DARKLY")) + "\"";
                    exports += " ENABLE_MATYOU=\"" + string(getenv("ENABLE_MATYOU")) + "\"";
                    exports += " APPLY_FONTS=\"" + string(getenv("APPLY_FONTS")) + "\"";
                    
                    
                    // Send as a single compound command so the listener evaluates it all at once and replies once
                    fprintf(cmd_fifo, "%s; echo -e '\\033[1;36m==> Running: %s\\033[0m'; %s\n", exports.c_str(), steps[i].name.c_str(), cmd.c_str());
                    fflush(cmd_fifo);
                    fclose(cmd_fifo);
                }

                // Continuously check for status or terminal resizes
                int exit_code = -1;
                while (true) {
                    if (g_resized) draw_progress_ui(i);
                    FILE* status_fifo = fopen("/tmp/caelestia_status", "r");
                    if (status_fifo) {
                        int fd = fileno(status_fifo);
                        int flags = fcntl(fd, F_GETFL, 0);
                        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
                        
                        char buf[32];
                        if (fgets(buf, sizeof(buf), status_fifo) != nullptr) {
                            exit_code = atoi(buf);
                            fclose(status_fifo);
                            break;
                        }
                        fclose(status_fifo);
                    }
                    this_thread::sleep_for(chrono::milliseconds(100));
                    
                    // Handle Ctrl+C gracefully
                    fd_set fds;
                    FD_ZERO(&fds);
                    FD_SET(STDIN_FILENO, &fds);
                    timeval tv{0, 0};
                    if (select(STDIN_FILENO + 1, &fds, nullptr, nullptr, &tv) > 0) {
                        char c;
                        if (read(STDIN_FILENO, &c, 1) > 0 && c == 3) { // Ctrl+C
                            Term::restore();
                            system("rm -rf /tmp/caelestia_pass.txt /tmp/caelestia_askpass.sh /tmp/caelestia_bin");
                            exit(130);
                        }
                    }
                }

                if (exit_code == 0) {
                    steps[i].status = "OK";
                } else {
                    steps[i].status = "FAILED";
                    draw_progress_ui(i);
                    
                    string action = show_error_dialog(steps[i].name, g_term_width, g_term_height);
                    if (action == "Retry") {
                        goto retry_step;
                    } else if (action == "Ignore") {
                        steps[i].status = "IGNORED";
                    } else {
                        Term::restore();
                        exit(1);
                    }
                }
            } else {
                // Fallback if not in tmux
                int status = system(cmd.c_str());
                if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                    steps[i].status = "OK";
                } else {
                    steps[i].status = "FAILED";
                    draw_progress_ui(i);
                    
                    string action = show_error_dialog(steps[i].name, g_term_width, g_term_height);
                    if (action == "Retry") {
                        goto retry_step;
                    } else if (action == "Ignore") {
                        steps[i].status = "IGNORED";
                    } else {
                        Term::restore();
                        exit(1);
                    }
                }
            }
        }
        
        draw_progress_ui(steps.size());
        this_thread::sleep_for(chrono::seconds(2));
    }
}
