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
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/sudo"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/welcome"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/theme"
)

func main() {
	os.Exit(run())
}

func run() int {
	bundleDir := detectBundleDir()
	presetAction := ""
	presetArg := ""
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--update":
			presetAction = "update"
			if len(os.Args) > 2 {
				presetArg = os.Args[2]
			}
		case "--uninstall":
			presetAction = "uninstall"
		default:
			bundleDir = os.Args[1]
		}
	}

	fmt.Fprintf(os.Stderr, "[installer] bundle dir: %s\n", bundleDir)

	// Update runs update-steps.json headlessly (no TUI) - update.sh's thin
	// shim calls this for cron/non-interactive use. Uninstall always needs a
	// backup to pick, so --uninstall instead starts the normal interactive
	// TUI, just skipping straight past the Welcome/Action screens (see below).
	if presetAction == "update" {
		return runUpdateHeadless(bundleDir, presetArg)
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

	var start tea.Model = welcome.New(ctx)
	if presetAction == "uninstall" {
		ctx.Action = "uninstall"
		start = sudo.New(ctx)
	}
	router := app.NewRouter(ctx, start)
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

	// The action screen sets ActionResult="exit" when the user picks Exit.
	// Install/Update/Uninstall all run fully inside the TUI now.
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
	} else if ctx.Action == "uninstall" {
		fmt.Println("\nCaelestia uninstall complete. Remember to log out to fully return to your previous session.")
	} else {
		fmt.Println("\nCaelestia installation complete. Remember to log out to activate your new session.")
	}

	// Completion marker setup.sh parses to distinguish success from early exit.
	fmt.Fprintln(os.Stderr, "[installer] done (success)")
	return 0
}

// runUpdateHeadless runs update-steps.json sequentially with no TUI, for
// update.sh's thin cron/non-interactive shim. branch may be empty, in which
// case u00-update-source.sh keeps whatever branch is already checked out.
func runUpdateHeadless(bundleDir, branch string) int {
	cfg, err := config.Load(bundleDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] failed to load config: %v\n", err)
		return 1
	}
	steps, err := config.LoadManifest(bundleDir, "update-steps.json")
	if err != nil {
		fmt.Fprintf(os.Stderr, "[installer] failed to load update-steps.json: %v\n", err)
		return 1
	}
	cfg.Manifest = steps

	answers := runner.LoadInstallEnv()
	if answers == nil {
		answers = map[string]string{}
	}
	if branch != "" {
		answers["UPDATE_BRANCH"] = branch
	}
	runner.ExportAnswers(answers)

	cacheDir := runner.CacheDir()
	if err := runner.PrepareInstallEnv(cacheDir, os.Getenv("BASE_DISTRO"), bundleDir, ""); err != nil {
		fmt.Fprintf(os.Stderr, "[installer] failed to prepare environment: %v\n", err)
		return 1
	}
	logPath := runner.InstallLogPath(cacheDir)

	for _, step := range cfg.Manifest.Steps {
		fmt.Printf("==> %s\n", step.Name)
		var startOffset int64
		if fi, statErr := os.Stat(logPath); statErr == nil {
			startOffset = fi.Size()
		}

		handle, err := runner.StartStep(bundleDir, step, logPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[installer] failed to start %s: %v\n", step.Name, err)
			return 1
		}
		code := handle.Wait()
		fmt.Print(runner.ReadLogDelta(logPath, startOffset))
		if code != 0 {
			fmt.Fprintf(os.Stderr, "[installer] step failed: %s (exit %d)\n", step.Name, code)
			return 1
		}
	}
	fmt.Println("[installer] update complete.")
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

