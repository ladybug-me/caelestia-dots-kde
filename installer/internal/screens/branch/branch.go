// Package branch lets the user pick which git branch an update pulls from,
// then swaps in update-steps.json before handing off to the shared
// Review/Progress/Log/Complete flow.
package branch

import (
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/config"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/runner"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/review"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

type branchOption struct{ id, help string }

// options mirrors the allow-list u00-update-source.sh enforces.
var options = []branchOption{
	{id: "main", help: "The stable release branch."},
	{id: "dev", help: "The active development branch - may be unstable."},
}

type Model struct {
	ctx    *app.Context
	cursor int
}

func New(ctx *app.Context) Model { return Model{ctx: ctx} }

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := msg.(tea.KeyPressMsg)
	if !ok {
		return m, nil
	}
	switch key.String() {
	case "up":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down":
		if m.cursor < len(options)-1 {
			m.cursor++
		}
	case "enter", "space":
		// Restore the install-time menu choices (default shell, lockscreen
		// plugin, ...) so the reused deploy/tweak steps don't silently
		// revert them to hardcoded defaults during an update.
		for k, v := range runner.LoadInstallEnv() {
			m.ctx.Answers[k] = v
		}
		m.ctx.Answers["UPDATE_BRANCH"] = options[m.cursor].id
		if steps, err := config.LoadManifest(m.ctx.BundleDir, "update-steps.json"); err == nil {
			m.ctx.Cfg.Manifest = steps
		}
		return m, app.Push(review.New(m.ctx))
	case "esc", "left":
		return m, app.Pop()
	}
	return m, nil
}

func (m Model) View() tea.View {
	rows := make([]widgets.ListOption, len(options))
	for i, o := range options {
		rows[i] = widgets.ListOption{Label: o.id, Desc: o.help}
	}
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Update Caelestia")
	b.WriteString(m.ctx.Theme.Normal.Render("Choose the branch to update from."))
	b.WriteString("\n\n")
	widgets.RenderOptionList(&b, m.ctx.Theme, m.ctx.Width-2, rows, m.cursor)
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "↑/↓", " to choose, ", "Enter", " to continue, ", "Esc", " to go back")
	return tea.NewView(b.String())
}
