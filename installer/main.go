package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/welcome"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/theme"
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

	cfg, err := config.Load(bundleDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] failed to load config: %v\n", err)
		return 1
	}

	ctx := &app.Context{
		Cfg:        cfg,
		Theme:      theme.New(cfg, true),
		IsDark:     true,
		Answers:    map[string]string{},
		BundleDir:  bundleDir,
		BaseDistro: os.Getenv("BASE_DISTRO"),
	}

	router := app.NewRouter(ctx, welcome.New(ctx))
	p := tea.NewProgram(router, tea.WithoutSignalHandler())

	signals := make(chan os.Signal, 2)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	done := make(chan struct{})
	go func() {
		for {
			select {
			case <-done:
				return
			case <-signals:
				p.Send(app.InterruptMsg{})
			}
		}
	}()

	_, err = p.Run()
	close(done)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] error: %v\n", err)
		return 1
	}

	// The action screen may have handed off to update.sh / uninstall.sh.
	if ctx.ActionResult == "update" || ctx.ActionResult == "uninstall" {
		return runExternalScript(filepath.Join(bundleDir, ctx.ActionResult+".sh"))
	}

	if ctx.ExitCode != 0 {
		return ctx.ExitCode
	}
	if ctx.ActionResult == "exit" {
		fmt.Println("\nExiting installer.")
		return 0
	}

	// Secure cleanup of sudo credentials and, when requested, the build cache.
	if ctx.Answers["REMOVE_CACHE"] == "true" {
		_ = os.RemoveAll(runner.CacheDir())
	}
	if ctx.SudoBinDir != "" {
		_ = os.RemoveAll(ctx.SudoBinDir)
	}

	if ctx.Logout {
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

// runExternalScript hands the restored terminal to update.sh / uninstall.sh
// and returns the script's exit code.
func runExternalScript(scriptPath string) int {
	cmd := exec.Command("bash", scriptPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err == nil {
		return 0
	} else if ee, ok := err.(*exec.ExitError); ok {
		return ee.ExitCode()
	}
	return 1
}

