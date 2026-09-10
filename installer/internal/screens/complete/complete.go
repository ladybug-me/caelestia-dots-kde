// Package complete is the final screen: a summary of what happened, quick
// shortcuts, and a log-out prompt.
package complete

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/logview"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type Model struct {
	ctx *app.Context

	logPath     string
	startEpoch  int64
	failedPkgs  []string
	shellFailed bool
}

// New reads the cache-dir bookkeeping files the step scripts leave behind to
// summarize what happened during install.
func New(ctx *app.Context) Model {
	cacheDir := runner.CacheDir()
	return Model{
		ctx:         ctx,
		logPath:     runner.InstallLogPath(cacheDir),
		startEpoch:  runner.ParseEpoch(os.Getenv("INSTALL_START_EPOCH")),
		failedPkgs:  runner.ReadLines(filepath.Join(cacheDir, "failed_packages.txt")),
		shellFailed: runner.FileContains(filepath.Join(cacheDir, "failed_steps.txt"), "Build Caelestia Shell"),
	}
}

func (m Model) Init() tea.Cmd { return nil }

func (m Model) hasErrors() bool {
	return len(m.failedPkgs) > 0 || m.shellFailed
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "y", "Y", "enter":
		m.ctx.Logout = true
		m.ctx.ExitCode = 0
		return m, tea.Quit
	case "n", "N", "esc":
		m.ctx.Logout = false
		m.ctx.ExitCode = 0
		return m, tea.Quit
	case "l", "L":
		return m, app.Push(logview.New(m.ctx, m.logPath))
	}
	return m, nil
}

func (m Model) View() tea.View {
	var b strings.Builder
	verb := "Installation"
	if m.ctx.Action == "uninstall" {
		verb = "Uninstall"
	}
	title := verb + " Complete"
	if m.hasErrors() {
		title = verb + " Finished With Issues"
	}
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, title)

	if m.startEpoch > 0 {
		elapsed := time.Since(time.Unix(m.startEpoch, 0)).Round(time.Second)
		b.WriteString(m.ctx.Theme.Subtle.Render("Elapsed: " + elapsed.String()))
		b.WriteString("\n\n")
	}

	if m.hasErrors() {
		var issues strings.Builder
		issues.WriteString("Attention needed:\n")
		if m.shellFailed {
			issues.WriteString("- Building the Caelestia shell failed.\n")
		}
		for _, p := range m.failedPkgs {
			fmt.Fprintf(&issues, "- Package failed: %s\n", p)
		}
		b.WriteString(m.ctx.Theme.ErrorBox.Render(strings.TrimRight(issues.String(), "\n")))
		b.WriteString("\n\n")
	}

	if m.ctx.Action == "uninstall" {
		b.WriteString(m.ctx.Theme.SectionLabel("Next steps"))
		b.WriteByte('\n')
		b.WriteString(m.ctx.Theme.Normal.Render("  Log out and back in to return to your previous desktop session."))
		b.WriteString("\n\n")
	} else {
		b.WriteString(m.ctx.Theme.SectionLabel("Quick start & shortcuts"))
		b.WriteByte('\n')
		for _, s := range []string{
			"Super            Application launcher",
			"Super+Q          Close window",
			"Super+Return     Terminal",
			"Super+E          File manager",
			"Super+L          Lock screen",
			"Super+Shift+S    Screenshot",
		} {
			b.WriteString(m.ctx.Theme.Normal.Render("  " + s))
			b.WriteByte('\n')
		}
		b.WriteByte('\n')

		b.WriteString(m.ctx.Theme.SectionLabel("Next steps"))
		b.WriteByte('\n')
		b.WriteString(m.ctx.Theme.Normal.Render("  Log out and back in for all changes to take effect."))
		b.WriteString("\n\n")
	}

	b.WriteString(m.ctx.Theme.Subtle.Render("Log: " + m.logPath))
	b.WriteString("\n\n")

	widgets.RenderFooter(&b, m.ctx.Theme, "L", " to view the full log, ", "Y/n", " to log out now")
	return tea.NewView(b.String())
}
