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

    void draw_progress_ui(int current_step, const deque<string>& log_lines, const string& current_line) {
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

        int lw = w * 0.35;
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

        int rw = w - lw - 1;
        Draw::box(lw + 2, 4, rw, h - 4, "LOGS");
        int log_h = h - 6;
        
        vector<string> render_lines(log_lines.begin(), log_lines.end());
        if (!current_line.empty()) {
            render_lines.push_back(current_line);
        }
        
        int start_idx = max(0, (int)render_lines.size() - log_h);
        for (int i = 0; i < log_h && start_idx + i < render_lines.size(); ++i) {
            string line = render_lines[start_idx + i];
            string filtered = "";
            size_t k = 0;
            while (k < line.length()) {
                if (line[k] == '\x1b') {
                    if (k + 1 < line.length() && line[k+1] == '[') {
                        // CSI sequence
                        size_t end = k + 2;
                        while (end < line.length() && !isalpha(line[end]) && line[end] != '~') end++;
                        if (end < line.length() && line[end] == 'm') {
                            filtered += line.substr(k, end - k + 1); // Keep color
                        }
                        k = end + 1;
                    } else if (k + 1 < line.length() && line[k+1] == ']') {
                        // OSC sequence
                        size_t end = k + 2;
                        while (end < line.length() && line[end] != '\x07' && line[end] != '\x1b') end++;
                        if (end < line.length() && line[end] == '\x1b' && end + 1 < line.length() && line[end+1] == '\\') end++;
                        k = end + 1;
                    } else {
                        k++; // Unknown escape, just skip the ESC char
                    }
                } else if (line[k] != '\b' && line[k] != '\r') {
                    filtered += line[k];
                    k++;
                } else {
                    k++;
                }
            }
            
            // Length calculation must ignore the remaining ANSI color codes
            int vis_len = 0;
            k = 0;
            while (k < filtered.length()) {
                if (filtered[k] == '\x1b' && k + 1 < filtered.length() && filtered[k+1] == '[') {
                    size_t end = k + 2;
                    while (end < filtered.length() && !isalpha(filtered[end])) end++;
                    k = end + 1;
                } else {
                    vis_len++;
                    k++;
                }
            }
            
            // Truncate safely without breaking ANSI
            if (vis_len > rw - 4) {
                // We must truncate the visible characters, not the raw string length!
                string trunc_filtered = "";
                int current_vis = 0;
                size_t idx = 0;
                while (idx < filtered.length() && current_vis < rw - 4) {
                    if (filtered[idx] == '\x1b' && idx + 1 < filtered.length() && filtered[idx+1] == '[') {
                        size_t end = idx + 2;
                        while (end < filtered.length() && !isalpha(filtered[end])) end++;
                        trunc_filtered += filtered.substr(idx, end - idx + 1);
                        idx = end + 1;
                    } else {
                        trunc_filtered += filtered[idx];
                        current_vis++;
                        idx++;
                    }
                }
                filtered = trunc_filtered + "\x1b[0m"; // Ensure colors reset
            }
            Draw::text(lw + 4, 5 + i, filtered);
        }

        cout << Draw::sync_end() << flush;
    }

    void execute() {
        deque<string> log_lines;
        
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

        for (size_t i = 0; i < steps.size(); ++i) {
retry_step:
            steps[i].status = "RUNNING";
            draw_progress_ui(i, log_lines);
            
            string cmd = "bash " + g_bundle_dir + "/" + steps[i].script_path;
            
            int master;
            struct winsize ws;
            int w = g_term_width - 10;
            int h = g_term_height - 6;
            int lw = w / 2;
            int rw = w - lw - 1;
            int log_h = h - 6;
            ws.ws_col = 120;
            ws.ws_row = log_h;
            ws.ws_xpixel = 0;
            ws.ws_ypixel = 0;
            pid_t pid = forkpty(&master, nullptr, nullptr, &ws);
            if (pid == 0) {
                // child
                execl("/bin/bash", "bash", "-c", cmd.c_str(), nullptr);
                exit(1);
            }
            
            // Disable ONLCR on the PTY after creation so we don't inherit raw mode from STDIN
            termios tio;
            tcgetattr(master, &tio);
            tio.c_oflag &= ~ONLCR;
            tcsetattr(master, TCSANOW, &tio);

            
            // Ignore SIGPIPE so writing to closed master doesn't crash the installer
            signal(SIGPIPE, SIG_IGN);

            int fd = master;
            int in_fd = master;
            
            int flags = fcntl(fd, F_GETFL, 0);
            fcntl(fd, F_SETFL, flags | O_NONBLOCK);

            char buffer[1024];
            string line_buf;
            int ansi_state = 0;
            string ansi_seq = "";
            
            while (true) {
                fd_set fds;
                FD_ZERO(&fds);
                FD_SET(STDIN_FILENO, &fds);
                FD_SET(fd, &fds);
                
                timeval tv{0, 100000}; // 100ms
                int max_fd = max(STDIN_FILENO, fd);
                
                int res = select(max_fd + 1, &fds, nullptr, nullptr, &tv);
                if (res > 0) {
                    if (FD_ISSET(STDIN_FILENO, &fds)) {
                        char buf[256];
                        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
                        if (n > 0) {
                            if (n == 1 && buf[0] == 3) { // Ctrl+C
                                Term::restore();
                                system("rm -rf /tmp/caelestia_pass.txt /tmp/caelestia_askpass.sh /tmp/caelestia_bin");
                                kill(pid, SIGINT);
                                exit(130);
                            }
                            // Convert \r to \n since terminal is in raw mode
                            for (ssize_t k = 0; k < n; ++k) {
                                if (buf[k] == '\r') buf[k] = '\n';
                            }
                            write(in_fd, buf, n);
                        }
                    }
                    if (FD_ISSET(fd, &fds)) {
                        ssize_t n = read(fd, buffer, sizeof(buffer));
                        if (n > 0) {
                            for (ssize_t j = 0; j < n; ++j) {
                                char c = buffer[j];
                                if (ansi_state == 0) {
                                    if (c == '\x1b') {
                                        ansi_state = 1;
                                    } else if (c == '\n') {
                                        log_lines.push_back(line_buf);
                                        if (log_lines.size() > 500) log_lines.pop_front();
                                        line_buf.clear();
                                        draw_progress_ui(i, log_lines);
                                    } else if (c == '\r') {
                                        draw_progress_ui(i, log_lines, line_buf);
                                        line_buf.clear();
                                    } else if (c == '\b' || c == 127) {
                                        if (!line_buf.empty()) line_buf.pop_back();
                                    } else {
                                        line_buf += c;
                                    }
                                } else if (ansi_state == 1) {
                                    if (c == '[') {
                                        ansi_state = 2;
                                        ansi_seq = "";
                                    } else {
                                        ansi_state = 0; // abort, likely not a CSI sequence
                                        line_buf += '\x1b';
                                        line_buf += c;
                                    }
                                } else if (ansi_state == 2) {
                                    if (isalpha(c) || c == '~') {
                                        if (c == 'A') { // Cursor up
                                            int count = ansi_seq.empty() ? 1 : atoi(ansi_seq.c_str());
                                            if (count <= 0) count = 1;
                                            if (!line_buf.empty()) { log_lines.push_back(line_buf); line_buf.clear(); }
                                            for (int x = 0; x < count; ++x) {
                                                if (!log_lines.empty()) {
                                                    line_buf = log_lines.back();
                                                    log_lines.pop_back();
                                                }
                                            }
                                        } else if (c == 'B') { // Cursor down
                                            int count = ansi_seq.empty() ? 1 : atoi(ansi_seq.c_str());
                                            if (count <= 0) count = 1;
                                            for (int x = 0; x < count; ++x) {
                                                log_lines.push_back(line_buf);
                                                line_buf.clear();
                                            }
                                        } else if (c == 'K') { // Erase line
                                            line_buf.clear();
                                        } else if (c == 'm') { // Color
                                            line_buf += "\x1b[" + ansi_seq + "m";
                                        }
                                        ansi_state = 0;
                                    } else {
                                        ansi_seq += c;
                                    }
                                }
                            }
                            // Render partial lines immediately (e.g. for [Y/n] prompts)
                            if (!line_buf.empty()) {
                                draw_progress_ui(i, log_lines, line_buf);
                            }
                        } else if (n == 0) { // EOF
                            break;
                        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                            break;
                        }
                    }
                }
                if (g_resized) draw_progress_ui(i, log_lines, line_buf);
            }
            if (!line_buf.empty()) {
                log_lines.push_back(line_buf);
                draw_progress_ui(i, log_lines);
            }
            
            close(fd);
            close(in_fd);
            
            int status;
            waitpid(pid, &status, 0);
            int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

            if (exit_code == 0) {
                steps[i].status = "OK";
            } else {
                steps[i].status = "FAILED";
                draw_progress_ui(i, log_lines);
                
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
        
        draw_progress_ui(steps.size(), log_lines);
        this_thread::sleep_for(chrono::seconds(2));
    }
}
