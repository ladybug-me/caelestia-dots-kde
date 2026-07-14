#include "Globals.hpp"
#include "Term.hpp"
#include "UI.hpp"
#include "Runner.hpp"
#include <iostream>
#include <csignal>
#include <cstdlib>

using namespace std;

void handle_sigwinch(int) {
    g_resized = true;
}

void handle_sigint(int) {
    g_quit = true;
    Term::restore();
    system("rm -rf /tmp/caelestia_pass.txt /tmp/caelestia_askpass.sh /tmp/caelestia_bin");
    exit(130);
}

int main(int argc, char** argv) {
    // Detect bundle dir from arg or exe path
    if (argc > 1) {
        g_bundle_dir = argv[1];
    } else {
        char buf[1024];
        ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf)-1);
        if (len != -1) {
            buf[len] = '\0';
            string path(buf);
            size_t pos = path.find_last_of('/');
            if (pos != string::npos) {
                g_bundle_dir = path.substr(0, pos);
            }
        }
    }

    load_theme();

    signal(SIGWINCH, handle_sigwinch);
    signal(SIGINT, handle_sigint);
    signal(SIGTERM, handle_sigint);

    Term::init();

    // Phase 1: Splash
    UI::splash_screen();

    // Phase 2: Sudo Auth
    if (!UI::sudo_prompt()) {
        Term::restore();
        return 0;
    }

    // Phase 3: Distro
    const char* env_distro = getenv("BASE_DISTRO");
    if (env_distro && string(env_distro) != "") {
        g_base_distro = env_distro;
    }

    if (g_base_distro == "unknown") {
        string res = UI::distro_select();
        if (res == "Exit") {
            Term::restore();
            return 0;
        } else if (res == "Arch-based") {
            g_base_distro = "arch";
        } else if (res == "Fedora") {
            g_base_distro = "fedora";
        }
    }

    // Phase 4: Checklist
    UI::config_checklist();

    // Phase 5: Execute
    Runner::execute();

    // Phase 6: Finalize
    UI::summary_screen();
    Term::restore();

    if (g_config.remove_cache) {
        string cache_dir = string(getenv("XDG_CACHE_HOME") ? getenv("XDG_CACHE_HOME") : (string(getenv("HOME")) + "/.cache")) + "/caelestia-kde";
        system(("rm -rf \"" + cache_dir + "\"").c_str());
    }
    
    // Secure cleanup of sudo credentials
    system("rm -rf /tmp/caelestia_pass.txt /tmp/caelestia_askpass.sh /tmp/caelestia_bin");

    // Cleanup cmake build cache as it contains absolute paths
    string cmake_cleanup = "rm -rf " + g_bundle_dir + "/shell/build " + g_bundle_dir + "/shell/plugin/build";
    system(cmake_cleanup.c_str());

    if (g_logout) {
        cout << "\n\n\nLogging out...\n";
        system("qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null");
    } else {
        cout << "\n\n\nExiting installer. Please remember to log out manually later.\n";
    }

    return 0;
}
