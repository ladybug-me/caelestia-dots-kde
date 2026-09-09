// Package progress runs the install steps in order, showing a spinner,
// progress bar, and live tail of the current step's output.
package progress

import (
	"fmt"
	"os"
	"strings"
	"time"

	bprogress "charm.land/bubbles/v2/progress"
	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/complete"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/logview"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/util"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

var spinnerFrames = []string{"|", "/", "-", "\\"}

type tickMsg struct{}

type stepFinishedMsg struct {
	exitCode    int
	startFailed bool
}

// Model runs the install steps in order. It implements app.Interruptible so
// Ctrl+C can ask the current step's process to stop.
type Model struct {
	ctx *app.Context

	statuses        []string
	current         int
	spinner         int
	stepStartOffset int64
	logPath         string
	handle          *runner.StepHandle

	dialog    bool
	detail    []string
	errCursor int

	started   bool
	startTime time.Time
	stepStart time.Time
	liveLines []string

	bar bprogress.Model
}

// New prepares the install environment and builds the step list. The first
// step is started from Init, once the screen is actually pushed.
func New(ctx *app.Context) *Model {
	runner.ExportAnswers(ctx.Answers)
	runner.PersistInstallEnv(ctx.Answers)
	cacheDir := runner.CacheDir()
	_ = runner.PrepareInstallEnv(cacheDir, ctx.BaseDistro, ctx.BundleDir, ctx.SudoBinDir)

	statuses := make([]string, len(ctx.Cfg.Manifest.Steps))
	for i := range statuses {
		statuses[i] = manifest.StatusPending
	}

	bar := bprogress.New(
		bprogress.WithColors(ctx.Theme.Color("seed"), ctx.Theme.Color("secondary")),
		bprogress.WithFillCharacters('█', '░'),
	)
	bar.SetWidth(progressBarWidth(ctx.Width))

	return &Model{
		ctx:       ctx,
		statuses:  statuses,
		logPath:   runner.InstallLogPath(cacheDir),
		startTime: time.Now(),
		bar:       bar,
	}
}

func (m *Model) Init() tea.Cmd {
	if !m.started {
		m.started = true
		return tea.Batch(m.tickCmd(), m.startStepCmd(0))
	}
	return m.tickCmd()
}

// Interrupt terminates the currently running step's process, if any.
func (m *Model) Interrupt() {
	if m.handle != nil && m.handle.Cmd != nil {
		runner.SignalTerminate(m.handle.Cmd.Process)
	}
}

func (m *Model) tickCmd() tea.Cmd {
	return tea.Tick(200*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
}

func (m *Model) startStepCmd(i int) tea.Cmd {
	if i >= len(m.statuses) {
		return nil
	}
	m.current = i
	percentCmd := m.bar.SetPercent(float64(i) / float64(len(m.statuses)))

	step := m.ctx.Cfg.Manifest.Steps[i]
	if manifest.StepIsSkipped(step, m.ctx.Answers) {
		m.statuses[i] = manifest.StatusSkipped
		return tea.Batch(percentCmd, m.advanceStepCmd())
	}

	m.statuses[i] = manifest.StatusRunning
	m.stepStart = time.Now()
	m.liveLines = nil
	if fi, err := os.Stat(m.logPath); err == nil {
		m.stepStartOffset = fi.Size()
	}

	handle, err := runner.StartStep(m.ctx.BundleDir, step, m.logPath)
	if err != nil {
		return tea.Batch(percentCmd, func() tea.Msg {
			return stepFinishedMsg{exitCode: 127, startFailed: true}
		})
	}
	m.handle = handle
	waitCmd := func() tea.Msg { return stepFinishedMsg{exitCode: handle.Wait()} }
	return tea.Batch(percentCmd, waitCmd)
}

func (m *Model) advanceStepCmd() tea.Cmd {
	next := m.current + 1
	if next >= len(m.statuses) {
		return app.Push(complete.New(m.ctx))
	}
	return m.startStepCmd(next)
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tickMsg:
		m.spinner = (m.spinner + 1) % len(spinnerFrames)
		if m.current < len(m.statuses) && m.statuses[m.current] == manifest.StatusRunning {
			m.refreshLive()
		}
		return m, m.tickCmd()

	case stepFinishedMsg:
		return m.handleStepFinished(msg)

	case bprogress.FrameMsg:
		updated, cmd := m.bar.Update(msg)
		m.bar = updated
		return m, cmd

	case tea.KeyPressMsg:
		return m.handleKey(msg.String())
	}
	return m, nil
}

func (m *Model) handleStepFinished(msg stepFinishedMsg) (tea.Model, tea.Cmd) {
	i := m.current
	if msg.exitCode == 0 {
		delta := runner.ReadLogDelta(m.logPath, m.stepStartOffset)
		if runner.ContainsWarn(delta) {
			m.statuses[i] = manifest.StatusWarn
		} else {
			m.statuses[i] = manifest.StatusOK
		}
		return m, m.advanceStepCmd()
	}

	m.statuses[i] = manifest.StatusFailed
	if msg.startFailed {
		m.detail = []string{"Could not start the step script."}
	} else {
		m.detail = runner.ReadLogTailLines(m.logPath, 10)
	}
	m.errCursor = 0
	m.dialog = true
	return m, nil
}

func (m *Model) handleKey(key string) (tea.Model, tea.Cmd) {
	if m.dialog {
		switch key {
		case "left":
			if m.errCursor > 0 {
				m.errCursor--
			}
		case "right":
			if m.errCursor < 2 {
				m.errCursor++
			}
		case "enter", "space":
			switch m.errCursor {
			case 0: // Retry
				m.dialog = false
				return m, m.startStepCmd(m.current)
			case 1: // Ignore
				m.statuses[m.current] = manifest.StatusIgnored
				m.dialog = false
				return m, m.advanceStepCmd()
			case 2: // Exit
				m.ctx.ExitCode = 1
				return m, tea.Quit
			}
		case "esc":
			m.ctx.ExitCode = 1
			return m, tea.Quit
		}
		return m, nil
	}

	switch key {
	case "l", "L", "shift+tab":
		return m, app.Push(logview.New(m.ctx, m.logPath))
	}
	return m, nil
}

func (m *Model) refreshLive() {
	delta := runner.ReadLogDelta(m.logPath, m.stepStartOffset)
	var out []string
	for _, l := range strings.Split(delta, "\n") {
		out = append(out, util.StripANSI(l))
	}
	if len(out) > 40 {
		out = out[len(out)-40:]
	}
	m.liveLines = out
}

func progressBarWidth(width int) int {
	w := width - 10
	if w < 12 {
		w = 12
	}
	if w > 72 {
		w = 72
	}
	return w
}

func (m *Model) runningTime() string {
	return fmt.Sprintf("Step: %s   Total: %s", formatDuration(time.Since(m.stepStart)), formatDuration(time.Since(m.startTime)))
}

func formatDuration(d time.Duration) string {
	d = d.Round(time.Second)
	h := d / time.Hour
	d -= h * time.Hour
	mm := d / time.Minute
	d -= mm * time.Minute
	s := d / time.Second
	switch {
	case h > 0:
		return fmt.Sprintf("%dh%02dm%02ds", h, mm, s)
	case mm > 0:
		return fmt.Sprintf("%dm%02ds", mm, s)
	default:
		return fmt.Sprintf("%ds", s)
	}
}

func (m *Model) renderLiveLine(l string) string {
	fitted := util.Fit(l, m.ctx.Width-4)
	switch {
	case strings.Contains(l, "[ERR]"):
		return m.ctx.Theme.Error.Render(fitted)
	case strings.Contains(l, "[WARN]"):
		return m.ctx.Theme.Warning.Render(fitted)
	default:
		return m.ctx.Theme.Subtle.Render(fitted)
	}
}

func (m *Model) View() tea.View {
	if m.dialog {
		return tea.NewView(m.viewErrorDialog())
	}

	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Installing")

	step := m.ctx.Cfg.Manifest.Steps[m.current]
	phaseName := step.Phase
	for _, p := range m.ctx.Cfg.Manifest.Phases {
		if p.ID == step.Phase {
			phaseName = p.Name
			break
		}
	}

	fmt.Fprintf(&b, "%s %s: %s\n\n", spinnerFrames[m.spinner], phaseName, step.Name)
	b.WriteString(m.ctx.Theme.Subtle.Render(m.runningTime()))
	b.WriteString("\n\n")

	m.bar.SetWidth(progressBarWidth(m.ctx.Width))
	b.WriteString(m.bar.View())
	b.WriteByte('\n')
	fmt.Fprintf(&b, "Step %d of %d\n\n", m.current+1, len(m.statuses))
	b.WriteString(m.ctx.Theme.Subtle.Render("$ bash " + step.Script))
	b.WriteByte('\n')

	if len(m.liveLines) > 0 {
		b.WriteByte('\n')
		b.WriteString(m.ctx.Theme.SectionLabel("Live output"))
		b.WriteByte('\n')
		start := 0
		if len(m.liveLines) > 8 {
			start = len(m.liveLines) - 8
		}
		for _, l := range m.liveLines[start:] {
			b.WriteString(m.renderLiveLine(l))
			b.WriteByte('\n')
		}
	}

	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "L", " for the full log, ", "Ctrl+C", " to cancel")
	return tea.NewView(b.String())
}

func (m *Model) viewErrorDialog() string {
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Installation Error")

	step := m.ctx.Cfg.Manifest.Steps[m.current]
	fmt.Fprintf(&b, "%s failed.\n", step.Name)
	b.WriteString(m.ctx.Theme.Subtle.Render("$ bash " + step.Script))
	b.WriteString("\n\n")
	for _, l := range m.detail {
		b.WriteString(m.ctx.Theme.Subtle.Render(l))
		b.WriteByte('\n')
	}
	b.WriteByte('\n')

	buttons := []string{"Retry", "Ignore", "Exit"}
	for i, label := range buttons {
		if i == m.errCursor {
			b.WriteString(m.ctx.Theme.Button.Render(" " + label + " "))
		} else {
			b.WriteString(m.ctx.Theme.Subtle.Render(" " + label + " "))
		}
		b.WriteString("  ")
	}
	b.WriteString("\n\n")
	widgets.RenderFooter(&b, m.ctx.Theme, "←/→", " to choose, ", "Enter", " to confirm, ", "Esc", " to exit")
	return b.String()
}
