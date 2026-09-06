package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	os.Exit(run())
}

func run() int {
	bundleDir := detectBundleDir()
	presetAction := ""
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--update":
			presetAction = "update"
		case "--uninstall":
			presetAction = "uninstall"
		default:
			bundleDir = os.Args[1]
		}
	}

	fmt.Fprintf(os.Stderr, "[installer] bundle dir: %s\n", bundleDir)

	// Update and uninstall hand the terminal straight to their scripts.
	if presetAction == "update" || presetAction == "uninstall" {
		return runExternalScript(filepath.Join(bundleDir, presetAction+".sh"))
	}

	cfg, err := loadConfig(bundleDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] failed to load config: %v\n", err)
		return 1
	}

	m := initialModel(cfg, bundleDir, os.Getenv("BASE_DISTRO"))
	p := tea.NewProgram(m, tea.WithAltScreen(), tea.WithoutSignalHandler())

	signals := make(chan os.Signal, 2)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	done := make(chan struct{})
	go func() {
		for {
			select {
			case <-done:
				return
			case <-signals:
				p.Send(interruptMsg{})
			}
		}
	}()

	final, err := p.Run()
	close(done)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] error: %v\n", err)
		return 1
	}
	fm := final.(model)

	// The action screen may have handed off to update.sh / uninstall.sh.
	if fm.actionResult == "update" || fm.actionResult == "uninstall" {
		return runExternalScript(filepath.Join(bundleDir, fm.actionResult+".sh"))
	}

	if fm.exitCode != 0 {
		return fm.exitCode
	}
	if fm.actionResult == "exit" {
		fmt.Println("\nExiting installer.")
		return 0
	}

	// Secure cleanup of sudo credentials and, when requested, the build cache.
	if fm.answers["REMOVE_CACHE"] == "true" {
		_ = os.RemoveAll(fm.cacheDir())
	}
	if fm.sudoBinDir != "" {
		_ = os.RemoveAll(fm.sudoBinDir)
	}

	if fm.logout {
		fmt.Println("\nLogging out...")
		_ = exec.Command("qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout").Run()
	} else {
		fmt.Println("\nCaelestia installation complete. Remember to log out to activate your new session.")
	}

	// Completion marker setup.sh parses to distinguish success from early exit.
	fmt.Fprintln(os.Stderr, "[installer] done (success)")
	return 0
}

func detectBundleDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	dir := filepath.Dir(exe)
	if dir == "" {
		return "."
	}
	return dir
}
