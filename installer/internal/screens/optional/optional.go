// Package optional asks whether to also theme supported third-party apps,
// before moving on to the full configuration menu.
package optional

import (
	"strings"

	tea "charm.land/bubbletea/v2"

	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/app"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/manifest"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/screens/configure"
	"github.com/ladybug-me/caelestia-dots-kde/installer/internal/widgets"
)

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
		if m.cursor < 1 {
			m.cursor++
		}
	case "enter", "space":
		if m.cursor == 0 {
			manifest.EnableOptionalApps(m.ctx.Cfg.Menu, m.ctx.Answers)
		}
		return m, app.Push(configure.New(m.ctx))
	case "esc":
		m.ctx.ExitCode = 0
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) View() tea.View {
	options := []widgets.ListOption{
		{Label: "Yes - also theme my applications", Desc: "Adds theming for VSCode/VSCodium, Zed, Spicetify, Discord/Equibop, Todoist, and Firefox."},
		{Label: "No - keep the standard install", Desc: "Installs the shell, packages, and theming only."},
	}
	var b strings.Builder
	widgets.RenderPageStart(&b, m.ctx.Theme, m.ctx.Cfg, "Optional App Theming")
	b.WriteString(m.ctx.Theme.Normal.Render("Theme supported applications alongside Caelestia."))
	b.WriteString("\n\n")
	widgets.RenderOptionList(&b, m.ctx.Theme, m.ctx.Width-2, options, m.cursor)
	b.WriteByte('\n')
	widgets.RenderFooter(&b, m.ctx.Theme, "↑/↓", " to choose, ", "Enter", " to confirm, ", "Esc", " to cancel installation")
	return tea.NewView(b.String())
}
