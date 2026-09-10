package runner

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func writeFileExcl(path, content string, mode os.FileMode) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(content)
	return err
}

func isSystemdInhibit(pid int) bool {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/cmdline", pid))
	if err != nil {
		return false
	}
	return strings.Contains(string(b), "systemd-inhibit")
}

func releaseKDEInhibit(cookieFile string) {
	b, err := os.ReadFile(cookieFile)
	if err != nil {
		return
	}
	value := strings.TrimSpace(strings.Split(string(b), "\n")[0])
	if value == "" {
		return
	}
	_ = exec.Command("qdbus6", "org.freedesktop.ScreenSaver", "/ScreenSaver",
		"org.freedesktop.ScreenSaver.UnInhibit", value).Run()
}

// SetupSudoEnvironment mirrors UI::setup_sudo_environment: it creates a
// per-run askpass + sudo wrapper directory, exports SUDO_PASS, and starts the
// screen/sleep inhibitors. It returns the wrapper directory to clean up later.
func SetupSudoEnvironment(pw, action string) (string, error) {
	dir, err := os.MkdirTemp("/tmp", "caelestia-bin.")
	if err != nil {
		return "", err
	}
	cleanup := func() {
		_ = os.RemoveAll(dir)
	}

	if err := os.WriteFile(filepath.Join(dir, "pass.txt"), []byte(pw+"\n"), 0600); err != nil {
		cleanup()
		return "", err
	}
	askpass := "#!/bin/bash\ncat " + filepath.Join(dir, "pass.txt") + "\n"
	if err := writeFileExcl(filepath.Join(dir, "askpass.sh"), askpass, 0700); err != nil {
		cleanup()
		return "", err
	}
	wrapper := "#!/bin/bash\nexport SUDO_ASKPASS=" + filepath.Join(dir, "askpass.sh") + "\nexec /usr/bin/sudo -A \"$@\"\n"
	if err := writeFileExcl(filepath.Join(dir, "sudo"), wrapper, 0700); err != nil {
		cleanup()
		return "", err
	}

	os.Setenv("SUDO_PASS", pw)

	stateDir := ""
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		stateDir = filepath.Join(runtime, "caelestia")
	} else if xdg := os.Getenv("XDG_STATE_HOME"); xdg != "" {
		stateDir = filepath.Join(xdg, "caelestia")
	} else if home := os.Getenv("HOME"); home != "" {
		stateDir = filepath.Join(home, ".local", "state", "caelestia")
	} else {
		stateDir = "/tmp/caelestia"
	}
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		cleanup()
		return "", err
	}
	_ = os.Chmod(stateDir, 0700)

	pidFile := filepath.Join(stateDir, "inhibit.pid")
	cookieFile := filepath.Join(stateDir, "kde_inhibit.cookie")

	if b, err := os.ReadFile(pidFile); err == nil {
		var pid int
		if _, err := fmt.Sscanf(string(b), "%d", &pid); err == nil && pid > 0 && isSystemdInhibit(pid) {
			if proc, err := os.FindProcess(pid); err == nil {
				_ = proc.Kill()
			}
		}
	}
	releaseKDEInhibit(cookieFile)

	who, why := "Caelestia Installer", "Installation in progress"
	if action == "uninstall" {
		who, why = "Caelestia Uninstaller", "Uninstallation in progress"
	}

	inhibit := exec.Command("systemd-inhibit", "--what=idle:sleep",
		"--who="+who, "--why="+why,
		"bash", "-c", "while :; do sleep 600; done")
	inhibit.SysProcAttr = detachedSysProcAttr()
	if err := inhibit.Start(); err == nil {
		_ = os.WriteFile(pidFile, []byte(fmt.Sprintf("%d\n", inhibit.Process.Pid)), 0600)
	}

	cookie, err := os.OpenFile(cookieFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err == nil {
		c := exec.Command("qdbus6", "org.freedesktop.ScreenSaver", "/ScreenSaver",
			"org.freedesktop.ScreenSaver.Inhibit", who, why)
		c.Stdout = cookie
		_ = c.Run()
		cookie.Close()
	}

	return dir, nil
}

// VerifySudoPassword checks pw against sudo -S without running anything else.
func VerifySudoPassword(pw string) bool {
	cmd := exec.Command("sudo", "-S", "true")
	cmd.Stdin = strings.NewReader(pw + "\n")
	cmd.Stderr = nil
	return cmd.Run() == nil
}
