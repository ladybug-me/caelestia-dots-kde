// Package review shows the full step list (grouped by phase, with skips
// resolved against the current answers) before installation starts.
package review

import (
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/progress"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type Model struct {
	ctx    *app.Context
	scroll int
}

func New(ctx *app.Context) Model { return Model{ctx: ctx} }

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "enter", "space":
		return m, app.Push(progress.New(m.ctx))
	case "esc", "left":
		return m, app.Pop()
	case "up":
		m.scroll -= 3
		if m.scroll < 0 {
			m.scroll = 0
		}
	case "down":
		m.scroll += 3
	}
	return m, nil
}

func (m Model) lines() []string {
	var all []string
	for _, phase := range m.ctx.Cfg.Manifest.Phases {
		all = append(all, m.ctx.Theme.SectionLabel(phase.Name))
		for _, step := range m.ctx.Cfg.Manifest.Steps {
			if step.Phase != phase.ID {
				continue
			}
			status := manifest.StatusPending
			if manifest.StepIsSkipped(step, m.ctx.Answers) {
				status = manifest.StatusSkipped
			}
			all = append(all, "  "+m.ctx.Theme.StatusText(status, fmt.Sprintf("%-7s", status))+" "+step.Name)
		}
	}
	return all
}

func visible(lines []string, top, maxRows int) []string {
	if maxRows < 1 {
		maxRows = 1
	}
	if top < 0 {
		top = 0
	}
	if top > len(lines) {
		top = len(lines)
	}
	end := top + maxRows
	if end > len(lines) {
		end = len(lines)
	}
	return lines[top:end]
}

func (m Model) View() tea.View {
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Review Installation")
	b.WriteString(m.ctx.Theme.Normal.Render("These steps will run in order. Skipped steps are shown but not run."))
	b.WriteString("\n\n")

	all := m.lines()
	maxRows := m.ctx.Height - 12
	for _, l := range visible(all, m.scroll, maxRows) {
		b.WriteString(l)
		b.WriteByte('\n')
	}
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "Enter", " to begin installation, ", "Esc", " to go back")
	return tea.NewView(b.String())
}
